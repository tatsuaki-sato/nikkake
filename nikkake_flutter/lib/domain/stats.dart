import '../models/models.dart';
import 'date_utils.dart';

/// 進捗画面の集計。すべて純粋関数。

/// その日「やった（実施した）」と数える基準。
/// 通算回数・カレンダー・実施状況など「活動量」の集計に使う。
/// 中断(skipped)以外はすべて実施した日として扱う。
bool didWorkout(RoutineLog log) => log.status != LogStatus.skipped;

/// その日「完了した」と数える基準。ストリークと「今日は完了」判定に使う。
/// 2026-11-14 の仕様変更で、partial は完了日に数えない
/// （サーバ側 Domain::Stats.completed_day? と同じ基準）。
bool completedDay(RoutineLog log) => log.status == LogStatus.completed;

/// 連続日数。数えるのは全セット完了(completed)の日だけ。
/// 「今日まだやっていない」だけで途切れた表示になるのは体験が悪いので、
/// 最終完了日が今日か昨日ならストリークは生きているものとして数える。
StreakInfo calculateStreak(List<RoutineLog> logs, [DateTime? now]) {
  final today = now ?? DateTime.now();
  final dates = logs.where(completedDay).map((l) => l.logDate).toSet().toList()..sort();

  if (dates.isEmpty) {
    return const StreakInfo(current: 0, longest: 0);
  }

  var longest = 1;
  var run = 1;
  for (var i = 1; i < dates.length; i++) {
    final gap = daysBetween(parseDateString(dates[i - 1]), parseDateString(dates[i]));
    run = gap == 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  final lastDate = dates.last;
  final gapFromToday = daysBetween(parseDateString(lastDate), today);

  var current = 0;
  if (gapFromToday <= 1) {
    current = 1;
    for (var i = dates.length - 1; i > 0; i--) {
      final gap = daysBetween(parseDateString(dates[i - 1]), parseDateString(dates[i]));
      if (gap != 1) break;
      current++;
    }
  }

  return StreakInfo(current: current, longest: longest, lastCompletedDate: lastDate);
}

/// 直近n日分の実施状況。記録の無い日も0で埋めて返す
List<DailyStats> calculateDailyStats(List<RoutineLog> logs, int days, [DateTime? now]) {
  final today = now ?? DateTime.now();
  final byDate = <String, List<RoutineLog>>{};
  for (final log in logs) {
    byDate.putIfAbsent(log.logDate, () => []).add(log);
  }

  final result = <DailyStats>[];
  for (var i = days - 1; i >= 0; i--) {
    final date = getDateString(addDays(today, -i));
    final dayLogs = byDate[date] ?? const <RoutineLog>[];
    result.add(DailyStats(
      date: date,
      completedCount: dayLogs.where(didWorkout).length,
      totalCount: dayLogs.length,
    ));
  }
  return result;
}

/// カレンダー用の「実施した日」の集合
Set<String> completedDateSet(List<RoutineLog> logs) =>
    logs.where(didWorkout).map((l) => l.logDate).toSet();

/// 種目ごとの推移。重量種目は最大重量、時間・回数種目は合計が伸びを表す
List<ExerciseProgressPoint> calculateExerciseProgress(
  String exerciseId,
  List<RoutineLog> routineLogs,
  List<ExerciseLog> exerciseLogs,
) {
  final dateByLogId = {for (final l in routineLogs) l.id: l.logDate};
  final byDate = <String, List<ExerciseLog>>{};

  for (final log in exerciseLogs) {
    if (log.exerciseId != exerciseId) continue;
    final date = dateByLogId[log.routineLogId];
    if (date == null) continue;
    byDate.putIfAbsent(date, () => []).add(log);
  }

  final points = byDate.entries.map((entry) {
    var maxWeight = 0.0;
    var totalReps = 0;
    var totalVolume = 0.0;

    for (final s in entry.value) {
      final w = s.actualWeight ?? 0;
      final r = s.actualReps ?? 0;
      if (w > maxWeight) maxWeight = w;
      totalReps += r;
      totalVolume += w * r;
    }

    return ExerciseProgressPoint(
      date: entry.key,
      maxWeight: maxWeight,
      totalReps: totalReps,
      totalVolume: totalVolume,
    );
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return points;
}

/// そのワークアウトの総挙上量(kg×回)。自重種目は0になる
double calculateVolume(List<ExerciseLog> logs) => logs.fold(
      0.0,
      (sum, l) => sum + (l.actualWeight ?? 0) * (l.actualReps ?? 0),
    );

OverallStats calculateOverallStats(
  List<RoutineLog> routineLogs,
  List<ExerciseLog> exerciseLogs, [
  DateTime? now,
]) {
  final today = now ?? DateTime.now();
  final done = routineLogs.where(didWorkout).toList();
  final weekAgo = getDateString(addDays(today, -6));

  return OverallStats(
    totalWorkouts: done.length,
    totalDurationSec: done.fold(0, (sum, l) => sum + (l.durationSec ?? 0)),
    totalSets: exerciseLogs.length,
    thisWeekCount: done.where((l) => l.logDate.compareTo(weekAgo) >= 0).length,
  );
}

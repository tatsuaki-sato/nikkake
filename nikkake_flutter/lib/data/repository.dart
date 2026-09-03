import '../constants/exercises.dart';
import '../domain/date_utils.dart';
import '../domain/stats.dart';
import '../models/models.dart';
import 'local_db.dart';
import 'nikkake_repository.dart';

/// 端末ローカルを真実の源とする実装。
///
/// 参照も更新も必ずローカルストレージに対して行い、ネットワークは介在しない。
/// サーバに登録できていない状態でもアプリが完全に動くのは、この実装があるため。
///
/// 集計済みビューは ServerRepository と同じ型を返す。
/// 区分の基準を変えるときは、サーバの HomeViewBuilder なども同時に直すこと。
class Repository implements NikkakeRepository {
  final LocalDb db;

  Repository(this.db);

  // ==============================
  // 初期データ
  // ==============================

  /// 初回起動時のデータ投入。
  /// サインインなしで即使えるよう、起動時点で「今日やるルーティン」を1つ用意する。
  /// ユーザーが消したあとに復活すると鬱陶しいので、投入は meta.seeded で1度だけ。
  @override
  Future<bool> seedIfNeeded() async {
    final meta = db.getMeta();
    await _syncPresetExercises();

    if (meta.seeded) return false;

    await _createStarterRoutine();
    await db.setMeta(seeded: true);
    return true;
  }

  /// アプリ側の定義に存在してローカルに無いプリセット種目を足す
  Future<int> _syncPresetExercises() async {
    final existingIds = db.listRaw(Collections.exercises).map((r) => r['id'] as String).toSet();
    final missing = presetExercises.where((p) => !existingIds.contains(p.id)).toList();
    if (missing.isEmpty) return 0;

    await db.insertMany(
      Collections.exercises,
      missing
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'category': p.category.name,
                'description': null,
                'icon': p.icon,
                'is_preset': true,
                'created_by': null,
              })
          .toList(),
    );

    return missing.length;
  }

  /// 初期ルーティンのIDは端末ごとに採番する（固定値にしない）。
  ///
  /// ローカルだけで完結していた頃は固定でも無害だったが、
  /// サーバへ預ける今は全端末が同じIDを送ることになり、
  /// 主キー衝突で2人目以降の初期ルーティンが黙って消える。
  Future<void> _createStarterRoutine() async {
    final routineId = LocalDb.newId();

    await db.insert(Collections.routines, {
      'id': routineId,
      'user_id': null,
      'name': starterRoutineName,
      'description': '器具なしで今すぐ始められる基本メニューです。自由に編集してください。',
      'color': routineColors.first,
      'icon': routineIcons.first,
      'frequency_type': 'daily',
      'frequency_value': 1,
      'frequency_days': <int>[],
      'preferred_time': null,
      'is_active': true,
      'sort_order': 0,
    });

    var index = 0;
    await db.insertMany(
      Collections.routineExercises,
      starterRoutineExercises.map((e) {
        final row = {
          'routine_id': routineId,
          'exercise_id': e.exerciseId,
          'sort_order': index,
          'target_sets': e.sets,
          'target_reps': e.reps,
          'target_weight': null,
          'target_duration_sec': e.durationSec,
          'rest_sec': e.restSec,
          'notes': null,
        };
        index++;
        return row;
      }).toList(),
    );
  }

  // ==============================
  // Exercises
  // ==============================

  List<Exercise> _listExercises() {
    final rows = db.list(Collections.exercises).map(Exercise.fromJson).toList();
    rows.sort((a, b) {
      if (a.category != b.category) return a.category.index.compareTo(b.category.index);
      return a.name.compareTo(b.name);
    });
    return rows;
  }

  @override
  Future<Exercise> createCustomExercise({
    required String name,
    required ExerciseCategory category,
    String? icon,
  }) async {
    final row = await db.insert(Collections.exercises, {
      'name': name,
      'category': category.name,
      'description': null,
      'icon': icon,
      'is_preset': false,
      'created_by': null,
    });
    return Exercise.fromJson(row);
  }

  // ==============================
  // Routines
  // ==============================

  List<Routine> listRoutines() {
    final rows = db.list(Collections.routines).map(Routine.fromJson).toList();
    rows.sort((a, b) {
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return a.createdAt.compareTo(b.createdAt);
    });
    return rows;
  }

  List<RoutineWithExercises> _listRoutinesWithExercises() {
    final routines = listRoutines();
    final links = db.list(Collections.routineExercises).map(RoutineExercise.fromJson).toList();
    final exerciseById = {for (final e in _listExercises()) e.id: e};

    return routines.map((routine) {
      final own = links.where((l) => l.routineId == routine.id).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return RoutineWithExercises(
        routine: routine,
        exercises: own
            // 種目が削除済みのリンクが残っていても画面を落とさない
            .where((l) => exerciseById.containsKey(l.exerciseId))
            .map((l) => RoutineExerciseWithExercise(link: l, exercise: exerciseById[l.exerciseId]!))
            .toList(),
      );
    }).toList();
  }

  RoutineWithExercises? _getRoutineWithExercises(String routineId) {
    for (final r in _listRoutinesWithExercises()) {
      if (r.id == routineId) return r;
    }
    return null;
  }

  @override
  Future<Routine> createRoutine(RoutineInput input) async {
    final existing = listRoutines();

    final row = await db.insert(Collections.routines, {
      'user_id': null,
      'name': input.name,
      'description': input.description,
      'color': input.color,
      'icon': input.icon,
      'frequency_type': frequencyTypeToJson(input.frequencyType),
      'frequency_value': input.frequencyValue,
      'frequency_days': input.frequencyDays,
      'preferred_time': null,
      'is_active': input.isActive,
      'sort_order': existing.length,
    });

    final routine = Routine.fromJson(row);
    await _replaceRoutineExercises(routine.id, input.exercises);
    return routine;
  }

  @override
  Future<Routine?> updateRoutine(String routineId, RoutineInput input) async {
    final row = await db.update(Collections.routines, routineId, {
      'name': input.name,
      'description': input.description,
      'color': input.color,
      'icon': input.icon,
      'frequency_type': frequencyTypeToJson(input.frequencyType),
      'frequency_value': input.frequencyValue,
      'frequency_days': input.frequencyDays,
      'is_active': input.isActive,
    });
    if (row == null) return null;

    await _replaceRoutineExercises(routineId, input.exercises);
    return Routine.fromJson(row);
  }

  /// ルーティン内の種目構成を丸ごと差し替える。
  /// 差分更新にすると並び順の入れ替えが厄介なので、既存リンクを論理削除して作り直す。
  /// 過去のログは exercise_id でも引けるので、作り直しても履歴グラフは途切れない。
  Future<void> _replaceRoutineExercises(
    String routineId,
    List<RoutineExerciseInput> exercises,
  ) async {
    await db.softDeleteWhere(
      Collections.routineExercises,
      (row) => row['routine_id'] == routineId,
    );

    if (exercises.isEmpty) return;

    var index = 0;
    await db.insertMany(
      Collections.routineExercises,
      exercises.map((e) {
        final row = {
          'routine_id': routineId,
          'exercise_id': e.exerciseId,
          'sort_order': index,
          'target_sets': e.targetSets,
          'target_reps': e.targetReps,
          'target_weight': e.targetWeight,
          'target_duration_sec': e.targetDurationSec,
          'rest_sec': e.restSec ?? defaultRestSec,
          'notes': null,
        };
        index++;
        return row;
      }).toList(),
    );
  }

  @override
  Future<void> setRoutineActive(String routineId, bool isActive) async {
    await db.update(Collections.routines, routineId, {'is_active': isActive});
  }

  @override
  Future<void> deleteRoutine(String routineId) async {
    await db.softDeleteWhere(
      Collections.routineExercises,
      (row) => row['routine_id'] == routineId,
    );
    await db.softDelete(Collections.routines, routineId);
  }

  // ==============================
  // Logs
  // ==============================


  // ==============================
  // ローカル専用の同期API
  // ==============================
  //
  // 契約（NikkakeRepository）には載せない。サーバ実装には対応する口が無いため。
  // 端末に何が書かれたかを確かめるテストからだけ使う。

  List<RoutineLog> listRoutineLogs() =>
      db.list(Collections.routineLogs).map(RoutineLog.fromJson).toList();

  List<ExerciseLog> listExerciseLogs() =>
      db.list(Collections.exerciseLogs).map(ExerciseLog.fromJson).toList();

  List<RoutineLog> getTodayLogs() {
    final today = getDateString();
    return listRoutineLogs().where((l) => l.logDate == today).toList();
  }

  /// ホーム画面用。ルーティンごとに「今日やるべきか」「今日もう終わったか」を解決して返す
  List<TodayRoutine> getTodayRoutines([DateTime? now]) {
    final today = getDateString(now);
    final logs = listRoutineLogs();

    return _listRoutinesWithExercises().where((r) => r.routine.isActive).map((routine) {
      final routineLogs = logs.where((l) => l.routineId == routine.id).toList()
        ..sort((a, b) => b.logDate.compareTo(a.logDate));

      RoutineLog? todayLog;
      RoutineLog? lastLog;
      for (final log in routineLogs) {
        if (todayLog == null && log.logDate == today) todayLog = log;
        if (lastLog == null && log.status != LogStatus.skipped) lastLog = log;
      }

      return TodayRoutine(
        routine: routine,
        // 全セット完了でなくても、記録を残した時点で今日の分は済んだものとして扱う。
        // ストリークの判定(stats.didWorkout)と基準を揃えている。
        isCompleted: todayLog != null && todayLog.status != LogStatus.skipped,
        isDueToday: isRoutineDueToday(routine.routine, lastLog, now),
        frequencyLabel: formatFrequency(routine.routine),
      );
    }).toList();
  }

  /// ワークアウト1回分の保存。
  ///
  /// status は入力として受け取らない。完了セット数から必ずここで導出する。
  /// 呼び出し側に決めさせると、サーバの WorkoutRecorder との判定基準が
  /// ずれても誰も気づけない。
  @override
  Future<WorkoutSummary> saveWorkout({
    required String routineId,
    required DateTime startedAt,
    required int durationSec,
    required List<SaveWorkoutExercise> exercises,
    String? notes,
  }) async {
    final tally = tallyWorkout(exercises);
    final status = resolveWorkoutStatus(tally.completedSets, tally.totalSets);

    final row = await db.insert(Collections.routineLogs, {
      'routine_id': routineId,
      'user_id': null,
      'log_date': getDateString(startedAt.toLocal()),
      'status': status.name,
      'duration_sec': durationSec,
      'notes': notes,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });

    final routineLog = RoutineLog.fromJson(row);

    final exerciseLogs = <Map<String, dynamic>>[];
    for (final exercise in exercises) {
      for (final set in exercise.sets.where((s) => s.completed)) {
        exerciseLogs.add({
          'routine_log_id': routineLog.id,
          'routine_exercise_id': exercise.routineExerciseId,
          'exercise_id': exercise.exerciseId,
          'set_number': set.setNumber,
          'actual_reps': set.reps,
          'actual_weight': set.weight,
          'actual_duration_sec': set.durationSec,
          'notes': null,
        });
      }
    }

    await db.insertMany(Collections.exerciseLogs, exerciseLogs);

    final routine = listRoutines().where((r) => r.id == routineId).firstOrNull;

    return WorkoutSummary(
      routineLogId: routineLog.id,
      routineName: routine?.name ?? '',
      durationSec: durationSec,
      completedSets: tally.completedSets,
      totalSets: tally.totalSets,
      totalVolume: tally.totalVolume,
      status: status,
    );
  }

  Future<void> deleteRoutineLog(String routineLogId) async {
    await db.softDeleteWhere(
      Collections.exerciseLogs,
      (row) => row['routine_log_id'] == routineLogId,
    );
    await db.softDelete(Collections.routineLogs, routineLogId);
  }

  /// 前回のワークアウトで各種目を何kg×何回やったか。
  /// ワークアウト画面で「前回の記録」を初期値に出すために使う。
  Map<String, List<WorkoutSet>> getLastSetsByExercise(String routineId) {
    final logs = listRoutineLogs()
        .where((l) => l.routineId == routineId && l.status != LogStatus.skipped)
        .toList();
    if (logs.isEmpty) return {};

    logs.sort((a, b) {
      final aAt = a.startedAt ?? a.createdAt;
      final bAt = b.startedAt ?? b.createdAt;
      return bAt.compareTo(aAt);
    });

    final latest = logs.first;
    final result = <String, List<WorkoutSet>>{};

    for (final log in listExerciseLogs().where((l) => l.routineLogId == latest.id)) {
      result.putIfAbsent(log.exerciseId, () => []).add(WorkoutSet(
            setNumber: log.setNumber,
            reps: log.actualReps,
            weight: log.actualWeight,
            durationSec: log.actualDurationSec,
            completed: true,
          ));
    }

    for (final sets in result.values) {
      sets.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    }
    return result;
  }

  @override
  Future<DataCounts> getCounts() async => DataCounts(
        routines: db.list(Collections.routines).length,
        exercises: db.list(Collections.exercises).length,
        routineLogs: db.list(Collections.routineLogs).length,
        exerciseLogs: db.list(Collections.exerciseLogs).length,
      );

  @override
  Future<void> resetAll() async {
    await db.reset();
    await seedIfNeeded();
  }

  /// サーバモードにしかない概念。ローカルでは常に送信済み扱い
  @override
  Future<int> pendingCount() async => 0;

  // ==============================
  // 契約が要求する非同期の口
  // ==============================
  //
  // 中身は同期で終わるが、ServerRepository と形を揃えるために Future で包む。

  @override
  Future<List<Exercise>> listExercises() async => _listExercises();

  @override
  Future<List<RoutineWithExercises>> listRoutinesWithExercises() async =>
      _listRoutinesWithExercises();

  @override
  Future<RoutineWithExercises?> getRoutineWithExercises(String routineId) async =>
      _getRoutineWithExercises(routineId);

  @override
  Future<HomeView> getHome([DateTime? now]) async {
    final items = getTodayRoutines(now);

    return HomeView(
      today: getDateString(now),
      streak: calculateStreak(listRoutineLogs(), now),
      due: items.where((i) => i.isDueToday && !i.isCompleted).toList(),
      notScheduled: items.where((i) => !i.isDueToday && !i.isCompleted).toList(),
      completed: items.where((i) => i.isCompleted).toList(),
    );
  }

  @override
  Future<ProgressView> getProgress({int rangeDays = 7, DateTime? now}) async {
    final routineLogs = listRoutineLogs();
    final exerciseLogs = listExerciseLogs();
    final loggedIds = exerciseLogs.map((l) => l.exerciseId).toSet();

    return ProgressView(
      overall: calculateOverallStats(routineLogs, exerciseLogs, now),
      streak: calculateStreak(routineLogs, now),
      dailyStats: calculateDailyStats(routineLogs, rangeDays, now),
      completedDates: completedDateSet(routineLogs),
      exercisesWithLogs:
          _listExercises().where((e) => loggedIds.contains(e.id)).toList(),
    );
  }

  @override
  Future<List<ExerciseProgressPoint>> getExerciseProgressPoints(
    String exerciseId, {
    int limit = 8,
  }) async {
    final points =
        calculateExerciseProgress(exerciseId, listRoutineLogs(), listExerciseLogs());
    return points.length <= limit ? points : points.sublist(points.length - limit);
  }

  @override
  Future<DayView> getDay(String date) async {
    final exerciseLogs = listExerciseLogs();
    final routineName = {for (final r in listRoutines()) r.id: r.name};
    final exerciseName = {for (final e in _listExercises()) e.id: e.name};

    final workouts = (listRoutineLogs().where((l) => l.logDate == date).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
        .map((log) {
      final byExercise = <String, List<ExerciseLog>>{};
      final sets = exerciseLogs.where((s) => s.routineLogId == log.id).toList()
        ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
      for (final s in sets) {
        byExercise.putIfAbsent(s.exerciseId, () => []).add(s);
      }

      return DayWorkout(
        routineLogId: log.id,
        routineName: routineName[log.routineId] ?? '',
        status: log.status,
        durationSec: log.durationSec,
        exercises: byExercise.entries
            .map((entry) => DayExerciseSummary(
                  exerciseName: exerciseName[entry.key] ?? '',
                  // 文言はサーバに寄せる。「前回: …」と同じ整形を使う
                  setsLabel: entry.value.isEmpty
                      ? null
                      : formatPreviousSets(entry.value
                          .map((s) => PreviousSetLike(
                                reps: s.actualReps,
                                weight: s.actualWeight,
                                durationSec: s.actualDurationSec,
                              ))
                          .toList()),
                ))
            .toList(),
      );
    }).toList();

    return DayView(date: date, workouts: workouts);
  }

  @override
  Future<WorkoutSessionView?> getWorkoutSession(String routineId) async {
    final routine = _getRoutineWithExercises(routineId);
    if (routine == null) return null;

    final previous = getLastSetsByExercise(routineId);

    return WorkoutSessionView(
      routine: routine,
      exercises: routine.exercises.map((link) {
        final sets = previous[link.exercise.id] ?? const <WorkoutSet>[];

        return WorkoutSessionEntry(
          routineExerciseId: link.link.id,
          exercise: link.exercise,
          targetSets: link.link.targetSets,
          targetReps: link.link.targetReps,
          targetWeight: link.link.targetWeight,
          targetDurationSec: link.link.targetDurationSec,
          restSec: link.link.restSec ?? defaultRestSec,
          previousSets: sets,
          previousLabel: sets.isEmpty
              ? null
              : formatPreviousSets(sets
                  .map((s) => PreviousSetLike(
                        reps: s.reps,
                        weight: s.weight,
                        durationSec: s.durationSec,
                      ))
                  .toList()),
        );
      }).toList(),
    );
  }
}

/// 完了セット数から status を決める。サーバの判定基準と同じ
LogStatus resolveWorkoutStatus(int completedSets, int totalSets) {
  if (completedSets == 0) return LogStatus.skipped;
  if (completedSets >= totalSets) return LogStatus.completed;
  return LogStatus.partial;
}

class WorkoutTally {
  const WorkoutTally(this.completedSets, this.totalSets, this.totalVolume);
  final int completedSets;
  final int totalSets;
  final double totalVolume;
}

WorkoutTally tallyWorkout(List<SaveWorkoutExercise> exercises) {
  var completedSets = 0;
  var totalSets = 0;
  var totalVolume = 0.0;

  for (final exercise in exercises) {
    for (final set in exercise.sets) {
      totalSets++;
      if (set.completed) {
        completedSets++;
        totalVolume += (set.weight ?? 0) * (set.reps ?? 0);
      }
    }
  }

  return WorkoutTally(completedSets, totalSets, totalVolume);
}

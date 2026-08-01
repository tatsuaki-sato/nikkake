import 'package:flutter_test/flutter_test.dart';
import 'package:nikkake_flutter/domain/stats.dart';
import 'package:nikkake_flutter/models/models.dart';
import 'helpers.dart';

void main() {
  group('calculateStreak', () {
    final today = DateTime(2026, 8, 5);

    test('記録が無ければ0', () {
      final result = calculateStreak([], today);
      expect(result.current, 0);
      expect(result.longest, 0);
      expect(result.lastCompletedDate, isNull);
    });

    test('今日まで連続していれば日数を数える', () {
      final logs = [buildLog('2026-08-03'), buildLog('2026-08-04'), buildLog('2026-08-05')];
      expect(calculateStreak(logs, today).current, 3);
    });

    test('今日まだ実施していなくても、昨日やっていればストリークは継続扱い', () {
      final logs = [buildLog('2026-08-03'), buildLog('2026-08-04')];
      expect(calculateStreak(logs, today).current, 2);
    });

    test('2日以上空いていればストリークは切れる', () {
      final logs = [buildLog('2026-08-01'), buildLog('2026-08-02')];
      expect(calculateStreak(logs, today).current, 0);
    });

    test('中断(skipped)はストリークに数えない', () {
      final logs = [buildLog('2026-08-04'), buildLog('2026-08-05', status: LogStatus.skipped)];
      final result = calculateStreak(logs, today);
      expect(result.current, 1);
      expect(result.lastCompletedDate, '2026-08-04');
    });

    test('全種目やりきれなかった日(partial)もストリークは途切れない', () {
      final logs = [buildLog('2026-08-04'), buildLog('2026-08-05', status: LogStatus.partial)];
      expect(calculateStreak(logs, today).current, 2);
    });

    test('過去の最長ストリークを保持する', () {
      final logs = [
        buildLog('2026-07-01'),
        buildLog('2026-07-02'),
        buildLog('2026-07-03'),
        buildLog('2026-07-04'),
        buildLog('2026-08-05'),
      ];
      final result = calculateStreak(logs, today);
      expect(result.longest, 4);
      expect(result.current, 1);
    });
  });

  group('calculateDailyStats', () {
    final today = DateTime(2026, 8, 5);

    test('指定日数分を古い順に、記録の無い日も0で埋めて返す', () {
      final stats = calculateDailyStats([buildLog('2026-08-05'), buildLog('2026-08-03')], 3, today);

      expect(stats.map((s) => s.date).toList(), ['2026-08-03', '2026-08-04', '2026-08-05']);
      expect(stats.map((s) => s.completedCount).toList(), [1, 0, 1]);
    });

    test('途中までのpartialも実施した日として数える', () {
      final stats = calculateDailyStats([buildLog('2026-08-05', status: LogStatus.partial)], 1, today);
      expect(stats.first.completedCount, 1);
      expect(stats.first.totalCount, 1);
    });

    test('中断したskippedは実施に数えない', () {
      final stats = calculateDailyStats([buildLog('2026-08-05', status: LogStatus.skipped)], 1, today);
      expect(stats.first.completedCount, 0);
      expect(stats.first.totalCount, 1);
    });
  });

  group('calculateExerciseProgress', () {
    test('日付ごとに最大重量・総回数・総ボリュームを集計する', () {
      final logA = buildLog('2026-08-01');
      final logB = buildLog('2026-08-03');

      final exerciseLogs = [
        buildExerciseLog(routineLogId: logA.id, exerciseId: 'ex1', setNumber: 1, reps: 10, weight: 60),
        buildExerciseLog(routineLogId: logA.id, exerciseId: 'ex1', setNumber: 2, reps: 8, weight: 65),
        buildExerciseLog(routineLogId: logB.id, exerciseId: 'ex1', setNumber: 1, reps: 10, weight: 70),
        buildExerciseLog(routineLogId: logB.id, exerciseId: 'ex2', setNumber: 1, reps: 12, weight: 20),
      ];

      final progress = calculateExerciseProgress('ex1', [logA, logB], exerciseLogs);

      expect(progress.length, 2);
      expect(progress[0].date, '2026-08-01');
      expect(progress[0].maxWeight, 65);
      expect(progress[0].totalReps, 18);
      expect(progress[0].totalVolume, 10 * 60 + 8 * 65);
      expect(progress[1].maxWeight, 70);
    });

    test('対象の種目が無ければ空', () {
      expect(calculateExerciseProgress('none', [buildLog('2026-08-01')], []), isEmpty);
    });
  });

  group('その他の集計', () {
    test('calculateVolume は自重種目(重量null)を0として扱う', () {
      final logs = [
        buildExerciseLog(routineLogId: 'l1', exerciseId: 'ex1', setNumber: 1, reps: 10),
        buildExerciseLog(routineLogId: 'l1', exerciseId: 'ex1', setNumber: 2, reps: 10, weight: 50),
      ];
      expect(calculateVolume(logs), 500);
    });

    test('completedDateSet は実施した日だけを集める', () {
      final set = completedDateSet([
        buildLog('2026-08-01'),
        buildLog('2026-08-02', status: LogStatus.skipped),
      ]);
      expect(set.contains('2026-08-01'), isTrue);
      expect(set.contains('2026-08-02'), isFalse);
    });

    test('calculateOverallStats は直近7日の回数を含めて集計する', () {
      final today = DateTime(2026, 8, 5);
      final logs = [buildLog('2026-08-05'), buildLog('2026-08-01'), buildLog('2026-07-01')];
      final stats = calculateOverallStats(
        logs,
        [buildExerciseLog(routineLogId: 'l1', exerciseId: 'ex1', setNumber: 1, reps: 10, weight: 50)],
        today,
      );

      expect(stats.totalWorkouts, 3);
      expect(stats.thisWeekCount, 2);
      expect(stats.totalDurationSec, 1800);
      expect(stats.totalSets, 1);
    });
  });
}

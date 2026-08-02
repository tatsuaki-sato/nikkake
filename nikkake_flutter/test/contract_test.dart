import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nikkake_flutter/domain/date_utils.dart';
import 'package:nikkake_flutter/domain/stats.dart';
import 'package:nikkake_flutter/models/models.dart';

/// packages/contract/domain_cases.json を唯一の期待値として検証する。
///
/// Ruby (nikkake_api/spec/domain/contract_spec.rb) と
/// TypeScript (nikkake_react_native/src/lib/__tests__/contract.test.ts) が
/// 同じ JSON を読んでいる。4言語が同じ答えを返すことを CI で保証するのが目的。
///
/// ここが落ちたら、まず Dart 側の実装を疑うこと。
/// 期待値を書き換えて通すのは、仕様変更だと確信できるときだけ。
void main() {
  final cases = jsonDecode(
    File('../packages/contract/domain_cases.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<dynamic> casesOf(String key) =>
      (cases[key] as Map<String, dynamic>)['cases'] as List<dynamic>;

  RoutineLog buildLog(Map<String, dynamic> raw) {
    final now = DateTime.now().toUtc();
    return RoutineLog(
      id: (raw['id'] ?? 'log-${raw['log_date']}-${raw['status']}') as String,
      routineId: 'r1',
      logDate: raw['log_date'] as String,
      status: logStatusFrom((raw['status'] ?? 'completed') as String),
      durationSec: raw['duration_sec'] as int?,
      createdAt: now,
      updatedAt: now,
    );
  }

  ExerciseLog buildSetLog(Map<String, dynamic> raw) {
    final now = DateTime.now().toUtc();
    return ExerciseLog(
      id: '${raw['routine_log_id']}-${raw['exercise_id']}-${raw['set_number']}',
      routineLogId: raw['routine_log_id'] as String,
      exerciseId: raw['exercise_id'] as String,
      setNumber: raw['set_number'] as int,
      actualReps: raw['actual_reps'] as int?,
      actualWeight: (raw['actual_weight'] as num?)?.toDouble(),
      createdAt: now,
      updatedAt: now,
    );
  }

  Routine buildRoutine(Map<String, dynamic> raw) {
    final now = DateTime.now().toUtc();
    return Routine(
      id: 'r1',
      name: 'テスト',
      color: '#6C5CE7',
      icon: '💪',
      frequencyType: frequencyTypeFrom(raw['frequency_type'] as String?),
      frequencyValue: (raw['frequency_value'] as num?)?.toInt() ?? 1,
      frequencyDays:
          ((raw['frequency_days'] as List?) ?? const []).map((e) => e as int).toList(),
      isActive: (raw['is_active'] ?? true) as bool,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('契約: streak', () {
    for (final c in casesOf('streak')) {
      test(c['name'] as String, () {
        final result = calculateStreak(
          (c['logs'] as List).map((e) => buildLog(e as Map<String, dynamic>)).toList(),
          parseDateString(c['today'] as String),
        );
        final expected = c['expect'] as Map<String, dynamic>;

        expect(result.current, expected['current']);
        expect(result.longest, expected['longest']);
        expect(result.lastCompletedDate, expected['lastCompletedDate']);
      });
    }
  });

  group('契約: dueToday', () {
    for (final c in casesOf('dueToday')) {
      test(c['name'] as String, () {
        final lastLog = c['lastLog'] == null
            ? null
            : buildLog(c['lastLog'] as Map<String, dynamic>);

        final result = isRoutineDueToday(
          buildRoutine(c['routine'] as Map<String, dynamic>),
          lastLog,
          parseDateString(c['today'] as String),
        );

        expect(result, c['expect']);
      });
    }
  });

  group('契約: dailyStats', () {
    for (final c in casesOf('dailyStats')) {
      test(c['name'] as String, () {
        final result = calculateDailyStats(
          (c['logs'] as List).map((e) => buildLog(e as Map<String, dynamic>)).toList(),
          c['days'] as int,
          parseDateString(c['today'] as String),
        );

        expect(
          result
              .map((s) => {
                    'date': s.date,
                    'completedCount': s.completedCount,
                    'totalCount': s.totalCount,
                  })
              .toList(),
          c['expect'],
        );
      });
    }
  });

  group('契約: exerciseProgress', () {
    for (final c in casesOf('exerciseProgress')) {
      test(c['name'] as String, () {
        final result = calculateExerciseProgress(
          c['exerciseId'] as String,
          (c['routineLogs'] as List).map((e) => buildLog(e as Map<String, dynamic>)).toList(),
          (c['exerciseLogs'] as List)
              .map((e) => buildSetLog(e as Map<String, dynamic>))
              .toList(),
        );

        final actual = result
            .map((p) => {
                  'date': p.date,
                  'maxWeight': p.maxWeight,
                  'totalReps': p.totalReps,
                  'totalVolume': p.totalVolume,
                })
            .toList();
        final expected = (c['expect'] as List)
            .map((e) => {
                  'date': e['date'],
                  'maxWeight': (e['maxWeight'] as num).toDouble(),
                  'totalReps': e['totalReps'],
                  'totalVolume': (e['totalVolume'] as num).toDouble(),
                })
            .toList();

        expect(actual, expected);
      });
    }
  });

  group('契約: overallStats', () {
    for (final c in casesOf('overallStats')) {
      test(c['name'] as String, () {
        final result = calculateOverallStats(
          (c['routineLogs'] as List).map((e) => buildLog(e as Map<String, dynamic>)).toList(),
          (c['exerciseLogs'] as List)
              .map((e) => buildSetLog(e as Map<String, dynamic>))
              .toList(),
          parseDateString(c['today'] as String),
        );

        expect({
          'totalWorkouts': result.totalWorkouts,
          'totalDurationSec': result.totalDurationSec,
          'totalSets': result.totalSets,
          'thisWeekCount': result.thisWeekCount,
        }, c['expect']);
      });
    }
  });

  group('契約: formatDuration', () {
    for (final c in casesOf('formatDuration')) {
      test(c['name'] as String, () {
        expect(formatDuration(c['seconds'] as int?), c['expect']);
      });
    }
  });

  group('契約: formatWeight', () {
    for (final c in casesOf('formatWeight')) {
      test(c['name'] as String, () {
        expect(formatWeight((c['weight'] as num?)?.toDouble()), c['expect']);
      });
    }
  });

  group('契約: formatFrequency', () {
    for (final c in casesOf('formatFrequency')) {
      test(c['name'] as String, () {
        expect(formatFrequency(buildRoutine(c['routine'] as Map<String, dynamic>)), c['expect']);
      });
    }
  });

  group('契約: greetingForHour', () {
    for (final c in casesOf('greetingForHour')) {
      test(c['name'] as String, () {
        expect(greetingForHour(c['hour'] as int), c['expect']);
      });
    }
  });

  group('契約: formatPreviousSets', () {
    for (final c in casesOf('formatPreviousSets')) {
      test(c['name'] as String, () {
        final sets = (c['sets'] as List)
            .map((e) => PreviousSetLike(
                  reps: e['reps'] as int?,
                  weight: (e['weight'] as num?)?.toDouble(),
                  durationSec: e['duration_sec'] as int?,
                ))
            .toList();

        expect(formatPreviousSets(sets), c['expect']);
      });
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nikkake_flutter/domain/date_utils.dart';
import 'package:nikkake_flutter/models/models.dart';

Routine buildRoutine({
  FrequencyType frequencyType = FrequencyType.daily,
  int frequencyValue = 1,
  List<int> frequencyDays = const [],
  bool isActive = true,
}) {
  final now = DateTime.now().toUtc();
  return Routine(
    id: 'r1',
    name: 'テスト',
    color: '#6C5CE7',
    icon: '💪',
    frequencyType: frequencyType,
    frequencyValue: frequencyValue,
    frequencyDays: frequencyDays,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

RoutineLog buildLog(String logDate) {
  final now = DateTime.now().toUtc();
  return RoutineLog(
    id: 'log-$logDate',
    routineId: 'r1',
    logDate: logDate,
    status: LogStatus.completed,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('日付ユーティリティ', () {
    test('getDateString はローカルタイムの YYYY-MM-DD を返す', () {
      expect(getDateString(DateTime(2026, 8, 1)), '2026-08-01');
      expect(getDateString(DateTime(2026, 1, 9)), '2026-01-09');
    });

    test('parseDateString はローカルの0時として解釈する', () {
      final parsed = parseDateString('2026-08-01');
      expect(parsed.year, 2026);
      expect(parsed.month, 8);
      expect(parsed.day, 1);
    });

    test('daysBetween は時刻を無視して日数差を返す', () {
      expect(daysBetween(DateTime(2026, 8, 1, 23), DateTime(2026, 8, 2, 1)), 1);
      expect(daysBetween(DateTime(2026, 8, 1), DateTime(2026, 8, 1)), 0);
      expect(daysBetween(DateTime(2026, 8, 5), DateTime(2026, 8, 1)), -4);
    });

    test('addDays は月をまたいでも正しく進む', () {
      expect(getDateString(addDays(DateTime(2026, 7, 30), 3)), '2026-08-02');
    });
  });

  group('isRoutineDueToday', () {
    // 2026-08-01 は土曜日
    final today = DateTime(2026, 8, 1);

    test('停止中のルーティンは対象外', () {
      expect(isRoutineDueToday(buildRoutine(isActive: false), null, today), isFalse);
    });

    test('毎日のルーティンは常に対象', () {
      expect(isRoutineDueToday(buildRoutine(), buildLog('2026-07-31'), today), isTrue);
    });

    test('N日ごとは前回からの間隔で判定する', () {
      final routine = buildRoutine(frequencyType: FrequencyType.everyNDays, frequencyValue: 3);
      expect(isRoutineDueToday(routine, buildLog('2026-07-29'), today), isTrue);
      expect(isRoutineDueToday(routine, buildLog('2026-07-30'), today), isFalse);
    });

    test('N日ごとで一度も実施していなければ今日から始められる', () {
      final routine = buildRoutine(frequencyType: FrequencyType.everyNDays, frequencyValue: 7);
      expect(isRoutineDueToday(routine, null, today), isTrue);
    });

    test('曜日指定は今日の曜日で判定する（日曜=0）', () {
      // 土曜 = 6
      expect(
        isRoutineDueToday(
          buildRoutine(frequencyType: FrequencyType.weekly, frequencyDays: [6]),
          null,
          today,
        ),
        isTrue,
      );
      expect(
        isRoutineDueToday(
          buildRoutine(frequencyType: FrequencyType.weekly, frequencyDays: [1, 3]),
          null,
          today,
        ),
        isFalse,
      );
    });

    test('日曜日が 0 として扱われる', () {
      final sunday = DateTime(2026, 8, 2);
      expect(
        isRoutineDueToday(
          buildRoutine(frequencyType: FrequencyType.weekly, frequencyDays: [0]),
          null,
          sunday,
        ),
        isTrue,
      );
    });

    test('曜日指定で曜日が未設定なら毎日扱い', () {
      expect(
        isRoutineDueToday(buildRoutine(frequencyType: FrequencyType.weekly), null, today),
        isTrue,
      );
    });
  });

  group('表示フォーマット', () {
    test('formatDuration は時間・分・秒を切り替える', () {
      expect(formatDuration(0), '0:00');
      expect(formatDuration(65), '1:05');
      expect(formatDuration(3725), '1:02:05');
      expect(formatDuration(null), '--:--');
    });

    test('formatWeight は不要な小数を落とす', () {
      expect(formatWeight(60), '60 kg');
      expect(formatWeight(62.5), '62.5 kg');
      expect(formatWeight(null), '-- kg');
    });

    test('formatFrequency は頻度を日本語にする', () {
      expect(formatFrequency(buildRoutine()), '毎日');
      expect(
        formatFrequency(buildRoutine(frequencyType: FrequencyType.everyNDays, frequencyValue: 3)),
        '3日ごと',
      );
      expect(
        formatFrequency(buildRoutine(frequencyType: FrequencyType.everyNDays, frequencyValue: 1)),
        '毎日',
      );
      expect(
        formatFrequency(buildRoutine(frequencyType: FrequencyType.weekly, frequencyDays: [3, 1])),
        '月・水',
      );
    });

    test('greetingForHour は時間帯に応じた挨拶を返す', () {
      expect(greetingForHour(3), 'おつかれさま');
      expect(greetingForHour(9), 'おはよう！');
      expect(greetingForHour(14), 'こんにちは！');
      expect(greetingForHour(21), 'こんばんは！');
    });
  });
}

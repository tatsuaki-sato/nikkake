import '../models/models.dart';

/// 日付と表示フォーマット。
/// すべて純粋関数なのでストレージ無しで単体テストできる。

String getDateString([DateTime? date]) {
  final d = date ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// 'YYYY-MM-DD' をローカルタイムの0時として解釈する
DateTime parseDateString(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts.length > 1 ? parts[1] : 1, parts.length > 2 ? parts[2] : 1);
}

DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// 時刻を無視した日数差。夏時間で±1時間ずれても丸めで吸収する
int daysBetween(DateTime from, DateTime to) =>
    (startOfDay(to).difference(startOfDay(from)).inHours / 24).round();

DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days, date.hour, date.minute, date.second);

/// そのルーティンを今日やる予定かどうか。
/// 「今日もう終わったか」は別で判定するので、ここでは予定だけを見る。
bool isRoutineDueToday(Routine routine, RoutineLog? lastLog, [DateTime? now]) {
  if (!routine.isActive) return false;
  final today = now ?? DateTime.now();

  switch (routine.frequencyType) {
    case FrequencyType.daily:
      return true;

    case FrequencyType.weekly:
      // 曜日が未設定なら毎日扱いにする
      if (routine.frequencyDays.isEmpty) return true;
      // Dartの weekday は 月=1..日=7。DBは 日=0..土=6 なので合わせる
      final dbWeekday = today.weekday % 7;
      return routine.frequencyDays.contains(dbWeekday);

    case FrequencyType.everyNDays:
      if (lastLog == null) return true; // 一度もやっていなければ今日から始める
      final interval = routine.frequencyValue < 1 ? 1 : routine.frequencyValue;
      return daysBetween(parseDateString(lastLog.logDate), today) >= interval;
  }
}

String formatDuration(int? seconds) {
  if (seconds == null) return '--:--';
  final total = seconds < 0 ? 0 : seconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;

  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatWeight(double? weight) {
  if (weight == null) return '-- kg';
  // 小数第1位まで。.0 は省く
  final rounded = double.parse(weight.toStringAsFixed(1));
  final text = rounded == rounded.roundToDouble() ? rounded.toInt().toString() : rounded.toString();
  return '$text kg';
}

const _dayNames = ['日', '月', '火', '水', '木', '金', '土'];

String formatFrequency(Routine routine) {
  switch (routine.frequencyType) {
    case FrequencyType.daily:
      return '毎日';
    case FrequencyType.everyNDays:
      return routine.frequencyValue <= 1 ? '毎日' : '${routine.frequencyValue}日ごと';
    case FrequencyType.weekly:
      if (routine.frequencyDays.isEmpty) return '毎日';
      final sorted = [...routine.frequencyDays]..sort();
      return sorted.map((d) => _dayNames[d]).join('・');
  }
}

String greetingForHour(int hour) {
  if (hour < 5) return 'おつかれさま';
  if (hour < 12) return 'おはよう！';
  if (hour < 18) return 'こんにちは！';
  return 'こんばんは！';
}

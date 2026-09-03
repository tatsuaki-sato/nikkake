import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../data/nikkake_repository.dart';
import '../domain/date_utils.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/ui.dart';

/// 進捗。
/// グラフ描画ライブラリは使わず、Containerの高さと色だけで表現している。
/// 3プラットフォームで同じ見た目を再現しやすく、依存も増えないため。
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _range = 7;
  String? _selectedExerciseId;
  String? _selectedDate;

  /// 種目別の推移はサーバへの別クエリなので、取れたぶんだけ持っておく
  final Map<String, List<ExerciseProgressPoint>> _pointsByExercise = {};

  Future<void> _loadPoints(AppState state, String exerciseId) async {
    final points = await state.exerciseProgress(exerciseId);
    if (!mounted) return;
    setState(() => _pointsByExercise[exerciseId] = points);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final view = state.progress;

    if (view.overall.totalWorkouts == 0) {
      return const Center(
        child: EmptyState(
          key: Key('progress-empty'),
          icon: '📈',
          title: 'まだ記録がありません',
          message: 'ワークアウトを1回完了すると、ここに推移が出ます。',
        ),
      );
    }

    // 数字はすべてサーバが集計したものを表示するだけ。
    // ここに計算を書き足したら、それはサーバへ移すべきロジックが漏れている。
    final overall = view.overall;
    final streak = view.streak;
    final daily = view.dailyStats;
    final doneDates = view.completedDates;

    // 記録が残っている種目だけが返ってくる
    final loggedExercises = view.exercisesWithLogs;

    final activeExerciseId = _selectedExerciseId ??
        (loggedExercises.isEmpty ? null : loggedExercises.first.id);
    final progress = activeExerciseId == null
        ? const <ExerciseProgressPoint>[]
        : (_pointsByExercise[activeExerciseId] ?? const <ExerciseProgressPoint>[]);

    if (activeExerciseId != null && !_pointsByExercise.containsKey(activeExerciseId)) {
      _loadPoints(state, activeExerciseId);
    }

    final maxCount = daily.fold(1, (m, d) => d.completedCount > m ? d.completedCount : m);

    return ListView(
      key: const Key('progress-screen'),
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Summary(label: '通算', value: '${overall.totalWorkouts}回', valueKey: const Key('progress-total')),
              _Summary(label: '今週', value: '${overall.thisWeekCount}回', valueKey: const Key('progress-week')),
              _Summary(label: '連続', value: '${streak.current}日', valueKey: const Key('progress-streak')),
              _Summary(
                label: '総時間',
                value: formatDuration(overall.totalDurationSec),
                valueKey: const Key('progress-duration'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle('実施状況', padding: EdgeInsets.zero),
            Row(
              children: [
                for (final value in [7, 30])
                  Padding(
                    padding: const EdgeInsets.only(left: Spacing.xs),
                    child: SelectableChip(
                      key: Key('progress-range-$value'),
                      label: '$value日',
                      selected: _range == value,
                      onTap: () {
                        setState(() => _range = value);
                        // 集計期間はサーバに投げ直す。手元で切り出さない
                        context.read<AppState>().setProgressRange(value);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),

        AppCard(
          key: const Key('progress-chart'),
          child: SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: daily
                  .map((day) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: (day.completedCount / maxCount * 96).clamp(4, 96),
                                decoration: BoxDecoration(
                                  color: day.completedCount > 0
                                      ? AppColors.darkSuccess
                                      : AppColors.darkBorder,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              if (_range == 7)
                                Padding(
                                  padding: const EdgeInsets.only(top: Spacing.xs),
                                  child: Text(
                                    day.date.substring(8),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.darkTextSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),

        const SectionTitle('カレンダー'),
        AppCard(
          key: const Key('progress-calendar'),
          child: _MonthGrid(
            doneDates: doneDates,
            selectedDate: _selectedDate,
            onSelectDate: (date) => setState(
              () => _selectedDate = _selectedDate == date ? null : date,
            ),
          ),
        ),
        if (_selectedDate != null) ...[
          const SizedBox(height: Spacing.md),
          _DayDetail(
            key: ValueKey(_selectedDate),
            date: _selectedDate!,
            onClose: () => setState(() => _selectedDate = null),
          ),
        ],
        const SizedBox(height: Spacing.lg),

        const SectionTitle('種目ごとの推移'),
        if (loggedExercises.isEmpty)
          const AppCard(
            child: Text(
              'セット記録が貯まるとここに種目別の推移が出ます。',
              style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
            ),
          )
        else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: loggedExercises
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: Spacing.sm),
                        child: SelectableChip(
                          key: Key('progress-exercise-${e.id}'),
                          label: e.name,
                          selected: activeExerciseId == e.id,
                          onTap: () => setState(() => _selectedExerciseId = e.id),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: Spacing.md),
          AppCard(
            key: const Key('progress-exercise-detail'),
            child: progress.isEmpty
                ? const Text('記録がありません。',
                    style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13))
                : Column(
                    children: progress.reversed
                        .take(8)
                        .map((point) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      point.date.substring(5),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.darkTextSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      point.maxWeight > 0
                                          ? '最大 ${formatWeight(point.maxWeight)}'
                                          : '${point.totalReps} 回',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkTextPrimary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      point.totalVolume > 0
                                          ? '${point.totalVolume.round()}kg'
                                          : '計 ${point.totalReps}回',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.darkTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
        const SizedBox(height: Spacing.xl),
      ],
    );
  }
}

/// カレンダー。実施した日を塗る。◀▶ で前月・翌月へ移動でき、日をタップするとその日の内容を開く
class _MonthGrid extends StatefulWidget {
  final Set<String> doneDates;
  final String? selectedDate;
  final ValueChanged<String> onSelectDate;

  const _MonthGrid({
    required this.doneDates,
    required this.selectedDate,
    required this.onSelectDate,
  });

  @override
  State<_MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<_MonthGrid> {
  int _monthsBack = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final view = DateTime(now.year, now.month - _monthsBack, 1);
    final daysInMonth = DateTime(view.year, view.month + 1, 0).day;
    // Dartの weekday は 月=1..日=7。カレンダーは日曜始まりなので変換する
    final leadingBlanks = view.weekday % 7;
    final todayString = getDateString(now);

    final cells = <String?>[
      ...List<String?>.filled(leadingBlanks, null),
      ...List.generate(daysInMonth, (i) => getDateString(addDays(view, i))),
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              key: const Key('calendar-prev'),
              onPressed: () => setState(() => _monthsBack++),
              icon: const Icon(Icons.chevron_left, size: 20),
              color: AppColors.darkPrimaryLight,
              tooltip: '前の月',
              visualDensity: VisualDensity.compact,
            ),
            Text(
              '${view.year}年${view.month}月',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
            ),
            IconButton(
              key: const Key('calendar-next'),
              onPressed:
                  _monthsBack == 0 ? null : () => setState(() => _monthsBack--),
              icon: const Icon(Icons.chevron_right, size: 20),
              color: AppColors.darkPrimaryLight,
              tooltip: '次の月',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: ['日', '月', '火', '水', '木', '金', '土']
              .map((d) => Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: Spacing.xs),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells.map((date) {
            if (date == null) return const SizedBox.shrink();
            final done = widget.doneDates.contains(date);
            final isToday = date == todayString;
            final isSelected = date == widget.selectedDate;

            return GestureDetector(
              key: Key('calendar-day-$date'),
              onTap: () => widget.onSelectDate(date),
              child: Container(
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.darkSuccess : null,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: isSelected
                      ? Border.all(color: AppColors.darkPrimary, width: 2)
                      : isToday
                          ? Border.all(color: AppColors.darkPrimaryLight)
                          : null,
                ),
                child: Text(
                  int.parse(date.substring(8)).toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: done ? AppColors.darkBackground : AppColors.darkTextSecondary,
                    fontWeight: done ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// カレンダーで選んだ日のワークアウト内容。集計と同じくサーバが整形して返す
class _DayDetail extends StatefulWidget {
  final String date;
  final VoidCallback onClose;

  const _DayDetail({super.key, required this.date, required this.onClose});

  @override
  State<_DayDetail> createState() => _DayDetailState();
}

class _DayDetailState extends State<_DayDetail> {
  late final Future<DayView> _future =
      context.read<AppState>().day(widget.date);

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final onClose = widget.onClose;

    return AppCard(
      key: const Key('progress-day-detail'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${date.substring(5).replaceFirst('-', '/')} の記録',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkTextPrimary,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 18, color: AppColors.darkTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          FutureBuilder<DayView>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Text('読み込み中…',
                    style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13));
              }
              final workouts = snapshot.data!.workouts;
              if (workouts.isEmpty) {
                return const Text('この日の記録はありません。',
                    style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final workout in workouts)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                workout.routineName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkTextPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              if (workout.durationSec != null)
                                Text(
                                  formatDuration(workout.durationSec!),
                                  style: const TextStyle(
                                    color: AppColors.darkTextSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                          for (final exercise in workout.exercises)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    exercise.exerciseName,
                                    style: const TextStyle(
                                      color: AppColors.darkTextSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    exercise.setsLabel ?? '—',
                                    style: const TextStyle(
                                      color: AppColors.darkTextPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final Key valueKey;

  const _Summary({required this.label, required this.value, required this.valueKey});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
          const SizedBox(height: Spacing.xs),
          Text(
            value,
            key: valueKey,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ],
      );
}

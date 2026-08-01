import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../domain/date_utils.dart';
import '../domain/stats.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final routineLogs = state.routineLogs;
    final exerciseLogs = state.exerciseLogs;

    if (routineLogs.isEmpty) {
      return const Center(
        child: EmptyState(
          key: Key('progress-empty'),
          icon: '📈',
          title: 'まだ記録がありません',
          message: 'ワークアウトを1回完了すると、ここに推移が出ます。',
        ),
      );
    }

    final overall = calculateOverallStats(routineLogs, exerciseLogs);
    final streak = calculateStreak(routineLogs);
    final daily = calculateDailyStats(routineLogs, _range);
    final doneDates = completedDateSet(routineLogs);

    // 記録が残っている種目だけを選択肢にする
    final loggedIds = exerciseLogs.map((l) => l.exerciseId).toSet();
    final loggedExercises = state.exercises.where((e) => loggedIds.contains(e.id)).toList();

    final activeExerciseId = _selectedExerciseId ??
        (loggedExercises.isEmpty ? null : loggedExercises.first.id);
    final progress = activeExerciseId == null
        ? <ExerciseProgressPoint>[]
        : calculateExerciseProgress(activeExerciseId, routineLogs, exerciseLogs);

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
                      onTap: () => setState(() => _range = value),
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
        AppCard(key: const Key('progress-calendar'), child: _MonthGrid(doneDates: doneDates)),
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

/// 当月のカレンダー。実施した日を塗る
class _MonthGrid extends StatelessWidget {
  final Set<String> doneDates;

  const _MonthGrid({required this.doneDates});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstOfMonth = DateTime(today.year, today.month, 1);
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    // Dartの weekday は 月=1..日=7。カレンダーは日曜始まりなので変換する
    final leadingBlanks = firstOfMonth.weekday % 7;
    final todayString = getDateString(today);

    final cells = <String?>[
      ...List<String?>.filled(leadingBlanks, null),
      ...List.generate(daysInMonth, (i) => getDateString(addDays(firstOfMonth, i))),
    ];

    return Column(
      children: [
        Text(
          '${today.year}年${today.month}月',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
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
            final done = date != null && doneDates.contains(date);
            final isToday = date == todayString;

            return Container(
              margin: const EdgeInsets.all(2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? AppColors.darkSuccess : null,
                borderRadius: BorderRadius.circular(Radii.sm),
                border: isToday ? Border.all(color: AppColors.darkPrimaryLight) : null,
              ),
              child: Text(
                date == null ? '' : int.parse(date.substring(8)).toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: done ? AppColors.darkBackground : AppColors.darkTextSecondary,
                  fontWeight: done ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ],
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

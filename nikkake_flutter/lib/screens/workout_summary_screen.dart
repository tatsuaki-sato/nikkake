import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../domain/date_utils.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../providers/workout_controller.dart';
import '../widgets/ui.dart';

/// ワークアウト完了直後のサマリー。
/// 「今やった分がちゃんと記録された」ことを見せて、連続記録が伸びたことを返す画面。
class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key});

  void _goHome(BuildContext context) {
    context.read<WorkoutController>().clearSummary();
    // スタックの一番下(タブ画面)まで戻る。pushで積み直すとタブが二重になる
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<WorkoutController>().lastSummary;
    final streak = context.watch<AppState>().home.streak;

    if (summary == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: EmptyState(
            key: const Key('summary-empty'),
            icon: '🤔',
            title: '表示できる記録がありません',
            message: 'ワークアウトを完了するとここに結果が出ます。',
            action: AppButton(label: 'ホームへ', onPressed: () => _goHome(context)),
          ),
        ),
      );
    }

    final statusLabel = switch (summary.status) {
      LogStatus.completed => 'コンプリート！',
      LogStatus.partial => '記録しました',
      LogStatus.skipped => '記録なし',
    };

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: ListView(
          key: const Key('summary-screen'),
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            const SizedBox(height: Spacing.xl),
            Center(
              child: Text(
                summary.status == LogStatus.completed ? '🎉' : '💪',
                style: const TextStyle(fontSize: 64),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Center(
              child: Text(
                statusLabel,
                key: const Key('summary-status'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Center(
              child: Text(
                summary.routineName,
                style: const TextStyle(fontSize: 15, color: AppColors.darkTextSecondary),
              ),
            ),
            const SizedBox(height: Spacing.xl),

            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(
                    label: '時間',
                    value: formatDuration(summary.durationSec),
                    valueKey: const Key('summary-duration'),
                  ),
                  _Stat(
                    label: 'セット',
                    value: '${summary.completedSets}/${summary.totalSets}',
                    valueKey: const Key('summary-sets'),
                  ),
                  _Stat(
                    label: '総重量',
                    value: summary.totalVolume > 0 ? '${summary.totalVolume.round()} kg' : '—',
                    valueKey: const Key('summary-volume'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),

            AppCard(
              color: AppColors.darkSurfaceElevated,
              child: Row(
                children: [
                  Text(streak.current > 0 ? '🔥' : '🌱', style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: Spacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('連続記録',
                          style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary)),
                      Text(
                        '${streak.current} 日',
                        key: const Key('summary-streak'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xl),

            AppButton(
              key: const Key('summary-home'),
              label: 'ホームに戻る',
              onPressed: () => _goHome(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Key valueKey;

  const _Stat({required this.label, required this.value, required this.valueKey});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary)),
          const SizedBox(height: Spacing.xs),
          Text(
            value,
            key: valueKey,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ],
      );
}

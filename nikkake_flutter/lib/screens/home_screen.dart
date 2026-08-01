import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../domain/date_utils.dart';
import '../domain/stats.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/ui.dart';
import 'routine_form_screen.dart';
import 'workout_screen.dart';

/// ホーム。アプリを開いた直後に見る画面。
/// サインインの有無に関係なく、ここに「今日やるルーティン」が並んでいて
/// 1タップで開始できる状態にしておくことがこの画面の唯一の役目。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final streak = calculateStreak(state.routineLogs);

    final today = state.todayRoutines;
    final due = today.where((t) => t.isDueToday && !t.isCompleted).toList();
    final later = today.where((t) => !t.isDueToday && !t.isCompleted).toList();
    final done = today.where((t) => t.isCompleted).toList();

    return RefreshIndicator(
      onRefresh: () async => state.refresh(),
      child: ListView(
        key: const Key('home-screen'),
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          _Header(),
          const SizedBox(height: Spacing.lg),
          _StreakBanner(streak: streak),
          const SizedBox(height: Spacing.xl),
          const Text(
            '今日のルーティン',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: Spacing.md),

          if (today.isEmpty)
            EmptyState(
              key: const Key('home-empty'),
              icon: '📋',
              title: 'ルーティンがありません',
              message: 'まずは1つ作ってみましょう。作ったその日から記録が残ります。',
              action: AppButton(
                label: 'ルーティンを作る',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoutineFormScreen()),
                ),
              ),
            )
          else if (due.isEmpty && later.isEmpty)
            const EmptyState(
              key: Key('home-all-done'),
              icon: '🎉',
              title: '今日の分は完了です',
              message: 'おつかれさま。この調子で続けましょう。',
            ),

          for (final item in due) _RoutineCard(item: item, state: _CardState.due),

          if (later.isNotEmpty) ...[
            const _SubTitle('今日は予定なし'),
            for (final item in later) _RoutineCard(item: item, state: _CardState.later),
          ],

          if (done.isNotEmpty) ...[
            const _SubTitle('完了'),
            for (final item in done) _RoutineCard(item: item, state: _CardState.done),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greetingForHour(now.hour),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          '${now.month}月${now.day}日 (${weekdays[now.weekday - 1]})',
          style: const TextStyle(fontSize: 14, color: AppColors.darkTextSecondary),
        ),
      ],
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final StreakInfo streak;

  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('streak-banner'),
      color: AppColors.darkSurfaceElevated,
      child: Row(
        children: [
          Text(streak.current > 0 ? '🔥' : '🌱', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('連続記録', style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary)),
                Text(
                  '${streak.current} 日',
                  key: const Key('streak-count'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkAccent,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('最長', style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary)),
              Text(
                '${streak.longest} 日',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;

  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkTextSecondary),
      ),
    );
  }
}

enum _CardState { due, later, done }

class _RoutineCard extends StatelessWidget {
  final TodayRoutine item;
  final _CardState state;

  const _RoutineCard({required this.item, required this.state});

  @override
  Widget build(BuildContext context) {
    final routine = item.routine.routine;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Opacity(
        opacity: state == _CardState.due ? 1 : 0.55,
        child: InkWell(
          key: Key('routine-card-${routine.id}'),
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WorkoutScreen(routineId: routine.id)),
          ),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hexToColor(routine.color),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(routine.icon, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state == _CardState.done
                            ? '今日は完了しました'
                            : '${formatFrequency(routine)} ・ ${item.routine.exercises.length}種目',
                        style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  state == _CardState.done ? '✅' : '▶',
                  style: TextStyle(
                    fontSize: 18,
                    color: state == _CardState.done ? null : AppColors.darkPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

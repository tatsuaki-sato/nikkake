import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../domain/date_utils.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/ui.dart';
import 'routine_form_screen.dart';
import 'workout_screen.dart';

/// ホーム。アプリを開いた直後に見る画面。
/// サインインの有無に関係なく、ここに「今日やるルーティン」が並んでいて
/// 1タップで開始できる状態にしておくことがこの画面の唯一の役目。
///
/// 挨拶・日付・連続記録は1行にまとめている。縦幅を食う要素を増やさないため。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // 区分（今日やる / 予定なし / 完了）も連続記録もサーバが決める。
    // ここで振り分け直すと、サーバと基準がずれても誰も気づけない。
    final home = state.home;
    final streak = home.streak;
    final due = home.due;
    final later = home.notScheduled;
    final done = home.completed;

    return RefreshIndicator(
      onRefresh: () async => state.refresh(),
      child: ListView(
        key: const Key('home-screen'),
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          _Header(streak: streak),
          const SizedBox(height: Spacing.md),
          const Text(
            '今日のルーティン',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: Spacing.md),

          if (home.total == 0)
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

          if (due.isNotEmpty)
            _ReorderableRoutineSection(
              items: due,
              state: _CardState.due,
              due: due,
              later: later,
              done: done,
            ),

          if (later.isNotEmpty) ...[
            const _SubTitle('今日は予定なし'),
            _ReorderableRoutineSection(
              items: later,
              state: _CardState.later,
              due: due,
              later: later,
              done: done,
            ),
          ],

          if (done.isNotEmpty) ...[
            const _SubTitle('完了'),
            _ReorderableRoutineSection(
              items: done,
              state: _CardState.done,
              due: due,
              later: later,
              done: done,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final StreakInfo streak;

  const _Header({required this.streak});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greetingForHour(now.hour),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '${now.month}月${now.day}日 (${weekdays[now.weekday - 1]})',
                style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
              ),
            ],
          ),
        ),
        Row(
          key: const Key('streak-banner'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(streak.current > 0 ? '🔥' : '🌱', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: Spacing.xs),
            Text(
              '${streak.current} 日',
              key: const Key('streak-count'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkAccent),
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              '(最長${streak.longest}日)',
              style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
            ),
          ],
        ),
      ],
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

/// 区分（今日やる／予定なし／完了）の中だけでドラッグ並び替えができるリスト。
/// 区分をまたいだ移動はさせない。「今日やる」か「完了」かはサーバが決めるもので、
/// ドラッグで変えるものではないため。
///
/// ReorderableListViewはモバイルでは長押しで、Web/デスクトップでは自動で
/// 付与されるハンドルアイコンでドラッグを始められる（buildDefaultDragHandles既定値）。
class _ReorderableRoutineSection extends StatelessWidget {
  final List<TodayRoutine> items;
  final _CardState state;
  final List<TodayRoutine> due;
  final List<TodayRoutine> later;
  final List<TodayRoutine> done;

  const _ReorderableRoutineSection({
    required this.items,
    required this.state,
    required this.due,
    required this.later,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: (oldIndex, newIndex) {
        final reordered = [...items];
        if (newIndex > oldIndex) newIndex -= 1;
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);

        List<String> idsOf(List<TodayRoutine> list) =>
            list.map((item) => item.routine.routine.id).toList();

        final ids = [
          ...idsOf(state == _CardState.due ? reordered : due),
          ...idsOf(state == _CardState.later ? reordered : later),
          ...idsOf(state == _CardState.done ? reordered : done),
        ];

        context.read<AppState>().reorderRoutines(ids);
      },
      children: [
        for (final item in items)
          _RoutineCard(
            key: Key('routine-card-${item.routine.routine.id}'),
            item: item,
            state: state,
          ),
      ],
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final TodayRoutine item;
  final _CardState state;

  const _RoutineCard({super.key, required this.item, required this.state});

  @override
  Widget build(BuildContext context) {
    final routine = item.routine.routine;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Opacity(
        opacity: state == _CardState.due ? 1 : 0.55,
        child: InkWell(
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
                            : '${item.frequencyLabel} ・ ${item.routine.exercises.length}種目',
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

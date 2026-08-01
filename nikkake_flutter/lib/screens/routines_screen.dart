import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../domain/date_utils.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/ui.dart';
import 'routine_form_screen.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  Future<void> _delete(BuildContext context, RoutineWithExercises routine) async {
    final confirmed = await confirmAction(
      context,
      title: 'ルーティンを削除',
      message: '「${routine.name}」を削除しますか？これまでの記録は残ります。',
    );
    if (!confirmed || !context.mounted) return;
    await context.read<AppState>().deleteRoutine(routine.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final routines = state.routines;

    return Scaffold(
      key: const Key('routines-screen'),
      backgroundColor: AppColors.darkBackground,
      body: routines.isEmpty
          ? Center(
              child: EmptyState(
                key: const Key('routines-empty'),
                icon: '📋',
                title: 'ルーティンがありません',
                message: 'よくやるメニューを登録しておくと、次からは1タップで始められます。',
                action: AppButton(
                  label: 'ルーティンを作る',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RoutineFormScreen()),
                  ),
                ),
              ),
            )
          : ListView.builder(
              key: const Key('routines-list'),
              padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, 100),
              itemCount: routines.length,
              itemBuilder: (context, index) {
                final item = routines[index];
                final routine = item.routine;

                return Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm),
                  child: Opacity(
                    opacity: routine.isActive ? 1 : 0.5,
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              key: Key('routine-edit-${routine.id}'),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RoutineFormScreen(routineId: routine.id),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
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
                                            '${formatFrequency(routine)} ・ ${item.exercises.length}種目'
                                            '${routine.isActive ? '' : ' ・ 停止中'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.darkTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            key: Key('routine-toggle-${routine.id}'),
                            tooltip: routine.isActive ? '停止する' : '再開する',
                            icon: Text(routine.isActive ? '⏸' : '▶', style: const TextStyle(fontSize: 16)),
                            onPressed: () => state.setRoutineActive(routine.id, !routine.isActive),
                          ),
                          IconButton(
                            key: Key('routine-delete-${routine.id}'),
                            tooltip: '削除する',
                            icon: const Text('🗑', style: TextStyle(fontSize: 16)),
                            onPressed: () => _delete(context, item),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        key: const Key('routines-fab'),
        backgroundColor: AppColors.darkPrimary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RoutineFormScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

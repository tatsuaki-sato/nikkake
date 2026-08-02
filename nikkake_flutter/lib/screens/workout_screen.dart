import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../domain/date_utils.dart';
import '../providers/app_state.dart';
import '../providers/workout_controller.dart';
import '../widgets/ui.dart';
import 'workout_summary_screen.dart';

/// ワークアウト実行画面。
/// 記録はすべてローカルなので、電波が無い場所（ジムの地下など）でも完全に動く。
class WorkoutScreen extends StatefulWidget {
  final String routineId;

  const WorkoutScreen({super.key, required this.routineId});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool _started = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    // buildの最中にコントローラを触ると通知が競合するので次フレームで始める
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final state = context.read<AppState>();

    // 種目・目標値・前回の記録がまとめて1本で返る
    final session = await state.repository
        .getWorkoutSession(widget.routineId)
        .catchError((_) => null);

    if (!mounted) return;

    if (session == null || session.exercises.isEmpty) {
      setState(() => _notFound = true);
      return;
    }

    context.read<WorkoutController>().start(session);
    setState(() => _started = true);
  }

  Future<void> _finish() async {
    final summary = await context.read<WorkoutController>().finish();
    if (!mounted || summary == null) return;

    await context.read<AppState>().refresh();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WorkoutSummaryScreen()),
    );
  }

  Future<void> _cancel() async {
    final confirmed = await confirmAction(
      context,
      title: '中断しますか？',
      message: 'ここまでの記録は保存されません。',
      confirmLabel: '中断する',
    );
    if (!confirmed || !mounted) return;

    context.read<WorkoutController>().cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: EmptyState(
            key: const Key('workout-not-found'),
            icon: '🤔',
            title: '開始できませんでした',
            message: 'ルーティンが見つからないか、種目が登録されていません。',
            action: AppButton(label: '戻る', onPressed: () => Navigator.of(context).pop()),
          ),
        ),
      );
    }

    final workout = context.watch<WorkoutController>();
    final current = workout.current;

    if (!_started || !workout.isActive || current == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(child: CircularProgressIndicator(key: Key('workout-loading'))),
      );
    }

    final index = workout.currentIndex;

    return Scaffold(
      key: const Key('workout-screen'),
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
              child: Row(
                children: [
                  TextButton(
                    key: const Key('workout-cancel'),
                    onPressed: _cancel,
                    child: const Text('中断', style: TextStyle(color: AppColors.darkTextSecondary)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          workout.routineName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                        Text(
                          formatDuration(workout.elapsedSec),
                          key: const Key('workout-elapsed'),
                          style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    key: const Key('workout-finish'),
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('完了'),
                  ),
                ],
              ),
            ),

            LinearProgressIndicator(
              value: workout.progress,
              backgroundColor: AppColors.darkSurface,
              color: AppColors.darkSuccess,
              minHeight: 4,
            ),

            if (workout.isRestActive)
              GestureDetector(
                key: const Key('rest-timer'),
                onTap: workout.stopRestTimer,
                child: Container(
                  margin: const EdgeInsets.all(Spacing.md),
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: AppColors.darkAccent),
                  ),
                  child: Column(
                    children: [
                      const Text('休憩中',
                          style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary)),
                      Text(
                        formatDuration(workout.restTimer),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkAccent,
                        ),
                      ),
                      const Text('タップでスキップ',
                          style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Spacing.md),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < workout.exercises.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: Spacing.sm),
                            child: SelectableChip(
                              key: Key('workout-tab-$i'),
                              label: '${workout.exercises[i].sets.every((s) => s.completed) ? '✓ ' : ''}'
                                  '${workout.exercises[i].exercise.name}',
                              selected: i == index,
                              onTap: () => workout.goToExercise(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.md),

                  Text(
                    '${index + 1}/${workout.exercises.length} ${current.exercise.name}',
                    key: const Key('workout-exercise-name'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),

                  if (current.previousSets.isNotEmpty) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      '前回: ${current.previousSets.map((s) => s.durationSec != null ? '${s.durationSec}秒' : '${s.weight ?? '自重'}×${s.reps ?? '-'}').join(' / ')}',
                      key: const Key('workout-previous-hint'),
                      style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                    ),
                  ],
                  const SizedBox(height: Spacing.md),

                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 40, child: _ColumnLabel('セット')),
                            const Expanded(child: _ColumnLabel('kg')),
                            Expanded(child: _ColumnLabel(current.isTimeBased ? '秒' : '回')),
                            const SizedBox(width: 56, child: _ColumnLabel('完了')),
                          ],
                        ),
                        for (final set in current.sets)
                          Container(
                            key: Key('set-row-$index-${set.setNumber}'),
                            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                            decoration: BoxDecoration(
                              color: set.completed ? AppColors.darkSurfaceElevated : null,
                              border: const Border(top: BorderSide(color: AppColors.darkBorder)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${set.setNumber}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.darkTextSecondary),
                                  ),
                                ),
                                Expanded(
                                  child: _SetInput(
                                    key: Key('set-weight-$index-${set.setNumber}'),
                                    value: set.weight?.toString() ?? '',
                                    hint: '自重',
                                    onChanged: (text) => workout.updateSet(
                                      index,
                                      set.setNumber,
                                      (s) => text.trim().isEmpty
                                          ? s.copyWith(clearWeight: true)
                                          : s.copyWith(weight: double.tryParse(text) ?? 0),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: current.isTimeBased
                                      ? _SetInput(
                                          key: Key('set-duration-$index-${set.setNumber}'),
                                          value: set.durationSec?.toString() ?? '',
                                          onChanged: (text) => workout.updateSet(
                                            index,
                                            set.setNumber,
                                            (s) => text.trim().isEmpty
                                                ? s.copyWith(clearDuration: true)
                                                : s.copyWith(durationSec: int.tryParse(text) ?? 0),
                                          ),
                                        )
                                      : _SetInput(
                                          key: Key('set-reps-$index-${set.setNumber}'),
                                          value: set.reps?.toString() ?? '',
                                          onChanged: (text) => workout.updateSet(
                                            index,
                                            set.setNumber,
                                            (s) => text.trim().isEmpty
                                                ? s.copyWith(clearReps: true)
                                                : s.copyWith(reps: int.tryParse(text) ?? 0),
                                          ),
                                        ),
                                ),
                                SizedBox(
                                  width: 56,
                                  child: Center(
                                    child: GestureDetector(
                                      key: Key('set-check-$index-${set.setNumber}'),
                                      onTap: () => workout.toggleSetComplete(index, set.setNumber),
                                      child: Container(
                                        width: 40,
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: set.completed
                                              ? AppColors.darkSuccess
                                              : AppColors.darkBackground,
                                          borderRadius: BorderRadius.circular(Radii.sm),
                                          border: Border.all(
                                            color: set.completed
                                                ? AppColors.darkSuccess
                                                : AppColors.darkBorder,
                                          ),
                                        ),
                                        child: Text(
                                          set.completed ? '✓' : '',
                                          style: const TextStyle(
                                            color: AppColors.darkBackground,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: Spacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              key: const Key('remove-set'),
                              onPressed: () => workout.removeSet(index),
                              child: const Text('− セットを減らす'),
                            ),
                            TextButton(
                              key: const Key('add-set'),
                              onPressed: () => workout.addSet(index),
                              child: const Text('＋ セットを追加'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Spacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          key: const Key('workout-prev'),
                          label: '前の種目',
                          variant: AppButtonVariant.secondary,
                          onPressed: index == 0 ? null : workout.previousExercise,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: AppButton(
                          key: const Key('workout-next'),
                          label: '次の種目',
                          variant: AppButtonVariant.secondary,
                          onPressed:
                              index == workout.exercises.length - 1 ? null : workout.nextExercise,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  final String text;

  const _ColumnLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextSecondary,
        ),
      );
}

class _SetInput extends StatefulWidget {
  final String value;
  final String? hint;
  final ValueChanged<String> onChanged;

  const _SetInput({super.key, required this.value, this.hint, required this.onChanged});

  @override
  State<_SetInput> createState() => _SetInputState();
}

class _SetInputState extends State<_SetInput> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: widget.hint ?? '—',
        isDense: true,
        fillColor: AppColors.darkBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      ),
      onChanged: widget.onChanged,
    );
  }
}

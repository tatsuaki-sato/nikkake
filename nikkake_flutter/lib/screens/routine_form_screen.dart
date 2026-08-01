import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/exercises.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/ui.dart';

/// ルーティンの作成と編集で共通のフォーム。
/// 2画面に分けると入力仕様がすぐズレるので、routineIdの有無で振る舞いを変える1画面にしている。
class RoutineFormScreen extends StatefulWidget {
  final String? routineId;

  const RoutineFormScreen({super.key, this.routineId});

  bool get isEdit => routineId != null;

  @override
  State<RoutineFormScreen> createState() => _RoutineFormScreenState();
}

class _ExerciseRow {
  final String exerciseId;
  final String name;
  final String? icon;
  int targetSets;
  int? targetReps;
  double? targetWeight;
  int? targetDurationSec;
  int restSec;

  _ExerciseRow({
    required this.exerciseId,
    required this.name,
    this.icon,
    this.targetSets = 3,
    this.targetReps = 10,
    this.targetWeight,
    this.targetDurationSec,
    this.restSec = defaultRestSec,
  });
}

class _RoutineFormScreenState extends State<RoutineFormScreen> {
  final _nameController = TextEditingController();
  final _frequencyValueController = TextEditingController(text: '2');

  String _icon = routineIcons.first;
  String _color = routineColors.first;
  FrequencyType _frequencyType = FrequencyType.daily;
  final _frequencyDays = <int>{};
  final _rows = <_ExerciseRow>[];
  bool _pickerOpen = false;
  bool _saving = false;
  String? _error;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final id = widget.routineId;
    if (id == null) return;

    final existing = context.read<AppState>().findRoutine(id);
    if (existing == null) return;

    final routine = existing.routine;
    _nameController.text = routine.name;
    _icon = routine.icon;
    _color = routine.color;
    _frequencyType = routine.frequencyType;
    _frequencyValueController.text = routine.frequencyValue.toString();
    _frequencyDays.addAll(routine.frequencyDays);

    for (final entry in existing.exercises) {
      _rows.add(_ExerciseRow(
        exerciseId: entry.exercise.id,
        name: entry.exercise.name,
        icon: entry.exercise.icon,
        targetSets: entry.link.targetSets,
        targetReps: entry.link.targetReps,
        targetWeight: entry.link.targetWeight,
        targetDurationSec: entry.link.targetDurationSec,
        restSec: entry.link.restSec ?? defaultRestSec,
      ));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _frequencyValueController.dispose();
    super.dispose();
  }

  void _addExercise(Exercise exercise) {
    setState(() {
      _rows.add(_ExerciseRow(
        exerciseId: exercise.id,
        name: exercise.name,
        icon: exercise.icon,
      ));
      _pickerOpen = false;
    });
  }

  void _moveRow(int index, int direction) {
    final target = index + direction;
    if (target < 0 || target >= _rows.length) return;
    setState(() {
      final row = _rows.removeAt(index);
      _rows.insert(target, row);
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'ルーティン名を入力してください');
      return;
    }
    if (_rows.isEmpty) {
      setState(() => _error = '種目を1つ以上追加してください');
      return;
    }
    if (_frequencyType == FrequencyType.weekly && _frequencyDays.isEmpty) {
      setState(() => _error = '曜日を1つ以上選んでください');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final input = RoutineInput(
      name: name,
      icon: _icon,
      color: _color,
      frequencyType: _frequencyType,
      frequencyValue: _frequencyType == FrequencyType.everyNDays
          ? (int.tryParse(_frequencyValueController.text) ?? 1).clamp(1, 365)
          : 1,
      frequencyDays: _frequencyType == FrequencyType.weekly ? _frequencyDays.toList() : const [],
      exercises: _rows
          .map((r) => RoutineExerciseInput(
                exerciseId: r.exerciseId,
                targetSets: r.targetSets,
                targetReps: r.targetReps,
                targetWeight: r.targetWeight,
                targetDurationSec: r.targetDurationSec,
                restSec: r.restSec,
              ))
          .toList(),
    );

    final state = context.read<AppState>();
    if (widget.isEdit) {
      await state.updateRoutine(widget.routineId!, input);
    } else {
      await state.createRoutine(input);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'ルーティンを削除',
      message: 'このルーティンを削除しますか？これまでの記録は残ります。',
    );
    if (!confirmed || !mounted) return;

    await context.read<AppState>().deleteRoutine(widget.routineId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<AppState>().exercises;
    final grouped = <ExerciseCategory, List<Exercise>>{};
    for (final e in exercises) {
      grouped.putIfAbsent(e.category, () => []).add(e);
    }

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: Text(widget.isEdit ? 'ルーティン編集' : 'ルーティン作成')),
      body: ListView(
        key: const Key('routine-form'),
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          ErrorText(_error),

          const _FieldLabel('ルーティン名'),
          TextField(
            key: const Key('routine-name-input'),
            controller: _nameController,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: const InputDecoration(hintText: '例: 朝の全身メニュー'),
          ),
          const SizedBox(height: Spacing.lg),

          const _FieldLabel('アイコン'),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: routineIcons
                .map((i) => GestureDetector(
                      key: Key('icon-$i'),
                      onTap: () => setState(() => _icon = i),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.darkSurfaceElevated,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _icon == i ? AppColors.darkPrimary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(i, style: const TextStyle(fontSize: 20)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: Spacing.lg),

          const _FieldLabel('カラー'),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: routineColors
                .map((c) => GestureDetector(
                      key: Key('color-$c'),
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: hexToColor(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c ? AppColors.darkTextPrimary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: Spacing.lg),

          const _FieldLabel('頻度'),
          Wrap(
            spacing: Spacing.sm,
            children: [
              SelectableChip(
                key: const Key('frequency-daily'),
                label: '毎日',
                selected: _frequencyType == FrequencyType.daily,
                onTap: () => setState(() => _frequencyType = FrequencyType.daily),
              ),
              SelectableChip(
                key: const Key('frequency-every_n_days'),
                label: 'N日ごと',
                selected: _frequencyType == FrequencyType.everyNDays,
                onTap: () => setState(() => _frequencyType = FrequencyType.everyNDays),
              ),
              SelectableChip(
                key: const Key('frequency-weekly'),
                label: '曜日指定',
                selected: _frequencyType == FrequencyType.weekly,
                onTap: () => setState(() => _frequencyType = FrequencyType.weekly),
              ),
            ],
          ),

          if (_frequencyType == FrequencyType.everyNDays) ...[
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    key: const Key('frequency-value-input'),
                    controller: _frequencyValueController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.darkTextPrimary),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                const Text('日ごとに実施',
                    style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13)),
              ],
            ),
          ],

          if (_frequencyType == FrequencyType.weekly) ...[
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.sm,
              children: List.generate(7, (day) {
                const names = ['日', '月', '火', '水', '木', '金', '土'];
                return SelectableChip(
                  key: Key('day-$day'),
                  label: names[day],
                  selected: _frequencyDays.contains(day),
                  onTap: () => setState(() {
                    if (!_frequencyDays.remove(day)) _frequencyDays.add(day);
                  }),
                );
              }),
            ),
          ],
          const SizedBox(height: Spacing.lg),

          const _FieldLabel('種目'),
          for (var i = 0; i < _rows.length; i++) _buildExerciseRow(i),

          const SizedBox(height: Spacing.sm),
          AppButton(
            key: const Key('add-exercise-button'),
            label: _pickerOpen ? '種目リストを閉じる' : '＋ 種目を追加',
            variant: AppButtonVariant.secondary,
            onPressed: () => setState(() => _pickerOpen = !_pickerOpen),
          ),

          if (_pickerOpen) ...[
            const SizedBox(height: Spacing.md),
            AppCard(
              key: const Key('exercise-picker'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: grouped.entries
                    .map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryLabels[entry.key] ?? entry.key.name,
                                style: const TextStyle(
                                  color: AppColors.darkTextSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: Spacing.sm),
                              Wrap(
                                spacing: Spacing.sm,
                                runSpacing: Spacing.sm,
                                children: entry.value
                                    .map((e) => SelectableChip(
                                          key: Key('pick-exercise-${e.id}'),
                                          label: '${e.icon ?? ''} ${e.name}'.trim(),
                                          selected: false,
                                          onTap: () => _addExercise(e),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: Spacing.lg),
          AppButton(
            key: const Key('routine-submit'),
            label: widget.isEdit ? '保存する' : '作成する',
            loading: _saving,
            onPressed: _submit,
          ),

          if (widget.isEdit) ...[
            const SizedBox(height: Spacing.md),
            AppButton(
              key: const Key('routine-delete'),
              label: 'このルーティンを削除',
              variant: AppButtonVariant.danger,
              onPressed: _delete,
            ),
          ],

          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(int index) {
    final row = _rows[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${row.icon ?? ''} ${row.name}'.trim(),
                    key: Key('exercise-row-$index'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
                _MiniButton(
                  key: Key('exercise-up-$index'),
                  label: '↑',
                  onTap: () => _moveRow(index, -1),
                ),
                _MiniButton(
                  key: Key('exercise-down-$index'),
                  label: '↓',
                  onTap: () => _moveRow(index, 1),
                ),
                _MiniButton(
                  key: Key('exercise-remove-$index'),
                  label: '✕',
                  onTap: () => setState(() => _rows.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                _NumberField(
                  key: Key('exercise-sets-$index'),
                  label: 'セット',
                  value: row.targetSets.toString(),
                  onChanged: (v) => row.targetSets = int.tryParse(v)?.clamp(1, 99) ?? 1,
                ),
                _NumberField(
                  key: Key('exercise-reps-$index'),
                  label: '回数',
                  value: row.targetReps?.toString() ?? '',
                  onChanged: (v) => row.targetReps = v.isEmpty ? null : int.tryParse(v),
                ),
                _NumberField(
                  key: Key('exercise-weight-$index'),
                  label: '重量kg',
                  value: row.targetWeight?.toString() ?? '',
                  onChanged: (v) => row.targetWeight = v.isEmpty ? null : double.tryParse(v),
                ),
                _NumberField(
                  key: Key('exercise-duration-$index'),
                  label: '秒',
                  value: row.targetDurationSec?.toString() ?? '',
                  onChanged: (v) => row.targetDurationSec = v.isEmpty ? null : int.tryParse(v),
                ),
                _NumberField(
                  key: Key('exercise-rest-$index'),
                  label: '休憩秒',
                  value: row.restSec.toString(),
                  onChanged: (v) => row.restSec = int.tryParse(v) ?? defaultRestSec,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextSecondary,
          ),
        ),
      );
}

class _MiniButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MiniButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Text(label, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 16)),
      );
}

class _NumberField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
          const SizedBox(height: Spacing.xs),
          TextFormField(
            initialValue: value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: const InputDecoration(
              hintText: '—',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: Spacing.sm),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

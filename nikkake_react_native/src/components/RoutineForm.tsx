import React, { useMemo, useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';
import { Colors } from '../constants/colors';
import { ROUTINE_COLORS, ROUTINE_ICONS, DEFAULT_REST_SEC } from '../constants/exercises';
import { Button, Card, ErrorText, Label, Spacing, Radius } from './ui';
import { Exercise, ExerciseCategory, FrequencyType, RoutineWithExercises } from '../../types';
import { RoutineExerciseInput, RoutineInput } from '../lib/repository';

/**
 * ルーティンの作成と編集で共通のフォーム。
 * 2画面で別々に組むと入力仕様がすぐズレるので1つに寄せている。
 *
 * ピッカー類はOSネイティブのPickerではなくボタンで実装している。
 * Web(Playwright)とネイティブで同じ操作手順にできて、E2Eが素直に書けるため。
 */

const C = Colors.dark;
const DAY_LABELS = ['日', '月', '火', '水', '木', '金', '土'];

const CATEGORY_LABELS: Record<ExerciseCategory, string> = {
  strength: '筋トレ',
  cardio: '有酸素',
  game: 'ゲーム',
  custom: 'カスタム',
};

export interface RoutineFormProps {
  exercises: Exercise[];
  initial?: RoutineWithExercises | null;
  submitLabel: string;
  onSubmit: (input: RoutineInput) => Promise<void>;
  onDelete?: () => void;
}

interface ExerciseRow extends RoutineExerciseInput {
  key: string;
  name: string;
  icon: string | null;
}

export const RoutineForm: React.FC<RoutineFormProps> = ({
  exercises,
  initial,
  submitLabel,
  onSubmit,
  onDelete,
}) => {
  const [name, setName] = useState(initial?.name ?? '');
  const [icon, setIcon] = useState(initial?.icon ?? ROUTINE_ICONS[0]);
  const [color, setColor] = useState(initial?.color ?? ROUTINE_COLORS[0]);
  const [frequencyType, setFrequencyType] = useState<FrequencyType>(initial?.frequency_type ?? 'daily');
  const [frequencyValue, setFrequencyValue] = useState(String(initial?.frequency_value ?? 2));
  const [frequencyDays, setFrequencyDays] = useState<number[]>(initial?.frequency_days ?? []);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  const [rows, setRows] = useState<ExerciseRow[]>(() =>
    (initial?.routine_exercises ?? []).map((link, index) => ({
      key: `${link.id}-${index}`,
      exerciseId: link.exercise_id,
      name: link.exercise.name,
      icon: link.exercise.icon,
      targetSets: link.target_sets,
      targetReps: link.target_reps,
      targetWeight: link.target_weight,
      targetDurationSec: link.target_duration_sec,
      restSec: link.rest_sec ?? DEFAULT_REST_SEC,
    }))
  );

  const grouped = useMemo(() => {
    const map = new Map<ExerciseCategory, Exercise[]>();
    for (const exercise of exercises) {
      const bucket = map.get(exercise.category) ?? [];
      bucket.push(exercise);
      map.set(exercise.category, bucket);
    }
    return Array.from(map.entries());
  }, [exercises]);

  const addExercise = (exercise: Exercise) => {
    setRows(prev => [
      ...prev,
      {
        key: `${exercise.id}-${prev.length}-${Date.now()}`,
        exerciseId: exercise.id,
        name: exercise.name,
        icon: exercise.icon,
        targetSets: 3,
        targetReps: 10,
        targetWeight: null,
        targetDurationSec: null,
        restSec: DEFAULT_REST_SEC,
      },
    ]);
    setPickerOpen(false);
  };

  const updateRow = (index: number, patch: Partial<ExerciseRow>) =>
    setRows(prev => prev.map((row, i) => (i === index ? { ...row, ...patch } : row)));

  const removeRow = (index: number) => setRows(prev => prev.filter((_, i) => i !== index));

  const moveRow = (index: number, direction: -1 | 1) => {
    const target = index + direction;
    if (target < 0 || target >= rows.length) return;

    setRows(prev => {
      const next = [...prev];
      [next[index], next[target]] = [next[target], next[index]];
      return next;
    });
  };

  const handleSubmit = async () => {
    if (!name.trim()) {
      setError('ルーティン名を入力してください');
      return;
    }
    if (rows.length === 0) {
      setError('種目を1つ以上追加してください');
      return;
    }
    if (frequencyType === 'weekly' && frequencyDays.length === 0) {
      setError('曜日を1つ以上選んでください');
      return;
    }

    setError('');
    setSaving(true);

    try {
      await onSubmit({
        name: name.trim(),
        icon,
        color,
        frequencyType,
        frequencyValue: frequencyType === 'every_n_days' ? Math.max(1, parseInt(frequencyValue, 10) || 1) : 1,
        frequencyDays: frequencyType === 'weekly' ? frequencyDays : [],
        exercises: rows.map(({ key, name: _n, icon: _i, ...rest }) => rest),
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : '保存に失敗しました');
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content} testID="routine-form">
      <ErrorText>{error}</ErrorText>

      <View style={styles.section}>
        <Label>ルーティン名</Label>
        <TextInput
          style={styles.input}
          value={name}
          onChangeText={setName}
          placeholder="例: 朝の全身メニュー"
          placeholderTextColor={C.textSecondary}
          testID="routine-name-input"
        />
      </View>

      <View style={styles.section}>
        <Label>アイコン</Label>
        <View style={styles.chipRow}>
          {ROUTINE_ICONS.map(i => (
            <TouchableOpacity
              key={i}
              style={[styles.iconChip, icon === i && styles.iconChipSelected]}
              onPress={() => setIcon(i)}
              accessibilityRole="button"
              testID={`icon-${i}`}
            >
              <Text style={styles.iconChipText}>{i}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      <View style={styles.section}>
        <Label>カラー</Label>
        <View style={styles.chipRow}>
          {ROUTINE_COLORS.map(c => (
            <TouchableOpacity
              key={c}
              style={[styles.colorChip, { backgroundColor: c }, color === c && styles.colorChipSelected]}
              onPress={() => setColor(c)}
              accessibilityRole="button"
              testID={`color-${c}`}
            />
          ))}
        </View>
      </View>

      <View style={styles.section}>
        <Label>頻度</Label>
        <View style={styles.chipRow}>
          {(
            [
              ['daily', '毎日'],
              ['every_n_days', 'N日ごと'],
              ['weekly', '曜日指定'],
            ] as [FrequencyType, string][]
          ).map(([value, label]) => (
            <TouchableOpacity
              key={value}
              style={[styles.chip, frequencyType === value && styles.chipSelected]}
              onPress={() => setFrequencyType(value)}
              accessibilityRole="button"
              testID={`frequency-${value}`}
            >
              <Text style={[styles.chipText, frequencyType === value && styles.chipTextSelected]}>{label}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {frequencyType === 'every_n_days' ? (
          <View style={styles.inlineRow}>
            <TextInput
              style={styles.smallInput}
              value={frequencyValue}
              onChangeText={setFrequencyValue}
              keyboardType="numeric"
              testID="frequency-value-input"
            />
            <Text style={styles.unitText}>日ごとに実施</Text>
          </View>
        ) : null}

        {frequencyType === 'weekly' ? (
          <View style={styles.chipRow}>
            {DAY_LABELS.map((label, day) => (
              <TouchableOpacity
                key={day}
                style={[styles.dayChip, frequencyDays.includes(day) && styles.chipSelected]}
                onPress={() =>
                  setFrequencyDays(prev =>
                    prev.includes(day) ? prev.filter(d => d !== day) : [...prev, day]
                  )
                }
                accessibilityRole="button"
                testID={`day-${day}`}
              >
                <Text style={[styles.chipText, frequencyDays.includes(day) && styles.chipTextSelected]}>
                  {label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        ) : null}
      </View>

      <View style={styles.section}>
        <Label>種目</Label>

        {rows.map((row, index) => (
          <Card key={row.key} style={styles.exerciseCard}>
            <View style={styles.exerciseHeader}>
              <Text style={styles.exerciseName} testID={`exercise-row-${index}`}>
                {row.icon} {row.name}
              </Text>
              <View style={styles.exerciseActions}>
                <TouchableOpacity onPress={() => moveRow(index, -1)} style={styles.miniButton} accessibilityLabel="上へ" testID={`exercise-up-${index}`}>
                  <Text style={styles.miniButtonText}>↑</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => moveRow(index, 1)} style={styles.miniButton} accessibilityLabel="下へ" testID={`exercise-down-${index}`}>
                  <Text style={styles.miniButtonText}>↓</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => removeRow(index)} style={styles.miniButton} accessibilityLabel="削除" testID={`exercise-remove-${index}`}>
                  <Text style={styles.miniButtonText}>✕</Text>
                </TouchableOpacity>
              </View>
            </View>

            <View style={styles.fieldRow}>
              <NumberField
                label="セット"
                value={row.targetSets}
                onChange={v => updateRow(index, { targetSets: Math.max(1, v ?? 1) })}
                testID={`exercise-sets-${index}`}
              />
              <NumberField
                label="回数"
                value={row.targetReps}
                onChange={v => updateRow(index, { targetReps: v })}
                testID={`exercise-reps-${index}`}
              />
              <NumberField
                label="重量kg"
                value={row.targetWeight}
                onChange={v => updateRow(index, { targetWeight: v })}
                testID={`exercise-weight-${index}`}
              />
              <NumberField
                label="秒"
                value={row.targetDurationSec}
                onChange={v => updateRow(index, { targetDurationSec: v })}
                testID={`exercise-duration-${index}`}
              />
              <NumberField
                label="休憩秒"
                value={row.restSec}
                onChange={v => updateRow(index, { restSec: v })}
                testID={`exercise-rest-${index}`}
              />
            </View>
          </Card>
        ))}

        <Button
          title={pickerOpen ? '種目リストを閉じる' : '＋ 種目を追加'}
          variant="secondary"
          onPress={() => setPickerOpen(v => !v)}
          testID="add-exercise-button"
          style={styles.addButton}
        />

        {pickerOpen ? (
          <Card style={styles.picker} testID="exercise-picker">
            {grouped.map(([category, items]) => (
              <View key={category} style={styles.pickerGroup}>
                <Text style={styles.pickerGroupTitle}>{CATEGORY_LABELS[category] ?? category}</Text>
                <View style={styles.chipRow}>
                  {items.map(exercise => (
                    <TouchableOpacity
                      key={exercise.id}
                      style={styles.chip}
                      onPress={() => addExercise(exercise)}
                      accessibilityRole="button"
                      testID={`pick-exercise-${exercise.id}`}
                    >
                      <Text style={styles.chipText}>
                        {exercise.icon} {exercise.name}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            ))}
          </Card>
        ) : null}
      </View>

      <Button title={submitLabel} onPress={handleSubmit} loading={saving} testID="routine-submit" />

      {onDelete ? (
        <Button title="このルーティンを削除" variant="danger" onPress={onDelete} testID="routine-delete" style={styles.deleteButton} />
      ) : null}

      <View style={{ height: Spacing.xl }} />
    </ScrollView>
  );
};

const NumberField: React.FC<{
  label: string;
  value: number | null;
  onChange: (value: number | null) => void;
  testID: string;
}> = ({ label, value, onChange, testID }) => (
  <View style={styles.field}>
    <Text style={styles.fieldLabel}>{label}</Text>
    <TextInput
      style={styles.fieldInput}
      value={value === null || value === undefined ? '' : String(value)}
      onChangeText={text => {
        const trimmed = text.trim();
        if (trimmed === '') {
          onChange(null);
          return;
        }
        const parsed = Number(trimmed);
        onChange(Number.isFinite(parsed) ? parsed : null);
      }}
      keyboardType="numeric"
      placeholder="—"
      placeholderTextColor={C.textSecondary}
      testID={testID}
    />
  </View>
);

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background },
  content: { padding: Spacing.md },
  section: { marginBottom: Spacing.lg },
  input: {
    backgroundColor: C.surface,
    padding: Spacing.md,
    borderRadius: Radius.sm,
    color: C.textPrimary,
    borderWidth: 1,
    borderColor: C.border,
  },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  chip: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: Radius.pill,
    backgroundColor: C.surface,
    borderWidth: 1,
    borderColor: C.border,
  },
  chipSelected: { backgroundColor: C.primary, borderColor: C.primary },
  chipText: { color: C.textPrimary, fontSize: 13 },
  chipTextSelected: { color: '#fff', fontWeight: 'bold' },
  iconChip: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: C.surfaceElevated,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  iconChipSelected: { borderColor: C.primary },
  iconChipText: { fontSize: 20 },
  colorChip: { width: 36, height: 36, borderRadius: 18, borderWidth: 3, borderColor: 'transparent' },
  colorChipSelected: { borderColor: C.textPrimary },
  dayChip: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: C.surface,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.border,
  },
  inlineRow: { flexDirection: 'row', alignItems: 'center', marginTop: Spacing.md, gap: Spacing.sm },
  smallInput: {
    backgroundColor: C.surface,
    width: 64,
    paddingVertical: Spacing.sm,
    textAlign: 'center',
    color: C.textPrimary,
    borderRadius: Radius.sm,
    borderWidth: 1,
    borderColor: C.border,
  },
  unitText: { color: C.textSecondary, fontSize: 13 },
  exerciseCard: { marginBottom: Spacing.sm },
  exerciseHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  exerciseName: { color: C.textPrimary, fontSize: 15, fontWeight: 'bold', flex: 1 },
  exerciseActions: { flexDirection: 'row' },
  miniButton: { paddingHorizontal: Spacing.sm, paddingVertical: Spacing.xs },
  miniButtonText: { color: C.textSecondary, fontSize: 16 },
  fieldRow: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm, marginTop: Spacing.md },
  field: { minWidth: 60 },
  fieldLabel: { color: C.textSecondary, fontSize: 11, marginBottom: Spacing.xs },
  fieldInput: {
    backgroundColor: C.background,
    borderRadius: Radius.sm,
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.sm,
    color: C.textPrimary,
    textAlign: 'center',
    borderWidth: 1,
    borderColor: C.border,
    minWidth: 60,
  },
  addButton: { marginTop: Spacing.sm },
  picker: { marginTop: Spacing.md },
  pickerGroup: { marginBottom: Spacing.md },
  pickerGroupTitle: { color: C.textSecondary, fontSize: 12, fontWeight: 'bold', marginBottom: Spacing.sm },
  deleteButton: { marginTop: Spacing.md },
});

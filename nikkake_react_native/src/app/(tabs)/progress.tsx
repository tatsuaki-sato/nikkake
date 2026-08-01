import React, { useMemo, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { useQuery } from '@tanstack/react-query';
import { useFocusEffect } from 'expo-router';
import { Colors } from '../../constants/colors';
import { listRoutineLogs, listExerciseLogs, listExercises } from '../../lib/repository';
import {
  calculateDailyStats,
  calculateExerciseProgress,
  calculateOverallStats,
  calculateStreak,
  completedDateSet,
} from '../../lib/stats';
import { addDays, formatDuration, getDateString } from '../../lib/utils';
import { Card, EmptyState, SectionTitle, Spacing, Radius } from '../../components/ui';

/**
 * 進捗。
 * グラフ描画ライブラリは使わず、Viewの高さと色だけで表現している。
 * 3プラットフォームで同じ見た目を再現しやすく、Web(E2E)でも確実に描画されるため。
 */
export default function ProgressScreen() {
  const [range, setRange] = useState<7 | 30>(7);
  const [selectedExerciseId, setSelectedExerciseId] = useState<string | null>(null);

  const routineLogsQuery = useQuery({ queryKey: ['routineLogs'], queryFn: listRoutineLogs });
  const exerciseLogsQuery = useQuery({ queryKey: ['exerciseLogs'], queryFn: listExerciseLogs });
  const exercisesQuery = useQuery({ queryKey: ['exercises'], queryFn: listExercises });

  useFocusEffect(
    React.useCallback(() => {
      void routineLogsQuery.refetch();
      void exerciseLogsQuery.refetch();
    }, [])
  );

  const routineLogs = routineLogsQuery.data ?? [];
  const exerciseLogs = exerciseLogsQuery.data ?? [];
  const exercises = exercisesQuery.data ?? [];

  const overall = calculateOverallStats(routineLogs, exerciseLogs);
  const streak = calculateStreak(routineLogs);
  const daily = calculateDailyStats(routineLogs, range);
  const doneDates = completedDateSet(routineLogs);

  // 記録が残っている種目だけを選択肢にする
  const loggedExercises = useMemo(() => {
    const ids = new Set(exerciseLogs.map(l => l.exercise_id));
    return exercises.filter(e => ids.has(e.id));
  }, [exercises, exerciseLogs]);

  const activeExerciseId = selectedExerciseId ?? loggedExercises[0]?.id ?? null;
  const exerciseProgress = activeExerciseId
    ? calculateExerciseProgress(activeExerciseId, routineLogs, exerciseLogs)
    : [];

  const maxCount = Math.max(1, ...daily.map(d => d.completedCount));

  if (routineLogs.length === 0) {
    return (
      <View style={styles.centered} testID="progress-screen">
        <EmptyState
          testID="progress-empty"
          icon="📈"
          title="まだ記録がありません"
          message="ワークアウトを1回完了すると、ここに推移が出ます。"
        />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content} testID="progress-screen">
      <Card style={styles.summaryCard}>
        <View style={styles.summaryRow}>
          <Summary label="通算" value={`${overall.totalWorkouts}回`} testID="progress-total" />
          <Summary label="今週" value={`${overall.thisWeekCount}回`} testID="progress-week" />
          <Summary label="連続" value={`${streak.current}日`} testID="progress-streak" />
          <Summary label="総時間" value={formatDuration(overall.totalDurationSec)} testID="progress-duration" />
        </View>
      </Card>

      <View style={styles.sectionHeader}>
        <SectionTitle style={styles.sectionTitleInline}>実施状況</SectionTitle>
        <View style={styles.rangeToggle}>
          {([7, 30] as const).map(value => (
            <TouchableOpacity
              key={value}
              onPress={() => setRange(value)}
              style={[styles.rangeButton, range === value && styles.rangeButtonActive]}
              accessibilityRole="button"
              testID={`progress-range-${value}`}
            >
              <Text style={[styles.rangeText, range === value && styles.rangeTextActive]}>{value}日</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      <Card testID="progress-chart">
        <View style={styles.chart}>
          {daily.map(day => (
            <View key={day.date} style={styles.chartColumn}>
              <View
                style={[
                  styles.chartBar,
                  {
                    height: Math.max(4, (day.completedCount / maxCount) * 96),
                    backgroundColor: day.completedCount > 0 ? C.success : C.border,
                  },
                ]}
              />
              {range === 7 ? <Text style={styles.chartLabel}>{day.date.slice(8)}</Text> : null}
            </View>
          ))}
        </View>
      </Card>

      <SectionTitle style={styles.sectionSpacing}>カレンダー</SectionTitle>
      <Card testID="progress-calendar">
        <MonthGrid doneDates={doneDates} />
      </Card>

      <SectionTitle style={styles.sectionSpacing}>種目ごとの推移</SectionTitle>
      {loggedExercises.length === 0 ? (
        <Card>
          <Text style={styles.muted}>セット記録が貯まるとここに種目別の推移が出ます。</Text>
        </Card>
      ) : (
        <>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
            {loggedExercises.map(exercise => (
              <TouchableOpacity
                key={exercise.id}
                onPress={() => setSelectedExerciseId(exercise.id)}
                style={[styles.chip, activeExerciseId === exercise.id && styles.chipActive]}
                accessibilityRole="button"
                testID={`progress-exercise-${exercise.id}`}
              >
                <Text style={[styles.chipText, activeExerciseId === exercise.id && styles.chipTextActive]}>
                  {exercise.name}
                </Text>
              </TouchableOpacity>
            ))}
          </ScrollView>

          <Card style={styles.sectionSpacing} testID="progress-exercise-detail">
            {exerciseProgress.length === 0 ? (
              <Text style={styles.muted}>記録がありません。</Text>
            ) : (
              exerciseProgress
                .slice(-8)
                .reverse()
                .map(point => (
                  <View key={point.date} style={styles.progressRow}>
                    <Text style={styles.progressDate}>{point.date.slice(5)}</Text>
                    <Text style={styles.progressValue}>
                      {point.maxWeight > 0 ? `最大 ${point.maxWeight}kg` : `${point.totalReps} 回`}
                    </Text>
                    <Text style={styles.progressSub}>
                      {point.totalVolume > 0 ? `${Math.round(point.totalVolume)}kg` : `計 ${point.totalReps}回`}
                    </Text>
                  </View>
                ))
            )}
          </Card>
        </>
      )}
    </ScrollView>
  );
}

/** 当月のカレンダー。実施した日を塗る */
const MonthGrid: React.FC<{ doneDates: Set<string> }> = ({ doneDates }) => {
  const today = new Date();
  const firstOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
  const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
  const leadingBlanks = firstOfMonth.getDay();
  const todayString = getDateString(today);

  const cells: (string | null)[] = [
    ...Array<null>(leadingBlanks).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => getDateString(addDays(firstOfMonth, i))),
  ];

  return (
    <View>
      <Text style={styles.monthLabel}>{today.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long' })}</Text>
      <View style={styles.weekHeader}>
        {['日', '月', '火', '水', '木', '金', '土'].map(d => (
          <Text key={d} style={styles.weekHeaderText}>
            {d}
          </Text>
        ))}
      </View>
      <View style={styles.calendarGrid}>
        {cells.map((date, index) => (
          <View
            key={date ?? `blank-${index}`}
            style={[
              styles.calendarCell,
              date && doneDates.has(date) && styles.calendarCellDone,
              date === todayString && styles.calendarCellToday,
            ]}
          >
            <Text style={[styles.calendarText, date && doneDates.has(date) && styles.calendarTextDone]}>
              {date ? Number(date.slice(8)) : ''}
            </Text>
          </View>
        ))}
      </View>
    </View>
  );
};

const Summary: React.FC<{ label: string; value: string; testID: string }> = ({ label, value, testID }) => (
  <View style={styles.summaryItem}>
    <Text style={styles.summaryLabel}>{label}</Text>
    <Text style={styles.summaryValue} testID={testID}>
      {value}
    </Text>
  </View>
);

const C = Colors.dark;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background },
  centered: { flex: 1, backgroundColor: C.background, justifyContent: 'center', padding: Spacing.md },
  content: { padding: Spacing.md, paddingBottom: Spacing.xl },
  summaryCard: { marginBottom: Spacing.lg },
  summaryRow: { flexDirection: 'row', justifyContent: 'space-between' },
  summaryItem: { alignItems: 'center', flex: 1 },
  summaryLabel: { color: C.textSecondary, fontSize: 11, marginBottom: Spacing.xs },
  summaryValue: { color: C.textPrimary, fontSize: 16, fontWeight: 'bold' },
  sectionHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  sectionTitleInline: { marginBottom: Spacing.sm },
  sectionSpacing: { marginTop: Spacing.lg },
  rangeToggle: { flexDirection: 'row', gap: Spacing.xs, marginBottom: Spacing.sm },
  rangeButton: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    borderRadius: Radius.pill,
    borderWidth: 1,
    borderColor: C.border,
  },
  rangeButtonActive: { backgroundColor: C.primary, borderColor: C.primary },
  rangeText: { color: C.textSecondary, fontSize: 12 },
  rangeTextActive: { color: '#fff', fontWeight: 'bold' },
  chart: { flexDirection: 'row', alignItems: 'flex-end', height: 120, gap: 2 },
  chartColumn: { flex: 1, alignItems: 'center', justifyContent: 'flex-end' },
  chartBar: { width: '80%', borderRadius: 2 },
  chartLabel: { color: C.textSecondary, fontSize: 9, marginTop: Spacing.xs },
  monthLabel: { color: C.textPrimary, fontWeight: 'bold', marginBottom: Spacing.sm, textAlign: 'center' },
  weekHeader: { flexDirection: 'row' },
  weekHeaderText: { flex: 1, textAlign: 'center', color: C.textSecondary, fontSize: 11, marginBottom: Spacing.xs },
  calendarGrid: { flexDirection: 'row', flexWrap: 'wrap' },
  calendarCell: {
    width: `${100 / 7}%`,
    aspectRatio: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 2,
  },
  calendarCellDone: { backgroundColor: C.success, borderRadius: Radius.sm },
  calendarCellToday: { borderWidth: 1, borderColor: C.primaryLight, borderRadius: Radius.sm },
  calendarText: { color: C.textSecondary, fontSize: 12 },
  calendarTextDone: { color: '#0F0F14', fontWeight: 'bold' },
  chipRow: { gap: Spacing.sm, paddingVertical: Spacing.sm },
  chip: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: Radius.pill,
    backgroundColor: C.surface,
    borderWidth: 1,
    borderColor: C.border,
  },
  chipActive: { backgroundColor: C.primary, borderColor: C.primary },
  chipText: { color: C.textSecondary, fontSize: 12 },
  chipTextActive: { color: '#fff', fontWeight: 'bold' },
  progressRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
  },
  progressDate: { color: C.textSecondary, fontSize: 12, width: 56 },
  progressValue: { color: C.textPrimary, fontSize: 14, fontWeight: 'bold', flex: 1, textAlign: 'center' },
  progressSub: { color: C.textSecondary, fontSize: 12, width: 72, textAlign: 'right' },
  muted: { color: C.textSecondary, fontSize: 13 },
});

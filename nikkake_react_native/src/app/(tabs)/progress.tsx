import React, { useMemo, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { useQuery } from '@tanstack/react-query';
import { useFocusEffect } from 'expo-router';
import { Colors } from '../../constants/colors';
import { getDay, getExerciseProgressPoints, getProgress } from '../../lib/repository';
import { addDays, formatDuration, getDateString } from '../../lib/utils';
import { Card, EmptyState, SectionTitle, Spacing, Radius } from '../../components/ui';

/**
 * 進捗。
 * グラフ描画ライブラリは使わず、Viewの高さと色だけで表現している。
 * 4クライアントで同じ見た目を再現しやすく、E2Eでも確実に描画されるため。
 *
 * 数字はすべてサーバが集計したものを表示するだけ。
 * ここに計算を書き足したら、それはサーバへ移すべきロジックが漏れている。
 */
export default function ProgressScreen() {
  const [range, setRange] = useState<7 | 30>(7);
  const [selectedExerciseId, setSelectedExerciseId] = useState<string | null>(null);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);

  const progressQuery = useQuery({
    queryKey: ['progress', range],
    queryFn: () => getProgress(range),
  });

  useFocusEffect(
    React.useCallback(() => {
      void progressQuery.refetch();
    }, [])
  );

  const progress = progressQuery.data;
  const overall = progress?.overall ?? {
    totalWorkouts: 0,
    thisWeekCount: 0,
    totalDurationSec: 0,
    totalSets: 0,
  };
  const streak = progress?.streak ?? { current: 0, longest: 0, lastCompletedDate: null };
  const daily = progress?.dailyStats ?? [];

  // 記録が残っている種目だけが返ってくる
  const loggedExercises = progress?.exercisesWithLogs ?? [];
  const doneDates = useMemo(
    () => new Set(progress?.completedDates ?? []),
    [progress?.completedDates]
  );

  const activeExerciseId = selectedExerciseId ?? loggedExercises[0]?.id ?? null;

  const exerciseProgressQuery = useQuery({
    queryKey: ['exerciseProgress', activeExerciseId],
    queryFn: () => getExerciseProgressPoints(activeExerciseId!),
    enabled: activeExerciseId !== null,
  });
  const exerciseProgress = exerciseProgressQuery.data ?? [];

  const maxCount = Math.max(1, ...daily.map(d => d.completedCount));

  // 読み込み中に空状態を出すと一瞬ちらつくので、応答が来るまでは何も出さない
  if (progressQuery.isLoading) {
    return <View style={styles.centered} testID="progress-screen" />;
  }

  if (overall.totalWorkouts === 0) {
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
        <MonthGrid
          doneDates={doneDates}
          selectedDate={selectedDate}
          onSelectDate={date => setSelectedDate(date === selectedDate ? null : date)}
        />
      </Card>
      {selectedDate ? (
        <DayDetail date={selectedDate} onClose={() => setSelectedDate(null)} />
      ) : null}

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
              [...exerciseProgress]
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

/** カレンダー。実施した日を塗る。◀▶ で前月・翌月へ移動でき、日をタップするとその日の内容を開く */
const MonthGrid: React.FC<{
  doneDates: Set<string>;
  selectedDate: string | null;
  onSelectDate: (date: string) => void;
}> = ({ doneDates, selectedDate, onSelectDate }) => {
  const [monthsBack, setMonthsBack] = useState(0);
  const now = new Date();
  const view = new Date(now.getFullYear(), now.getMonth() - monthsBack, 1);
  const daysInMonth = new Date(view.getFullYear(), view.getMonth() + 1, 0).getDate();
  const todayString = getDateString(now);

  const cells: (string | null)[] = [
    ...Array<null>(view.getDay()).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => getDateString(addDays(view, i))),
  ];

  return (
    <View>
      <View style={styles.monthHeader}>
        <TouchableOpacity
          onPress={() => setMonthsBack(m => m + 1)}
          accessibilityRole="button"
          accessibilityLabel="前の月"
          testID="calendar-prev"
          style={styles.monthNav}
        >
          <Text style={styles.monthNavText}>◀</Text>
        </TouchableOpacity>
        <Text style={styles.monthLabel}>
          {view.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long' })}
        </Text>
        <TouchableOpacity
          onPress={() => setMonthsBack(m => Math.max(0, m - 1))}
          disabled={monthsBack === 0}
          accessibilityRole="button"
          accessibilityLabel="次の月"
          testID="calendar-next"
          style={styles.monthNav}
        >
          <Text style={[styles.monthNavText, monthsBack === 0 && styles.monthNavDisabled]}>▶</Text>
        </TouchableOpacity>
      </View>
      <View style={styles.weekHeader}>
        {['日', '月', '火', '水', '木', '金', '土'].map(d => (
          <Text key={d} style={styles.weekHeaderText}>
            {d}
          </Text>
        ))}
      </View>
      <View style={styles.calendarGrid}>
        {cells.map((date, index) => {
          if (!date) return <View key={`blank-${index}`} style={styles.calendarCell} />;
          const done = doneDates.has(date);
          return (
            <TouchableOpacity
              key={date}
              onPress={() => onSelectDate(date)}
              accessibilityRole="button"
              testID={`calendar-day-${date}`}
              style={[
                styles.calendarCell,
                done && styles.calendarCellDone,
                date === todayString && styles.calendarCellToday,
                date === selectedDate && styles.calendarCellSelected,
              ]}
            >
              <Text style={[styles.calendarText, done && styles.calendarTextDone]}>
                {Number(date.slice(8))}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
};

/** カレンダーで選んだ日のワークアウト内容。集計と同じくサーバが整形して返す */
const DayDetail: React.FC<{ date: string; onClose: () => void }> = ({ date, onClose }) => {
  const dayQuery = useQuery({
    queryKey: ['day', date],
    queryFn: () => getDay(date),
  });

  const workouts = dayQuery.data?.workouts ?? [];

  return (
    <Card style={styles.sectionSpacing} testID="progress-day-detail">
      <View style={styles.dayHeader}>
        <Text style={styles.dayTitle}>{date.slice(5).replace('-', '/')} の記録</Text>
        <TouchableOpacity onPress={onClose} accessibilityRole="button" accessibilityLabel="閉じる">
          <Text style={styles.monthNavText}>✕</Text>
        </TouchableOpacity>
      </View>
      {dayQuery.isLoading ? (
        <Text style={styles.muted}>読み込み中…</Text>
      ) : workouts.length === 0 ? (
        <Text style={styles.muted}>この日の記録はありません。</Text>
      ) : (
        workouts.map(workout => (
          <View key={workout.routineLogId} style={styles.dayWorkout}>
            <View style={styles.dayWorkoutHead}>
              <Text style={styles.dayRoutineName}>{workout.routineName}</Text>
              {workout.durationSec != null ? (
                <Text style={styles.muted}>{formatDuration(workout.durationSec)}</Text>
              ) : null}
            </View>
            {workout.exercises.map((exercise, i) => (
              <View key={i} style={styles.dayExerciseRow}>
                <Text style={styles.muted}>{exercise.exerciseName}</Text>
                <Text style={styles.dayExerciseSets}>{exercise.setsLabel ?? '—'}</Text>
              </View>
            ))}
          </View>
        ))
      )}
    </Card>
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
  monthHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: Spacing.sm,
  },
  monthLabel: { color: C.textPrimary, fontWeight: 'bold', textAlign: 'center' },
  monthNav: { paddingHorizontal: Spacing.sm, paddingVertical: Spacing.xs },
  monthNavText: { color: C.primaryLight, fontSize: 15 },
  monthNavDisabled: { opacity: 0.3 },
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
  calendarCellSelected: { borderWidth: 2, borderColor: C.primary, borderRadius: Radius.sm },
  calendarText: { color: C.textSecondary, fontSize: 12 },
  calendarTextDone: { color: '#0F0F14', fontWeight: 'bold' },
  dayHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: Spacing.sm,
  },
  dayTitle: { color: C.textPrimary, fontWeight: 'bold', fontSize: 14 },
  dayWorkout: { borderTopWidth: 1, borderTopColor: C.border, paddingVertical: Spacing.sm },
  dayWorkoutHead: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: Spacing.xs },
  dayRoutineName: { color: C.textPrimary, fontWeight: 'bold', fontSize: 14 },
  dayExerciseRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 2 },
  dayExerciseSets: { color: C.textPrimary, fontSize: 13 },
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

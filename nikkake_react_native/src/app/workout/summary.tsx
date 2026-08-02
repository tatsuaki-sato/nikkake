import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { useRouter } from 'expo-router';
import { useQuery } from '@tanstack/react-query';
import { Colors } from '../../constants/colors';
import { useWorkoutStore } from '../../stores/workoutStore';
import { getStreak } from '../../lib/repository';
import { formatDuration } from '../../lib/utils';
import { Button, Card, EmptyState, Spacing, Radius } from '../../components/ui';

/**
 * ワークアウト完了直後のサマリー。
 * 「今やった分がちゃんと記録された」ことを見せて、連続記録が伸びたことを返す画面。
 */
export default function WorkoutSummaryScreen() {
  const router = useRouter();
  const summary = useWorkoutStore(s => s.lastSummary);
  const clearSummary = useWorkoutStore(s => s.clearSummary);

  const { data: streak = { current: 0, longest: 0, lastCompletedDate: null } } = useQuery({
    queryKey: ['streak'],
    queryFn: () => getStreak(),
  });

  const goHome = () => {
    clearSummary();

    // スタックは [タブ, サマリー] の状態。replaceで /(tabs) へ飛ぶと
    // 既にあるタブ画面の上にもう1つタブ画面が積まれてしまうので、必ず戻る。
    if (router.canGoBack()) {
      router.back();
    } else {
      router.replace('/(tabs)');
    }
  };

  if (!summary) {
    return (
      <View style={styles.centered}>
        <EmptyState
          testID="summary-empty"
          icon="🤔"
          title="表示できる記録がありません"
          message="ワークアウトを完了するとここに結果が出ます。"
          action={<Button title="ホームへ" onPress={goHome} />}
        />
      </View>
    );
  }

  const statusLabel =
    summary.status === 'completed' ? 'コンプリート！' : summary.status === 'partial' ? '記録しました' : '記録なし';

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content} testID="summary-screen">
      <Text style={styles.emoji}>{summary.status === 'completed' ? '🎉' : '💪'}</Text>
      <Text style={styles.title} testID="summary-status">
        {statusLabel}
      </Text>
      <Text style={styles.routineName}>{summary.routineName}</Text>

      <Card style={styles.statsCard}>
        <View style={styles.statsRow}>
          <Stat label="時間" value={formatDuration(summary.durationSec)} testID="summary-duration" />
          <Stat label="セット" value={`${summary.completedSets}/${summary.totalSets}`} testID="summary-sets" />
          <Stat
            label="総重量"
            value={summary.totalVolume > 0 ? `${Math.round(summary.totalVolume)} kg` : '—'}
            testID="summary-volume"
          />
        </View>
      </Card>

      <Card style={styles.streakCard}>
        <Text style={styles.streakIcon}>{streak.current > 0 ? '🔥' : '🌱'}</Text>
        <View>
          <Text style={styles.streakLabel}>連続記録</Text>
          <Text style={styles.streakValue} testID="summary-streak">
            {streak.current} 日
          </Text>
        </View>
      </Card>

      <Button title="ホームに戻る" onPress={goHome} testID="summary-home" style={styles.homeButton} />
    </ScrollView>
  );
}

const Stat: React.FC<{ label: string; value: string; testID: string }> = ({ label, value, testID }) => (
  <View style={styles.stat}>
    <Text style={styles.statLabel}>{label}</Text>
    <Text style={styles.statValue} testID={testID}>
      {value}
    </Text>
  </View>
);

const C = Colors.dark;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background },
  content: { padding: Spacing.lg, paddingTop: 80, alignItems: 'center' },
  centered: { flex: 1, backgroundColor: C.background, justifyContent: 'center', padding: Spacing.md },
  emoji: { fontSize: 64, marginBottom: Spacing.md },
  title: { fontSize: 26, fontWeight: 'bold', color: C.textPrimary, marginBottom: Spacing.xs },
  routineName: { fontSize: 15, color: C.textSecondary, marginBottom: Spacing.xl },
  statsCard: { alignSelf: 'stretch', marginBottom: Spacing.md },
  statsRow: { flexDirection: 'row', justifyContent: 'space-around' },
  stat: { alignItems: 'center' },
  statLabel: { color: C.textSecondary, fontSize: 12, marginBottom: Spacing.xs },
  statValue: { color: C.textPrimary, fontSize: 20, fontWeight: 'bold' },
  streakCard: {
    alignSelf: 'stretch',
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    backgroundColor: C.surfaceElevated,
    borderRadius: Radius.lg,
    marginBottom: Spacing.xl,
  },
  streakIcon: { fontSize: 32 },
  streakLabel: { color: C.textSecondary, fontSize: 12 },
  streakValue: { color: C.accent, fontSize: 20, fontWeight: 'bold' },
  homeButton: { alignSelf: 'stretch' },
});

import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, RefreshControl } from 'react-native';
import { useQuery } from '@tanstack/react-query';
import { useRouter, useFocusEffect } from 'expo-router';
import { Colors } from '../../constants/colors';
import { getHome } from '../../lib/repository';
import { greetingForHour } from '../../lib/utils';
import { Button, EmptyState, Spacing, Radius } from '../../components/ui';

/**
 * ホーム。アプリを開いた直後に見る画面。
 * サインインの有無に関係なく、ここに「今日やるルーティン」が並んでいて
 * 1タップで開始できる状態にしておくことがこの画面の唯一の役目。
 */
export default function HomeScreen() {
  const router = useRouter();

  // 区分（今日やる / 予定なし / 完了）も連続記録もサーバが決める。
  // ここで振り分け直すと、サーバと端末で基準がずれても誰も気づけない。
  const homeQuery = useQuery({ queryKey: ['home'], queryFn: () => getHome() });

  // ワークアウトから戻ってきたときに完了状態を即反映させる
  useFocusEffect(
    React.useCallback(() => {
      void homeQuery.refetch();
    }, [])
  );

  const home = homeQuery.data;
  const streak = home?.streak ?? { current: 0, longest: 0, lastCompletedDate: null };

  const due = home?.due ?? [];
  const done = home?.completed ?? [];
  const later = home?.notScheduled ?? [];
  const total = due.length + done.length + later.length;

  const refreshing = homeQuery.isFetching && !homeQuery.isLoading;

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      testID="home-screen"
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={() => {
            void homeQuery.refetch();
          }}
          tintColor={Colors.dark.primary}
        />
      }
    >
      <View style={styles.header}>
        <Text style={styles.greeting}>{greetingForHour(new Date().getHours())}</Text>
        <Text style={styles.date}>
          {new Date().toLocaleDateString('ja-JP', { month: 'long', day: 'numeric', weekday: 'short' })}
        </Text>
      </View>

      <View style={styles.streakBanner} testID="streak-banner">
        <Text style={styles.streakIcon}>{streak.current > 0 ? '🔥' : '🌱'}</Text>
        <View style={styles.streakInfo}>
          <Text style={styles.streakTitle}>連続記録</Text>
          <Text style={styles.streakCount} testID="streak-count">
            {streak.current} 日
          </Text>
        </View>
        <View style={styles.streakBest}>
          <Text style={styles.streakTitle}>最長</Text>
          <Text style={styles.streakBestCount}>{streak.longest} 日</Text>
        </View>
      </View>

      <Text style={styles.sectionTitle}>今日のルーティン</Text>

      {total === 0 ? (
        <EmptyState
          testID="home-empty"
          icon="📋"
          title="ルーティンがありません"
          message="まずは1つ作ってみましょう。作ったその日から記録が残ります。"
          action={<Button title="ルーティンを作る" onPress={() => router.push('/routine/create')} testID="home-create-routine" />}
        />
      ) : due.length === 0 && later.length === 0 ? (
        <EmptyState
          testID="home-all-done"
          icon="🎉"
          title="今日の分は完了です"
          message="おつかれさま。この調子で続けましょう。"
        />
      ) : null}

      {due.map(item => (
        <RoutineCard
          key={item.routine.id}
          testID={`routine-card-${item.routine.id}`}
          name={item.routine.name}
          icon={item.routine.icon}
          color={item.routine.color}
          subtitle={`${item.frequencyLabel} ・ ${item.routine.routineExercises.length}種目`}
          state="due"
          onPress={() => router.push(`/workout/${item.routine.id}`)}
        />
      ))}

      {later.length > 0 ? (
        <>
          <Text style={styles.subSectionTitle}>今日は予定なし</Text>
          {later.map(item => (
            <RoutineCard
              key={item.routine.id}
              testID={`routine-card-${item.routine.id}`}
              name={item.routine.name}
              icon={item.routine.icon}
              color={item.routine.color}
              subtitle={item.frequencyLabel}
              state="later"
              onPress={() => router.push(`/workout/${item.routine.id}`)}
            />
          ))}
        </>
      ) : null}

      {done.length > 0 ? (
        <>
          <Text style={styles.subSectionTitle}>完了</Text>
          {done.map(item => (
            <RoutineCard
              key={item.routine.id}
              testID={`routine-card-${item.routine.id}`}
              name={item.routine.name}
              icon={item.routine.icon}
              color={item.routine.color}
              subtitle="今日は完了しました"
              state="done"
              onPress={() => router.push(`/workout/${item.routine.id}`)}
            />
          ))}
        </>
      ) : null}
    </ScrollView>
  );
}

const RoutineCard: React.FC<{
  name: string;
  icon: string;
  color: string;
  subtitle: string;
  state: 'due' | 'done' | 'later';
  onPress: () => void;
  testID: string;
}> = ({ name, icon, color, subtitle, state, onPress, testID }) => (
  <TouchableOpacity
    testID={testID}
    accessibilityRole="button"
    style={[styles.card, state !== 'due' && styles.cardMuted]}
    onPress={onPress}
  >
    <View style={[styles.iconContainer, { backgroundColor: color }]}>
      <Text style={styles.icon}>{icon}</Text>
    </View>
    <View style={styles.cardInfo}>
      <Text style={styles.cardTitle}>{name}</Text>
      <Text style={styles.cardSubtitle}>{subtitle}</Text>
    </View>
    <Text style={state === 'done' ? styles.doneIcon : styles.startIcon}>{state === 'done' ? '✅' : '▶'}</Text>
  </TouchableOpacity>
);

const C = Colors.dark;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background },
  content: { padding: Spacing.md, paddingBottom: Spacing.xl },
  header: { marginBottom: Spacing.lg },
  greeting: { fontSize: 28, fontWeight: 'bold', color: C.textPrimary },
  date: { fontSize: 14, color: C.textSecondary, marginTop: Spacing.xs },
  streakBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: C.surfaceElevated,
    padding: Spacing.md,
    borderRadius: Radius.lg,
    marginBottom: Spacing.xl,
    borderWidth: 1,
    borderColor: C.border,
  },
  streakIcon: { fontSize: 32, marginRight: Spacing.md },
  streakInfo: { flex: 1 },
  streakBest: { alignItems: 'flex-end' },
  streakTitle: { color: C.textSecondary, fontSize: 12 },
  streakCount: { color: C.accent, fontSize: 20, fontWeight: 'bold' },
  streakBestCount: { color: C.textPrimary, fontSize: 16, fontWeight: 'bold' },
  sectionTitle: { fontSize: 20, fontWeight: 'bold', color: C.textPrimary, marginBottom: Spacing.md },
  subSectionTitle: {
    fontSize: 13,
    fontWeight: 'bold',
    color: C.textSecondary,
    marginTop: Spacing.md,
    marginBottom: Spacing.sm,
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: C.surface,
    padding: Spacing.md,
    borderRadius: Radius.lg,
    marginBottom: Spacing.sm,
    borderWidth: 1,
    borderColor: C.border,
  },
  cardMuted: { opacity: 0.55 },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: Spacing.md,
  },
  icon: { fontSize: 24 },
  cardInfo: { flex: 1 },
  cardTitle: { color: C.textPrimary, fontSize: 16, fontWeight: 'bold', marginBottom: 2 },
  cardSubtitle: { color: C.textSecondary, fontSize: 12 },
  startIcon: { fontSize: 18, color: C.primaryLight, paddingHorizontal: Spacing.sm },
  doneIcon: { fontSize: 18, paddingHorizontal: Spacing.sm },
});

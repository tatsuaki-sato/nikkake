import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  PanResponder,
  GestureResponderEvent,
  PanResponderGestureState,
} from 'react-native';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter, useFocusEffect } from 'expo-router';
import { Colors } from '../../constants/colors';
import { getHome, reorderRoutines } from '../../lib/repository';
import { greetingForHour } from '../../lib/utils';
import { Button, EmptyState, Spacing, Radius } from '../../components/ui';
import type { HomeView, TodayRoutineView } from '../../lib/views';

/**
 * ホーム。アプリを開いた直後に見る画面。
 * サインインの有無に関係なく、ここに「今日やるルーティン」が並んでいて
 * 1タップで開始できる状態にしておくことがこの画面の唯一の役目。
 *
 * 挨拶・日付・連続記録は1行にまとめている。縦幅を食う要素を増やさないため。
 */
export default function HomeScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();

  // 区分（今日やる / 予定なし / 完了）も連続記録もサーバが決める。
  // ここで振り分け直すと、サーバと端末で基準がずれても誰も気づけない。
  const homeQuery = useQuery({ queryKey: ['home'], queryFn: () => getHome() });

  // ワークアウトから戻ってきたときに完了状態を即反映させる
  useFocusEffect(
    React.useCallback(() => {
      void homeQuery.refetch();
    }, [])
  );

  const reorder = useMutation({
    mutationFn: (ids: string[]) => reorderRoutines(ids),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['home'] }),
  });

  const home = homeQuery.data;
  const streak = home?.streak ?? { current: 0, longest: 0, lastCompletedDate: null };

  const due = home?.due ?? [];
  const done = home?.completed ?? [];
  const later = home?.notScheduled ?? [];
  const total = due.length + done.length + later.length;

  const dueOrder = useSortableOrder(due.map(item => item.routine.id));
  const laterOrder = useSortableOrder(later.map(item => item.routine.id));
  const doneOrder = useSortableOrder(done.map(item => item.routine.id));

  const itemsById = new Map<string, TodayRoutineView>(
    [...due, ...later, ...done].map(item => [item.routine.id, item])
  );

  // 区分をまたいだ移動はさせない。「今日やる」か「完了」かはサーバが決めるもので、
  // ドラッグで変えるものではないため
  const commitOrder = () => {
    reorder.mutate([...dueOrder.order, ...laterOrder.order, ...doneOrder.order]);
  };

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
        <View style={styles.headerGreeting}>
          <Text style={styles.greeting}>{greetingForHour(new Date().getHours())}</Text>
          <Text style={styles.date}>
            {new Date().toLocaleDateString('ja-JP', { month: 'long', day: 'numeric', weekday: 'short' })}
          </Text>
        </View>
        <View style={styles.streakBanner} testID="streak-banner">
          <Text style={styles.streakIcon}>{streak.current > 0 ? '🔥' : '🌱'}</Text>
          <Text style={styles.streakCount} testID="streak-count">
            {streak.current} 日
          </Text>
          <Text style={styles.streakBest}>(最長{streak.longest}日)</Text>
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

      <SortableSection
        order={dueOrder}
        itemsById={itemsById}
        state="due"
        onPress={id => router.push(`/workout/${id}`)}
        onCommit={commitOrder}
      />

      {later.length > 0 ? (
        <>
          <Text style={styles.subSectionTitle}>今日は予定なし</Text>
          <SortableSection
            order={laterOrder}
            itemsById={itemsById}
            state="later"
            onPress={id => router.push(`/workout/${id}`)}
            onCommit={commitOrder}
          />
        </>
      ) : null}

      {done.length > 0 ? (
        <>
          <Text style={styles.subSectionTitle}>完了</Text>
          <SortableSection
            order={doneOrder}
            itemsById={itemsById}
            state="done"
            onPress={id => router.push(`/workout/${id}`)}
            onCommit={commitOrder}
          />
        </>
      ) : null}
    </ScrollView>
  );
}

/**
 * 区分（今日やる／予定なし／完了）内での並び順。
 * サーバの応答が変わったら追従するが、ドラッグ中は追従させない
 * （ドラッグの最中に invalidate が走って手元の並びが飛ぶのを防ぐ）。
 */
function useSortableOrder(ids: string[]) {
  const key = ids.join(' ');
  const [order, setOrder] = useState(ids);
  const dragging = useRef(false);

  useEffect(() => {
    if (!dragging.current) setOrder(ids);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  return { order, setOrder, dragging };
}

type SortState = 'due' | 'later' | 'done';

const SortableSection: React.FC<{
  order: ReturnType<typeof useSortableOrder>;
  itemsById: Map<string, TodayRoutineView>;
  state: SortState;
  onPress: (routineId: string) => void;
  onCommit: () => void;
}> = ({ order, itemsById, state, onPress, onCommit }) => {
  // ページ座標やmeasure()は使わない。onLayoutで拾った「コンテナ内での相対位置」と
  // PanResponderが返す移動量(dy、ジェスチャー開始からの累計)だけで完結させる。
  const itemLayouts = useRef<Record<string, { y: number; height: number }>>({});
  const [dragId, setDragId] = useState<string | null>(null);
  const [dragDy, setDragDy] = useState(0);
  const dragStartY = useRef(0);
  const dragHeight = useRef(0);

  // orderやonCommitは毎レンダー新しいオブジェクト/関数になるが、PanResponderの
  // インスタンス自体はidごとに使い回す。PanResponder.create()を毎レンダー呼び直すと
  // (ドラッグ中はorder.setOrder/setDragDyのたびに再レンダーが起きる)、
  // react-native-webはpanHandlersの中身が変わったDOMノードにハンドラを付け替え、
  // そのたびにジェスチャーの起点がリセットされて移動量が1ステップ分にしかならない。
  const latest = useRef({ order, onCommit });
  latest.current = { order, onCommit };
  const responders = useRef<Record<string, ReturnType<typeof PanResponder.create>>>({});

  const getResponder = (id: string) => {
    if (!responders.current[id]) {
      const finishDrag = () => {
        setDragId(null);
        latest.current.order.dragging.current = false;
        latest.current.onCommit();
      };

      responders.current[id] = PanResponder.create({
        onStartShouldSetPanResponder: () => true,
        onPanResponderTerminationRequest: () => false,
        onPanResponderGrant: () => {
          const layout = itemLayouts.current[id];
          if (!layout) return;
          dragStartY.current = layout.y;
          dragHeight.current = layout.height;
          latest.current.order.dragging.current = true;
          setDragId(id);
          setDragDy(0);
        },
        onPanResponderMove: (_evt: GestureResponderEvent, gestureState: PanResponderGestureState) => {
          setDragDy(gestureState.dy);

          const currentOrder = latest.current.order.order;
          const others = currentOrder.filter(otherId => otherId !== id);
          const pointerMidY = dragStartY.current + gestureState.dy + dragHeight.current / 2;

          let insertIndex = others.length;
          for (let i = 0; i < others.length; i++) {
            const layout = itemLayouts.current[others[i]];
            if (!layout) continue;
            if (pointerMidY < layout.y + layout.height / 2) {
              insertIndex = i;
              break;
            }
          }

          const next = [...others.slice(0, insertIndex), id, ...others.slice(insertIndex)];
          if (next.join() !== currentOrder.join()) latest.current.order.setOrder(next);
        },
        // web(react-native-web)ではmouseupの位置によってreleaseではなく
        // terminateが飛んでくることがある。どちらでもドラッグは終わっているので
        // 同じ後始末をする（terminateだからと元の順番に戻すと、ユーザーから見て
        // 触ったのに反映されない挙動になる）
        onPanResponderRelease: () => finishDrag(),
        onPanResponderTerminate: () => finishDrag(),
      });
    }
    return responders.current[id];
  };

  return (
    <View style={styles.sortableContainer}>
      {order.order.map(id => {
        const item = itemsById.get(id);
        if (!item) return null;
        const isDragging = id === dragId;
        const responder = getResponder(id);

        return (
          <View
            key={id}
            onLayout={e => {
              itemLayouts.current[id] = { y: e.nativeEvent.layout.y, height: e.nativeEvent.layout.height };
            }}
            style={isDragging ? [styles.draggingWrap, { top: dragStartY.current + dragDy }] : undefined}
          >
            <RoutineCard
              testID={`routine-card-${item.routine.id}`}
              name={item.routine.name}
              icon={item.routine.icon}
              color={item.routine.color}
              subtitle={
                state === 'done'
                  ? '今日は完了しました'
                  : state === 'later'
                    ? item.frequencyLabel
                    : `${item.frequencyLabel} ・ ${item.routine.routineExercises.length}種目`
              }
              state={state}
              onPress={() => onPress(item.routine.id)}
              dragHandlers={responder.panHandlers}
            />
          </View>
        );
      })}
    </View>
  );
};

const RoutineCard: React.FC<{
  name: string;
  icon: string;
  color: string;
  subtitle: string;
  state: SortState;
  onPress: () => void;
  testID: string;
  dragHandlers: ReturnType<typeof PanResponder.create>['panHandlers'];
}> = ({ name, icon, color, subtitle, state, onPress, testID, dragHandlers }) => (
  <View style={[styles.card, state !== 'due' && styles.cardMuted]}>
    <TouchableOpacity testID={testID} accessibilityRole="button" style={styles.cardMain} onPress={onPress}>
      <View style={[styles.iconContainer, { backgroundColor: color }]}>
        <Text style={styles.icon}>{icon}</Text>
      </View>
      <View style={styles.cardInfo}>
        <Text style={styles.cardTitle}>{name}</Text>
        <Text style={styles.cardSubtitle}>{subtitle}</Text>
      </View>
      <Text style={state === 'done' ? styles.doneIcon : styles.startIcon}>{state === 'done' ? '✅' : '▶'}</Text>
    </TouchableOpacity>
    <View
      style={styles.dragHandle}
      accessibilityRole="button"
      accessibilityLabel="ドラッグして並び替え"
      testID={`routine-drag-${testID.replace('routine-card-', '')}`}
      {...dragHandlers}
    >
      <Text style={styles.dragHandleIcon}>⠿</Text>
    </View>
  </View>
);

const C = Colors.dark;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background },
  content: { padding: Spacing.md, paddingBottom: Spacing.xl },
  header: { flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: Spacing.lg },
  headerGreeting: { flexShrink: 1 },
  greeting: { fontSize: 20, fontWeight: 'bold', color: C.textPrimary },
  date: { fontSize: 12, color: C.textSecondary, marginTop: 2 },
  streakBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    flexShrink: 1,
    flexWrap: 'wrap',
    justifyContent: 'flex-end',
    paddingLeft: Spacing.sm,
  },
  streakIcon: { fontSize: 20 },
  streakCount: { color: C.accent, fontSize: 16, fontWeight: 'bold' },
  streakBest: { color: C.textSecondary, fontSize: 12 },
  sectionTitle: { fontSize: 20, fontWeight: 'bold', color: C.textPrimary, marginBottom: Spacing.md },
  subSectionTitle: {
    fontSize: 13,
    fontWeight: 'bold',
    color: C.textSecondary,
    marginTop: Spacing.md,
    marginBottom: Spacing.sm,
  },
  sortableContainer: { position: 'relative' },
  draggingWrap: {
    position: 'absolute',
    left: 0,
    right: 0,
    zIndex: 50,
    elevation: 10,
    shadowColor: '#000',
    shadowOpacity: 0.4,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 8 },
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: C.surface,
    borderRadius: Radius.lg,
    marginBottom: Spacing.sm,
    borderWidth: 1,
    borderColor: C.border,
    paddingRight: Spacing.sm,
  },
  cardMain: { flexDirection: 'row', alignItems: 'center', flex: 1, padding: Spacing.md },
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
  dragHandle: { width: 40, minHeight: 40, alignItems: 'center', justifyContent: 'center' },
  dragHandleIcon: { fontSize: 18, color: C.textSecondary },
});

import { useEffect, useRef, useState } from 'react';
import type { PointerEvent as ReactPointerEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { getDateString, greetingForHour } from '@nikkake/domain';
import type { TodayRoutine, WorkoutSummary } from '@nikkake/api-client';
import { api } from '../lib';
import { EmptyState, Button, Loading } from '../components/ui';
import { Workout } from './Workout';

/**
 * ホーム。起動直後に見る画面。
 *
 * タップやクリックで別の表示に切り替える、ということをしない。
 * 今日のルーティンは、開いた瞬間からその種目のチェック欄がそのまま並んでいる
 * （ここでの「ホーム画面」は、URLも中身も変わらない、この関数が返す1つの画面のみを指す）。
 * 完了済みのルーティンもチェック欄は表示したままにする（やり直し・追加記録ができるように）。
 * 完了後に別画面へ飛ばすこともしない。結果はその場に出す。
 *
 * 完了直後の結果はここ（Home）で持つ。ルーティンが「今日やる」→「完了」へ移ると
 * 表示位置のセクションが変わり、その中のWorkoutは一度アンマウント・再マウントされる
 * ため、Workout自身に状態を持たせると表示した瞬間に消えてしまう。
 *
 * 挨拶・日付・連続記録は1行にまとめている。縦幅を食う要素を増やさないため。
 */
export const Home = ({ onCreateRoutine }: {
  onCreateRoutine: () => void;
}) => {
  const qc = useQueryClient();
  const today = getDateString();
  const { data, isLoading } = useQuery({
    queryKey: ['home', today],
    queryFn: () => api.home(today),
  });
  const [results, setResults] = useState<Record<string, WorkoutSummary | 'offline'>>({});

  const reorder = useMutation({
    mutationFn: (ids: string[]) => api.reorderRoutines(ids),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['home'] }),
  });

  const dueOrder = useSortableOrder(data?.due.map(item => item.routine.id) ?? []);
  const laterOrder = useSortableOrder(data?.notScheduled.map(item => item.routine.id) ?? []);
  const doneOrder = useSortableOrder(data?.completed.map(item => item.routine.id) ?? []);

  if (isLoading || !data) return <Loading />;

  const total = data.due.length + data.notScheduled.length + data.completed.length;
  const now = new Date();

  const itemsById = new Map<string, TodayRoutine>(
    [...data.due, ...data.notScheduled, ...data.completed].map(item => [item.routine.id, item])
  );

  const handleFinished = (routineId: string) => (result: WorkoutSummary | 'offline') => {
    setResults(prev => ({ ...prev, [routineId]: result }));
    void qc.invalidateQueries();
  };
  const dismissResult = (routineId: string) =>
    setResults(prev => {
      const next = { ...prev };
      delete next[routineId];
      return next;
    });

  // 区分ごとの順序を結合した並びをそのまま送る。区分をまたいだ移動はさせない
  // （「今日やる」か「完了」かはサーバが決めるもので、ドラッグで変えるものではないため）
  const commitOrder = () => {
    reorder.mutate([...dueOrder.order, ...laterOrder.order, ...doneOrder.order]);
  };

  return (
    <div data-testid="home-screen">
      <div className="home-header">
        <div>
          <h1 className="h1" style={{ fontSize: 20 }}>{greetingForHour(now.getHours())}</h1>
          <div className="muted" style={{ marginTop: 2 }}>
            {now.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric', weekday: 'short' })}
          </div>
        </div>
        <div className="row home-header__streak" data-testid="streak-banner">
          <span style={{ fontSize: 22 }}>{data.streak.current > 0 ? '🔥' : '🌱'}</span>
          <span data-testid="streak-count" style={{ fontWeight: 'bold', color: 'var(--accent)' }}>
            {data.streak.current} 日
          </span>
          <span className="muted">(最長{data.streak.longest}日)</span>
        </div>
      </div>

      <h2 className="section-title" style={{ margin: 'var(--sp-3) 0 var(--sp-2)' }}>今日のルーティン</h2>

      {total === 0 ? (
        <EmptyState
          testId="home-empty"
          icon="📋"
          title="ルーティンがありません"
          message="まずは1つ作ってみましょう。作ったその日から記録が残ります。"
          action={<Button label="ルーティンを作る" onClick={onCreateRoutine} testId="home-create-routine" />}
        />
      ) : data.due.length === 0 && data.notScheduled.length === 0 ? (
        <EmptyState
          testId="home-all-done"
          icon="🎉"
          title="今日の分は完了です"
          message="おつかれさま。この調子で続けましょう。"
        />
      ) : null}

      <SortableSection
        state="due"
        order={dueOrder}
        itemsById={itemsById}
        results={results}
        onFinished={handleFinished}
        onDismissResult={dismissResult}
        onCommit={commitOrder}
      />

      {laterOrder.order.length > 0 && (
        <>
          <div className="muted" style={{ marginTop: 'var(--sp-3)', fontWeight: 'bold' }}>今日は予定なし</div>
          <SortableSection
            state="later"
            order={laterOrder}
            itemsById={itemsById}
            results={results}
            onFinished={handleFinished}
            onDismissResult={dismissResult}
            onCommit={commitOrder}
          />
        </>
      )}

      {doneOrder.order.length > 0 && (
        <>
          <div className="muted" style={{ marginTop: 'var(--sp-3)', fontWeight: 'bold' }}>完了</div>
          <SortableSection
            state="done"
            order={doneOrder}
            itemsById={itemsById}
            results={results}
            onFinished={handleFinished}
            onDismissResult={dismissResult}
            onCommit={commitOrder}
          />
        </>
      )}
    </div>
  );
};

/**
 * 区分（今日やる／予定なし／完了）内での並び順。
 * サーバの応答が変わったら追従するが、ドラッグ中は追従させない
 * （ドラッグの最中に invalidate が走って手元の並びが飛ぶのを防ぐ）。
 */
const useSortableOrder = (ids: string[]) => {
  const key = ids.join(' ');
  const [order, setOrder] = useState(ids);
  const dragging = useRef(false);

  useEffect(() => {
    if (!dragging.current) setOrder(ids);
    // idsの中身が変わったときだけ追従すればよい
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  return { order, setOrder, dragging };
};

type SortState = 'due' | 'later' | 'done';

const SortableSection = ({ state, order, itemsById, results, onFinished, onDismissResult, onCommit }: {
  state: SortState;
  order: ReturnType<typeof useSortableOrder>;
  itemsById: Map<string, TodayRoutine>;
  results: Record<string, WorkoutSummary | 'offline'>;
  onFinished: (routineId: string) => (result: WorkoutSummary | 'offline') => void;
  onDismissResult: (routineId: string) => void;
  onCommit: () => void;
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const itemRefs = useRef<Record<string, HTMLDivElement | null>>({});
  const [dragId, setDragId] = useState<string | null>(null);
  const [dragY, setDragY] = useState(0);
  const grabOffset = useRef(0);
  const dragMetrics = useRef({ left: 0, width: 0, height: 0 });

  const startDrag = (id: string) => (e: ReactPointerEvent<HTMLButtonElement>) => {
    const el = itemRefs.current[id];
    const container = containerRef.current;
    if (!el || !container) return;

    const rect = el.getBoundingClientRect();
    const containerRect = container.getBoundingClientRect();
    grabOffset.current = e.clientY - rect.top;
    dragMetrics.current = { left: containerRect.left, width: containerRect.width, height: rect.height };
    order.dragging.current = true;
    setDragId(id);
    setDragY(e.clientY);
    e.currentTarget.setPointerCapture(e.pointerId);
  };

  const onMove = (e: ReactPointerEvent<HTMLButtonElement>) => {
    if (!dragId) return;
    setDragY(e.clientY);

    const others = order.order.filter(id => id !== dragId);
    const pointerMid = e.clientY - grabOffset.current + dragMetrics.current.height / 2;

    let insertIndex = others.length;
    for (let i = 0; i < others.length; i++) {
      const otherEl = itemRefs.current[others[i]];
      if (!otherEl) continue;
      const r = otherEl.getBoundingClientRect();
      if (pointerMid < r.top + r.height / 2) {
        insertIndex = i;
        break;
      }
    }

    const next = [...others.slice(0, insertIndex), dragId, ...others.slice(insertIndex)];
    if (next.join() !== order.order.join()) order.setOrder(next);
  };

  const endDrag = () => {
    if (!dragId) return;
    setDragId(null);
    order.dragging.current = false;
    onCommit();
  };

  return (
    <div ref={containerRef}>
      {order.order.map(id => {
        const item = itemsById.get(id);
        if (!item) return null;
        const isDragging = id === dragId;

        return (
          <div
            key={id}
            ref={el => { itemRefs.current[id] = el; }}
            style={isDragging ? {
              position: 'fixed',
              left: dragMetrics.current.left,
              width: dragMetrics.current.width,
              top: dragY - grabOffset.current,
              zIndex: 50,
              opacity: 0.95,
              boxShadow: '0 8px 24px rgba(0, 0, 0, 0.4)',
            } : undefined}
          >
            <RoutineSection
              item={item}
              state={state}
              result={results[id] ?? null}
              onFinished={onFinished(id)}
              onDismissResult={() => onDismissResult(id)}
              onDragPointerDown={startDrag(id)}
              onDragPointerMove={onMove}
              onDragPointerUp={endDrag}
            />
          </div>
        );
      })}
    </div>
  );
};

const RoutineSection = ({ item, state, result, onFinished, onDismissResult, onDragPointerDown, onDragPointerMove, onDragPointerUp }: {
  item: TodayRoutine;
  state: SortState;
  result: WorkoutSummary | 'offline' | null;
  onFinished: (result: WorkoutSummary | 'offline') => void;
  onDismissResult: () => void;
  onDragPointerDown: (e: ReactPointerEvent<HTMLButtonElement>) => void;
  onDragPointerMove: (e: ReactPointerEvent<HTMLButtonElement>) => void;
  onDragPointerUp: (e: ReactPointerEvent<HTMLButtonElement>) => void;
}) => (
  <div style={{ marginTop: 'var(--sp-4)', opacity: state === 'due' ? 1 : 0.75 }}>
    <div className="row" data-testid={`routine-card-${item.routine.id}`}>
      <span className="routine-card__icon" style={{ backgroundColor: item.routine.color }}>
        {item.routine.icon}
      </span>
      <span className="routine-card__body">
        <span className="routine-card__name">{item.routine.name}</span>
        <div className="muted">
          {state === 'done' ? '✅ 今日は完了しました' : `${item.frequencyLabel} ・ ${item.routine.routineExercises.length}種目`}
        </div>
      </span>
      <button
        type="button"
        className="drag-handle"
        aria-label="ドラッグして並び替え"
        data-testid={`routine-drag-${item.routine.id}`}
        onPointerDown={onDragPointerDown}
        onPointerMove={onDragPointerMove}
        onPointerUp={onDragPointerUp}
        onPointerCancel={onDragPointerUp}
      >
        ⠿
      </button>
    </div>
    <div style={{ marginTop: 'var(--sp-3)' }}>
      <Workout routineId={item.routine.id} result={result} onFinished={onFinished} onDismissResult={onDismissResult} />
    </div>
  </div>
);

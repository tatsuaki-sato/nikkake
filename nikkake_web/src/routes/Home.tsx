import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getDateString, greetingForHour } from '@nikkake/domain';
import type { TodayRoutine, WorkoutSummary } from '@nikkake/api-client';
import { api } from '../lib';
import { Card, EmptyState, Button, Loading } from '../components/ui';
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

  if (isLoading || !data) return <Loading />;

  const total = data.due.length + data.notScheduled.length + data.completed.length;
  const now = new Date();

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

  return (
    <div data-testid="home-screen">
      <h1 className="h1">{greetingForHour(now.getHours())}</h1>
      <div className="muted">
        {now.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric', weekday: 'short' })}
      </div>

      <div style={{ marginTop: 'var(--sp-4)' }}>
        <Card elevated testId="streak-banner">
          <div className="row">
            <span style={{ fontSize: 32 }}>{data.streak.current > 0 ? '🔥' : '🌱'}</span>
            <div style={{ flex: 1 }}>
              <div className="muted">連続記録</div>
              <div data-testid="streak-count" style={{ fontSize: 20, fontWeight: 'bold', color: 'var(--accent)' }}>
                {data.streak.current} 日
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div className="muted">最長</div>
              <div style={{ fontWeight: 'bold' }}>{data.streak.longest} 日</div>
            </div>
          </div>
        </Card>
      </div>

      <h2 className="section-title">今日のルーティン</h2>

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

      {data.due.map(item => (
        <RoutineSection key={item.routine.id} item={item} state="due"
          result={results[item.routine.id] ?? null}
          onFinished={handleFinished(item.routine.id)}
          onDismissResult={() => dismissResult(item.routine.id)} />
      ))}

      {data.notScheduled.length > 0 && (
        <>
          <div className="muted" style={{ marginTop: 'var(--sp-3)', fontWeight: 'bold' }}>今日は予定なし</div>
          {data.notScheduled.map(item => (
            <RoutineSection key={item.routine.id} item={item} state="later"
              result={results[item.routine.id] ?? null}
              onFinished={handleFinished(item.routine.id)}
              onDismissResult={() => dismissResult(item.routine.id)} />
          ))}
        </>
      )}

      {data.completed.length > 0 && (
        <>
          <div className="muted" style={{ marginTop: 'var(--sp-3)', fontWeight: 'bold' }}>完了</div>
          {data.completed.map(item => (
            <RoutineSection key={item.routine.id} item={item} state="done"
              result={results[item.routine.id] ?? null}
              onFinished={handleFinished(item.routine.id)}
              onDismissResult={() => dismissResult(item.routine.id)} />
          ))}
        </>
      )}
    </div>
  );
};

const RoutineSection = ({ item, state, result, onFinished, onDismissResult }: {
  item: TodayRoutine;
  state: 'due' | 'later' | 'done';
  result: WorkoutSummary | 'offline' | null;
  onFinished: (result: WorkoutSummary | 'offline') => void;
  onDismissResult: () => void;
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
    </div>
    <div style={{ marginTop: 'var(--sp-3)' }}>
      <Workout routineId={item.routine.id} result={result} onFinished={onFinished} onDismissResult={onDismissResult} />
    </div>
  </div>
);

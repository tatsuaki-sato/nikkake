import { useQuery } from '@tanstack/react-query';
import { getDateString, greetingForHour } from '@nikkake/domain';
import type { TodayRoutine } from '@nikkake/api-client';
import { api } from '../lib';
import { Card, EmptyState, Button, Loading } from '../components/ui';

/**
 * ホーム。起動直後に見る画面。
 * 「今日やるルーティン」が並んでいて1タップで開始できることが、この画面の唯一の役目。
 * 区分（due / notScheduled / completed）はサーバが決めている。
 */
export const Home = ({ onOpenWorkout, onCreateRoutine }: {
  onOpenWorkout: (routineId: string) => void;
  onCreateRoutine: () => void;
}) => {
  const today = getDateString();
  const { data, isLoading } = useQuery({
    queryKey: ['home', today],
    queryFn: () => api.home(today),
  });

  if (isLoading || !data) return <Loading />;

  const total = data.due.length + data.notScheduled.length + data.completed.length;
  const now = new Date();

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

      {data.due.map(item => <RoutineCard key={item.routine.id} item={item} state="due" onClick={onOpenWorkout} />)}

      {data.notScheduled.length > 0 && (
        <>
          <div className="muted" style={{ marginTop: 'var(--sp-3)', fontWeight: 'bold' }}>今日は予定なし</div>
          {data.notScheduled.map(item => (
            <RoutineCard key={item.routine.id} item={item} state="later" onClick={onOpenWorkout} />
          ))}
        </>
      )}

      {data.completed.length > 0 && (
        <>
          <div className="muted" style={{ marginTop: 'var(--sp-3)', fontWeight: 'bold' }}>完了</div>
          {data.completed.map(item => (
            <RoutineCard key={item.routine.id} item={item} state="done" onClick={onOpenWorkout} />
          ))}
        </>
      )}
    </div>
  );
};

const RoutineCard = ({ item, state, onClick }: {
  item: TodayRoutine; state: 'due' | 'later' | 'done'; onClick: (id: string) => void;
}) => (
  <button
    className={`routine-card${state === 'due' ? '' : ' routine-card--muted'}`}
    data-testid={`routine-card-${item.routine.id}`}
    onClick={() => onClick(item.routine.id)}
  >
    <span className="routine-card__icon" style={{ backgroundColor: item.routine.color }}>
      {item.routine.icon}
    </span>
    <span className="routine-card__body">
      <span className="routine-card__name">{item.routine.name}</span>
      <div className="muted">
        {state === 'done'
          ? '今日は完了しました'
          : `${item.frequencyLabel} ・ ${item.routine.routineExercises.length}種目`}
      </div>
    </span>
    <span style={{ fontSize: 18, color: state === 'done' ? undefined : 'var(--primary-light)' }}>
      {state === 'done' ? '✅' : '▶'}
    </span>
  </button>
);

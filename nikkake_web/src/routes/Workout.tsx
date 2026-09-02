import { useEffect, useMemo, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { formatDuration, getDateString, uuid } from '@nikkake/domain';
import type { RecordedSetInput, WorkoutSummary } from '@nikkake/api-client';
import { api } from '../lib';
import { Card, EmptyState, Loading } from '../components/ui';

interface SetState {
  id: string;
  setNumber: number;
  reps: number | null;
  weight: number | null;
  durationSec: number | null;
  completed: boolean;
}

/**
 * ワークアウトのチェック欄。ホーム画面の各ルーティンの下に常時そのまま表示される
 * （別画面へ切り替える・タップで開く、という操作を挟まない。「1画面で全部やりたい」
 * という要望への対応）。記録はオフラインでもキューに積まれるので、圏外でも操作が失われない。
 *
 * 全種目のチェック欄を一度に表示する（スクロールだけで全種目に届く）。
 */
export const Workout = ({ routineId, result, onFinished, onDismissResult }: {
  routineId: string;
  // 完了直後の結果。ルーティンが「今日やる」→「完了」へ移ると、このコンポーネントは
  // 一度アンマウント・再マウントされるため、コンポーネント内には持たずHomeから受け取る
  result: WorkoutSummary | 'offline' | null;
  onFinished: (result: WorkoutSummary | 'offline') => void;
  onDismissResult: () => void;
}) => {
  const { data, isLoading } = useQuery({
    queryKey: ['workoutSession', routineId],
    queryFn: () => api.workoutSession(routineId),
    // 実行中に再取得されると入力中の値が飛ぶので固定する。
    // 一方で「前回の記録」は開始のたびに最新でなければならないので、
    // 画面を離れたらキャッシュを捨てて次回は必ず取り直す。
    staleTime: Infinity,
    gcTime: 0,
    refetchOnWindowFocus: false,
    refetchOnMount: 'always',
  });

  const [sets, setSets] = useState<SetState[][]>([]);
  const [elapsed, setElapsed] = useState(0);
  // タイマーはホームを開いた瞬間ではなく、人間が「開始」を押した時だけ進む
  const [running, setRunning] = useState(false);
  const [rest, setRest] = useState(0);
  const [saving, setSaving] = useState(false);
  // 過去の日付の実績も登録できるように。既定は今日（日付はサーバではなく端末が決める）
  const today = getDateString();
  const [logDate, setLogDate] = useState(today);
  const startedAt = useRef(new Date().toISOString());
  const initialised = useRef(false);

  // 前回の記録を各セットの初期値にする
  useEffect(() => {
    if (!data || initialised.current) return;
    initialised.current = true;

    setSets(
      data.exercises.map(e => {
        const count = Math.max(1, e.targetSets);
        return Array.from({ length: count }, (_, i) => {
          const previous = e.previousSets.find(p => p.setNumber === i + 1);
          return {
            id: uuid(),
            setNumber: i + 1,
            reps: previous?.reps ?? e.targetReps,
            weight: previous?.weight ?? e.targetWeight,
            durationSec: previous?.durationSec ?? e.targetDurationSec,
            completed: false,
          };
        });
      }),
    );
  }, [data]);

  // 経過時間とレストタイマーを1本のintervalで進める。一時停止中は進めない
  useEffect(() => {
    if (!running) return;
    const timer = setInterval(() => {
      setElapsed(v => v + 1);
      setRest(v => (v > 0 ? v - 1 : 0));
    }, 1000);
    return () => clearInterval(timer);
  }, [running]);

  const totals = useMemo(() => {
    const all = sets.flat();
    return { done: all.filter(s => s.completed).length, total: all.length };
  }, [sets]);

  if (isLoading || !data) return <Loading />;
  if (data.exercises.length === 0) {
    return (
      <EmptyState
        testId="workout-not-found"
        icon="🤔"
        title="種目が登録されていません"
        message="ルーティンの編集から種目を追加してください。"
      />
    );
  }
  if (sets.length === 0) return <Loading />;

  const patch = (exerciseIndex: number, setNumber: number, changes: Partial<SetState>) =>
    setSets(prev => prev.map((group, i) =>
      i === exerciseIndex ? group.map(s => (s.setNumber === setNumber ? { ...s, ...changes } : s)) : group,
    ));

  const toggle = (exerciseIndex: number, setNumber: number) => {
    const target = sets[exerciseIndex]?.find(s => s.setNumber === setNumber);
    if (!target) return;

    const willComplete = !target.completed;
    patch(exerciseIndex, setNumber, { completed: willComplete });
    // セット完了で休憩タイマーを自動で回す。手動だと押し忘れる
    setRest(willComplete ? data.exercises[exerciseIndex].restSec : 0);
  };

  const finish = async () => {
    setSaving(true);
    const payload: RecordedSetInput[] = sets.flatMap((group, i) =>
      group
        .filter(s => s.completed)
        .map(s => ({
          id: s.id,
          routineExerciseId: data.exercises[i].routineExerciseId,
          exerciseId: data.exercises[i].exercise.id,
          setNumber: s.setNumber,
          actualReps: s.reps,
          actualWeight: s.weight,
          actualDurationSec: s.durationSec,
        })),
    );

    const recorded = await api.recordWorkout({
      routineId,
      logDate,
      startedAt: startedAt.current,
      durationSec: elapsed,
      totalSets: totals.total,
      sets: payload,
    });

    setSaving(false);
    setRunning(false);
    onFinished(recorded.data?.summary ?? 'offline');
  };

  return (
    <div data-testid="workout-screen">
      <div className="row" style={{ marginBottom: 'var(--sp-2)' }}>
        {/* 何日の実績として記録するか。既定は今日。過去の日付を選べば後から実績を登録できる */}
        <input type="date" className="set-input" style={{ width: 'auto' }} value={logDate} max={today}
               onChange={e => setLogDate(e.target.value)} data-testid="workout-log-date" />
        <div style={{ flex: 1 }} />
        <button className="btn" style={{ width: 'auto' }} onClick={finish} disabled={saving} data-testid="workout-finish">
          完了
        </button>
      </div>

      <div className="row" style={{ marginBottom: 'var(--sp-3)' }}>
        <button className="btn btn--ghost" style={{ width: 'auto' }}
                onClick={() => setRunning(v => !v)} data-testid="workout-timer-toggle">
          {running ? '⏸ 一時停止' : '▶ 開始'}
        </button>
        <div className="muted" data-testid="workout-elapsed" style={{ marginLeft: 'var(--sp-2)' }}>
          {formatDuration(elapsed)}
        </div>
      </div>

      {result && (
        <div className="card card--elevated" style={{ marginBottom: 'var(--sp-3)', textAlign: 'center' }}
             data-testid="workout-result" onClick={onDismissResult}>
          {result === 'offline' ? (
            <>
              <div style={{ fontWeight: 'bold' }}>📥 記録しました</div>
              <div className="muted">オフラインのため、まだサーバへ送れていません。オンラインになったら自動で送信されます。</div>
            </>
          ) : (
            <>
              <div style={{ fontWeight: 'bold' }} data-testid="workout-result-status">
                {result.status === 'COMPLETED' ? '🎉 コンプリート！' : result.status === 'PARTIAL' ? '💪 記録しました' : '記録なし'}
              </div>
              <div className="muted" data-testid="workout-result-sets">
                {formatDuration(result.durationSec)} ・ {result.completedSets}/{result.totalSets}セット
                {result.totalVolume > 0 ? ` ・ ${Math.round(result.totalVolume)}kg` : ''}
              </div>
            </>
          )}
          <div className="muted" style={{ marginTop: 'var(--sp-2)' }}>タップで閉じる</div>
        </div>
      )}

      <div style={{ height: 4, background: 'var(--surface)', borderRadius: 2 }}>
        <div style={{
          height: 4, borderRadius: 2, background: 'var(--success)',
          width: `${totals.total === 0 ? 0 : Math.round((totals.done / totals.total) * 100)}%`,
        }} />
      </div>

      {rest > 0 && (
        <div className="card card--elevated" style={{ marginTop: 'var(--sp-3)', textAlign: 'center', borderColor: 'var(--accent)' }}
             onClick={() => setRest(0)} data-testid="rest-timer">
          <div className="muted">休憩中</div>
          <div style={{ fontSize: 28, fontWeight: 'bold', color: 'var(--accent)' }}>{formatDuration(rest)}</div>
          <div className="muted">タップでスキップ</div>
        </div>
      )}

      {data.exercises.map((exercise, i) => {
        const exerciseSets = sets[i] ?? [];
        const isTimeBased = exercise.targetDurationSec !== null;
        // 有酸素・ゲーム系はルーティン設定と同じく重量(kg)欄を出さない
        const category = exercise.exercise.category;
        const hasNoWeight = category === 'CARDIO' || category === 'GAME';
        const allDone = exerciseSets.length > 0 && exerciseSets.every(s => s.completed);

        return (
          <div key={exercise.routineExerciseId} style={{ marginTop: 'var(--sp-4)' }}>
            <h2 className="section-title" data-testid={`workout-exercise-name-${i}`}>
              {allDone ? '✓ ' : ''}{i + 1}/{data.exercises.length} {exercise.exercise.name}
            </h2>

            {exercise.previousLabel && (
              <div className="muted" data-testid={`workout-previous-hint-${i}`}>前回: {exercise.previousLabel}</div>
            )}

            <div style={{ marginTop: 'var(--sp-3)' }}>
              <Card>
                <div className={`set-row${hasNoWeight ? ' set-row--no-weight' : ''}`} style={{ borderTop: 'none' }}>
                  <div className="muted">セット</div>
                  {!hasNoWeight && <div className="muted" style={{ textAlign: 'center' }}>kg</div>}
                  <div className="muted" style={{ textAlign: 'center' }}>{isTimeBased ? '秒' : '回'}</div>
                  <div className="muted" style={{ textAlign: 'center' }}>完了</div>
                </div>

                {exerciseSets.map(s => (
                  <div key={s.setNumber}
                       className={`set-row${hasNoWeight ? ' set-row--no-weight' : ''}${s.completed ? ' set-row--done' : ''}`}
                       data-testid={`set-row-${i}-${s.setNumber}`}>
                    <div style={{ textAlign: 'center' }} className="muted">{s.setNumber}</div>
                    {!hasNoWeight && (
                      <input
                        className="set-input" inputMode="decimal" placeholder="自重"
                        value={s.weight ?? ''}
                        onChange={e => patch(i, s.setNumber, { weight: e.target.value === '' ? null : Number(e.target.value) })}
                        data-testid={`set-weight-${i}-${s.setNumber}`}
                      />
                    )}
                    {isTimeBased ? (
                      <input
                        className="set-input" inputMode="numeric"
                        value={s.durationSec ?? ''}
                        onChange={e => patch(i, s.setNumber, { durationSec: e.target.value === '' ? null : Number(e.target.value) })}
                        data-testid={`set-duration-${i}-${s.setNumber}`}
                      />
                    ) : (
                      <input
                        className="set-input" inputMode="numeric"
                        value={s.reps ?? ''}
                        onChange={e => patch(i, s.setNumber, { reps: e.target.value === '' ? null : Number(e.target.value) })}
                        data-testid={`set-reps-${i}-${s.setNumber}`}
                      />
                    )}
                    <button className="check" role="checkbox" aria-checked={s.completed}
                            onClick={() => toggle(i, s.setNumber)} data-testid={`set-check-${i}-${s.setNumber}`}>
                      {s.completed ? '✓' : ''}
                    </button>
                  </div>
                ))}

                <div className="row" style={{ justifyContent: 'space-between', marginTop: 'var(--sp-3)' }}>
                  <button className="btn btn--ghost" style={{ width: 'auto' }} data-testid={`remove-set-${i}`}
                          onClick={() => setSets(prev => prev.map((g, gi) => (gi === i && g.length > 1 ? g.slice(0, -1) : g)))}>
                    − セットを減らす
                  </button>
                  <button className="btn btn--ghost" style={{ width: 'auto' }} data-testid={`add-set-${i}`}
                          onClick={() => setSets(prev => prev.map((g, gi) => {
                            if (gi !== i) return g;
                            const last = g[g.length - 1];
                            return [...g, { ...last, id: uuid(), setNumber: last.setNumber + 1, completed: false }];
                          }))}>
                    ＋ セットを追加
                  </button>
                </div>
              </Card>
            </div>
          </div>
        );
      })}
    </div>
  );
};

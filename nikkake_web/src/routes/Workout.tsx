import { useEffect, useMemo, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { formatDuration, getDateString, uuid } from '@nikkake/domain';
import type { RecordedSetInput, WorkoutSummary } from '@nikkake/api-client';
import { api } from '../lib';
import { Card, Button, EmptyState, Loading } from '../components/ui';

interface SetState {
  id: string;
  setNumber: number;
  reps: number | null;
  weight: number | null;
  durationSec: number | null;
  completed: boolean;
}

/**
 * ワークアウト実行画面。
 * 記録はオフラインでもキューに積まれるので、圏外でも操作が失われない。
 *
 * 全種目のチェック欄を一度に表示する（スクロールだけで全種目に届く）。
 * 種目を1つずつタブでめくる形は「1画面で全部やりたい」という要望に合わないため廃止した。
 */
export const Workout = ({ routineId, onFinished, onCancel }: {
  routineId: string;
  onFinished: (summary: WorkoutSummary | null) => void;
  onCancel: () => void;
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
  const [rest, setRest] = useState(0);
  const [saving, setSaving] = useState(false);
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

  // 経過時間とレストタイマーを1本のintervalで進める
  useEffect(() => {
    const timer = setInterval(() => {
      setElapsed(Math.floor((Date.now() - Date.parse(startedAt.current)) / 1000));
      setRest(v => (v > 0 ? v - 1 : 0));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

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
        title="開始できませんでした"
        message="種目が登録されていません。"
        action={<Button label="戻る" onClick={onCancel} />}
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

    const result = await api.recordWorkout({
      routineId,
      logDate: getDateString(),
      startedAt: startedAt.current,
      durationSec: elapsed,
      totalSets: totals.total,
      sets: payload,
    });

    setSaving(false);
    onFinished(result.data?.summary ?? null);
  };

  return (
    <div data-testid="workout-screen">
      <div className="row" style={{ marginBottom: 'var(--sp-3)' }}>
        <button className="btn btn--ghost" style={{ width: 'auto' }} onClick={onCancel} data-testid="workout-cancel">
          中断
        </button>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <div style={{ fontWeight: 'bold' }}>{data.routine.name}</div>
          <div className="muted" data-testid="workout-elapsed">{formatDuration(elapsed)}</div>
        </div>
        <button className="btn" style={{ width: 'auto' }} onClick={finish} disabled={saving} data-testid="workout-finish">
          完了
        </button>
      </div>

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
                <div className="set-row" style={{ borderTop: 'none' }}>
                  <div className="muted">セット</div>
                  <div className="muted" style={{ textAlign: 'center' }}>kg</div>
                  <div className="muted" style={{ textAlign: 'center' }}>{isTimeBased ? '秒' : '回'}</div>
                  <div className="muted" style={{ textAlign: 'center' }}>完了</div>
                </div>

                {exerciseSets.map(s => (
                  <div key={s.setNumber} className={`set-row${s.completed ? ' set-row--done' : ''}`}
                       data-testid={`set-row-${i}-${s.setNumber}`}>
                    <div style={{ textAlign: 'center' }} className="muted">{s.setNumber}</div>
                    <input
                      className="set-input" inputMode="decimal" placeholder="自重"
                      value={s.weight ?? ''}
                      onChange={e => patch(i, s.setNumber, { weight: e.target.value === '' ? null : Number(e.target.value) })}
                      data-testid={`set-weight-${i}-${s.setNumber}`}
                    />
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

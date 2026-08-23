import { useEffect, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { uuid } from '@nikkake/domain';
import type { Exercise, ExerciseCategory, FrequencyType, RoutineExerciseInput } from '@nikkake/api-client';
import { OFFLINE_SAVE_MESSAGE, isNetworkError } from '@nikkake/api-client';
import { api } from '../lib';
import { Button, Card, Chip, ErrorText, Loading } from '../components/ui';

const ICONS = ['💪', '🏃', '🎮', '🏋️', '🚴', '🔥'];
const COLORS = ['#6C5CE7', '#00B894', '#0984E3', '#D63031', '#FDCB6E', '#E84393'];
const DAY_LABELS = ['日', '月', '火', '水', '木', '金', '土'];
const DEFAULT_REST_SEC = 60;

interface Row extends RoutineExerciseInput {
  name: string;
  icon: string | null;
  category: ExerciseCategory;
}

/** 有酸素・ゲーム系は「回数×重量」ではなく「何分やるか」で目標を決める */
const isDurationBased = (category: ExerciseCategory) => category === 'CARDIO' || category === 'GAME';
const DEFAULT_CARDIO_DURATION_SEC = 300;

/** 作成と編集で共通のフォーム。2画面に分けると入力仕様がすぐズレる */
export const RoutineForm = ({ routineId, onDone }: {
  routineId: string | null; onDone: () => void;
}) => {
  const qc = useQueryClient();
  const isEdit = routineId !== null;

  const exercisesQuery = useQuery({ queryKey: ['exercises'], queryFn: () => api.exercises() });
  const routineQuery = useQuery({
    queryKey: ['routine', routineId],
    queryFn: () => api.routine(routineId!),
    enabled: isEdit,
  });

  const [name, setName] = useState('');
  const [icon, setIcon] = useState(ICONS[0]);
  const [color, setColor] = useState(COLORS[0]);
  const [frequencyType, setFrequencyType] = useState<FrequencyType>('DAILY');
  const [frequencyValue, setFrequencyValue] = useState('2');
  const [days, setDays] = useState<number[]>([]);
  const [rows, setRows] = useState<Row[]>([]);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const routine = routineQuery.data;
    if (!isEdit || !routine || loaded) return;
    setLoaded(true);

    setName(routine.name);
    setIcon(routine.icon);
    setColor(routine.color);
    setFrequencyType(routine.frequencyType);
    setFrequencyValue(String(routine.frequencyValue));
    setDays(routine.frequencyDays);
    setRows(routine.routineExercises.map(re => ({
      id: re.id,
      exerciseId: re.exercise.id,
      name: re.exercise.name,
      icon: re.exercise.icon,
      category: re.exercise.category,
      targetSets: re.targetSets,
      targetReps: re.targetReps,
      targetWeight: re.targetWeight,
      targetDurationSec: re.targetDurationSec,
      restSec: re.restSec ?? DEFAULT_REST_SEC,
    })));
  }, [routineQuery.data, isEdit, loaded]);

  if (exercisesQuery.isLoading || (isEdit && routineQuery.isLoading)) return <Loading />;

  const submit = async () => {
    setSaving(true);
    setError(null);

    const input = {
      name: name.trim(),
      icon, color,
      frequencyType,
      frequencyValue: frequencyType === 'EVERY_N_DAYS' ? Math.max(1, Number(frequencyValue) || 1) : 1,
      frequencyDays: frequencyType === 'WEEKLY' ? days : [],
      exercises: rows.map(({ name: _n, icon: _i, category: _c, ...rest }) => rest),
    };

    try {
      // 入力検証はサーバが行う。文言が docs/FEATURES.md の仕様なので二重に持たない
      const result = isEdit
        ? await api.updateRoutine({ ...input, id: routineId!, lockVersion: routineQuery.data!.lockVersion })
        : await api.createRoutine(input);

      if (result.userErrors.length > 0) {
        setError(result.userErrors[0].message);
        return;
      }

      await qc.invalidateQueries();
      onDone();
    } catch (e) {
      // 圏外でルーティンを作れると、サーバの採番や検証を通っていない
      // ルーティンに対して記録が積まれ、整合を取る手段が無くなる。
      // 保存させずに、電波が戻ってからやり直してもらう
      setError(isNetworkError(e) ? OFFLINE_SAVE_MESSAGE : '保存に失敗しました');
    } finally {
      // catch が無いと圏外のとき「保存中…」のまま固まる
      setSaving(false);
    }
  };

  const addExercise = (e: Exercise) => {
    const row: Row = isDurationBased(e.category)
      ? {
          id: uuid(), exerciseId: e.id, name: e.name, icon: e.icon, category: e.category,
          targetSets: 1, targetReps: null, targetWeight: null,
          targetDurationSec: DEFAULT_CARDIO_DURATION_SEC, restSec: DEFAULT_REST_SEC,
        }
      : {
          id: uuid(), exerciseId: e.id, name: e.name, icon: e.icon, category: e.category,
          targetSets: 3, targetReps: 10, targetWeight: null, targetDurationSec: null, restSec: DEFAULT_REST_SEC,
        };
    setRows(prev => [...prev, row]);
    setPickerOpen(false);
  };

  const patchRow = (i: number, changes: Partial<Row>) =>
    setRows(prev => prev.map((r, idx) => (idx === i ? { ...r, ...changes } : r)));

  const move = (i: number, dir: -1 | 1) => {
    const target = i + dir;
    if (target < 0 || target >= rows.length) return;
    setRows(prev => {
      const next = [...prev];
      [next[i], next[target]] = [next[target], next[i]];
      return next;
    });
  };

  return (
    <div className="stack" data-testid="routine-form">
      <ErrorText message={error} />

      <div>
        <div className="muted">ルーティン名</div>
        <input className="set-input" style={{ textAlign: 'left' }} value={name}
               onChange={e => setName(e.target.value)} placeholder="例: 朝の全身メニュー"
               data-testid="routine-name-input" />
      </div>

      <div>
        <div className="muted">アイコン</div>
        <div className="row" style={{ flexWrap: 'wrap' }}>
          {ICONS.map(i => (
            <Chip key={i} label={i} selected={icon === i} onClick={() => setIcon(i)} testId={`icon-${i}`} />
          ))}
        </div>
      </div>

      <div>
        <div className="muted">カラー</div>
        <div className="row" style={{ flexWrap: 'wrap' }}>
          {COLORS.map(c => (
            <button key={c} data-testid={`color-${c}`} onClick={() => setColor(c)}
                    aria-pressed={color === c}
                    style={{
                      width: 36, height: 36, borderRadius: '50%', backgroundColor: c,
                      border: color === c ? '3px solid var(--text-primary)' : '3px solid transparent',
                    }} />
          ))}
        </div>
      </div>

      <div>
        <div className="muted">頻度</div>
        <div className="row">
          <Chip label="毎日" selected={frequencyType === 'DAILY'} onClick={() => setFrequencyType('DAILY')} testId="frequency-daily" />
          <Chip label="N日ごと" selected={frequencyType === 'EVERY_N_DAYS'} onClick={() => setFrequencyType('EVERY_N_DAYS')} testId="frequency-every_n_days" />
          <Chip label="曜日指定" selected={frequencyType === 'WEEKLY'} onClick={() => setFrequencyType('WEEKLY')} testId="frequency-weekly" />
        </div>

        {frequencyType === 'EVERY_N_DAYS' && (
          <div className="row" style={{ marginTop: 'var(--sp-2)' }}>
            <input className="set-input" style={{ width: 72 }} value={frequencyValue}
                   onChange={e => setFrequencyValue(e.target.value.replace(/\D/g, ''))}
                   data-testid="frequency-value-input" />
            <span className="muted">日ごとに実施</span>
          </div>
        )}

        {frequencyType === 'WEEKLY' && (
          <div className="row" style={{ marginTop: 'var(--sp-2)', flexWrap: 'wrap' }}>
            {DAY_LABELS.map((label, day) => (
              <Chip key={day} label={label} selected={days.includes(day)}
                    onClick={() => setDays(prev => prev.includes(day) ? prev.filter(d => d !== day) : [...prev, day])}
                    testId={`day-${day}`} />
            ))}
          </div>
        )}
      </div>

      <div>
        <div className="muted">種目</div>
        {rows.map((row, i) => (
          <div key={row.id} style={{ marginBottom: 'var(--sp-2)' }}>
            <Card>
              <div className="row">
                <span style={{ flex: 1, fontWeight: 'bold' }} data-testid={`exercise-row-${i}`}>
                  {row.icon} {row.name}
                </span>
                <button className="btn btn--ghost" style={{ width: 'auto', minHeight: 28 }}
                        onClick={() => move(i, -1)} data-testid={`exercise-up-${i}`}>↑</button>
                <button className="btn btn--ghost" style={{ width: 'auto', minHeight: 28 }}
                        onClick={() => move(i, 1)} data-testid={`exercise-down-${i}`}>↓</button>
                <button className="btn btn--ghost" style={{ width: 'auto', minHeight: 28 }}
                        onClick={() => setRows(prev => prev.filter((_, idx) => idx !== i))}
                        data-testid={`exercise-remove-${i}`}>✕</button>
              </div>
              <div className="row" style={{ marginTop: 'var(--sp-2)', flexWrap: 'wrap' }}>
                <NumField label="セット" value={row.targetSets} testId={`exercise-sets-${i}`}
                          onChange={v => patchRow(i, { targetSets: Math.max(1, v ?? 1) })} />
                {isDurationBased(row.category) ? (
                  <NumField label="分" testId={`exercise-minutes-${i}`}
                            value={row.targetDurationSec != null ? row.targetDurationSec / 60 : null}
                            onChange={v => patchRow(i, { targetDurationSec: v !== null ? Math.round(v * 60) : null })} />
                ) : (
                  <>
                    <NumField label="回数" value={row.targetReps ?? null} testId={`exercise-reps-${i}`}
                              onChange={v => patchRow(i, { targetReps: v })} />
                    <NumField label="重量kg" value={row.targetWeight ?? null} testId={`exercise-weight-${i}`}
                              onChange={v => patchRow(i, { targetWeight: v })} />
                    <NumField label="秒" value={row.targetDurationSec ?? null} testId={`exercise-duration-${i}`}
                              onChange={v => patchRow(i, { targetDurationSec: v })} />
                  </>
                )}
                <NumField label="休憩秒" value={row.restSec ?? null} testId={`exercise-rest-${i}`}
                          onChange={v => patchRow(i, { restSec: v })} />
              </div>
            </Card>
          </div>
        ))}

        <Button label={pickerOpen ? '種目リストを閉じる' : '＋ 種目を追加'} variant="secondary"
                onClick={() => setPickerOpen(v => !v)} testId="add-exercise-button" />

        {pickerOpen && (
          <div style={{ marginTop: 'var(--sp-2)' }}>
            <Card testId="exercise-picker">
              <div className="row" style={{ flexWrap: 'wrap' }}>
                {(exercisesQuery.data ?? []).map(e => (
                  <Chip key={e.id} label={`${e.icon ?? ''} ${e.name}`} selected={false}
                        onClick={() => addExercise(e)} testId={`pick-exercise-${e.id}`} />
                ))}
              </div>
            </Card>
          </div>
        )}
      </div>

      <Button label={isEdit ? '保存する' : '作成する'} onClick={submit} disabled={saving} testId="routine-submit" />
      <Button label="キャンセル" variant="ghost" onClick={onDone} testId="routine-cancel" />
    </div>
  );
};

const NumField = ({ label, value, onChange, testId }: {
  label: string; value: number | null; onChange: (v: number | null) => void; testId: string;
}) => (
  <div>
    <div className="muted" style={{ fontSize: 11 }}>{label}</div>
    <input className="set-input" style={{ width: 72 }} inputMode="decimal" placeholder="—"
           value={value ?? ''} data-testid={testId}
           onChange={e => {
             const t = e.target.value.trim();
             onChange(t === '' ? null : (Number.isFinite(Number(t)) ? Number(t) : null));
           }} />
  </div>
);

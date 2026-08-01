import { COLLECTIONS, getMeta, setMeta, insertMany, listRaw, insert } from './localDb';
import { PRESET_EXERCISES, STARTER_ROUTINE } from '../constants/exercises';
import { Exercise, Routine, RoutineExercise } from '../../types';
import { nowIso } from './id';

/**
 * 初回起動時のデータ投入。
 *
 * このアプリはサインインなしで即使えることを最優先にしているので、
 * 起動した時点で「今日やるルーティン」が1つ入っている状態にする。
 * ユーザーがそれを消したあとに再投入されると鬱陶しいため、
 * 投入したかどうかは meta.seeded で1度だけ判定する。
 */
export const seedIfNeeded = async (): Promise<boolean> => {
  const meta = await getMeta();
  if (meta.seeded) {
    // プリセット種目だけはアプリ更新で増えることがあるので毎回差分を補う
    await syncPresetExercises();
    return false;
  }

  await syncPresetExercises();
  await createStarterRoutine();
  await setMeta({ seeded: true });
  return true;
};

/** アプリ側の定義に存在してローカルに無いプリセット種目を足す */
export const syncPresetExercises = async (): Promise<number> => {
  const existing = await listRaw<Exercise>(COLLECTIONS.exercises);
  const existingIds = new Set(existing.map(e => e.id));

  const missing = PRESET_EXERCISES.filter(p => !existingIds.has(p.id));
  if (missing.length === 0) return 0;

  await insertMany<Exercise>(
    COLLECTIONS.exercises,
    missing.map(p => ({
      id: p.id,
      name: p.name,
      category: p.category,
      description: null,
      icon: p.icon,
      is_preset: true,
      created_by: null,
    }))
  );

  return missing.length;
};

const createStarterRoutine = async (): Promise<void> => {
  const timestamp = nowIso();

  await insert<Routine>(COLLECTIONS.routines, {
    id: STARTER_ROUTINE.id,
    user_id: null,
    name: STARTER_ROUTINE.name,
    description: '器具なしで今すぐ始められる基本メニューです。自由に編集してください。',
    color: STARTER_ROUTINE.color,
    icon: STARTER_ROUTINE.icon,
    frequency_type: 'daily',
    frequency_value: 1,
    frequency_days: [],
    preferred_time: null,
    is_active: true,
    sort_order: 0,
    created_at: timestamp,
  });

  await insertMany<RoutineExercise>(
    COLLECTIONS.routineExercises,
    STARTER_ROUTINE.exercises.map((e, index) => ({
      routine_id: STARTER_ROUTINE.id,
      exercise_id: e.exerciseId,
      sort_order: index,
      target_sets: e.sets,
      target_reps: e.reps,
      target_weight: null,
      target_duration_sec: e.durationSec,
      rest_sec: e.restSec,
      notes: null,
      created_at: timestamp,
    }))
  );
};

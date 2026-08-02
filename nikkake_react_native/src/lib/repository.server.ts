import { NikkakeApi } from '@nikkake/api-client';
import { API_ENDPOINT } from '../config';
import { nativeStore } from './nativeStore';
import { getDateString } from './utils';
import { uuid } from './id';
import type {
  Exercise,
  ExerciseCategory,
  FrequencyType,
  RoutineExercise,
  RoutineWithExercises,
  Routine,
  WorkoutSet,
  WorkoutSummary,
} from '../../types';
import type { RoutineInput } from './repository.local';
import type {
  ApiExercise,
  ApiRoutine,
  ExerciseProgressPoint,
  HomeView,
  ProgressView,
  Streak,
  WorkoutSession,
} from './views';
import type { SaveWorkoutInput } from './repository.local';

/**
 * Rails の GraphQL を真実の源とする実装。
 *
 * 集計は一切しない。home / progress / workoutSession は
 * サーバが組み立てたものをそのまま画面へ渡す。
 * ここに計算が生えたら、それはサーバへ移すべきロジックが漏れている合図。
 *
 * 例外はワークアウト記録で、圏外のときだけ手元で暫定のサマリーを作る。
 * サーバの応答を待たないと結果画面が出せない、という状態を避けるため。
 */

export const api = new NikkakeApi(nativeStore, API_ENDPOINT);

// ==============================
// サーバ表現 → 端末表現
// ==============================
//
// 画面とストアは移行前から snake_case の型を使っている。
// ここで詰め替えることで、画面側の書き換えを最小限にしている。

const nowIso = () => new Date().toISOString();

const lower = <T extends string>(value: string): T => value.toLowerCase() as T;

const toLocalExercise = (e: ApiExercise): Exercise => ({
  id: e.id,
  name: e.name,
  category: lower<ExerciseCategory>(e.category),
  description: null,
  icon: e.icon,
  is_preset: e.isPreset,
  created_by: null,
  created_at: nowIso(),
  updated_at: nowIso(),
  deleted_at: null,
});

const toLocalRoutine = (r: ApiRoutine): RoutineWithExercises => {
  const timestamp = nowIso();

  const routine_exercises: (RoutineExercise & { exercise: Exercise })[] = r.routineExercises.map(
    link => ({
      id: link.id,
      routine_id: r.id,
      exercise_id: link.exercise.id,
      sort_order: link.sortOrder,
      target_sets: link.targetSets,
      target_reps: link.targetReps,
      target_weight: link.targetWeight,
      target_duration_sec: link.targetDurationSec,
      rest_sec: link.restSec,
      notes: null,
      created_at: timestamp,
      updated_at: timestamp,
      deleted_at: null,
      exercise: toLocalExercise(link.exercise),
    })
  );

  return {
    id: r.id,
    user_id: null,
    name: r.name,
    description: r.description,
    color: r.color,
    icon: r.icon,
    frequency_type: lower<FrequencyType>(r.frequencyType),
    frequency_value: r.frequencyValue,
    frequency_days: r.frequencyDays,
    preferred_time: null,
    is_active: r.isActive,
    sort_order: r.sortOrder,
    created_at: timestamp,
    updated_at: timestamp,
    deleted_at: null,
    routine_exercises,
  };
};

/** 更新系で楽観ロックに使う。サーバが返した lockVersion を覚えておく */
const lockVersions = new Map<string, number>();

const remember = (r: ApiRoutine): ApiRoutine => {
  lockVersions.set(r.id, r.lockVersion);
  return r;
};

// ==============================
// 参照
// ==============================

export const getHome = (today: Date = new Date()): Promise<HomeView> =>
  api.home(getDateString(today));

export const getStreak = async (today: Date = new Date()): Promise<Streak> =>
  (await api.home(getDateString(today))).streak;

export const getProgress = (rangeDays = 7, today: Date = new Date()): Promise<ProgressView> =>
  api.progress(getDateString(today), rangeDays);

export const getExerciseProgressPoints = (
  exerciseId: string,
  limit = 8
): Promise<ExerciseProgressPoint[]> => api.exerciseProgress(exerciseId, limit);

export const getWorkoutSession = async (routineId: string): Promise<WorkoutSession | null> => {
  const session = await api.workoutSession(routineId);
  remember(session.routine);
  return session;
};

export const listExercises = async (): Promise<Exercise[]> =>
  (await api.exercises()).map(toLocalExercise);

export const listRoutinesWithExercises = async (): Promise<RoutineWithExercises[]> => {
  const routines = await api.routines();
  routines.forEach(remember);
  return routines.map(toLocalRoutine);
};

export const listRoutines = listRoutinesWithExercises;

export const getRoutineWithExercises = async (
  routineId: string
): Promise<RoutineWithExercises | null> => {
  const routine = await api.routine(routineId);
  if (!routine) return null;

  remember(routine);
  return toLocalRoutine(routine);
};

// ==============================
// 更新（オンライン必須）
// ==============================
//
// 記録と違ってキューに積まない。
// 圏外でルーティンを作れると、サーバ側の採番や検証を通っていない
// ルーティンに対して記録が積まれ、整合を取る手段が無くなる。
// 画面は userErrors を出して保存させない。

/** userErrors をそのまま例外に変える。message はそのまま画面に出せる日本語 */
const unwrap = <T>(result: { data: T | null; userErrors: { message: string }[] }): T => {
  if (result.userErrors.length > 0) throw new Error(result.userErrors[0].message);
  if (result.data === null) throw new Error('保存できませんでした');
  return result.data;
};

const toExerciseInputs = (input: RoutineInput) =>
  input.exercises.map(e => ({
    id: uuid(),
    exerciseId: e.exerciseId,
    targetSets: e.targetSets,
    targetReps: e.targetReps,
    targetWeight: e.targetWeight,
    targetDurationSec: e.targetDurationSec,
    restSec: e.restSec,
  }));

const upperFrequency = (value: FrequencyType) =>
  value.toUpperCase() as ApiRoutine['frequencyType'];

export const createRoutine = async (input: RoutineInput): Promise<Routine> => {
  const routine = unwrap(
    await api.createRoutine({
      name: input.name,
      description: input.description ?? null,
      icon: input.icon,
      color: input.color,
      frequencyType: upperFrequency(input.frequencyType),
      frequencyValue: input.frequencyValue,
      frequencyDays: input.frequencyDays,
      exercises: toExerciseInputs(input),
    })
  );

  return toLocalRoutine(remember(routine));
};

export const updateRoutine = async (
  routineId: string,
  input: RoutineInput
): Promise<Routine | null> => {
  const routine = unwrap(
    await api.updateRoutine({
      id: routineId,
      name: input.name,
      description: input.description ?? null,
      icon: input.icon,
      color: input.color,
      frequencyType: upperFrequency(input.frequencyType),
      frequencyValue: input.frequencyValue,
      frequencyDays: input.frequencyDays,
      isActive: input.isActive ?? true,
      // 直前に読んだ版を送る。他端末が先に更新していれば CONFLICT で弾かれる
      lockVersion: lockVersions.get(routineId) ?? 0,
      exercises: toExerciseInputs(input),
    })
  );

  return toLocalRoutine(remember(routine));
};

export const setRoutineActive = async (
  routineId: string,
  isActive: boolean
): Promise<Routine | null> => {
  const routine = unwrap(await api.setRoutineActive(routineId, isActive));
  return toLocalRoutine(remember(routine));
};

export const deleteRoutine = async (routineId: string): Promise<void> => {
  unwrap(await api.deleteRoutine(routineId));
  lockVersions.delete(routineId);
};

export const createCustomExercise = async (input: {
  name: string;
  category: ExerciseCategory;
  icon: string | null;
}): Promise<Exercise> => {
  const result = await api.createCustomExercise({
    name: input.name,
    category: input.category.toUpperCase() as ApiExercise['category'],
    icon: input.icon,
  });

  return toLocalExercise(unwrap(result));
};

// ==============================
// 記録（オフライン可）
// ==============================

const toRecordedSets = (input: SaveWorkoutInput) =>
  input.exercises.flatMap(exercise =>
    exercise.sets
      .filter(set => set.completed)
      .map(set => ({
        id: uuid(),
        routineExerciseId: exercise.routineExerciseId,
        exerciseId: exercise.exerciseId,
        setNumber: set.setNumber,
        actualReps: set.reps,
        actualWeight: set.weight,
        actualDurationSec: set.durationSec,
      }))
  );

const tally = (input: SaveWorkoutInput) => {
  let completedSets = 0;
  let totalSets = 0;
  let totalVolume = 0;

  for (const exercise of input.exercises) {
    for (const set of exercise.sets) {
      totalSets++;
      if (set.completed) {
        completedSets++;
        totalVolume += (set.weight ?? 0) * (set.reps ?? 0);
      }
    }
  }

  return { completedSets, totalSets, totalVolume };
};

export const saveWorkout = async (input: SaveWorkoutInput): Promise<WorkoutSummary> => {
  const counts = tally(input);

  const result = await api.recordWorkout({
    routineId: input.routineId,
    // 「今日」は必ず端末が決める。サーバに求めさせるとタイムゾーンで1日ずれる
    logDate: getDateString(new Date(input.startedAt)),
    startedAt: input.startedAt,
    durationSec: input.durationSec ?? 0,
    totalSets: counts.totalSets,
    sets: toRecordedSets(input),
  });

  if (result.userErrors.length > 0) throw new Error(result.userErrors[0].message);

  if (result.data) {
    return {
      routineLogId: result.data.summary.routineLogId,
      routineName: result.data.summary.routineName,
      durationSec: result.data.summary.durationSec,
      completedSets: result.data.summary.completedSets,
      totalSets: result.data.summary.totalSets,
      totalVolume: result.data.summary.totalVolume,
      status: result.data.summary.status.toLowerCase() as WorkoutSummary['status'],
    };
  }

  // 圏外。キューに積まれているので記録は失われない。
  // 結果画面を出すぶんの数字だけ手元で作る（サーバの判定と同じ基準）。
  return {
    routineLogId: '',
    routineName: '',
    durationSec: input.durationSec ?? 0,
    completedSets: counts.completedSets,
    totalSets: counts.totalSets,
    totalVolume: counts.totalVolume,
    status:
      counts.completedSets === 0
        ? 'skipped'
        : counts.completedSets >= counts.totalSets
          ? 'completed'
          : 'partial',
  };
};

// ==============================
// 送信キュー
// ==============================

export const pendingCount = async (): Promise<number> => api.queue.pending().length;

export const flushPending = (): Promise<{ sent: number; remaining: number }> => api.flushQueue();

export type { SaveWorkoutInput, RoutineInput, WorkoutSet };

import {
  COLLECTIONS,
  list,
  find,
  where,
  insert,
  insertMany,
  update,
  softDelete,
  softDeleteWhere,
} from './localDb';
import { uuid, nowIso } from './id';
import { getDateString, isRoutineDueToday } from './utils';
import {
  Exercise,
  ExerciseCategory,
  ExerciseLog,
  FrequencyType,
  LogStatus,
  Routine,
  RoutineExercise,
  RoutineLog,
  RoutineWithExercises,
  TodayRoutine,
  WorkoutSet,
} from '../../types';

/**
 * 画面が直接触るデータAPI。
 *
 * 参照も更新も必ずローカルストレージに対して行い、ネットワークは介在しない。
 * サインインしている場合は sync.ts がバックグラウンドでSupabaseへ複製するが、
 * 画面はその成否を待たないので、オフラインでも常に即座に応答する。
 */

// ==============================
// Exercises
// ==============================

export const listExercises = async (): Promise<Exercise[]> => {
  const rows = await list<Exercise>(COLLECTIONS.exercises);
  return rows.sort((a, b) => {
    if (a.category !== b.category) return a.category.localeCompare(b.category);
    return a.name.localeCompare(b.name, 'ja');
  });
};

export const createCustomExercise = async (input: {
  name: string;
  category: ExerciseCategory;
  icon: string | null;
}): Promise<Exercise> =>
  insert<Exercise>(COLLECTIONS.exercises, {
    name: input.name,
    category: input.category,
    description: null,
    icon: input.icon,
    is_preset: false,
    created_by: null,
  });

// ==============================
// Routines
// ==============================

export const listRoutines = async (): Promise<Routine[]> => {
  const rows = await list<Routine>(COLLECTIONS.routines);
  return rows.sort((a, b) => {
    if (a.sort_order !== b.sort_order) return a.sort_order - b.sort_order;
    return a.created_at.localeCompare(b.created_at);
  });
};

export const getRoutineWithExercises = async (
  routineId: string
): Promise<RoutineWithExercises | null> => {
  const routine = await find<Routine>(COLLECTIONS.routines, routineId);
  if (!routine) return null;

  const [links, exercises] = await Promise.all([
    where<RoutineExercise>(COLLECTIONS.routineExercises, r => r.routine_id === routineId),
    list<Exercise>(COLLECTIONS.exercises),
  ]);

  const exerciseById = new Map(exercises.map(e => [e.id, e]));

  const routine_exercises = links
    .sort((a, b) => a.sort_order - b.sort_order)
    .map(link => ({ ...link, exercise: exerciseById.get(link.exercise_id)! }))
    // 種目が削除済みのリンクが残っていても画面を落とさない
    .filter(link => !!link.exercise);

  return { ...routine, routine_exercises };
};

export const listRoutinesWithExercises = async (): Promise<RoutineWithExercises[]> => {
  const [routines, links, exercises] = await Promise.all([
    listRoutines(),
    list<RoutineExercise>(COLLECTIONS.routineExercises),
    list<Exercise>(COLLECTIONS.exercises),
  ]);

  const exerciseById = new Map(exercises.map(e => [e.id, e]));

  return routines.map(routine => ({
    ...routine,
    routine_exercises: links
      .filter(l => l.routine_id === routine.id)
      .sort((a, b) => a.sort_order - b.sort_order)
      .map(link => ({ ...link, exercise: exerciseById.get(link.exercise_id)! }))
      .filter(link => !!link.exercise),
  }));
};

export interface RoutineExerciseInput {
  exerciseId: string;
  targetSets: number;
  targetReps: number | null;
  targetWeight: number | null;
  targetDurationSec: number | null;
  restSec: number | null;
}

export interface RoutineInput {
  name: string;
  description?: string | null;
  icon: string;
  color: string;
  frequencyType: FrequencyType;
  frequencyValue: number;
  frequencyDays: number[];
  preferredTime?: string | null;
  isActive?: boolean;
  exercises: RoutineExerciseInput[];
}

export const createRoutine = async (input: RoutineInput): Promise<Routine> => {
  const existing = await listRoutines();

  const routine = await insert<Routine>(COLLECTIONS.routines, {
    user_id: null,
    name: input.name,
    description: input.description ?? null,
    color: input.color,
    icon: input.icon,
    frequency_type: input.frequencyType,
    frequency_value: input.frequencyValue,
    frequency_days: input.frequencyDays,
    preferred_time: input.preferredTime ?? null,
    is_active: input.isActive ?? true,
    sort_order: existing.length,
  });

  await replaceRoutineExercises(routine.id, input.exercises);
  return routine;
};

export const updateRoutine = async (
  routineId: string,
  input: RoutineInput
): Promise<Routine | null> => {
  const routine = await update<Routine>(COLLECTIONS.routines, routineId, {
    name: input.name,
    description: input.description ?? null,
    color: input.color,
    icon: input.icon,
    frequency_type: input.frequencyType,
    frequency_value: input.frequencyValue,
    frequency_days: input.frequencyDays,
    preferred_time: input.preferredTime ?? null,
    is_active: input.isActive ?? true,
  });

  if (!routine) return null;

  await replaceRoutineExercises(routineId, input.exercises);
  return routine;
};

export const setRoutineActive = (routineId: string, isActive: boolean) =>
  update<Routine>(COLLECTIONS.routines, routineId, { is_active: isActive });

/**
 * ルーティン内の種目構成を丸ごと差し替える。
 * 差分更新にすると並び順の入れ替えが厄介なので、既存リンクを論理削除して作り直す。
 * 過去のログは routine_exercise_id ではなく exercise_id でも引けるようにしてあるので、
 * 作り直しても履歴グラフは途切れない。
 */
const replaceRoutineExercises = async (
  routineId: string,
  exercises: RoutineExerciseInput[]
): Promise<void> => {
  await softDeleteWhere(
    COLLECTIONS.routineExercises,
    row => (row as unknown as RoutineExercise).routine_id === routineId
  );

  if (exercises.length === 0) return;

  await insertMany<RoutineExercise>(
    COLLECTIONS.routineExercises,
    exercises.map((e, index) => ({
      routine_id: routineId,
      exercise_id: e.exerciseId,
      sort_order: index,
      target_sets: e.targetSets,
      target_reps: e.targetReps,
      target_weight: e.targetWeight,
      target_duration_sec: e.targetDurationSec,
      rest_sec: e.restSec,
      notes: null,
    }))
  );
};

export const deleteRoutine = async (routineId: string): Promise<void> => {
  await softDeleteWhere(
    COLLECTIONS.routineExercises,
    row => (row as unknown as RoutineExercise).routine_id === routineId
  );
  await softDelete(COLLECTIONS.routines, routineId);
};

// ==============================
// Logs
// ==============================

export const listRoutineLogs = (): Promise<RoutineLog[]> =>
  list<RoutineLog>(COLLECTIONS.routineLogs);

export const listExerciseLogs = (): Promise<ExerciseLog[]> =>
  list<ExerciseLog>(COLLECTIONS.exerciseLogs);

export const getTodayLogs = async (): Promise<RoutineLog[]> => {
  const today = getDateString();
  return where<RoutineLog>(COLLECTIONS.routineLogs, l => l.log_date === today);
};

export const getLastLogForRoutine = async (routineId: string): Promise<RoutineLog | null> => {
  const logs = await where<RoutineLog>(
    COLLECTIONS.routineLogs,
    l => l.routine_id === routineId && l.status !== 'skipped'
  );
  if (logs.length === 0) return null;

  return logs.sort((a, b) => b.log_date.localeCompare(a.log_date))[0];
};

/**
 * ホーム画面用。ルーティンごとに「今日やるべきか」「今日もう終わったか」を解決して返す。
 */
export const getTodayRoutines = async (): Promise<TodayRoutine[]> => {
  const [routines, logs] = await Promise.all([listRoutinesWithExercises(), listRoutineLogs()]);
  const today = getDateString();

  return routines
    .filter(r => r.is_active)
    .map(routine => {
      const routineLogs = logs
        .filter(l => l.routine_id === routine.id)
        .sort((a, b) => b.log_date.localeCompare(a.log_date));

      const todayLog = routineLogs.find(l => l.log_date === today) ?? null;
      const lastLog = routineLogs.find(l => l.status !== 'skipped') ?? null;

      return {
        routine,
        // 全セット完了でなくても、記録を残した時点で今日の分は済んだものとして扱う。
        // ストリークの判定（stats.didWorkout）と基準を揃えている。
        isCompleted: !!todayLog && todayLog.status !== 'skipped',
        lastLog,
        isDueToday: isRoutineDueToday(routine, lastLog, new Date()),
      };
    });
};

export interface SaveWorkoutInput {
  routineId: string;
  startedAt: string;
  durationSec: number | null;
  status: LogStatus;
  notes?: string | null;
  exercises: {
    routineExerciseId: string;
    exerciseId: string;
    sets: WorkoutSet[];
  }[];
}

/**
 * ワークアウト1回分の保存。
 * 同じ日に同じルーティンを2回やった場合は上書きではなく追記する（日跨ぎの判定はlog_dateで行う）。
 */
export const saveWorkout = async (input: SaveWorkoutInput): Promise<RoutineLog> => {
  const completedAt = nowIso();

  const routineLog = await insert<RoutineLog>(COLLECTIONS.routineLogs, {
    id: uuid(),
    routine_id: input.routineId,
    user_id: null,
    log_date: getDateString(new Date(input.startedAt)),
    status: input.status,
    duration_sec: input.durationSec,
    notes: input.notes ?? null,
    started_at: input.startedAt,
    completed_at: completedAt,
  });

  const exerciseLogs = input.exercises.flatMap(exercise =>
    exercise.sets
      .filter(set => set.completed)
      .map(set => ({
        routine_log_id: routineLog.id,
        routine_exercise_id: exercise.routineExerciseId,
        exercise_id: exercise.exerciseId,
        set_number: set.setNumber,
        actual_reps: set.reps,
        actual_weight: set.weight,
        actual_duration_sec: set.durationSec,
        notes: null,
      }))
  );

  if (exerciseLogs.length > 0) {
    await insertMany<ExerciseLog>(COLLECTIONS.exerciseLogs, exerciseLogs);
  }

  return routineLog;
};

export const deleteRoutineLog = async (routineLogId: string): Promise<void> => {
  await softDeleteWhere(
    COLLECTIONS.exerciseLogs,
    row => (row as unknown as ExerciseLog).routine_log_id === routineLogId
  );
  await softDelete(COLLECTIONS.routineLogs, routineLogId);
};

/**
 * 前回のワークアウトで各種目を何kg×何回やったか。
 * ワークアウト画面で「前回の記録」を初期値に出すために使う。
 */
export const getLastSetsByExercise = async (
  routineId: string
): Promise<Record<string, WorkoutSet[]>> => {
  const logs = await where<RoutineLog>(
    COLLECTIONS.routineLogs,
    l => l.routine_id === routineId && l.status !== 'skipped'
  );
  if (logs.length === 0) return {};

  const latest = logs.sort((a, b) => (b.started_at ?? b.created_at).localeCompare(a.started_at ?? a.created_at))[0];

  const exerciseLogs = await where<ExerciseLog>(
    COLLECTIONS.exerciseLogs,
    l => l.routine_log_id === latest.id
  );

  const result: Record<string, WorkoutSet[]> = {};
  for (const log of exerciseLogs) {
    const sets = result[log.exercise_id] ?? (result[log.exercise_id] = []);
    sets.push({
      setNumber: log.set_number,
      reps: log.actual_reps,
      weight: log.actual_weight,
      durationSec: log.actual_duration_sec,
      completed: true,
    });
  }

  for (const key of Object.keys(result)) {
    result[key].sort((a, b) => a.setNumber - b.setNumber);
  }

  return result;
};

export const getRoutineLogDetail = async (
  routineLogId: string
): Promise<{ log: RoutineLog; exerciseLogs: ExerciseLog[] } | null> => {
  const log = await find<RoutineLog>(COLLECTIONS.routineLogs, routineLogId);
  if (!log) return null;

  const exerciseLogs = await where<ExerciseLog>(
    COLLECTIONS.exerciseLogs,
    l => l.routine_log_id === routineLogId
  );

  return { log, exerciseLogs: exerciseLogs.sort((a, b) => a.set_number - b.set_number) };
};

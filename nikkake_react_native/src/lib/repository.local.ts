import {
  COLLECTIONS,
  resetDatabase,
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
import { seedIfNeeded } from './seed';
import { getDateString, formatFrequency, formatPreviousSets, isRoutineDueToday } from './utils';
import {
  calculateDailyStats,
  calculateExerciseProgress,
  calculateOverallStats,
  calculateStreak,
  completedDateSet,
} from './stats';
import type {
  ExerciseProgressPoint,
  HomeView,
  ProgressView,
  Streak,
  TodayRoutineView,
  ApiExercise,
  ApiRoutine,
  RecordedSet,
  WorkoutSession,
} from './views';
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
  WorkoutSummary,
} from '../../types';

/**
 * 端末ローカルを真実の源とする実装。
 *
 * 参照も更新も必ずローカルストレージに対して行い、ネットワークは介在しない。
 * 未登録（サーバに匿名アカウントを作れていない）状態でもアプリが完全に動くのは、
 * この実装が残っているため。EXPO_PUBLIC_BACKEND=local で選ばれる。
 *
 * ファイル末尾のビュー組み立ては repository.server.ts と同じ型を返す。
 * 片方だけ形が変わればコンパイルが落ちる。
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
  notes?: string | null;
  exercises: {
    routineExerciseId: string;
    exerciseId: string;
    sets: WorkoutSet[];
  }[];
}

/**
 * status は入力として受け取らない。完了セット数から必ずここで導出する。
 * 呼び出し側に決めさせると、サーバ実装（WorkoutRecorder）との判定基準がずれても
 * 誰も気づけない。基準を1か所に閉じ込めるのが目的。
 */
export const resolveWorkoutStatus = (completedSets: number, totalSets: number): LogStatus => {
  if (completedSets === 0) return 'skipped';
  if (completedSets >= totalSets) return 'completed';
  return 'partial';
};

export const tallyWorkout = (input: SaveWorkoutInput) => {
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

/**
 * ワークアウト1回分の保存。
 * 同じ日に同じルーティンを2回やった場合は上書きではなく追記する（日跨ぎの判定はlog_dateで行う）。
 */
export const saveWorkout = async (input: SaveWorkoutInput): Promise<WorkoutSummary> => {
  const completedAt = nowIso();
  const { completedSets, totalSets, totalVolume } = tallyWorkout(input);
  const status = resolveWorkoutStatus(completedSets, totalSets);

  const routineLog = await insert<RoutineLog>(COLLECTIONS.routineLogs, {
    id: uuid(),
    routine_id: input.routineId,
    user_id: null,
    log_date: getDateString(new Date(input.startedAt)),
    status,
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

  const routine = await find<Routine>(COLLECTIONS.routines, input.routineId);

  return {
    routineLogId: routineLog.id,
    routineName: routine?.name ?? '',
    durationSec: input.durationSec ?? 0,
    completedSets,
    totalSets,
    totalVolume,
    status,
  };
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

// ==============================
// 集計済みビュー
// ==============================
//
// 未登録モードで画面が必要とする形を、ローカルデータから組み立てる。
// 返す型は repository.server.ts（＝サーバの応答）と同一。
// サーバ側は HomeViewBuilder / ProgressViewBuilder / WorkoutSessionBuilder が
// 対応するので、区分の基準や並び順を変えるときは両方直すこと。

const upper = <T extends string>(value: string): T => value.toUpperCase() as T;

const toApiExercise = (exercise: Exercise): ApiExercise => ({
  id: exercise.id,
  name: exercise.name,
  category: upper(exercise.category),
  icon: exercise.icon,
  isPreset: exercise.is_preset,
});

const toApiRoutine = (routine: RoutineWithExercises): ApiRoutine => ({
  id: routine.id,
  name: routine.name,
  description: routine.description,
  color: routine.color,
  icon: routine.icon,
  frequencyType: upper(routine.frequency_type),
  frequencyValue: routine.frequency_value,
  frequencyDays: routine.frequency_days,
  isActive: routine.is_active,
  sortOrder: routine.sort_order,
  // ローカルには楽観ロックが無い。サーバへ送る経路も無いので 0 で埋める
  lockVersion: 0,
  routineExercises: routine.routine_exercises.map(link => ({
    id: link.id,
    exercise: toApiExercise(link.exercise),
    sortOrder: link.sort_order,
    targetSets: link.target_sets,
    targetReps: link.target_reps,
    targetWeight: link.target_weight,
    targetDurationSec: link.target_duration_sec,
    restSec: link.rest_sec,
  })),
});

export const getHome = async (today: Date = new Date()): Promise<HomeView> => {
  const [routines, logs] = await Promise.all([listRoutinesWithExercises(), listRoutineLogs()]);
  const todayString = getDateString(today);

  const items: TodayRoutineView[] = routines
    .filter(r => r.is_active)
    .map(routine => {
      const routineLogs = logs
        .filter(l => l.routine_id === routine.id)
        .sort((a, b) => b.log_date.localeCompare(a.log_date));

      const todayLog = routineLogs.find(l => l.log_date === todayString) ?? null;
      const lastLog = routineLogs.find(l => l.status !== 'skipped') ?? null;

      return {
        routine: toApiRoutine(routine),
        isDueToday: isRoutineDueToday(routine, lastLog, today),
        isCompleted: !!todayLog && todayLog.status !== 'skipped',
        frequencyLabel: formatFrequency(routine),
      };
    });

  return {
    today: todayString,
    streak: calculateStreak(logs, today),
    due: items.filter(i => i.isDueToday && !i.isCompleted),
    notScheduled: items.filter(i => !i.isDueToday && !i.isCompleted),
    completed: items.filter(i => i.isCompleted),
  };
};

export const getStreak = async (today: Date = new Date()): Promise<Streak> =>
  calculateStreak(await listRoutineLogs(), today);

export const getProgress = async (
  rangeDays = 7,
  today: Date = new Date()
): Promise<ProgressView> => {
  const [routineLogs, exerciseLogs, exercises] = await Promise.all([
    listRoutineLogs(),
    listExerciseLogs(),
    listExercises(),
  ]);

  const loggedIds = new Set(exerciseLogs.map(l => l.exercise_id));

  return {
    overall: calculateOverallStats(routineLogs, exerciseLogs, today),
    streak: calculateStreak(routineLogs, today),
    dailyStats: calculateDailyStats(routineLogs, rangeDays, today),
    completedDates: [...completedDateSet(routineLogs)].sort(),
    exercisesWithLogs: exercises.filter(e => loggedIds.has(e.id)).map(toApiExercise),
  };
};

export const getExerciseProgressPoints = async (
  exerciseId: string,
  limit = 8
): Promise<ExerciseProgressPoint[]> => {
  const [routineLogs, exerciseLogs] = await Promise.all([listRoutineLogs(), listExerciseLogs()]);
  return calculateExerciseProgress(exerciseId, routineLogs, exerciseLogs).slice(-limit);
};

export const getWorkoutSession = async (routineId: string): Promise<WorkoutSession | null> => {
  const routine = await getRoutineWithExercises(routineId);
  if (!routine) return null;

  const previous = await getLastSetsByExercise(routineId);

  return {
    routine: toApiRoutine(routine),
    exercises: routine.routine_exercises.map(link => {
      const sets: RecordedSet[] = (previous[link.exercise_id] ?? []).map(s => ({
        setNumber: s.setNumber,
        reps: s.reps,
        weight: s.weight,
        durationSec: s.durationSec,
      }));

      return {
        routineExerciseId: link.id,
        exercise: toApiExercise(link.exercise),
        targetSets: link.target_sets,
        targetReps: link.target_reps,
        targetWeight: link.target_weight,
        targetDurationSec: link.target_duration_sec,
        restSec: link.rest_sec ?? 60,
        previousSets: sets,
        previousLabel: sets.length === 0 ? null : formatPreviousSets(sets),
      };
    }),
  };
};

export interface DataCounts {
  routines: number;
  exercises: number;
  routineLogs: number;
  exerciseLogs: number;
}

/** 設定画面に出す保存件数 */
export const getCounts = async (): Promise<DataCounts> => {
  const [routines, exercises, routineLogs, exerciseLogs] = await Promise.all([
    list(COLLECTIONS.routines),
    list(COLLECTIONS.exercises),
    list(COLLECTIONS.routineLogs),
    list(COLLECTIONS.exerciseLogs),
  ]);

  return {
    routines: routines.length,
    exercises: exercises.length,
    routineLogs: routineLogs.length,
    exerciseLogs: exerciseLogs.length,
  };
};

/** 全部消して初期状態に戻す。取り消せない */
export const resetData = async (): Promise<void> => {
  await resetDatabase();
  await seedIfNeeded();
};

/** サーバモードにしかない概念。ローカルでは常に「送信済み扱い」 */
export const pendingCount = async (): Promise<number> => 0;
export const flushPending = async (): Promise<{ sent: number; remaining: number }> => ({
  sent: 0,
  remaining: 0,
});

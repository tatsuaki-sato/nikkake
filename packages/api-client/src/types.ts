/**
 * GraphQL の応答型。
 * packages/contract/schema.graphql が正で、将来 codegen で自動生成に置き換える。
 * それまでは手書きだが、rake graphql:verify が操作の過不足を検査している。
 */

export type LogStatus = 'COMPLETED' | 'PARTIAL' | 'SKIPPED';
export type FrequencyType = 'DAILY' | 'EVERY_N_DAYS' | 'WEEKLY';
export type ExerciseCategory = 'STRENGTH' | 'CARDIO' | 'GAME' | 'CUSTOM';

export interface Exercise {
  id: string;
  name: string;
  category: ExerciseCategory;
  icon: string | null;
  isPreset: boolean;
}

export interface RoutineExercise {
  id: string;
  exercise: Exercise;
  sortOrder: number;
  targetSets: number;
  targetReps: number | null;
  targetWeight: number | null;
  targetDurationSec: number | null;
  restSec: number | null;
}

export interface Routine {
  id: string;
  name: string;
  description: string | null;
  color: string;
  icon: string;
  frequencyType: FrequencyType;
  frequencyValue: number;
  frequencyDays: number[];
  isActive: boolean;
  sortOrder: number;
  lockVersion: number;
  routineExercises: RoutineExercise[];
}

export interface Streak {
  current: number;
  longest: number;
  lastCompletedDate: string | null;
}

export interface TodayRoutine {
  routine: Routine;
  isDueToday: boolean;
  isCompleted: boolean;
  frequencyLabel: string;
}

export interface HomeView {
  today: string;
  streak: Streak;
  due: TodayRoutine[];
  notScheduled: TodayRoutine[];
  completed: TodayRoutine[];
}

export interface RecordedSet {
  setNumber: number;
  reps: number | null;
  weight: number | null;
  durationSec: number | null;
}

export interface WorkoutSessionExercise {
  routineExerciseId: string;
  exercise: Exercise;
  targetSets: number;
  targetReps: number | null;
  targetWeight: number | null;
  targetDurationSec: number | null;
  restSec: number;
  previousSets: RecordedSet[];
  previousLabel: string | null;
}

export interface WorkoutSession {
  routine: Routine;
  exercises: WorkoutSessionExercise[];
}

export interface DailyStat {
  date: string;
  completedCount: number;
  totalCount: number;
}

export interface OverallStats {
  totalWorkouts: number;
  thisWeekCount: number;
  totalDurationSec: number;
  totalSets: number;
}

export interface ProgressView {
  overall: OverallStats;
  streak: Streak;
  dailyStats: DailyStat[];
  completedDates: string[];
  exercisesWithLogs: Exercise[];
}

export interface ExerciseProgressPoint {
  date: string;
  maxWeight: number;
  totalReps: number;
  totalVolume: number;
}

export interface DayExerciseSummary {
  exerciseName: string;
  /** 「50.0×10 / 50.0×8」形式の整形済み文字列。文言はサーバが返す */
  setsLabel: string | null;
}

export interface DayWorkout {
  routineLogId: string;
  routineName: string;
  status: LogStatus;
  durationSec: number | null;
  exercises: DayExerciseSummary[];
}

export interface DayView {
  date: string;
  workouts: DayWorkout[];
}

export interface DataCounts {
  routines: number;
  exercises: number;
  routineLogs: number;
  exerciseLogs: number;
}

export interface Viewer {
  id: string;
  email: string | null;
  isAnonymous: boolean;
  emailVerified: boolean;
  storageMode: 'LOCAL_ONLY' | 'CLOUD';
  counts: DataCounts;
}

export interface WorkoutSummary {
  routineLogId: string;
  routineName: string;
  durationSec: number;
  completedSets: number;
  totalSets: number;
  totalVolume: number;
  status: LogStatus;
}

/** 入力起因のエラー。message はそのまま画面に出せる日本語 */
export interface UserError {
  path: string[] | null;
  message: string;
  code:
    | 'VALIDATION'
    | 'NOT_FOUND'
    | 'CONFLICT'
    | 'ALREADY_PROMOTED'
    | 'INVALID_CREDENTIALS'
    | 'RATE_LIMITED';
}

export interface RoutineExerciseInput {
  id: string;
  exerciseId: string;
  targetSets: number;
  targetReps?: number | null;
  targetWeight?: number | null;
  targetDurationSec?: number | null;
  restSec?: number | null;
}

export interface RecordedSetInput {
  id: string;
  routineExerciseId?: string | null;
  exerciseId: string;
  setNumber: number;
  actualReps?: number | null;
  actualWeight?: number | null;
  actualDurationSec?: number | null;
}

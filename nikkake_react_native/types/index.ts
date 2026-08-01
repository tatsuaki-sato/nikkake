// ============================================
// nikkake - TypeScript型定義
// ============================================
//
// データはすべて端末ローカルが真実の源(source of truth)。
// サインインしている場合のみ、同じ形のレコードがSupabaseへ複製される。
// そのため全エンティティが updated_at / deleted_at を持ち、
// 同期は updated_at による last-write-wins で解決する。

export interface SyncFields {
  /** ISO8601。同期の衝突解決キー */
  updated_at: string;
  /** 論理削除。物理削除すると他端末へ削除が伝播しないため */
  deleted_at: string | null;
}

export interface Profile {
  id: string;
  display_name: string | null;
  avatar_url: string | null;
  created_at: string;
}

export interface Exercise extends SyncFields {
  id: string;
  name: string;
  category: ExerciseCategory;
  description: string | null;
  icon: string | null;
  is_preset: boolean;
  created_by: string | null;
  created_at: string;
}

export type ExerciseCategory = 'strength' | 'cardio' | 'game' | 'custom';

export interface Routine extends SyncFields {
  id: string;
  /** ローカル専用データは null。サインイン後の同期で埋まる */
  user_id: string | null;
  name: string;
  description: string | null;
  color: string;
  icon: string;
  frequency_type: FrequencyType;
  frequency_value: number;
  frequency_days: number[];
  preferred_time: string | null;
  is_active: boolean;
  sort_order: number;
  created_at: string;
}

export type FrequencyType = 'daily' | 'every_n_days' | 'weekly';

export interface RoutineExercise extends SyncFields {
  id: string;
  routine_id: string;
  exercise_id: string;
  sort_order: number;
  target_sets: number;
  target_reps: number | null;
  target_weight: number | null;
  target_duration_sec: number | null;
  rest_sec: number | null;
  notes: string | null;
  created_at: string;
  // Joined fields
  exercise?: Exercise;
}

export interface RoutineLog extends SyncFields {
  id: string;
  routine_id: string;
  user_id: string | null;
  log_date: string;
  status: LogStatus;
  duration_sec: number | null;
  notes: string | null;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
  // Joined fields
  routine?: Routine;
  exercise_logs?: ExerciseLog[];
}

export type LogStatus = 'completed' | 'partial' | 'skipped';

export interface ExerciseLog extends SyncFields {
  id: string;
  routine_log_id: string;
  routine_exercise_id: string;
  exercise_id: string;
  set_number: number;
  actual_reps: number | null;
  actual_weight: number | null;
  actual_duration_sec: number | null;
  notes: string | null;
  created_at: string;
}

// ============================================
// UI用の拡張型
// ============================================

export interface RoutineWithExercises extends Routine {
  routine_exercises: (RoutineExercise & { exercise: Exercise })[];
}

export interface TodayRoutine {
  routine: RoutineWithExercises;
  isCompleted: boolean;
  lastLog: RoutineLog | null;
  isDueToday: boolean;
}

export interface WorkoutSet {
  setNumber: number;
  reps: number | null;
  weight: number | null;
  durationSec: number | null;
  completed: boolean;
}

export interface WorkoutExerciseState {
  routineExerciseId: string;
  exercise: Exercise;
  targetSets: number;
  targetReps: number | null;
  targetWeight: number | null;
  targetDurationSec: number | null;
  restSec: number | null;
  sets: WorkoutSet[];
  previousSets: WorkoutSet[];
}

export interface WorkoutState {
  routineId: string;
  routineName: string;
  exercises: WorkoutExerciseState[];
  startedAt: string;
  currentExerciseIndex: number;
}

// ============================================
// 統計用の型
// ============================================

export interface DailyStats {
  date: string;
  completedCount: number;
  totalCount: number;
}

export interface ExerciseProgress {
  date: string;
  maxWeight: number;
  totalVolume: number;
  totalReps: number;
}

export interface StreakInfo {
  current: number;
  longest: number;
  lastCompletedDate: string | null;
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

// ============================================
// 同期
// ============================================

/**
 * local  : サインインしていない。端末内だけにデータがある
 * cloud  : サインイン済み。ローカルを正としつつSupabaseへ複製する
 */
export type StorageMode = 'local' | 'cloud';

export type SyncStatus = 'idle' | 'syncing' | 'error' | 'offline';

export interface SyncState {
  status: SyncStatus;
  lastSyncedAt: string | null;
  lastError: string | null;
}

/**
 * 画面が受け取る「集計済みビュー」の型。
 *
 * 定義そのものは packages/api-client（＝ packages/contract/schema.graphql）を正とし、
 * ここでは再輸出するだけにしている。ローカルモードもこの型に合わせて組み立てるので、
 * 型が合わなくなった時点でコンパイルエラーになり、
 * 「サーバとローカルで画面に渡る形が違う」事故を防げる。
 */
export type {
  DailyStat,
  Exercise as ApiExercise,
  ExerciseProgressPoint,
  HomeView,
  OverallStats,
  ProgressView,
  RecordedSet,
  Routine as ApiRoutine,
  RoutineExercise as ApiRoutineExercise,
  Streak,
  TodayRoutine as TodayRoutineView,
  WorkoutSession,
  WorkoutSessionExercise,
  WorkoutSummary as ApiWorkoutSummary,
} from '@nikkake/api-client';

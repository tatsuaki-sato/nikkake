import { DailyStats, ExerciseLog, ExerciseProgress, RoutineLog, StreakInfo } from '../../types';
import { addDays, daysBetween, getDateString, parseDateString } from './utils';

/**
 * 進捗画面の集計。すべて純粋関数にしてあるので、ストレージを触らずに単体テストできる。
 */

/**
 * その日「やった」と数える基準。
 *
 * 全セット完了(completed)だけを対象にすると、4種目のうち3種目やった日が
 * ノーカウントになりストリークが切れる。習慣化アプリとしてそれは逆効果なので、
 * 中断(skipped)以外はすべて実施した日として扱う。
 */
export const didWorkout = (log: RoutineLog): boolean => log.status !== 'skipped';

/**
 * 連続日数。
 * 「今日まだやっていない」だけでストリークが途切れた表示になるのは体験が悪いので、
 * 最終実施日が今日か昨日ならストリークは生きているものとして数える。
 */
export const calculateStreak = (logs: RoutineLog[], today: Date = new Date()): StreakInfo => {
  const completedDates = Array.from(new Set(logs.filter(didWorkout).map(l => l.log_date))).sort();

  if (completedDates.length === 0) {
    return { current: 0, longest: 0, lastCompletedDate: null };
  }

  // 最長ストリーク
  let longest = 1;
  let run = 1;
  for (let i = 1; i < completedDates.length; i++) {
    const gap = daysBetween(parseDateString(completedDates[i - 1]), parseDateString(completedDates[i]));
    run = gap === 1 ? run + 1 : 1;
    longest = Math.max(longest, run);
  }

  // 現在のストリーク
  const lastCompletedDate = completedDates[completedDates.length - 1];
  const gapFromToday = daysBetween(parseDateString(lastCompletedDate), today);

  let current = 0;
  if (gapFromToday <= 1) {
    current = 1;
    for (let i = completedDates.length - 1; i > 0; i--) {
      const gap = daysBetween(parseDateString(completedDates[i - 1]), parseDateString(completedDates[i]));
      if (gap !== 1) break;
      current++;
    }
  }

  return { current, longest, lastCompletedDate };
};

/** 直近n日分の実施状況。カレンダーと棒グラフの元データ */
export const calculateDailyStats = (
  logs: RoutineLog[],
  days: number,
  today: Date = new Date()
): DailyStats[] => {
  const byDate = new Map<string, RoutineLog[]>();
  for (const log of logs) {
    const bucket = byDate.get(log.log_date) ?? [];
    bucket.push(log);
    byDate.set(log.log_date, bucket);
  }

  const result: DailyStats[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const date = getDateString(addDays(today, -i));
    const dayLogs = byDate.get(date) ?? [];
    result.push({
      date,
      completedCount: dayLogs.filter(didWorkout).length,
      totalCount: dayLogs.length,
    });
  }

  return result;
};

/** カレンダー用の「実施した日」の集合 */
export const completedDateSet = (logs: RoutineLog[]): Set<string> =>
  new Set(logs.filter(didWorkout).map(l => l.log_date));

/**
 * 種目ごとの推移。重量種目は最大重量、時間種目は合計時間が伸びを表すので両方返す。
 */
export const calculateExerciseProgress = (
  exerciseId: string,
  routineLogs: RoutineLog[],
  exerciseLogs: ExerciseLog[]
): ExerciseProgress[] => {
  const dateByLogId = new Map(routineLogs.map(l => [l.id, l.log_date]));
  const byDate = new Map<string, ExerciseLog[]>();

  for (const log of exerciseLogs) {
    if (log.exercise_id !== exerciseId) continue;
    const date = dateByLogId.get(log.routine_log_id);
    if (!date) continue;

    const bucket = byDate.get(date) ?? [];
    bucket.push(log);
    byDate.set(date, bucket);
  }

  return Array.from(byDate.entries())
    .map(([date, sets]) => ({
      date,
      maxWeight: sets.reduce((max, s) => Math.max(max, s.actual_weight ?? 0), 0),
      totalReps: sets.reduce((sum, s) => sum + (s.actual_reps ?? 0), 0),
      totalVolume: sets.reduce((sum, s) => sum + (s.actual_weight ?? 0) * (s.actual_reps ?? 0), 0),
    }))
    .sort((a, b) => a.date.localeCompare(b.date));
};

/** そのワークアウトの総挙上量(kg×回)。自重種目は0になる */
export const calculateVolume = (logs: ExerciseLog[]): number =>
  logs.reduce((sum, l) => sum + (l.actual_weight ?? 0) * (l.actual_reps ?? 0), 0);

export interface OverallStats {
  totalWorkouts: number;
  totalDurationSec: number;
  totalSets: number;
  thisWeekCount: number;
}

export const calculateOverallStats = (
  routineLogs: RoutineLog[],
  exerciseLogs: ExerciseLog[],
  today: Date = new Date()
): OverallStats => {
  const completed = routineLogs.filter(l => l.status !== 'skipped');
  const weekAgo = getDateString(addDays(today, -6));

  return {
    totalWorkouts: completed.length,
    totalDurationSec: completed.reduce((sum, l) => sum + (l.duration_sec ?? 0), 0),
    totalSets: exerciseLogs.length,
    thisWeekCount: completed.filter(l => l.log_date >= weekAgo).length,
  };
};

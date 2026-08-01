import cases from '../../../../packages/contract/domain_cases.json';
import {
  calculateStreak,
  calculateDailyStats,
  calculateExerciseProgress,
  calculateOverallStats,
} from '../stats';
import {
  isRoutineDueToday,
  formatDuration,
  formatWeight,
  formatFrequency,
  greetingForHour,
  parseDateString,
} from '../utils';
import { ExerciseLog, LogStatus, Routine, RoutineLog } from '../../../types';

/**
 * packages/contract/domain_cases.json を唯一の期待値として検証する。
 *
 * サーバ(Ruby)へロジックを移したあと、同じ JSON を Ruby / Dart / Kotlin のテストも読む。
 * 5言語が同じ答えを返すことを CI で機械的に保証するのが目的で、
 * 「1つの実装だけ直して終わり」を構造的に防ぐ。
 *
 * このファイルが通ることが、契約が現行仕様を正しく写し取れている証拠になる。
 */

/** JSON 由来の素の値を受け取る。status などは string で来るのでここで型を確定させる */
type RawLog = { id?: string; log_date: string; status?: string; duration_sec?: number | null };

const routineLog = (patch: RawLog): RoutineLog => ({
  id: patch.id ?? `log-${patch.log_date}-${patch.status}`,
  routine_id: 'r1',
  user_id: null,
  log_date: patch.log_date,
  status: (patch.status ?? 'completed') as LogStatus,
  duration_sec: patch.duration_sec ?? null,
  notes: null,
  started_at: null,
  completed_at: null,
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
  deleted_at: null,
});

const exerciseLog = (patch: Record<string, unknown>): ExerciseLog => ({
  id: `${patch.routine_log_id}-${patch.exercise_id}-${patch.set_number}`,
  routine_log_id: patch.routine_log_id as string,
  routine_exercise_id: 're1',
  exercise_id: patch.exercise_id as string,
  set_number: patch.set_number as number,
  actual_reps: (patch.actual_reps ?? null) as number | null,
  actual_weight: (patch.actual_weight ?? null) as number | null,
  actual_duration_sec: null,
  notes: null,
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
  deleted_at: null,
});

const routine = (patch: Record<string, unknown>): Routine => ({
  id: 'r1',
  user_id: null,
  name: 'テスト',
  description: null,
  color: '#6C5CE7',
  icon: '💪',
  frequency_type: patch.frequency_type as Routine['frequency_type'],
  frequency_value: patch.frequency_value as number,
  frequency_days: patch.frequency_days as number[],
  preferred_time: null,
  is_active: (patch.is_active ?? true) as boolean,
  sort_order: 0,
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
  deleted_at: null,
});

describe('契約: streak', () => {
  it.each(cases.streak.cases.map(c => [c.name, c] as const))('%s', (_name, c) => {
    const result = calculateStreak(c.logs.map(routineLog), parseDateString(c.today));
    expect(result).toEqual(c.expect);
  });
});

describe('契約: dueToday', () => {
  it.each(cases.dueToday.cases.map(c => [c.name, c] as const))('%s', (_name, c) => {
    const result = isRoutineDueToday(
      routine(c.routine),
      c.lastLog ? routineLog(c.lastLog) : null,
      parseDateString(c.today)
    );
    expect(result).toBe(c.expect);
  });
});

describe('契約: dailyStats', () => {
  it.each(cases.dailyStats.cases.map(c => [c.name, c] as const))('%s', (_name, c) => {
    const result = calculateDailyStats(c.logs.map(routineLog), c.days, parseDateString(c.today));
    expect(result).toEqual(c.expect);
  });
});

describe('契約: exerciseProgress', () => {
  it.each(cases.exerciseProgress.cases.map(c => [c.name, c] as const))('%s', (_name, c) => {
    const result = calculateExerciseProgress(
      c.exerciseId,
      c.routineLogs.map(routineLog),
      c.exerciseLogs.map(exerciseLog)
    );
    expect(result).toEqual(c.expect);
  });
});

describe('契約: overallStats', () => {
  it.each(cases.overallStats.cases.map(c => [c.name, c] as const))('%s', (_name, c) => {
    const result = calculateOverallStats(
      c.routineLogs.map(routineLog),
      c.exerciseLogs.map(exerciseLog),
      parseDateString(c.today)
    );
    expect(result).toEqual(c.expect);
  });
});

describe('契約: formatDuration', () => {
  it.each(cases.formatDuration.cases.map(c => [c.name, c] as const))('%s', (_name, c) => {
    expect(formatDuration(c.seconds)).toBe(c.expect);
  });
});

describe('契約: formatWeight', () => {
  it.each(cases.formatWeight.cases.map(c => [c.name, c] as const))('%s', (_name, c) => {
    expect(formatWeight(c.weight)).toBe(c.expect);
  });
});

describe('契約: formatFrequency', () => {
  it.each(cases.formatFrequency.cases.map(c => [c.name, c] as const))('%s', (_name, c) => {
    expect(formatFrequency(c.routine as Routine)).toBe(c.expect);
  });
});

describe('契約: greetingForHour', () => {
  it.each(cases.greetingForHour.cases.map(c => [c.name, c] as const))('%s', (_name, c) => {
    expect(greetingForHour(c.hour)).toBe(c.expect);
  });
});

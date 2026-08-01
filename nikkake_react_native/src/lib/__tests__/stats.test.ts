import {
  calculateStreak,
  calculateDailyStats,
  calculateExerciseProgress,
  calculateOverallStats,
  calculateVolume,
  completedDateSet,
} from '../stats';
import { ExerciseLog, LogStatus, RoutineLog } from '../../../types';

const log = (logDate: string, status: LogStatus = 'completed', durationSec = 600): RoutineLog => ({
  id: `log-${logDate}-${status}`,
  routine_id: 'r1',
  user_id: null,
  log_date: logDate,
  status,
  duration_sec: durationSec,
  notes: null,
  started_at: null,
  completed_at: null,
  created_at: `${logDate}T10:00:00.000Z`,
  updated_at: `${logDate}T10:00:00.000Z`,
  deleted_at: null,
});

const setLog = (
  routineLogId: string,
  exerciseId: string,
  setNumber: number,
  reps: number | null,
  weight: number | null
): ExerciseLog => ({
  id: `${routineLogId}-${exerciseId}-${setNumber}`,
  routine_log_id: routineLogId,
  routine_exercise_id: 're1',
  exercise_id: exerciseId,
  set_number: setNumber,
  actual_reps: reps,
  actual_weight: weight,
  actual_duration_sec: null,
  notes: null,
  created_at: '2026-08-01T10:00:00.000Z',
  updated_at: '2026-08-01T10:00:00.000Z',
  deleted_at: null,
});

describe('calculateStreak', () => {
  const today = new Date(2026, 7, 5); // 2026-08-05

  it('記録が無ければ0', () => {
    expect(calculateStreak([], today)).toEqual({ current: 0, longest: 0, lastCompletedDate: null });
  });

  it('今日まで連続していれば日数を数える', () => {
    const logs = [log('2026-08-03'), log('2026-08-04'), log('2026-08-05')];
    expect(calculateStreak(logs, today).current).toBe(3);
  });

  it('今日まだ実施していなくても、昨日やっていればストリークは継続扱い', () => {
    const logs = [log('2026-08-03'), log('2026-08-04')];
    expect(calculateStreak(logs, today).current).toBe(2);
  });

  it('2日以上空いていればストリークは切れる', () => {
    const logs = [log('2026-08-01'), log('2026-08-02')];
    expect(calculateStreak(logs, today).current).toBe(0);
  });

  it('同じ日に複数ルーティンをやっても1日として数える', () => {
    const logs = [
      { ...log('2026-08-04'), id: 'a' },
      { ...log('2026-08-04'), id: 'b' },
      log('2026-08-05'),
    ];
    expect(calculateStreak(logs, today).current).toBe(2);
  });

  it('中断(skipped)はストリークに数えない', () => {
    const logs = [log('2026-08-04'), log('2026-08-05', 'skipped')];
    const result = calculateStreak(logs, today);
    expect(result.current).toBe(1);
    expect(result.lastCompletedDate).toBe('2026-08-04');
  });

  it('全種目やりきれなかった日(partial)もストリークは途切れない', () => {
    // 4種目中3種目で終えた日にストリークが切れると習慣化の妨げになる
    const logs = [log('2026-08-04'), log('2026-08-05', 'partial')];
    expect(calculateStreak(logs, today).current).toBe(2);
  });

  it('過去の最長ストリークを保持する', () => {
    const logs = [
      log('2026-07-01'), log('2026-07-02'), log('2026-07-03'), log('2026-07-04'),
      log('2026-08-05'),
    ];
    const result = calculateStreak(logs, today);
    expect(result.longest).toBe(4);
    expect(result.current).toBe(1);
  });
});

describe('calculateDailyStats', () => {
  it('指定日数分を古い順に、記録の無い日も0で埋めて返す', () => {
    const today = new Date(2026, 7, 5);
    const stats = calculateDailyStats([log('2026-08-05'), log('2026-08-03')], 3, today);

    expect(stats.map(s => s.date)).toEqual(['2026-08-03', '2026-08-04', '2026-08-05']);
    expect(stats.map(s => s.completedCount)).toEqual([1, 0, 1]);
  });

  it('途中までのpartialも実施した日として数える', () => {
    const today = new Date(2026, 7, 5);
    const stats = calculateDailyStats([log('2026-08-05', 'partial')], 1, today);

    expect(stats[0].completedCount).toBe(1);
    expect(stats[0].totalCount).toBe(1);
  });

  it('中断したskippedは実施に数えない', () => {
    const today = new Date(2026, 7, 5);
    const stats = calculateDailyStats([log('2026-08-05', 'skipped')], 1, today);

    expect(stats[0].completedCount).toBe(0);
    expect(stats[0].totalCount).toBe(1);
  });
});

describe('calculateExerciseProgress', () => {
  it('日付ごとに最大重量・総回数・総ボリュームを集計する', () => {
    const routineLogs = [log('2026-08-01'), { ...log('2026-08-03'), id: 'log-2' }];
    const exerciseLogs = [
      setLog('log-2026-08-01-completed', 'ex1', 1, 10, 60),
      setLog('log-2026-08-01-completed', 'ex1', 2, 8, 65),
      setLog('log-2', 'ex1', 1, 10, 70),
      setLog('log-2', 'ex2', 1, 12, 20),
    ];

    const progress = calculateExerciseProgress('ex1', routineLogs, exerciseLogs);

    expect(progress).toHaveLength(2);
    expect(progress[0]).toEqual({
      date: '2026-08-01',
      maxWeight: 65,
      totalReps: 18,
      totalVolume: 10 * 60 + 8 * 65,
    });
    expect(progress[1].maxWeight).toBe(70);
  });

  it('対象の種目が無ければ空配列', () => {
    expect(calculateExerciseProgress('none', [log('2026-08-01')], [])).toEqual([]);
  });
});

describe('その他の集計', () => {
  it('calculateVolume は自重種目(重量null)を0として扱う', () => {
    const logs = [setLog('l1', 'ex1', 1, 10, null), setLog('l1', 'ex1', 2, 10, 50)];
    expect(calculateVolume(logs)).toBe(500);
  });

  it('completedDateSet は完了した日付だけを集める', () => {
    const set = completedDateSet([log('2026-08-01'), log('2026-08-02', 'skipped')]);
    expect(set.has('2026-08-01')).toBe(true);
    expect(set.has('2026-08-02')).toBe(false);
  });

  it('calculateOverallStats は直近7日の回数を含めて集計する', () => {
    const today = new Date(2026, 7, 5);
    const routineLogs = [log('2026-08-05'), log('2026-08-01'), log('2026-07-01')];
    const stats = calculateOverallStats(routineLogs, [setLog('l1', 'ex1', 1, 10, 50)], today);

    expect(stats.totalWorkouts).toBe(3);
    expect(stats.thisWeekCount).toBe(2);
    expect(stats.totalDurationSec).toBe(1800);
    expect(stats.totalSets).toBe(1);
  });
});

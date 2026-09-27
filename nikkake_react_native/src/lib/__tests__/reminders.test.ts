import { isValidTime, planReminders } from '../reminders';
import type { ApiRoutine, HomeView, TodayRoutineView } from '../views';

/**
 * 通知の予定の組み立て。
 * 「今日もう終えた日は鳴らさない」「予定の無い日は鳴らさない」が守られているかを見る。
 */

const routine = (overrides: Partial<ApiRoutine> = {}): ApiRoutine => ({
  id: 'r1',
  name: '朝の腕立て',
  description: null,
  color: '#6C5CE7',
  icon: '💪',
  frequencyType: 'DAILY',
  frequencyValue: 1,
  frequencyDays: [],
  preferredTime: '07:30',
  isActive: true,
  sortOrder: 0,
  lockVersion: 0,
  routineExercises: [],
  ...overrides,
});

const entry = (r: ApiRoutine): TodayRoutineView => ({
  routine: r,
  isDueToday: true,
  isCompleted: false,
  frequencyLabel: '毎日',
});

const home = (parts: Partial<Pick<HomeView, 'due' | 'notScheduled' | 'completed'>>): HomeView => ({
  // 2026-09-28 は月曜
  today: '2026-09-28',
  streak: { current: 0, longest: 0, lastCompletedDate: null },
  due: [],
  notScheduled: [],
  completed: [],
  ...parts,
});

const EARLY = new Date(2026, 8, 28, 6, 0); // 通知時刻より前
const LATE = new Date(2026, 8, 28, 8, 0); // 通知時刻を過ぎた

const days = (plan: ReturnType<typeof planReminders>) => plan.map(p => p.at.getDate());

describe('planReminders', () => {
  it('毎日: 今日まだなら今日から7日分', () => {
    const plan = planReminders(home({ due: [entry(routine())] }), EARLY);

    expect(days(plan)).toEqual([28, 29, 30, 1, 2, 3, 4]);
    expect(plan[0].at.getHours()).toBe(7);
    expect(plan[0].at.getMinutes()).toBe(30);
    expect(plan[0].identifier).toBe('routine_r1_2026-09-28');
  });

  it('今日もう終えていたら今日は鳴らさない', () => {
    const plan = planReminders(home({ completed: [entry(routine())] }), EARLY);

    expect(days(plan)[0]).toBe(29);
  });

  it('通知時刻を過ぎていたら今日の分は出さない', () => {
    const plan = planReminders(home({ due: [entry(routine())] }), LATE);

    expect(days(plan)[0]).toBe(29);
  });

  it('曜日指定: 選んだ曜日だけ', () => {
    // 水(3)と金(5)
    const r = routine({ frequencyType: 'WEEKLY', frequencyDays: [3, 5] });
    const plan = planReminders(home({ notScheduled: [entry(r)] }), EARLY);

    expect(days(plan)).toEqual([30, 2]);
  });

  it('N日ごと: 今日終えたら N 日おき', () => {
    const r = routine({ frequencyType: 'EVERY_N_DAYS', frequencyValue: 3 });
    const plan = planReminders(home({ completed: [entry(r)] }), EARLY);

    expect(days(plan)).toEqual([1, 4]);
  });

  it('N日ごと: 今日の分をまだ終えていなければ、終えるまで毎日', () => {
    const r = routine({ frequencyType: 'EVERY_N_DAYS', frequencyValue: 3 });
    const plan = planReminders(home({ due: [entry(r)] }), EARLY);

    expect(plan).toHaveLength(7);
  });

  it('時刻が無い・停止中のルーティンは鳴らさない', () => {
    const plan = planReminders(
      home({ due: [entry(routine({ preferredTime: null })), entry(routine({ id: 'r2', isActive: false }))] }),
      EARLY
    );

    expect(plan).toEqual([]);
  });
});

describe('isValidTime', () => {
  it.each([
    ['07:30', true],
    ['23:59', true],
    ['00:00', true],
    ['24:00', false],
    ['7:30', false],
    ['07:60', false],
    ['', false],
  ])('%s → %s', (value, expected) => {
    expect(isValidTime(value)).toBe(expected);
  });
});

import {
  getDateString,
  parseDateString,
  daysBetween,
  addDays,
  isRoutineDueToday,
  formatDuration,
  formatWeight,
  formatFrequency,
  greetingForHour,
} from '../utils';
import { Routine, RoutineLog } from '../../../types';

const routine = (patch: Partial<Routine> = {}): Routine => ({
  id: 'r1',
  user_id: null,
  name: 'テスト',
  description: null,
  color: '#6C5CE7',
  icon: '💪',
  frequency_type: 'daily',
  frequency_value: 1,
  frequency_days: [],
  preferred_time: null,
  is_active: true,
  sort_order: 0,
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
  deleted_at: null,
  ...patch,
});

const log = (logDate: string): RoutineLog => ({
  id: `log-${logDate}`,
  routine_id: 'r1',
  user_id: null,
  log_date: logDate,
  status: 'completed',
  duration_sec: 600,
  notes: null,
  started_at: null,
  completed_at: null,
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
  deleted_at: null,
});

describe('日付ユーティリティ', () => {
  it('getDateString はローカルタイムの YYYY-MM-DD を返す', () => {
    expect(getDateString(new Date(2026, 7, 1))).toBe('2026-08-01');
    expect(getDateString(new Date(2026, 0, 9))).toBe('2026-01-09');
  });

  it('parseDateString はUTCではなくローカルの0時として解釈する', () => {
    const parsed = parseDateString('2026-08-01');
    expect(parsed.getFullYear()).toBe(2026);
    expect(parsed.getMonth()).toBe(7);
    expect(parsed.getDate()).toBe(1);
  });

  it('daysBetween は日付単位の差を返す（時刻は無視する）', () => {
    expect(daysBetween(new Date(2026, 7, 1, 23), new Date(2026, 7, 2, 1))).toBe(1);
    expect(daysBetween(new Date(2026, 7, 1), new Date(2026, 7, 1))).toBe(0);
    expect(daysBetween(new Date(2026, 7, 5), new Date(2026, 7, 1))).toBe(-4);
  });

  it('addDays は月をまたいでも正しく進む', () => {
    expect(getDateString(addDays(new Date(2026, 6, 30), 3))).toBe('2026-08-02');
  });
});

describe('isRoutineDueToday', () => {
  const today = new Date(2026, 7, 1); // 2026-08-01 は土曜日

  it('停止中のルーティンは対象外', () => {
    expect(isRoutineDueToday(routine({ is_active: false }), null, today)).toBe(false);
  });

  it('毎日のルーティンは常に対象', () => {
    expect(isRoutineDueToday(routine({ frequency_type: 'daily' }), log('2026-07-31'), today)).toBe(true);
  });

  it('N日ごとは前回からの間隔で判定する', () => {
    const r = routine({ frequency_type: 'every_n_days', frequency_value: 3 });
    expect(isRoutineDueToday(r, log('2026-07-29'), today)).toBe(true);  // 3日経過
    expect(isRoutineDueToday(r, log('2026-07-30'), today)).toBe(false); // 2日しか経っていない
  });

  it('N日ごとで一度も実施していなければ今日から始められる', () => {
    const r = routine({ frequency_type: 'every_n_days', frequency_value: 7 });
    expect(isRoutineDueToday(r, null, today)).toBe(true);
  });

  it('曜日指定は今日の曜日が含まれるかで判定する', () => {
    expect(isRoutineDueToday(routine({ frequency_type: 'weekly', frequency_days: [6] }), null, today)).toBe(true);
    expect(isRoutineDueToday(routine({ frequency_type: 'weekly', frequency_days: [1, 3] }), null, today)).toBe(false);
  });

  it('曜日指定で曜日が未設定なら毎日扱いにする', () => {
    expect(isRoutineDueToday(routine({ frequency_type: 'weekly', frequency_days: [] }), null, today)).toBe(true);
  });
});

describe('表示フォーマット', () => {
  it('formatDuration は時間・分・秒を切り替える', () => {
    expect(formatDuration(0)).toBe('0:00');
    expect(formatDuration(65)).toBe('1:05');
    expect(formatDuration(3725)).toBe('1:02:05');
    expect(formatDuration(null)).toBe('--:--');
  });

  it('formatWeight は不要な小数を落とす', () => {
    expect(formatWeight(60)).toBe('60 kg');
    expect(formatWeight(62.5)).toBe('62.5 kg');
    expect(formatWeight(null)).toBe('-- kg');
  });

  it('formatFrequency は頻度を日本語にする', () => {
    expect(formatFrequency({ frequency_type: 'daily', frequency_value: 1, frequency_days: [] })).toBe('毎日');
    expect(formatFrequency({ frequency_type: 'every_n_days', frequency_value: 3, frequency_days: [] })).toBe('3日ごと');
    expect(formatFrequency({ frequency_type: 'every_n_days', frequency_value: 1, frequency_days: [] })).toBe('毎日');
    expect(formatFrequency({ frequency_type: 'weekly', frequency_value: 1, frequency_days: [3, 1] })).toBe('月・水');
  });

  it('greetingForHour は時間帯に応じた挨拶を返す', () => {
    expect(greetingForHour(3)).toBe('おつかれさま');
    expect(greetingForHour(9)).toBe('おはよう！');
    expect(greetingForHour(14)).toBe('こんにちは！');
    expect(greetingForHour(21)).toBe('こんばんは！');
  });
});

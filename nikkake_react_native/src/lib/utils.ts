import { Routine, RoutineLog } from '../../types';

export const getDateString = (date: Date = new Date()): string => {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};

/** 'YYYY-MM-DD' をローカルタイムの0時として解釈する（new Date(str)はUTC扱いになるため） */
export const parseDateString = (value: string): Date => {
  const [y, m, d] = value.split('-').map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
};

export const startOfDay = (date: Date): Date =>
  new Date(date.getFullYear(), date.getMonth(), date.getDate());

export const daysBetween = (from: Date, to: Date): number =>
  Math.round((startOfDay(to).getTime() - startOfDay(from).getTime()) / 86400000);

export const addDays = (date: Date, days: number): Date => {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
};

/**
 * そのルーティンを今日やる予定かどうか。
 * 「今日もう終わったか」は別で判定するので、ここでは予定だけを見る。
 */
export const isRoutineDueToday = (
  routine: Routine,
  lastLog: RoutineLog | null,
  today: Date = new Date()
): boolean => {
  if (!routine.is_active) return false;

  switch (routine.frequency_type) {
    case 'daily':
      return true;

    case 'weekly':
      // frequency_days が空なら曜日が未設定なので毎日扱いにする
      if (routine.frequency_days.length === 0) return true;
      return routine.frequency_days.includes(today.getDay());

    case 'every_n_days': {
      if (!lastLog) return true; // 一度もやっていなければ今日から始める
      const interval = Math.max(1, routine.frequency_value);
      return daysBetween(parseDateString(lastLog.log_date), today) >= interval;
    }

    default:
      return false;
  }
};

export const formatDuration = (seconds: number | null | undefined): string => {
  if (seconds === null || seconds === undefined || Number.isNaN(seconds)) return '--:--';

  const total = Math.max(0, Math.floor(seconds));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;

  if (h > 0) {
    return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  return `${m}:${String(s).padStart(2, '0')}`;
};

export const formatWeight = (weight: number | null | undefined): string => {
  if (weight === null || weight === undefined || Number.isNaN(weight)) return '-- kg';
  return `${formatWeightNumber(weight)} kg`;
};

/** 単位なしの重量。小数第1位まで、.0 は省く */
export const formatWeightNumber = (weight: number): string => String(Number(weight.toFixed(1)));

export interface PreviousSetLike {
  reps: number | null;
  weight: number | null;
  durationSec: number | null;
}

/**
 * ワークアウト画面の「前回: …」に出す文字列。
 * packages/contract/domain_cases.json の formatPreviousSets が正で、
 * Ruby の Domain::Stats.format_previous_sets と同じ答えを返さなければならない。
 */
export const formatPreviousSets = (sets: PreviousSetLike[]): string =>
  sets
    .map(set => {
      if (set.durationSec !== null && set.durationSec !== undefined) return `${set.durationSec}秒`;

      const label = set.weight === null || set.weight === undefined
        ? '自重'
        : formatWeightNumber(set.weight);
      return `${label}×${set.reps ?? '-'}`;
    })
    .join(' / ');

export const formatFrequency = (routine: Pick<Routine, 'frequency_type' | 'frequency_value' | 'frequency_days'>): string => {
  const dayNames = ['日', '月', '火', '水', '木', '金', '土'];

  switch (routine.frequency_type) {
    case 'daily':
      return '毎日';
    case 'every_n_days':
      return routine.frequency_value <= 1 ? '毎日' : `${routine.frequency_value}日ごと`;
    case 'weekly':
      if (routine.frequency_days.length === 0) return '毎日';
      return routine.frequency_days
        .slice()
        .sort((a, b) => a - b)
        .map(d => dayNames[d])
        .join('・');
    default:
      return '';
  }
};

export const greetingForHour = (hour: number): string => {
  if (hour < 5) return 'おつかれさま';
  if (hour < 12) return 'おはよう！';
  if (hour < 18) return 'こんにちは！';
  return 'こんばんは！';
};

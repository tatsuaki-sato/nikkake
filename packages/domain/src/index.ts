/**
 * クライアントに残す少数の純粋関数。
 *
 * 判定（今日やるか）と集計（ストリーク、進捗）はサーバが持つ。
 * ここに残しているのは、サーバへ往復できないものだけ:
 *
 *   - formatDuration : 実行中タイマーを毎秒描画する
 *   - formatWeight   : 入力中の表示
 *   - greetingForHour: 端末の時計。サーバに聞く意味がない
 *   - 日付ユーティリティ: log_date を端末TZで決めるのに必要
 *   - didWorkout     : 未送信の記録を楽観的に「完了」表示するための1行
 *   - calculateStreak: サーバ未登録（遅延登録の途中）のあいだだけ使う
 *
 * 期待値は packages/contract/domain_cases.json が唯一の正。
 */

export type LogStatus = 'completed' | 'partial' | 'skipped';

export interface DateLike {
  log_date: string;
  status: LogStatus;
}

export interface StreakInfo {
  current: number;
  longest: number;
  lastCompletedDate: string | null;
}

// ---------- 日付 ----------

export const getDateString = (date: Date = new Date()): string => {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};

/** 'YYYY-MM-DD' をローカルタイムの0時として解釈する（new Date(str) はUTC扱いになる） */
export const parseDateString = (value: string): Date => {
  const [y, m, d] = value.split('-').map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
};

export const startOfDay = (date: Date): Date =>
  new Date(date.getFullYear(), date.getMonth(), date.getDate());

/** 時刻を無視した日数差。DSTの23時間・25時間の日は丸めで吸収される */
export const daysBetween = (from: Date, to: Date): number =>
  Math.round((startOfDay(to).getTime() - startOfDay(from).getTime()) / 86400000);

export const addDays = (date: Date, days: number): Date => {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
};

/** 端末のIANAタイムゾーン名。log_date と一緒にサーバへ送る */
export const currentTimeZone = (): string =>
  Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Tokyo';

// ---------- 表示 ----------

export const formatDuration = (seconds: number | null | undefined): string => {
  if (seconds === null || seconds === undefined || Number.isNaN(seconds)) return '--:--';

  const total = Math.max(0, Math.floor(seconds));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;

  return h > 0
    ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
    : `${m}:${String(s).padStart(2, '0')}`;
};

export const formatWeight = (weight: number | null | undefined): string => {
  if (weight === null || weight === undefined || Number.isNaN(weight)) return '-- kg';
  return `${Number(weight.toFixed(1))} kg`;
};

export const greetingForHour = (hour: number): string => {
  if (hour < 5) return 'おつかれさま';
  if (hour < 12) return 'おはよう！';
  if (hour < 18) return 'こんにちは！';
  return 'こんばんは！';
};

// ---------- 楽観表示のための最小ロジック ----------

/**
 * その日「やった」と数える基準。
 * 全セット完了だけを対象にすると、4種目中3種目やった日がノーカウントになる。
 */
export const didWorkout = (log: { status: LogStatus }): boolean => log.status !== 'skipped';

/**
 * 連続日数。通常はサーバの値を使い、これはサーバ未登録のあいだだけ使う。
 * 最終実施日が今日か昨日なら継続扱い。この猶予が ±1日のTZズレも吸収する。
 */
export const calculateStreak = (logs: DateLike[], today: Date = new Date()): StreakInfo => {
  const dates = Array.from(new Set(logs.filter(didWorkout).map(l => l.log_date))).sort();
  if (dates.length === 0) return { current: 0, longest: 0, lastCompletedDate: null };

  let longest = 1;
  let run = 1;
  for (let i = 1; i < dates.length; i++) {
    const gap = daysBetween(parseDateString(dates[i - 1]), parseDateString(dates[i]));
    run = gap === 1 ? run + 1 : 1;
    longest = Math.max(longest, run);
  }

  const lastCompletedDate = dates[dates.length - 1];
  let current = 0;
  if (daysBetween(parseDateString(lastCompletedDate), today) <= 1) {
    current = 1;
    for (let i = dates.length - 1; i > 0; i--) {
      const gap = daysBetween(parseDateString(dates[i - 1]), parseDateString(dates[i]));
      if (gap !== 1) break;
      current++;
    }
  }

  return { current, longest, lastCompletedDate };
};

export const uuid = (): string => {
  const c = globalThis.crypto;
  if (c && typeof c.randomUUID === 'function') return c.randomUUID();

  // 古い環境向けのフォールバック。SupabaseのUUID列にそのまま入る形にする
  const bytes = new Uint8Array(16);
  if (c && typeof c.getRandomValues === 'function') c.getRandomValues(bytes);
  else for (let i = 0; i < 16; i++) bytes[i] = Math.floor(Math.random() * 256);

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
};

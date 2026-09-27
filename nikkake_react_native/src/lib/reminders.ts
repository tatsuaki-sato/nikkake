import type { HomeView, TodayRoutineView } from './views';

/**
 * ルーティンの通知をいつ出すかを決める（純粋関数）。
 *
 * 繰り返し通知（毎日◯時）にすると「今日はもう終えた」日にも鳴ってしまう。
 * そこで数日先までの1回きりの通知を並べ、ホームを開くたび（＝記録するたび）に
 * 並べ直す。今日の区分はサーバが決めたホームの区分をそのまま使う。
 */

export const REMINDER_HORIZON_DAYS = 7;
export const REMINDER_ID_PREFIX = 'routine_';

const TIME_PATTERN = /^([01]\d|2[0-3]):[0-5]\d$/;

export const isValidTime = (value: string): boolean => TIME_PATTERN.test(value);

export interface PlannedReminder {
  identifier: string;
  routineId: string;
  title: string;
  body: string;
  at: Date;
}

type Group = 'due' | 'notScheduled' | 'completed';

const pad = (n: number) => String(n).padStart(2, '0');
const dateKey = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

/** offset 日後に通知するか。offset 0（今日）は「今日やる分でまだ終えていない」ときだけ */
const remindsOn = (group: Group, entry: TodayRoutineView, offset: number, day: Date): boolean => {
  if (offset === 0) return group === 'due';

  const routine = entry.routine;
  switch (routine.frequencyType) {
    case 'DAILY':
      return true;
    case 'WEEKLY':
      return routine.frequencyDays.length === 0 || routine.frequencyDays.includes(day.getDay());
    case 'EVERY_N_DAYS': {
      // まだ終えていなければ、終えるまで毎日が予定日のまま。
      // 終えたらアプリ内でホームが開き直され、並べ直される
      if (group === 'due') return true;
      if (group === 'completed') return offset % Math.max(1, routine.frequencyValue) === 0;
      // 次の予定日は端末では分からない。開いたときに並べ直す
      return false;
    }
    default:
      return false;
  }
};

export const planReminders = (
  home: HomeView,
  now: Date,
  horizonDays: number = REMINDER_HORIZON_DAYS
): PlannedReminder[] => {
  const [y, m, d] = home.today.split('-').map(Number);
  const groups: [Group, TodayRoutineView[]][] = [
    ['due', home.due],
    ['notScheduled', home.notScheduled],
    ['completed', home.completed],
  ];

  const planned: PlannedReminder[] = [];
  for (const [group, entries] of groups) {
    for (const entry of entries) {
      const { routine } = entry;
      if (!routine.isActive || !routine.preferredTime || !isValidTime(routine.preferredTime)) continue;
      const [hour, minute] = routine.preferredTime.split(':').map(Number);

      for (let offset = 0; offset < horizonDays; offset++) {
        const at = new Date(y, m - 1, d + offset, hour, minute);
        if (at <= now || !remindsOn(group, entry, offset, at)) continue;

        planned.push({
          identifier: `${REMINDER_ID_PREFIX}${routine.id}_${dateKey(at)}`,
          routineId: routine.id,
          title: 'ルーティンの時間です！ 🏋️',
          body: `${routine.icon} ${routine.name} の予定時間になりました。`,
          at,
        });
      }
    }
  }
  return planned.sort((a, b) => a.at.getTime() - b.at.getTime());
};

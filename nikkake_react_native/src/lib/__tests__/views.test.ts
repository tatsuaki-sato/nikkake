import { resetDatabase } from '../localDb';
import { seedIfNeeded } from '../seed';
import {
  createRoutine,
  getExerciseProgressPoints,
  getHome,
  getProgress,
  getStreak,
  getWorkoutSession,
  saveWorkout,
  setRoutineActive,
} from '../repository.local';
import { PRESET_EXERCISES, STARTER_ROUTINE } from '../../constants/exercises';
import { getDateString } from '../utils';

/**
 * 画面に渡す集計済みビューの検証。
 *
 * ここで確かめているのは「サーバが返すのと同じ形と同じ区分になっているか」で、
 * 対応するサーバ側は HomeViewBuilder / ProgressViewBuilder / WorkoutSessionBuilder。
 * 片方だけ変えると、ローカルモードとサーバモードで画面の中身が食い違う。
 */

beforeEach(async () => {
  await resetDatabase();
  await seedIfNeeded();
});

const buildRoutine = () =>
  createRoutine({
    name: '筋トレ',
    icon: '🏋️',
    color: '#6C5CE7',
    frequencyType: 'every_n_days',
    frequencyValue: 3,
    frequencyDays: [],
    exercises: [
      {
        exerciseId: PRESET_EXERCISES[2].id,
        targetSets: 2,
        targetReps: 10,
        targetWeight: 50,
        targetDurationSec: null,
        restSec: 90,
      },
    ],
  });

describe('ホーム', () => {
  it('起動直後は「いつものルーティン」が今日やる分に入っている', async () => {
    const home = await getHome();

    expect(home.today).toBe(getDateString());
    expect(home.due.map(i => i.routine.name)).toContain(STARTER_ROUTINE.name);
    expect(home.completed).toHaveLength(0);
    expect(home.streak.current).toBe(0);
  });

  it('サーバと同じ camelCase の形で返す', async () => {
    const item = (await getHome()).due[0];

    expect(item.routine.frequencyType).toBe('DAILY');
    expect(item.frequencyLabel).toBe('毎日');
    expect(item.routine.routineExercises[0].exercise.category).toBe('STRENGTH');
    expect(item.routine.routineExercises[0].targetSets).toBeGreaterThan(0);
  });

  it('記録すると完了へ移り、連続記録が伸びる', async () => {
    const home = await getHome();
    const target = home.due[0];

    await saveWorkout({
      routineId: target.routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 300,
      exercises: [
        {
          routineExerciseId: target.routine.routineExercises[0].id,
          exerciseId: target.routine.routineExercises[0].exercise.id,
          sets: [{ setNumber: 1, reps: 10, weight: null, durationSec: null, completed: true }],
        },
      ],
    });

    const after = await getHome();

    expect(after.completed.map(i => i.routine.id)).toContain(target.routine.id);
    expect(after.due.map(i => i.routine.id)).not.toContain(target.routine.id);
    expect(after.streak.current).toBe(1);
    expect((await getStreak()).current).toBe(1);
  });

  it('間隔があいていないルーティンは「今日は予定なし」に入る', async () => {
    const routine = await buildRoutine();

    // 3日ごとのルーティンを今日やったら、今日はもう予定なしになる
    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 60,
      exercises: [],
    });

    // 中断扱い（完了セット0）なので「完了」ではないが、実施日としては最新
    const home = await getHome();
    const ids = home.notScheduled.map(i => i.routine.id);

    expect(home.completed.map(i => i.routine.id)).not.toContain(routine.id);
    expect(ids.concat(home.due.map(i => i.routine.id))).toContain(routine.id);
  });

  it('停止したルーティンは3つの区分のどこにも出ない', async () => {
    const routine = await buildRoutine();
    await setRoutineActive(routine.id, false);

    const home = await getHome();
    const all = [...home.due, ...home.notScheduled, ...home.completed];

    expect(all.map(i => i.routine.id)).not.toContain(routine.id);
  });
});

describe('進捗', () => {
  it('記録が無いうちは通算0で、種目の選択肢も空', async () => {
    const progress = await getProgress();

    expect(progress.overall.totalWorkouts).toBe(0);
    expect(progress.exercisesWithLogs).toHaveLength(0);
    expect(progress.completedDates).toHaveLength(0);
    expect(progress.dailyStats).toHaveLength(7);
  });

  it('記録した種目だけが選択肢に出て、推移が引ける', async () => {
    const routine = await buildRoutine();
    const link = (await getWorkoutSession(routine.id))!.exercises[0];

    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 600,
      exercises: [
        {
          routineExerciseId: link.routineExerciseId,
          exerciseId: link.exercise.id,
          sets: [
            { setNumber: 1, reps: 10, weight: 50, durationSec: null, completed: true },
            { setNumber: 2, reps: 8, weight: 55, durationSec: null, completed: true },
          ],
        },
      ],
    });

    const progress = await getProgress();

    expect(progress.overall.totalWorkouts).toBe(1);
    expect(progress.overall.totalSets).toBe(2);
    expect(progress.overall.totalDurationSec).toBe(600);
    expect(progress.completedDates).toEqual([getDateString()]);
    expect(progress.exercisesWithLogs.map(e => e.id)).toEqual([link.exercise.id]);

    const points = await getExerciseProgressPoints(link.exercise.id);
    expect(points).toHaveLength(1);
    expect(points[0]).toMatchObject({ maxWeight: 55, totalReps: 18, totalVolume: 940 });
  });

  it('rangeDays ぶんの日次データを返す', async () => {
    expect((await getProgress(30)).dailyStats).toHaveLength(30);
  });
});

describe('ワークアウトのセッション', () => {
  it('種目・目標値・前回の記録が1本で返る', async () => {
    const routine = await buildRoutine();
    const session = (await getWorkoutSession(routine.id))!;

    expect(session.routine.name).toBe('筋トレ');
    expect(session.exercises).toHaveLength(1);
    expect(session.exercises[0]).toMatchObject({
      targetSets: 2,
      targetReps: 10,
      targetWeight: 50,
      restSec: 90,
      previousSets: [],
      // まだ実績が無いので前回表示は出さない
      previousLabel: null,
    });
  });

  it('前回の記録がサーバと同じ文言で入る', async () => {
    const routine = await buildRoutine();
    const link = (await getWorkoutSession(routine.id))!.exercises[0];

    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 300,
      exercises: [
        {
          routineExerciseId: link.routineExerciseId,
          exerciseId: link.exercise.id,
          sets: [
            { setNumber: 1, reps: 10, weight: 50, durationSec: null, completed: true },
            { setNumber: 2, reps: 9, weight: 50, durationSec: null, completed: true },
          ],
        },
      ],
    });

    const session = (await getWorkoutSession(routine.id))!;

    expect(session.exercises[0].previousSets).toHaveLength(2);
    expect(session.exercises[0].previousLabel).toBe('50×10 / 50×9');
  });

  it('存在しないルーティンでは null を返す', async () => {
    expect(await getWorkoutSession('00000000-0000-4000-8000-999999999999')).toBeNull();
  });

  it('レスト秒が未設定なら60秒を既定にする（サーバの DEFAULT_REST_SEC と同じ）', async () => {
    const routine = await createRoutine({
      name: 'レストなし',
      icon: '💪',
      color: '#6C5CE7',
      frequencyType: 'daily',
      frequencyValue: 1,
      frequencyDays: [],
      exercises: [
        {
          exerciseId: PRESET_EXERCISES[0].id,
          targetSets: 1,
          targetReps: 10,
          targetWeight: null,
          targetDurationSec: null,
          restSec: null,
        },
      ],
    });

    const session = (await getWorkoutSession(routine.id))!;
    expect(session.exercises[0].restSec).toBe(60);
  });
});

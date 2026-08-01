import { resetDatabase } from '../localDb';
import { seedIfNeeded } from '../seed';
import {
  listExercises,
  listRoutines,
  listRoutinesWithExercises,
  getRoutineWithExercises,
  createRoutine,
  updateRoutine,
  deleteRoutine,
  setRoutineActive,
  createCustomExercise,
  saveWorkout,
  getTodayRoutines,
  getTodayLogs,
  listRoutineLogs,
  listExerciseLogs,
  getLastSetsByExercise,
  getRoutineLogDetail,
  deleteRoutineLog,
  RoutineInput,
} from '../repository';
import { PRESET_EXERCISES, STARTER_ROUTINE } from '../../constants/exercises';
import { getDateString } from '../utils';

const routineInput = (patch: Partial<RoutineInput> = {}): RoutineInput => ({
  name: 'テストルーティン',
  icon: '💪',
  color: '#6C5CE7',
  frequencyType: 'daily',
  frequencyValue: 1,
  frequencyDays: [],
  exercises: [
    {
      exerciseId: PRESET_EXERCISES[2].id,
      targetSets: 3,
      targetReps: 10,
      targetWeight: null,
      targetDurationSec: null,
      restSec: 60,
    },
  ],
  ...patch,
});

beforeEach(async () => {
  await resetDatabase();
  await seedIfNeeded();
});

describe('初期状態', () => {
  it('サインインしなくても、起動直後にすぐ始められるルーティンがある', async () => {
    const routines = await listRoutinesWithExercises();

    expect(routines).toHaveLength(1);
    expect(routines[0].name).toBe(STARTER_ROUTINE.name);
    expect(routines[0].routine_exercises.length).toBeGreaterThan(0);
    // 種目が紐づいていないとワークアウトを開始できない
    expect(routines[0].routine_exercises[0].exercise).toBeDefined();
  });

  it('プリセット種目が全件入っている', async () => {
    const exercises = await listExercises();
    expect(exercises).toHaveLength(PRESET_EXERCISES.length);
  });

  it('2回目の起動では初期ルーティンを作り直さない', async () => {
    await seedIfNeeded();
    expect(await listRoutines()).toHaveLength(1);
  });
});

describe('ルーティンのCRUD', () => {
  it('作成すると種目の紐付けごと保存される', async () => {
    const routine = await createRoutine(routineInput({ name: '新しいメニュー' }));
    const loaded = await getRoutineWithExercises(routine.id);

    expect(loaded?.name).toBe('新しいメニュー');
    expect(loaded?.routine_exercises).toHaveLength(1);
    expect(loaded?.routine_exercises[0].target_sets).toBe(3);
    expect(loaded?.routine_exercises[0].rest_sec).toBe(60);
  });

  it('更新すると種目構成が丸ごと差し替わる', async () => {
    const routine = await createRoutine(routineInput());

    await updateRoutine(routine.id, routineInput({
      name: '更新後',
      exercises: [
        {
          exerciseId: PRESET_EXERCISES[8].id,
          targetSets: 5,
          targetReps: 20,
          targetWeight: 40,
          targetDurationSec: null,
          restSec: 90,
        },
        {
          exerciseId: PRESET_EXERCISES[0].id,
          targetSets: 4,
          targetReps: 8,
          targetWeight: 60,
          targetDurationSec: null,
          restSec: 120,
        },
      ],
    }));

    const loaded = await getRoutineWithExercises(routine.id);

    expect(loaded?.name).toBe('更新後');
    expect(loaded?.routine_exercises).toHaveLength(2);
    // 並び順は入力どおり
    expect(loaded?.routine_exercises[0].exercise_id).toBe(PRESET_EXERCISES[8].id);
    expect(loaded?.routine_exercises[1].exercise_id).toBe(PRESET_EXERCISES[0].id);
  });

  it('削除すると一覧から消える', async () => {
    const routine = await createRoutine(routineInput());
    await deleteRoutine(routine.id);

    expect(await getRoutineWithExercises(routine.id)).toBeNull();
    expect((await listRoutines()).find(r => r.id === routine.id)).toBeUndefined();
  });

  it('停止したルーティンは今日の一覧に出ない', async () => {
    const routine = await createRoutine(routineInput());
    await setRoutineActive(routine.id, false);

    const today = await getTodayRoutines();
    expect(today.find(t => t.routine.id === routine.id)).toBeUndefined();
  });

  it('作成順にsort_orderが振られる', async () => {
    const first = await createRoutine(routineInput({ name: '1つ目' }));
    const second = await createRoutine(routineInput({ name: '2つ目' }));

    const routines = await listRoutines();
    expect(routines.find(r => r.id === first.id)!.sort_order).toBeLessThan(
      routines.find(r => r.id === second.id)!.sort_order
    );
  });
});

describe('カスタム種目', () => {
  it('追加した種目が一覧に出る', async () => {
    await createCustomExercise({ name: '自作トレ', category: 'custom', icon: '🌟' });
    const exercises = await listExercises();

    const created = exercises.find(e => e.name === '自作トレ');
    expect(created).toBeDefined();
    expect(created?.is_preset).toBe(false);
  });
});

describe('ワークアウトの保存', () => {
  const workoutFor = async () => {
    const routine = await createRoutine(routineInput());
    const loaded = await getRoutineWithExercises(routine.id);
    return { routine, link: loaded!.routine_exercises[0] };
  };

  it('完了したセットだけがログに残る', async () => {
    const { routine, link } = await workoutFor();

    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 600,
      status: 'completed',
      exercises: [
        {
          routineExerciseId: link.id,
          exerciseId: link.exercise_id,
          sets: [
            { setNumber: 1, reps: 10, weight: 50, durationSec: null, completed: true },
            { setNumber: 2, reps: 10, weight: 50, durationSec: null, completed: true },
            { setNumber: 3, reps: 10, weight: 50, durationSec: null, completed: false },
          ],
        },
      ],
    });

    const exerciseLogs = await listExerciseLogs();
    expect(exerciseLogs).toHaveLength(2);
    expect(exerciseLogs.every(l => l.exercise_id === link.exercise_id)).toBe(true);
  });

  it('保存したワークアウトは今日のログとして引ける', async () => {
    const { routine, link } = await workoutFor();

    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 300,
      status: 'completed',
      exercises: [{ routineExerciseId: link.id, exerciseId: link.exercise_id, sets: [] }],
    });

    const todayLogs = await getTodayLogs();
    expect(todayLogs).toHaveLength(1);
    expect(todayLogs[0].log_date).toBe(getDateString());
  });

  it('完了済みのルーティンは今日の一覧で完了扱いになる', async () => {
    const { routine, link } = await workoutFor();

    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 300,
      status: 'completed',
      exercises: [{ routineExerciseId: link.id, exerciseId: link.exercise_id, sets: [] }],
    });

    const today = await getTodayRoutines();
    expect(today.find(t => t.routine.id === routine.id)?.isCompleted).toBe(true);
  });

  it('途中までの記録でも今日の分は済んだ扱いになる', async () => {
    const { routine, link } = await workoutFor();

    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 120,
      status: 'partial',
      exercises: [
        {
          routineExerciseId: link.id,
          exerciseId: link.exercise_id,
          sets: [{ setNumber: 1, reps: 10, weight: 50, durationSec: null, completed: true }],
        },
      ],
    });

    const today = await getTodayRoutines();
    expect(today.find(t => t.routine.id === routine.id)?.isCompleted).toBe(true);
  });

  it('中断した記録だけなら今日の分は未実施のまま', async () => {
    const { routine, link } = await workoutFor();

    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 10,
      status: 'skipped',
      exercises: [{ routineExerciseId: link.id, exerciseId: link.exercise_id, sets: [] }],
    });

    const today = await getTodayRoutines();
    expect(today.find(t => t.routine.id === routine.id)?.isCompleted).toBe(false);
  });

  it('前回の記録を種目ごとに引ける（次回の初期値に使う）', async () => {
    const { routine, link } = await workoutFor();

    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 300,
      status: 'completed',
      exercises: [
        {
          routineExerciseId: link.id,
          exerciseId: link.exercise_id,
          sets: [
            { setNumber: 1, reps: 12, weight: 55, durationSec: null, completed: true },
            { setNumber: 2, reps: 10, weight: 60, durationSec: null, completed: true },
          ],
        },
      ],
    });

    const lastSets = await getLastSetsByExercise(routine.id);

    expect(lastSets[link.exercise_id]).toHaveLength(2);
    expect(lastSets[link.exercise_id][0]).toMatchObject({ setNumber: 1, reps: 12, weight: 55 });
  });

  it('ルーティンを編集しても過去のセット記録は残る', async () => {
    const { routine, link } = await workoutFor();

    await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 300,
      status: 'completed',
      exercises: [
        {
          routineExerciseId: link.id,
          exerciseId: link.exercise_id,
          sets: [{ setNumber: 1, reps: 10, weight: 50, durationSec: null, completed: true }],
        },
      ],
    });

    // 編集するとrouine_exercisesは作り直されるが、exercise_id経由で履歴は辿れる
    await updateRoutine(routine.id, routineInput({ name: '編集後' }));

    const logs = await listExerciseLogs();
    expect(logs).toHaveLength(1);
    expect(logs[0].exercise_id).toBe(link.exercise_id);
  });

  it('ログを削除するとセット記録も一緒に消える', async () => {
    const { routine, link } = await workoutFor();

    const routineLog = await saveWorkout({
      routineId: routine.id,
      startedAt: new Date().toISOString(),
      durationSec: 300,
      status: 'completed',
      exercises: [
        {
          routineExerciseId: link.id,
          exerciseId: link.exercise_id,
          sets: [{ setNumber: 1, reps: 10, weight: 50, durationSec: null, completed: true }],
        },
      ],
    });

    expect((await getRoutineLogDetail(routineLog.id))?.exerciseLogs).toHaveLength(1);

    await deleteRoutineLog(routineLog.id);

    expect(await getRoutineLogDetail(routineLog.id)).toBeNull();
    expect(await listExerciseLogs()).toHaveLength(0);
    expect(await listRoutineLogs()).toHaveLength(0);
  });
});

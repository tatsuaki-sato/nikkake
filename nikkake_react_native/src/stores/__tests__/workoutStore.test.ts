import { useWorkoutStore } from '../workoutStore';
import { resetDatabase } from '../../lib/localDb';
import { seedIfNeeded } from '../../lib/seed';
import { createRoutine, getRoutineWithExercises, listExerciseLogs, listRoutineLogs } from '../../lib/repository';
import { PRESET_EXERCISES } from '../../constants/exercises';
import { RoutineWithExercises } from '../../../types';

const buildRoutine = async (): Promise<RoutineWithExercises> => {
  const routine = await createRoutine({
    name: 'テスト',
    icon: '💪',
    color: '#6C5CE7',
    frequencyType: 'daily',
    frequencyValue: 1,
    frequencyDays: [],
    exercises: [
      {
        exerciseId: PRESET_EXERCISES[2].id,
        targetSets: 2,
        targetReps: 10,
        targetWeight: 50,
        targetDurationSec: null,
        restSec: 60,
      },
      {
        exerciseId: PRESET_EXERCISES[8].id,
        targetSets: 1,
        targetReps: 15,
        targetWeight: null,
        targetDurationSec: null,
        restSec: 30,
      },
    ],
  });

  return (await getRoutineWithExercises(routine.id))!;
};

beforeEach(async () => {
  await resetDatabase();
  await seedIfNeeded();
  useWorkoutStore.setState({
    activeWorkout: null,
    restTimer: 0,
    isRestTimerActive: false,
    lastSummary: null,
  });
});

describe('ワークアウトの開始', () => {
  it('目標値をそのままセットの初期値にする', async () => {
    const routine = await buildRoutine();
    useWorkoutStore.getState().startWorkout(routine);

    const workout = useWorkoutStore.getState().activeWorkout!;

    expect(workout.exercises).toHaveLength(2);
    expect(workout.exercises[0].sets).toHaveLength(2);
    expect(workout.exercises[0].sets[0]).toMatchObject({ reps: 10, weight: 50, completed: false });
    expect(workout.currentExerciseIndex).toBe(0);
  });

  it('前回の記録があればそちらを初期値にする', async () => {
    const routine = await buildRoutine();
    const exerciseId = routine.routine_exercises[0].exercise_id;

    useWorkoutStore.getState().startWorkout(routine, {
      [exerciseId]: [
        { setNumber: 1, reps: 12, weight: 65, durationSec: null, completed: true },
        { setNumber: 2, reps: 11, weight: 65, durationSec: null, completed: true },
      ],
    });

    const workout = useWorkoutStore.getState().activeWorkout!;
    expect(workout.exercises[0].sets[0]).toMatchObject({ reps: 12, weight: 65 });
    expect(workout.exercises[0].previousSets).toHaveLength(2);
  });

  it('target_setsが0でも最低1セットは用意する', async () => {
    const routine = await buildRoutine();
    routine.routine_exercises[0].target_sets = 0;

    useWorkoutStore.getState().startWorkout(routine);
    expect(useWorkoutStore.getState().activeWorkout!.exercises[0].sets).toHaveLength(1);
  });
});

describe('セットの操作', () => {
  beforeEach(async () => {
    useWorkoutStore.getState().startWorkout(await buildRoutine());
  });

  it('値を編集できる', () => {
    useWorkoutStore.getState().updateSet(0, 1, { weight: 70, reps: 8 });

    const set = useWorkoutStore.getState().activeWorkout!.exercises[0].sets[0];
    expect(set).toMatchObject({ weight: 70, reps: 8 });
  });

  it('完了にするとレストタイマーが自動で走る', () => {
    useWorkoutStore.getState().toggleSetComplete(0, 1);

    const state = useWorkoutStore.getState();
    expect(state.activeWorkout!.exercises[0].sets[0].completed).toBe(true);
    expect(state.isRestTimerActive).toBe(true);
    expect(state.restTimer).toBe(60);
  });

  it('完了を取り消すとレストタイマーも止まる', () => {
    useWorkoutStore.getState().toggleSetComplete(0, 1);
    useWorkoutStore.getState().toggleSetComplete(0, 1);

    const state = useWorkoutStore.getState();
    expect(state.activeWorkout!.exercises[0].sets[0].completed).toBe(false);
    expect(state.isRestTimerActive).toBe(false);
  });

  it('レストタイマーは0で自動停止する', () => {
    useWorkoutStore.getState().startRestTimer(2);
    useWorkoutStore.getState().tickRestTimer();
    expect(useWorkoutStore.getState().restTimer).toBe(1);

    useWorkoutStore.getState().tickRestTimer();
    expect(useWorkoutStore.getState().restTimer).toBe(0);
    expect(useWorkoutStore.getState().isRestTimerActive).toBe(false);

    // 停止後にtickしてもマイナスにならない
    useWorkoutStore.getState().tickRestTimer();
    expect(useWorkoutStore.getState().restTimer).toBe(0);
  });

  it('セットを増減できる', () => {
    useWorkoutStore.getState().addSet(0);
    expect(useWorkoutStore.getState().activeWorkout!.exercises[0].sets).toHaveLength(3);

    useWorkoutStore.getState().removeSet(0);
    expect(useWorkoutStore.getState().activeWorkout!.exercises[0].sets).toHaveLength(2);
  });

  it('セットは1本未満にはできない', () => {
    useWorkoutStore.getState().removeSet(1); // 元々1セットの種目
    expect(useWorkoutStore.getState().activeWorkout!.exercises[1].sets).toHaveLength(1);
  });

  it('種目の移動は範囲外に出ない', () => {
    const store = useWorkoutStore.getState();

    store.previousExercise();
    expect(useWorkoutStore.getState().activeWorkout!.currentExerciseIndex).toBe(0);

    store.nextExercise();
    store.nextExercise();
    expect(useWorkoutStore.getState().activeWorkout!.currentExerciseIndex).toBe(1);
  });
});

describe('ワークアウトの完了', () => {
  it('全セット完了なら completed として保存される', async () => {
    useWorkoutStore.getState().startWorkout(await buildRoutine());
    const store = useWorkoutStore.getState();

    store.toggleSetComplete(0, 1);
    store.toggleSetComplete(0, 2);
    store.toggleSetComplete(1, 1);

    const summary = await useWorkoutStore.getState().finishWorkout();

    expect(summary).not.toBeNull();
    expect(summary!.status).toBe('completed');
    expect(summary!.completedSets).toBe(3);
    expect(summary!.totalSets).toBe(3);
    // 50kg × 10回 × 2セット（2種目目は自重なので0）
    expect(summary!.totalVolume).toBe(1000);

    expect(await listRoutineLogs()).toHaveLength(1);
    expect(await listExerciseLogs()).toHaveLength(3);
  });

  it('一部だけなら partial になる', async () => {
    useWorkoutStore.getState().startWorkout(await buildRoutine());
    useWorkoutStore.getState().toggleSetComplete(0, 1);

    const summary = await useWorkoutStore.getState().finishWorkout();

    expect(summary!.status).toBe('partial');
    expect(summary!.completedSets).toBe(1);
    expect(await listExerciseLogs()).toHaveLength(1);
  });

  it('1つも完了していなければ skipped になる', async () => {
    useWorkoutStore.getState().startWorkout(await buildRoutine());

    const summary = await useWorkoutStore.getState().finishWorkout();

    expect(summary!.status).toBe('skipped');
    expect(await listExerciseLogs()).toHaveLength(0);
  });

  it('完了後は実行中の状態がクリアされ、サマリーが残る', async () => {
    useWorkoutStore.getState().startWorkout(await buildRoutine());
    await useWorkoutStore.getState().finishWorkout();

    const state = useWorkoutStore.getState();
    expect(state.activeWorkout).toBeNull();
    expect(state.isRestTimerActive).toBe(false);
    expect(state.lastSummary).not.toBeNull();
  });

  it('中断すると何も保存されない', async () => {
    useWorkoutStore.getState().startWorkout(await buildRoutine());
    useWorkoutStore.getState().toggleSetComplete(0, 1);
    useWorkoutStore.getState().cancelWorkout();

    expect(useWorkoutStore.getState().activeWorkout).toBeNull();
    expect(await listRoutineLogs()).toHaveLength(0);
  });

  it('実行中でなければ finishWorkout は null を返す', async () => {
    expect(await useWorkoutStore.getState().finishWorkout()).toBeNull();
  });
});

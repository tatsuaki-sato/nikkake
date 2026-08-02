import { create } from 'zustand';
import { WorkoutSet, WorkoutState, WorkoutSummary } from '../../types';
import type { WorkoutSession } from '../lib/views';
import { saveWorkout } from '../lib/repository';
import { DEFAULT_REST_SEC } from '../constants/exercises';
import { nowIso } from '../lib/id';

/**
 * 実行中のワークアウトの状態。
 * 保存はローカルストレージへの書き込みなので即座に完了し、失敗し得るのはストレージ枯渇のみ。
 */

interface WorkoutStoreState {
  activeWorkout: WorkoutState | null;
  restTimer: number;
  isRestTimerActive: boolean;
  lastSummary: WorkoutSummary | null;

  startWorkout: (session: WorkoutSession) => void;
  updateSet: (exerciseIndex: number, setNumber: number, patch: Partial<WorkoutSet>) => void;
  toggleSetComplete: (exerciseIndex: number, setNumber: number) => void;
  addSet: (exerciseIndex: number) => void;
  removeSet: (exerciseIndex: number) => void;
  goToExercise: (index: number) => void;
  nextExercise: () => void;
  previousExercise: () => void;
  startRestTimer: (seconds: number) => void;
  stopRestTimer: () => void;
  tickRestTimer: () => void;
  finishWorkout: () => Promise<WorkoutSummary | null>;
  cancelWorkout: () => void;
  clearSummary: () => void;
}

export const useWorkoutStore = create<WorkoutStoreState>((set, get) => ({
  activeWorkout: null,
  restTimer: 0,
  isRestTimerActive: false,
  lastSummary: null,

  startWorkout: session => {
    const exercises = session.exercises.map(entry => {
      // 「前回の記録」はサーバが解決済み。ここで過去ログを漁らない
      const previousSets: WorkoutSet[] = entry.previousSets.map(s => ({
        setNumber: s.setNumber,
        reps: s.reps,
        weight: s.weight,
        durationSec: s.durationSec,
        completed: true,
      }));

      return {
        routineExerciseId: entry.routineExerciseId,
        exercise: {
          id: entry.exercise.id,
          name: entry.exercise.name,
          icon: entry.exercise.icon,
        },
        targetSets: entry.targetSets,
        targetReps: entry.targetReps,
        targetWeight: entry.targetWeight,
        targetDurationSec: entry.targetDurationSec,
        restSec: entry.restSec ?? DEFAULT_REST_SEC,
        // 前回の記録があればそれを初期値にする。前回と同じ重量から始めることが多いため。
        sets: Array.from({ length: Math.max(1, entry.targetSets) }, (_, i) => {
          const previous = previousSets.find(s => s.setNumber === i + 1);
          return {
            setNumber: i + 1,
            reps: previous?.reps ?? entry.targetReps,
            weight: previous?.weight ?? entry.targetWeight,
            durationSec: previous?.durationSec ?? entry.targetDurationSec,
            completed: false,
          };
        }),
        previousSets,
      };
    });

    set({
      activeWorkout: {
        routineId: session.routine.id,
        routineName: session.routine.name,
        exercises,
        startedAt: nowIso(),
        currentExerciseIndex: 0,
      },
      restTimer: 0,
      isRestTimerActive: false,
      lastSummary: null,
    });
  },

  updateSet: (exerciseIndex, setNumber, patch) => {
    const { activeWorkout } = get();
    if (!activeWorkout) return;

    const exercises = activeWorkout.exercises.map((exercise, i) => {
      if (i !== exerciseIndex) return exercise;
      return {
        ...exercise,
        sets: exercise.sets.map(s => (s.setNumber === setNumber ? { ...s, ...patch } : s)),
      };
    });

    set({ activeWorkout: { ...activeWorkout, exercises } });
  },

  toggleSetComplete: (exerciseIndex, setNumber) => {
    const { activeWorkout } = get();
    if (!activeWorkout) return;

    const target = activeWorkout.exercises[exerciseIndex]?.sets.find(s => s.setNumber === setNumber);
    if (!target) return;

    const willComplete = !target.completed;
    get().updateSet(exerciseIndex, setNumber, { completed: willComplete });

    // セットを終えた直後にレストタイマーを自動で回す。手動で押させるとまず押し忘れる。
    if (willComplete) {
      const restSec = activeWorkout.exercises[exerciseIndex].restSec ?? DEFAULT_REST_SEC;
      if (restSec > 0) get().startRestTimer(restSec);
    } else {
      get().stopRestTimer();
    }
  },

  addSet: exerciseIndex => {
    const { activeWorkout } = get();
    if (!activeWorkout) return;

    const exercises = activeWorkout.exercises.map((exercise, i) => {
      if (i !== exerciseIndex) return exercise;

      const last = exercise.sets[exercise.sets.length - 1];
      return {
        ...exercise,
        sets: [
          ...exercise.sets,
          {
            setNumber: (last?.setNumber ?? 0) + 1,
            reps: last?.reps ?? exercise.targetReps,
            weight: last?.weight ?? exercise.targetWeight,
            durationSec: last?.durationSec ?? exercise.targetDurationSec,
            completed: false,
          },
        ],
      };
    });

    set({ activeWorkout: { ...activeWorkout, exercises } });
  },

  removeSet: exerciseIndex => {
    const { activeWorkout } = get();
    if (!activeWorkout) return;

    const exercises = activeWorkout.exercises.map((exercise, i) => {
      // セット0本にすると種目自体が意味を失うので最低1本は残す
      if (i !== exerciseIndex || exercise.sets.length <= 1) return exercise;
      return { ...exercise, sets: exercise.sets.slice(0, -1) };
    });

    set({ activeWorkout: { ...activeWorkout, exercises } });
  },

  goToExercise: index => {
    const { activeWorkout } = get();
    if (!activeWorkout) return;

    const clamped = Math.min(Math.max(index, 0), activeWorkout.exercises.length - 1);
    set({ activeWorkout: { ...activeWorkout, currentExerciseIndex: clamped } });
  },

  nextExercise: () => get().goToExercise((get().activeWorkout?.currentExerciseIndex ?? 0) + 1),
  previousExercise: () => get().goToExercise((get().activeWorkout?.currentExerciseIndex ?? 0) - 1),

  startRestTimer: seconds => set({ restTimer: seconds, isRestTimerActive: true }),
  stopRestTimer: () => set({ restTimer: 0, isRestTimerActive: false }),

  tickRestTimer: () => {
    const { restTimer, isRestTimerActive } = get();
    if (!isRestTimerActive) return;

    if (restTimer <= 1) {
      set({ restTimer: 0, isRestTimerActive: false });
      return;
    }
    set({ restTimer: restTimer - 1 });
  },

  finishWorkout: async () => {
    const { activeWorkout } = get();
    if (!activeWorkout) return null;

    const durationSec = Math.round((Date.now() - new Date(activeWorkout.startedAt).getTime()) / 1000);

    // セット数の集計も status の判定も repository が行う。
    // ここで決めるとサーバの判定基準とずれたときに気づけない。
    const saved = await saveWorkout({
      routineId: activeWorkout.routineId,
      startedAt: activeWorkout.startedAt,
      durationSec,
      exercises: activeWorkout.exercises.map(e => ({
        routineExerciseId: e.routineExerciseId,
        exerciseId: e.exercise.id,
        sets: e.sets,
      })),
    });

    // ルーティン名だけは手元のほうが確実。
    // オフラインで記録したときサーバは名前を返せない
    const summary: WorkoutSummary = { ...saved, routineName: activeWorkout.routineName };

    set({ activeWorkout: null, restTimer: 0, isRestTimerActive: false, lastSummary: summary });
    return summary;
  },

  cancelWorkout: () =>
    set({ activeWorkout: null, restTimer: 0, isRestTimerActive: false }),

  clearSummary: () => set({ lastSummary: null }),
}));

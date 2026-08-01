import { create } from 'zustand';
import { LogStatus, RoutineWithExercises, WorkoutSet, WorkoutState, WorkoutSummary } from '../../types';
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

  startWorkout: (routine: RoutineWithExercises, lastSets?: Record<string, WorkoutSet[]>) => void;
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

const countSets = (workout: WorkoutState) => {
  let completed = 0;
  let total = 0;
  let volume = 0;

  for (const exercise of workout.exercises) {
    for (const set of exercise.sets) {
      total++;
      if (set.completed) {
        completed++;
        volume += (set.weight ?? 0) * (set.reps ?? 0);
      }
    }
  }

  return { completed, total, volume };
};

const resolveStatus = (completed: number, total: number): LogStatus => {
  if (completed === 0) return 'skipped';
  if (completed >= total) return 'completed';
  return 'partial';
};

export const useWorkoutStore = create<WorkoutStoreState>((set, get) => ({
  activeWorkout: null,
  restTimer: 0,
  isRestTimerActive: false,
  lastSummary: null,

  startWorkout: (routine, lastSets = {}) => {
    const exercises = routine.routine_exercises.map(link => {
      const previousSets = lastSets[link.exercise_id] ?? [];

      return {
        routineExerciseId: link.id,
        exercise: link.exercise,
        targetSets: link.target_sets,
        targetReps: link.target_reps,
        targetWeight: link.target_weight,
        targetDurationSec: link.target_duration_sec,
        restSec: link.rest_sec ?? DEFAULT_REST_SEC,
        // 前回の記録があればそれを初期値にする。前回と同じ重量から始めることが多いため。
        sets: Array.from({ length: Math.max(1, link.target_sets) }, (_, i) => {
          const previous = previousSets.find(s => s.setNumber === i + 1);
          return {
            setNumber: i + 1,
            reps: previous?.reps ?? link.target_reps,
            weight: previous?.weight ?? link.target_weight,
            durationSec: previous?.durationSec ?? link.target_duration_sec,
            completed: false,
          };
        }),
        previousSets,
      };
    });

    set({
      activeWorkout: {
        routineId: routine.id,
        routineName: routine.name,
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

    const { completed, total, volume } = countSets(activeWorkout);
    const status = resolveStatus(completed, total);
    const durationSec = Math.round((Date.now() - new Date(activeWorkout.startedAt).getTime()) / 1000);

    const routineLog = await saveWorkout({
      routineId: activeWorkout.routineId,
      startedAt: activeWorkout.startedAt,
      durationSec,
      status,
      exercises: activeWorkout.exercises.map(e => ({
        routineExerciseId: e.routineExerciseId,
        exerciseId: e.exercise.id,
        sets: e.sets,
      })),
    });

    const summary: WorkoutSummary = {
      routineLogId: routineLog.id,
      routineName: activeWorkout.routineName,
      durationSec,
      completedSets: completed,
      totalSets: total,
      totalVolume: volume,
      status,
    };

    set({ activeWorkout: null, restTimer: 0, isRestTimerActive: false, lastSummary: summary });
    return summary;
  },

  cancelWorkout: () =>
    set({ activeWorkout: null, restTimer: 0, isRestTimerActive: false }),

  clearSummary: () => set({ lastSummary: null }),
}));

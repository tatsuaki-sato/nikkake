import * as localImpl from './repository.local';
import * as serverImpl from './repository.server';
import { isServerReady } from './session';

/**
 * 画面が触る唯一のデータAPI。
 *
 * 実装は2つある。
 *   local  : 端末ストレージが真実の源。ネットワークを使わない
 *   server : Rails の GraphQL が真実の源。集計もサーバが返す
 *
 * どちらを使うかは EXPO_PUBLIC_BACKEND と、実行時の登録状態で決まる。
 * サーバモードでも、サーバへの登録と端末データの預け入れが済むまでは
 * ローカル実装を使う（遅延登録）。判定を毎回行うのはそのため。
 * 同じ E2E スイートが両方で通ることを、移行で挙動が変わっていないことの
 * 証明にしているので、片方だけに関数を生やさないこと。
 * 型が食い違えば下の Repository で不一致になり、コンパイルが落ちる。
 */

/** 両実装が満たすべき形。ここに無いものは画面から呼ばせない */
interface Repository {
  getHome: typeof localImpl.getHome;
  getStreak: typeof localImpl.getStreak;
  getProgress: typeof localImpl.getProgress;
  getExerciseProgressPoints: typeof localImpl.getExerciseProgressPoints;
  getDay: typeof localImpl.getDay;
  getWorkoutSession: typeof localImpl.getWorkoutSession;

  listExercises: typeof localImpl.listExercises;
  createCustomExercise: typeof localImpl.createCustomExercise;

  listRoutinesWithExercises: typeof localImpl.listRoutinesWithExercises;
  getRoutineWithExercises: typeof localImpl.getRoutineWithExercises;
  createRoutine: typeof localImpl.createRoutine;
  updateRoutine: typeof localImpl.updateRoutine;
  setRoutineActive: typeof localImpl.setRoutineActive;
  deleteRoutine: typeof localImpl.deleteRoutine;

  saveWorkout: typeof localImpl.saveWorkout;

  getCounts: typeof localImpl.getCounts;
  resetData: typeof localImpl.resetData;

  pendingCount: typeof localImpl.pendingCount;
  flushPending: typeof localImpl.flushPending;
}

const local: Repository = localImpl;
const server: Repository = serverImpl;

/**
 * 呼び出しのたびに選ぶ。モジュール読み込み時に固定してはいけない。
 * 起動直後はまだ登録が終わっていないので、固定するとローカルのまま戻らない。
 */
const impl = (): Repository => (isServerReady() ? server : local);

export const getHome: Repository['getHome'] = (...args) => impl().getHome(...args);
export const getStreak: Repository['getStreak'] = (...args) => impl().getStreak(...args);
export const getProgress: Repository['getProgress'] = (...args) => impl().getProgress(...args);
export const getExerciseProgressPoints: Repository['getExerciseProgressPoints'] = (...args) =>
  impl().getExerciseProgressPoints(...args);
export const getDay: Repository['getDay'] = (...args) => impl().getDay(...args);
export const getWorkoutSession: Repository['getWorkoutSession'] = (...args) =>
  impl().getWorkoutSession(...args);

export const listExercises: Repository['listExercises'] = (...args) => impl().listExercises(...args);
export const createCustomExercise: Repository['createCustomExercise'] = (...args) =>
  impl().createCustomExercise(...args);

export const listRoutinesWithExercises: Repository['listRoutinesWithExercises'] = (...args) =>
  impl().listRoutinesWithExercises(...args);
export const getRoutineWithExercises: Repository['getRoutineWithExercises'] = (...args) =>
  impl().getRoutineWithExercises(...args);
export const createRoutine: Repository['createRoutine'] = (...args) => impl().createRoutine(...args);
export const updateRoutine: Repository['updateRoutine'] = (...args) => impl().updateRoutine(...args);
export const setRoutineActive: Repository['setRoutineActive'] = (...args) =>
  impl().setRoutineActive(...args);
export const deleteRoutine: Repository['deleteRoutine'] = (...args) => impl().deleteRoutine(...args);

export const saveWorkout: Repository['saveWorkout'] = (...args) => impl().saveWorkout(...args);

export const getCounts: Repository['getCounts'] = (...args) => impl().getCounts(...args);
export const resetData: Repository['resetData'] = (...args) => impl().resetData(...args);

export const pendingCount: Repository['pendingCount'] = (...args) => impl().pendingCount(...args);
export const flushPending: Repository['flushPending'] = (...args) => impl().flushPending(...args);

export type { DataCounts, RoutineInput, RoutineExerciseInput, SaveWorkoutInput } from './repository.local';

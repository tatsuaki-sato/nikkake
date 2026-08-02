import { COLLECTIONS, getMeta, listRaw, setMeta } from './localDb';
import { seedIfNeeded } from './seed';
import { hydrateNativeStore } from './nativeStore';
import { isServerBackend } from '../config';
import { markServerReady } from './session';

/**
 * 起動処理。
 *
 * 待つ部分と待ってはいけない部分を、意図的に別の関数に分けてある。
 *
 *   prepareLocalData()      画面を出す前に必ず待つ。ネットワークを使わない
 *   registerInBackground()  絶対に待たない。圏外なら何もせず次回に回す
 *
 * サーバへの登録を待ってから画面を出すと、アプリを入れた直後に圏外だと
 * 1歩も動かなくなる。docs/FEATURES.md の絶対条件
 * 「起動直後に1タップで始められる」に反するので、この順序は変えないこと。
 */

/** 端末のデータをサーバへ預け終わった印。localDb の meta に持つ */
const IMPORTED_KEY = 'snapshotImportedAt';

/**
 * 画面を出すのに必要な準備。ネットワークを使わないので必ず終わる。
 * @returns 初回起動でシードしたか
 */
export const prepareLocalData = async (): Promise<boolean> => seedIfNeeded();

export interface RegistrationResult {
  /** サーバに登録できたか。圏外なら false */
  registered: boolean;
  /** 端末のデータをサーバへ預けたか */
  imported: boolean;
}

/**
 * サーバへの遅延登録。呼び出し側は結果を待たない。
 * 失敗しても例外を投げない（起動を巻き添えにしない）。
 */
export const registerInBackground = async (): Promise<RegistrationResult> => {
  const nothingDone: RegistrationResult = { registered: false, imported: false };
  if (!isServerBackend()) return nothingDone;

  try {
    await hydrateNativeStore();

    const { api } = await import('./repository.server');

    // 端末側でシード済みなので、サーバにもう1つ作らせない。
    // 両方で作ると「いつものルーティン」が2つ並ぶ
    api.suppressStarterRoutine();

    const token = await api.ensureSession();
    if (!token) return nothingDone;

    const imported = await importLocalSnapshot();

    // ここから先はサーバが真実の源。画面のキャッシュを捨てさせる
    markServerReady();

    // 切り替えの直前に端末へ書かれた分を拾う。
    //
    // 登録が終わる前でもユーザーは操作できる（それがこの設計の目的）ので、
    // 1回目の預け入れとサーバ切り替えのあいだに書かれた記録は
    // どちらにも属さないまま取り残される。
    // ID は端末生成で ON CONFLICT DO NOTHING に吸収されるため、
    // もう一度送るのは安全で、これで隙間が閉じる。
    await Promise.resolve();
    await importLocalSnapshot({ force: true });

    // 圏外中に溜まった記録を送る
    void api.flushQueue();

    return { registered: true, imported };
  } catch {
    // 圏外・サーバ停止・不正な応答。次回起動で再試行する
    return nothingDone;
  }
};

/**
 * 端末のデータをサーバへ預ける。
 *
 * 起動のたびに送ってはいけない。以降の書き込みはサーバが正になるので、
 * 繰り返すとサーバ側で消したはずのルーティンが端末のコピーから復活する。
 * だから初回だけ送り、印を meta に残す。
 *
 * force は「同じ起動の中でもう一度だけ送る」ためのもの
 * （切り替え直前の書き込みを拾う用途）。
 */
const importLocalSnapshot = async ({ force = false } = {}): Promise<boolean> => {
  const meta = await getMeta();
  if (meta[IMPORTED_KEY] && !force) return false;

  const { api } = await import('./repository.server');

  const [exercises, routines, routineExercises, routineLogs, exerciseLogs] = await Promise.all([
    listRaw(COLLECTIONS.exercises),
    listRaw(COLLECTIONS.routines),
    listRaw(COLLECTIONS.routineExercises),
    listRaw(COLLECTIONS.routineLogs),
    listRaw(COLLECTIONS.exerciseLogs),
  ]);

  const result = await api.importSnapshot({
    // プリセット種目はサーバが持っているので送らない。
    // 送ると is_preset を端末の値で上書きしてしまう
    exercises: exercises.filter(e => !(e as { is_preset?: boolean }).is_preset),
    routines,
    routineExercises,
    routineLogs,
    exerciseLogs,
  });

  if (result.userErrors.length > 0) return false;

  await setMeta({ [IMPORTED_KEY]: new Date().toISOString() });
  return true;
};

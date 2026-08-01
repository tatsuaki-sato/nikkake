import { supabase } from './supabase';
import {
  COLLECTIONS,
  CollectionName,
  changedSince,
  getMeta,
  setMeta,
  listRaw,
  upsertFromRemote,
} from './localDb';
import { readCollection, writeCollection } from './storage';
import { Exercise, Routine, RoutineLog, SyncState } from '../../types';
import { nowIso } from './id';

/**
 * Supabaseとの同期。
 *
 * 方針:
 *  - ローカルが常に真実の源。同期はあくまで「バックアップと他端末への複製」
 *  - 衝突は updated_at の新しい方を採用する (last-write-wins)
 *  - 失敗しても画面は動き続ける。次回の同期でリトライされる
 *
 * サインインしていない場合、この層は一切呼ばれない。
 */

/** ユーザーに紐づくテーブル。pull時に user_id で絞り込む */
const USER_SCOPED: CollectionName[] = [
  COLLECTIONS.routines,
  COLLECTIONS.routineLogs,
];

/** 親テーブル→子テーブルの順。外部キー制約を壊さないためにこの順でpushする */
const PUSH_ORDER: CollectionName[] = [
  COLLECTIONS.exercises,
  COLLECTIONS.routines,
  COLLECTIONS.routineExercises,
  COLLECTIONS.routineLogs,
  COLLECTIONS.exerciseLogs,
];

/** pullは子から消えても困らないので親から。順序はpushと同じで問題ない */
const PULL_ORDER = PUSH_ORDER;

export class SyncError extends Error {
  constructor(message: string, readonly collection?: CollectionName) {
    super(message);
    this.name = 'SyncError';
  }
}

/**
 * サインイン直後に一度だけ実行する。
 * それまで user_id = null で作られていたローカルのレコードを、
 * このアカウントのものとして引き取る。
 */
export const claimLocalRows = async (userId: string): Promise<number> => {
  let claimed = 0;

  for (const collection of USER_SCOPED) {
    const rows = await readCollection<Routine | RoutineLog>(collection);
    let changed = false;

    const next = rows.map(row => {
      if (row.user_id === userId) return row;
      changed = true;
      claimed++;
      return { ...row, user_id: userId, updated_at: nowIso() };
    });

    if (changed) {
      await writeCollection(collection, next);
    }
  }

  return claimed;
};

const pushCollection = async (collection: CollectionName, since: string | null): Promise<number> => {
  let rows = await changedSince<any>(collection, since);

  // プリセット種目はサーバ側にも同じIDで存在する共有マスタなので送らない
  if (collection === COLLECTIONS.exercises) {
    rows = rows.filter((r: Exercise) => !r.is_preset);
  }

  if (rows.length === 0) return 0;

  const { error } = await supabase.from(collection).upsert(rows, { onConflict: 'id' });
  if (error) throw new SyncError(error.message, collection);

  return rows.length;
};

const pullCollection = async (
  collection: CollectionName,
  since: string | null,
  userId: string
): Promise<number> => {
  let query = supabase.from(collection).select('*');

  if (since) {
    query = query.gt('updated_at', since);
  }
  if (USER_SCOPED.includes(collection)) {
    query = query.eq('user_id', userId);
  }

  const { data, error } = await query;
  if (error) throw new SyncError(error.message, collection);
  if (!data || data.length === 0) return 0;

  const result = await upsertFromRemote(collection, data as any[]);
  return result.inserted + result.updated;
};

export interface SyncResult {
  pushed: number;
  pulled: number;
  syncedAt: string;
}

/**
 * 双方向同期を1回実行する。
 *
 * pushを先にやるのは、同じレコードを両方が持っていた場合に
 * サーバ側の updated_at が確定してからpullしたいため。
 */
export const runSync = async (userId: string): Promise<SyncResult> => {
  const meta = await getMeta();

  // 別アカウントでサインインし直した場合は差分カーソルを捨てて全件取り直す
  const since = meta.syncUserId === userId ? meta.lastSyncedAt : null;

  // 同期の開始時刻を基準にする。処理中に増えた変更を取りこぼさないため、
  // 完了時刻ではなく開始時刻をカーソルに保存する。
  const startedAt = nowIso();

  let pushed = 0;
  for (const collection of PUSH_ORDER) {
    pushed += await pushCollection(collection, since);
  }

  let pulled = 0;
  for (const collection of PULL_ORDER) {
    pulled += await pullCollection(collection, since, userId);
  }

  await setMeta({ lastSyncedAt: startedAt, syncUserId: userId });

  return { pushed, pulled, syncedAt: startedAt };
};

/**
 * 例外を投げない版。UIから呼ぶときはこちらを使い、
 * 失敗しても操作をブロックしない。
 */
export const trySync = async (userId: string): Promise<SyncState> => {
  try {
    const result = await runSync(userId);
    return { status: 'idle', lastSyncedAt: result.syncedAt, lastError: null };
  } catch (error) {
    const meta = await getMeta();
    const message = error instanceof Error ? error.message : String(error);

    // ネットワーク由来かどうかで表示を出し分ける
    const isOffline = /network|fetch|timeout|failed to fetch/i.test(message);

    return {
      status: isOffline ? 'offline' : 'error',
      lastSyncedAt: meta.lastSyncedAt,
      lastError: message,
    };
  }
};

/** 設定画面に出す「バックアップ対象の件数」 */
export const getPendingCount = async (): Promise<number> => {
  const meta = await getMeta();
  let count = 0;

  for (const collection of PUSH_ORDER) {
    const rows = await changedSince<any>(collection, meta.lastSyncedAt);
    count += collection === COLLECTIONS.exercises
      ? rows.filter((r: Exercise) => !r.is_preset).length
      : rows.length;
  }

  return count;
};

/** デバッグ・設定画面用のローカル件数 */
export const getLocalCounts = async (): Promise<Record<string, number>> => {
  const entries = await Promise.all(
    PUSH_ORDER.map(async collection => {
      const rows = await listRaw<any>(collection);
      return [collection, rows.filter(r => !r.deleted_at).length] as const;
    })
  );

  return Object.fromEntries(entries);
};

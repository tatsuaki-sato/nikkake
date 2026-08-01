import { readCollection, writeCollection, readObject, writeObject, clearAll } from './storage';
import { uuid, nowIso } from './id';
import { SyncFields } from '../../types';

/**
 * ローカルの「テーブル」定義。Supabase側のテーブル名と1:1で対応させてあるので、
 * 同期処理は名前をそのまま使ってpush/pullできる。
 */
export const COLLECTIONS = {
  exercises: 'exercises',
  routines: 'routines',
  routineExercises: 'routine_exercises',
  routineLogs: 'routine_logs',
  exerciseLogs: 'exercise_logs',
} as const;

export type CollectionName = (typeof COLLECTIONS)[keyof typeof COLLECTIONS];

export interface LocalMeta {
  schemaVersion: number;
  seeded: boolean;
  /** 最後にSupabaseと同期できた時刻。pullの差分取得カーソルも兼ねる */
  lastSyncedAt: string | null;
  /** 同期先アカウント。別アカウントでサインインしたら作り直す */
  syncUserId: string | null;
}

export const CURRENT_SCHEMA_VERSION = 1;

const DEFAULT_META: LocalMeta = {
  schemaVersion: CURRENT_SCHEMA_VERSION,
  seeded: false,
  lastSyncedAt: null,
  syncUserId: null,
};

export const getMeta = (): Promise<LocalMeta> => readObject<LocalMeta>('meta', DEFAULT_META);

export const setMeta = async (patch: Partial<LocalMeta>): Promise<LocalMeta> => {
  const current = await getMeta();
  const next = { ...current, ...patch };
  await writeObject('meta', next);
  return next;
};

type Row = SyncFields & { id: string };

/** 論理削除されていない行だけを返す */
export const list = async <T extends Row>(collection: CollectionName): Promise<T[]> => {
  const rows = await readCollection<T>(collection);
  return rows.filter(r => !r.deleted_at);
};

/** 論理削除済みも含めた生データ。同期処理だけが使う */
export const listRaw = <T extends Row>(collection: CollectionName): Promise<T[]> =>
  readCollection<T>(collection);

export const find = async <T extends Row>(
  collection: CollectionName,
  id: string
): Promise<T | null> => {
  const rows = await list<T>(collection);
  return rows.find(r => r.id === id) ?? null;
};

export const where = async <T extends Row>(
  collection: CollectionName,
  predicate: (row: T) => boolean
): Promise<T[]> => {
  const rows = await list<T>(collection);
  return rows.filter(predicate);
};

export const insert = async <T extends Row>(
  collection: CollectionName,
  values: Omit<T, 'id' | 'updated_at' | 'deleted_at' | 'created_at'> & Partial<Row> & { created_at?: string }
): Promise<T> => {
  const rows = await readCollection<T>(collection);
  const timestamp = nowIso();

  const row = {
    ...values,
    id: values.id ?? uuid(),
    created_at: values.created_at ?? timestamp,
    updated_at: timestamp,
    deleted_at: null,
  } as unknown as T;

  await writeCollection(collection, [...rows, row]);
  return row;
};

export const insertMany = async <T extends Row>(
  collection: CollectionName,
  valuesList: (Omit<T, 'id' | 'updated_at' | 'deleted_at' | 'created_at'> & Partial<Row> & { created_at?: string })[]
): Promise<T[]> => {
  const rows = await readCollection<T>(collection);
  const timestamp = nowIso();

  const created = valuesList.map(values => ({
    ...values,
    id: (values as Partial<Row>).id ?? uuid(),
    created_at: values.created_at ?? timestamp,
    updated_at: timestamp,
    deleted_at: null,
  })) as unknown as T[];

  await writeCollection(collection, [...rows, ...created]);
  return created;
};

export const update = async <T extends Row>(
  collection: CollectionName,
  id: string,
  patch: Partial<T>
): Promise<T | null> => {
  const rows = await readCollection<T>(collection);
  const index = rows.findIndex(r => r.id === id);
  if (index < 0) return null;

  const updated = { ...rows[index], ...patch, id, updated_at: nowIso() } as T;
  const next = [...rows];
  next[index] = updated;
  await writeCollection(collection, next);
  return updated;
};

/**
 * 論理削除。物理削除にすると「削除した」という事実が同期先に伝わらず、
 * 他端末からpullし直すたびに復活してしまう。
 */
export const softDelete = async (collection: CollectionName, id: string): Promise<boolean> => {
  const rows = await readCollection<Row>(collection);
  const index = rows.findIndex(r => r.id === id);
  if (index < 0) return false;

  const timestamp = nowIso();
  const next = [...rows];
  next[index] = { ...rows[index], deleted_at: timestamp, updated_at: timestamp };
  await writeCollection(collection, next);
  return true;
};

export const softDeleteWhere = async (
  collection: CollectionName,
  predicate: (row: Row) => boolean
): Promise<number> => {
  const rows = await readCollection<Row>(collection);
  const timestamp = nowIso();
  let count = 0;

  const next = rows.map(row => {
    if (row.deleted_at || !predicate(row)) return row;
    count++;
    return { ...row, deleted_at: timestamp, updated_at: timestamp };
  });

  if (count > 0) {
    await writeCollection(collection, next);
  }
  return count;
};

/**
 * 同期のpull結果をローカルへ取り込む。updated_atが新しい方を採用する
 * (last-write-wins)。ローカル側が新しければリモートの値は捨てる。
 */
export const upsertFromRemote = async <T extends Row>(
  collection: CollectionName,
  remoteRows: T[]
): Promise<{ inserted: number; updated: number; skipped: number }> => {
  const rows = await readCollection<T>(collection);
  const byId = new Map(rows.map(r => [r.id, r]));
  let inserted = 0;
  let updated = 0;
  let skipped = 0;

  for (const remote of remoteRows) {
    const local = byId.get(remote.id);
    if (!local) {
      byId.set(remote.id, remote);
      inserted++;
      continue;
    }

    if (new Date(remote.updated_at).getTime() > new Date(local.updated_at).getTime()) {
      byId.set(remote.id, remote);
      updated++;
    } else {
      skipped++;
    }
  }

  await writeCollection(collection, Array.from(byId.values()));
  return { inserted, updated, skipped };
};

/** 前回同期以降に変更された行（push対象） */
export const changedSince = async <T extends Row>(
  collection: CollectionName,
  since: string | null
): Promise<T[]> => {
  const rows = await readCollection<T>(collection);
  if (!since) return rows;

  const cursor = new Date(since).getTime();
  return rows.filter(r => new Date(r.updated_at).getTime() > cursor);
};

export const resetDatabase = clearAll;

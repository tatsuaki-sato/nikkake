import { readCollection, writeCollection, readObject, writeObject, clearAll } from './storage';
import { uuid, nowIso } from './id';
import { SyncFields } from '../../types';

/**
 * ローカルの「テーブル」定義。Rails 側の列名（snake_case）と1:1で対応させてあるので、
 * 遅延登録で預けるとき（importSnapshot）に変換が要らない。
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
  /**
   * 端末のデータをサーバへ預けた日時（サーバモードのみ）。
   * 一度入ったら二度と送らない。繰り返すとサーバで消したルーティンが復活する
   */
  snapshotImportedAt?: string | null;
  schemaVersion: number;
  seeded: boolean;
}

export const CURRENT_SCHEMA_VERSION = 1;

const DEFAULT_META: LocalMeta = {
  schemaVersion: CURRENT_SCHEMA_VERSION,
  seeded: false,
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

export const resetDatabase = clearAll;

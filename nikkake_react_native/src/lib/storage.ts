import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * 端末ローカルの永続化レイヤ。
 *
 * AsyncStorage はネイティブでは非同期SQLite/ファイル、Web では localStorage に落ちる。
 * 画面描画のたびにストレージI/Oが走ると体感が悪いので、読み込んだコレクションは
 * メモリにキャッシュし、書き込み時にキャッシュとストレージの両方を更新する。
 */

export const STORAGE_PREFIX = 'nikkake:v1:';

const cache = new Map<string, unknown>();

export const storageKey = (name: string): string => `${STORAGE_PREFIX}${name}`;

export const readCollection = async <T>(name: string): Promise<T[]> => {
  const key = storageKey(name);
  if (cache.has(key)) {
    return cache.get(key) as T[];
  }

  const raw = await AsyncStorage.getItem(key);
  if (!raw) {
    cache.set(key, []);
    return [];
  }

  try {
    const parsed = JSON.parse(raw);
    const value = Array.isArray(parsed) ? (parsed as T[]) : [];
    cache.set(key, value);
    return value;
  } catch {
    // 壊れたJSONで起動不能になるのが最悪なので、握りつぶして空で復旧する
    cache.set(key, []);
    return [];
  }
};

export const writeCollection = async <T>(name: string, rows: T[]): Promise<void> => {
  const key = storageKey(name);
  cache.set(key, rows);
  await AsyncStorage.setItem(key, JSON.stringify(rows));
};

export const readObject = async <T>(name: string, fallback: T): Promise<T> => {
  const key = storageKey(name);
  if (cache.has(key)) {
    return cache.get(key) as T;
  }

  const raw = await AsyncStorage.getItem(key);
  if (!raw) {
    cache.set(key, fallback);
    return fallback;
  }

  try {
    const value = JSON.parse(raw) as T;
    cache.set(key, value);
    return value;
  } catch {
    cache.set(key, fallback);
    return fallback;
  }
};

export const writeObject = async <T>(name: string, value: T): Promise<void> => {
  const key = storageKey(name);
  cache.set(key, value);
  await AsyncStorage.setItem(key, JSON.stringify(value));
};

/** テストとサインアウト時のリセット用 */
export const clearAll = async (): Promise<void> => {
  const keys = await AsyncStorage.getAllKeys();
  const ours = keys.filter(k => k.startsWith(STORAGE_PREFIX));
  if (ours.length > 0) {
    await AsyncStorage.removeMany(ours);
  }
  cache.clear();
};

/** ストレージを直接書き換えた場合にキャッシュを捨てる（同期処理後など） */
export const invalidateCache = (): void => {
  cache.clear();
};

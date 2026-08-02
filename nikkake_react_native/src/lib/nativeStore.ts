import AsyncStorage from '@react-native-async-storage/async-storage';
import type { KeyValueStore } from '@nikkake/api-client';

/**
 * api-client が要求する同期の KeyValueStore を、AsyncStorage の上に作る。
 *
 * AsyncStorage は非同期なので、起動時に対象キーをメモリへ読み込んでおき、
 * 以降は読みをメモリ、書きをメモリ＋AsyncStorage（結果を待たない）にしている。
 *
 * これでいい理由: 保持しているのはトークンと送信待ちキューだけで、
 * どちらも「書いた直後に同じプロセスから読む」用途しかない。
 * プロセスをまたぐ整合性は hydrate 時に取れる。
 *
 * 逆に、ここを AsyncStorage の完了待ちにすると
 * OfflineQueue の同期APIが全部 async になり、記録の途中で await が挟まる。
 */

/** メモリに載せるキー。増やしたらここに足す */
const HYDRATED_KEYS = [
  'nikkake:v2:token',
  'nikkake:v2:queue',
  'nikkake:v2:queue_dead',
] as const;

const cache = new Map<string, string>();
let hydrated = false;

/** 起動時に1回だけ呼ぶ。呼ぶ前に読むと必ず null が返る */
export const hydrateNativeStore = async (): Promise<void> => {
  if (hydrated) return;

  try {
    const entries = await AsyncStorage.getMany([...HYDRATED_KEYS]);
    for (const [key, value] of Object.entries(entries)) {
      if (value !== null) cache.set(key, value);
    }
  } catch {
    // ストレージが読めなくてもアプリは起動させる。
    // トークンが無いものとして扱われ、匿名アカウントを作り直すだけで済む
  } finally {
    hydrated = true;
  }
};

export const isNativeStoreHydrated = (): boolean => hydrated;

export const nativeStore: KeyValueStore = {
  get: key => cache.get(key) ?? null,
  set: (key, value) => {
    cache.set(key, value);
    void AsyncStorage.setItem(key, value).catch(() => undefined);
  },
  remove: key => {
    cache.delete(key);
    void AsyncStorage.removeItem(key).catch(() => undefined);
  },
};

/** テスト用。プロセス内の状態を初期化する */
export const resetNativeStore = (): void => {
  cache.clear();
  hydrated = false;
};

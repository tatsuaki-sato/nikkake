/**
 * トークンとキャッシュの保管。
 * Web は localStorage、ネイティブは差し替える想定で口だけ切っておく。
 */
export interface KeyValueStore {
  get(key: string): string | null;
  set(key: string, value: string): void;
  remove(key: string): void;
}

export const memoryStore = (): KeyValueStore => {
  const map = new Map<string, string>();
  return {
    get: k => map.get(k) ?? null,
    set: (k, v) => void map.set(k, v),
    remove: k => void map.delete(k),
  };
};

export const browserStore = (): KeyValueStore => {
  try {
    if (typeof localStorage === 'undefined') return memoryStore();
    return {
      get: k => localStorage.getItem(k),
      set: (k, v) => localStorage.setItem(k, v),
      remove: k => localStorage.removeItem(k),
    };
  } catch {
    // プライベートブラウジングなどで localStorage が使えない環境
    return memoryStore();
  }
};

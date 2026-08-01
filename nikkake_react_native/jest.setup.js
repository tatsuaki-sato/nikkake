/**
 * 単体テストの共通セットアップ。
 *
 * データ層のテストはAsyncStorageを実際に読み書きするので、
 * インメモリの実装に差し替えてテスト間で状態が漏れないようにする。
 *
 * 変数名の `mock` プレフィックスは必須。jest.mock のファクトリは
 * それ以外の外部変数を参照できない（巻き上げ対策のガード）。
 */

const mockStorageMap = new Map();

jest.mock('@react-native-async-storage/async-storage', () => ({
  __esModule: true,
  default: {
    getItem: jest.fn(async key => (mockStorageMap.has(key) ? mockStorageMap.get(key) : null)),
    setItem: jest.fn(async (key, value) => {
      mockStorageMap.set(key, String(value));
    }),
    removeItem: jest.fn(async key => {
      mockStorageMap.delete(key);
    }),
    getMany: jest.fn(async keys =>
      Object.fromEntries(keys.map(k => [k, mockStorageMap.has(k) ? mockStorageMap.get(k) : null]))
    ),
    setMany: jest.fn(async entries => {
      for (const [key, value] of Object.entries(entries)) mockStorageMap.set(key, String(value));
    }),
    removeMany: jest.fn(async keys => {
      for (const key of keys) mockStorageMap.delete(key);
    }),
    getAllKeys: jest.fn(async () => Array.from(mockStorageMap.keys())),
    clear: jest.fn(async () => {
      mockStorageMap.clear();
    }),
  },
}));

// 通知はネイティブモジュールに触れるため、単体テストでは無効化する
jest.mock('expo-notifications', () => ({
  setNotificationHandler: jest.fn(),
  getPermissionsAsync: jest.fn(async () => ({ status: 'granted' })),
  requestPermissionsAsync: jest.fn(async () => ({ status: 'granted' })),
  scheduleNotificationAsync: jest.fn(async () => 'notification-id'),
  cancelScheduledNotificationAsync: jest.fn(async () => undefined),
  cancelAllScheduledNotificationsAsync: jest.fn(async () => undefined),
  getAllScheduledNotificationsAsync: jest.fn(async () => []),
  SchedulableTriggerInputTypes: { DAILY: 'daily', TIME_INTERVAL: 'timeInterval' },
  AndroidImportance: { DEFAULT: 3, HIGH: 4 },
  setNotificationChannelAsync: jest.fn(async () => undefined),
}));

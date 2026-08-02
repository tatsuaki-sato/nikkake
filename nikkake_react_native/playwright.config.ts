import { defineConfig, devices } from '@playwright/test';

/**
 * E2EはExpoのWebビルドに対して実行する。
 *
 * このアプリはサインイン不要でローカルストレージに保存する設計なので、
 * テスト側で認証をモックする必要はない。ブラウザコンテキストはテストごとに
 * 新規作成されるため、localStorageも毎回空＝初回起動の状態から始まる。
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['html'], ['list']] : 'list',

  use: {
    baseURL: 'http://localhost:8081',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  // Metroの初回バンドルは時間がかかるので、既定値より長めに取る
  timeout: 60_000,
  expect: { timeout: 15_000 },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'Mobile Chrome', use: { ...devices['Pixel 5'] } },
  ],

  webServer: {
    command: 'npx expo start --web --port 8081',
    // EXPO_PUBLIC_* はバンドル時に埋め込まれるので、
    // 同じスイートを local / server 両モードで走らせるにはここで渡す必要がある
    env: {
      EXPO_PUBLIC_BACKEND: process.env.EXPO_PUBLIC_BACKEND ?? 'local',
      EXPO_PUBLIC_API_ENDPOINT:
        process.env.EXPO_PUBLIC_API_ENDPOINT ?? 'http://localhost:3000/graphql',
    },
    url: 'http://localhost:8081',
    reuseExistingServer: false,
    timeout: 300_000,
    stdout: 'ignore',
    stderr: 'pipe',
  },
});

import { defineConfig, devices } from '@playwright/test';

/**
 * E2E は Rails と Vite の両方を立てて実行する。
 *
 * Rails は事前に別途起動しておく（DBが要るため）。
 *   cd nikkake_api && bin/rails s -p 3000
 *
 * Vite は webServer が自動で起動し、/graphql を Rails へプロキシする。
 * 同一オリジン扱いになるので httpOnly Cookie がそのまま効き、CORS も要らない。
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false, // 匿名アカウントが並列で増えると検証しにくいので直列
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: process.env.CI ? [['html'], ['list']] : 'list',

  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  timeout: 30_000,
  expect: { timeout: 10_000 },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'Mobile Chrome', use: { ...devices['Pixel 5'] } },
  ],

  webServer: {
    command: 'npx vite --port 5173',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: 'ignore',
    stderr: 'pipe',
  },
});

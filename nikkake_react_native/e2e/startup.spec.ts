import { test, expect } from '@playwright/test';
import { openApp } from './helpers';

/**
 * このアプリの一番の要件:
 * 「立ち上げたらすぐ、いつものルーティンができる」
 * ここが壊れたら他が全部通っても意味がないので、最初に検証する。
 */
test.describe('起動フロー', () => {
  test('サインインせずに起動でき、ログイン画面へ飛ばされない', async ({ page }) => {
    await openApp(page);

    await expect(page).toHaveURL(/localhost:8081\/?$/);
    await expect(page.getByTestId('login-screen')).toHaveCount(0);
  });

  test('初回起動でも今日のルーティンがすぐ用意されている', async ({ page }) => {
    await openApp(page);

    await expect(page.getByText('いつものルーティン')).toBeVisible();
    await expect(page.getByText('今日のルーティン')).toBeVisible();
  });

  test('初期ルーティンをタップするとその場でワークアウトが始まる', async ({ page }) => {
    await openApp(page);

    await page.getByText('いつものルーティン').click();

    await expect(page.getByTestId('workout-screen')).toBeVisible();
    await expect(page.getByTestId('workout-exercise-name')).toContainText('腕立て伏せ');
  });

  test('ストリークが0日から表示される', async ({ page }) => {
    await openApp(page);

    await expect(page.getByTestId('streak-banner')).toBeVisible();
    await expect(page.getByTestId('streak-count')).toHaveText('0 日');
  });

  test('リロードしてもデータが残る', async ({ page }) => {
    await openApp(page);
    await expect(page.getByText('いつものルーティン')).toBeVisible();

    await page.reload();
    await expect(page.getByTestId('home-screen')).toBeVisible({ timeout: 30_000 });

    // 再シードで重複していないこと
    await expect(page.getByText('いつものルーティン')).toHaveCount(1);
  });
});

import { test, expect, type Page } from '@playwright/test';

/**
 * このアプリの一番の要件:
 * 「立ち上げたらすぐ、いつものルーティンができる」
 *
 * サーバ主導へ移行してもここが守れていることを、まず確認する。
 * 匿名アカウントはサーバが自動発行するので、ログイン画面は一切出ない。
 */

/** localStorage を消して初回訪問の状態に戻す */
const freshVisit = async (page: Page) => {
  await page.goto('/');
  await page.evaluate(() => {
    Object.keys(localStorage)
      .filter(k => k.startsWith('nikkake:'))
      .forEach(k => localStorage.removeItem(k));
  });
  await page.reload();
  await expect(page.getByTestId('home-screen')).toBeVisible({ timeout: 20_000 });
};

const openTab = (page: Page, label: string) => page.getByRole('tab', { name: label }).click();

test.describe('起動フロー', () => {
  test('サインインせずに起動でき、ログイン画面が出ない', async ({ page }) => {
    await freshVisit(page);

    await expect(page.getByTestId('home-screen')).toBeVisible();
    // 起動導線にログイン画面は存在しない
    await expect(page.getByText('サインイン', { exact: true })).toHaveCount(0);
    await expect(page.getByText('パスワード', { exact: true })).toHaveCount(0);
  });

  test('匿名アカウントがサーバから自動発行される', async ({ page }) => {
    await freshVisit(page);

    const token = await page.evaluate(() => localStorage.getItem('nikkake:v2:token'));
    expect(token).toBeTruthy();
    // 端末IDから導出しない 256bit のランダム値
    expect(token!.length).toBe(43);
  });

  test('ストリークが0日から表示される', async ({ page }) => {
    await freshVisit(page);

    await expect(page.getByTestId('streak-banner')).toBeVisible();
    await expect(page.getByTestId('streak-count')).toHaveText('0 日');
  });

  test('リロードしても同じアカウントが使われる', async ({ page }) => {
    await freshVisit(page);
    const first = await page.evaluate(() => localStorage.getItem('nikkake:v2:token'));

    await page.reload();
    await expect(page.getByTestId('home-screen')).toBeVisible();
    const second = await page.evaluate(() => localStorage.getItem('nikkake:v2:token'));

    expect(second).toBe(first);
  });

  test('設定でアカウント未登録と表示され、登録導線がある', async ({ page }) => {
    await freshVisit(page);
    await openTab(page, '設定');

    await expect(page.getByTestId('settings-anonymous-card')).toBeVisible();
    await expect(page.getByTestId('settings-attach-email')).toBeVisible();
    await expect(page.getByTestId('count-exercises')).toHaveText('25');
  });
});

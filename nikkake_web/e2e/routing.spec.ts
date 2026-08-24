import { test, expect, type Page } from '@playwright/test';

/** localStorage を消して初回訪問の状態に戻す */
const freshVisit = async (page: Page, path = '/') => {
  await page.goto(path);
  await page.evaluate(() => {
    Object.keys(localStorage)
      .filter(k => k.startsWith('nikkake:'))
      .forEach(k => localStorage.removeItem(k));
  });
  await page.reload();
  await expect(page.getByTestId('home-screen')).toBeVisible({ timeout: 20_000 });
};

/**
 * URLで各画面を直接指定できること。
 * リロードや直接アクセスでも同じ画面が開く必要があるため、Renderの
 * 静的サイトホスティング側でも `public/_redirects` によるSPA rewriteが要る。
 */
test.describe('URLによる画面遷移', () => {
  test('各タブのURLを直接開ける', async ({ page }) => {
    await freshVisit(page);

    await page.goto('/routines');
    await expect(page.getByTestId('routines-screen')).toBeVisible();

    await page.goto('/progress');
    await expect(page.getByTestId('progress-empty')).toBeVisible();

    await page.goto('/settings');
    await expect(page.getByTestId('settings-anonymous-card')).toBeVisible();

    await page.goto('/');
    await expect(page.getByTestId('home-screen')).toBeVisible();
  });

  test('/routines/new を直接開くとルーティン作成フォームが開く', async ({ page }) => {
    await freshVisit(page);
    await page.goto('/routines/new');
    await expect(page.getByTestId('routine-form')).toBeVisible();
    await expect(page.getByTestId('routine-name-input')).toHaveValue('');
  });

  test('タブをクリックするとURLが変わり、ブラウザの戻るで前の画面に戻れる', async ({ page }) => {
    await freshVisit(page);

    await page.getByRole('tab', { name: 'ルーティン' }).click();
    await expect(page).toHaveURL(/\/routines$/);

    await page.getByRole('tab', { name: '進捗' }).click();
    await expect(page).toHaveURL(/\/progress$/);

    await page.goBack();
    await expect(page).toHaveURL(/\/routines$/);

    await page.goBack();
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByTestId('home-screen')).toBeVisible();
  });
});

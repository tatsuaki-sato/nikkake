import { test, expect, type Page } from '@playwright/test';

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

const createRoutine = async (page: Page, name: string) => {
  await openTab(page, 'ルーティン');
  await page.getByTestId('routines-fab').click();
  await page.getByTestId('routine-name-input').fill(name);
  await page.getByTestId('add-exercise-button').click();
  await page.getByTestId('exercise-picker').getByText('スクワット').first().click();
  await page.getByTestId('routine-submit').click();
  await expect(page.getByTestId('routines-screen')).toBeVisible();
};

test.describe('ルーティンの並び替え', () => {
  test.beforeEach(async ({ page }) => {
    await freshVisit(page);
  });

  test('▲▼で並び替えると、ホームの表示順とリロード後も反映される', async ({ page }) => {
    await createRoutine(page, 'ルーティンB');

    // 作成直後は「いつものルーティン」→「ルーティンB」の順
    const names = () => page.locator('[data-testid=routines-list] .routine-card__name').allTextContents();
    await expect.poll(names).toEqual([ 'いつものルーティン', 'ルーティンB' ]);

    // 「ルーティンB」を上へ移動
    const rows = await page.locator('[data-testid^=routine-row-]').all();
    const bRowId = await rows[1].getAttribute('data-testid');
    const bId = bRowId!.replace('routine-row-', '');
    await page.getByTestId(`routine-move-up-${bId}`).click();

    await expect.poll(names).toEqual([ 'ルーティンB', 'いつものルーティン' ]);

    // リロードしてもサーバ側の並びが反映されている
    await page.reload();
    await page.waitForSelector('[data-testid=routines-list]');
    await expect.poll(names).toEqual([ 'ルーティンB', 'いつものルーティン' ]);

    // ホーム側の表示順にも反映される
    await openTab(page, 'ホーム');
    await expect(page.getByTestId('home-screen')).toBeVisible();
    const homeNames = () => page.locator('.routine-card__name').allTextContents();
    await expect.poll(homeNames).toContain('ルーティンB');
    const resolved = await homeNames();
    expect(resolved[0]).toBe('ルーティンB');
  });
});

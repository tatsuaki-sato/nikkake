import { test, expect, Page } from '@playwright/test';
import { openApp, openTab } from './helpers';

const homeScreen = (page: Page) => page.getByTestId('home-screen');

/** ワークアウトを1回やりきって記録を作る */
const recordOneWorkout = async (page: Page, weight = '50') => {
  await homeScreen(page).getByText('いつものルーティン').click();
  await expect(page.getByTestId('workout-screen')).toBeVisible();

  await page.getByTestId('set-weight-0-1').fill(weight);
  await page.getByTestId('set-check-0-1').click();

  await page.getByTestId('workout-finish').click();
  await expect(page.getByTestId('summary-screen')).toBeVisible();
  await page.getByTestId('summary-home').click();
  await expect(homeScreen(page)).toBeVisible();
};

test.describe('進捗', () => {
  test.beforeEach(async ({ page }) => {
    await openApp(page);
  });

  test('記録が無いうちは空状態を出す', async ({ page }) => {
    await openTab(page, '進捗');

    await expect(page.getByTestId('progress-empty')).toBeVisible();
    await expect(page.getByTestId('progress-empty')).toContainText('まだ記録がありません');
  });

  test('1回記録すると集計・グラフ・カレンダーが出る', async ({ page }) => {
    await recordOneWorkout(page);
    await openTab(page, '進捗');

    await expect(page.getByTestId('progress-total')).toHaveText('1回');
    await expect(page.getByTestId('progress-week')).toHaveText('1回');
    await expect(page.getByTestId('progress-streak')).toHaveText('1日');
    await expect(page.getByTestId('progress-chart')).toBeVisible();
    await expect(page.getByTestId('progress-calendar')).toBeVisible();
  });

  test('表示期間を7日と30日で切り替えられる', async ({ page }) => {
    await recordOneWorkout(page);
    await openTab(page, '進捗');

    await page.getByTestId('progress-range-30').click();
    await expect(page.getByTestId('progress-chart')).toBeVisible();

    await page.getByTestId('progress-range-7').click();
    await expect(page.getByTestId('progress-chart')).toBeVisible();
  });

  test('種目ごとの推移に記録した重量が出る', async ({ page }) => {
    await recordOneWorkout(page, '47');
    await openTab(page, '進捗');

    const detail = page.getByTestId('progress-exercise-detail');
    await expect(detail).toBeVisible();
    await expect(detail).toContainText('47kg');
  });

  test('カレンダーの日をタップするとその日のワークアウト内容が出る', async ({ page }) => {
    await recordOneWorkout(page, '48');
    await openTab(page, '進捗');

    const today = new Date();
    const iso = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

    await page.getByTestId(`calendar-day-${iso}`).click();
    const detail = page.getByTestId('progress-day-detail');
    await expect(detail).toBeVisible();
    await expect(detail).toContainText('いつものルーティン');
    await expect(detail).toContainText('腕立て伏せ');
    await expect(detail).toContainText('48×10');
  });

  test('カレンダーは前月へめくれる', async ({ page }) => {
    await recordOneWorkout(page);
    await openTab(page, '進捗');

    const now = new Date();
    const label = (d: Date) => d.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long' });
    const calendar = page.getByTestId('progress-calendar');

    await expect(calendar).toContainText(label(now));
    await expect(page.getByTestId('calendar-next')).toBeDisabled();

    await page.getByTestId('calendar-prev').click();
    await expect(calendar).toContainText(label(new Date(now.getFullYear(), now.getMonth() - 1, 1)));
    await expect(page.getByTestId('calendar-next')).toBeEnabled();
  });

  test('記録した種目だけが選択肢に出る', async ({ page }) => {
    await recordOneWorkout(page);
    await openTab(page, '進捗');

    // 1種目目(腕立て伏せ)だけ記録したので、それだけが並ぶ
    await expect(page.locator('[data-testid^="progress-exercise-"]').filter({ hasText: '腕立て伏せ' })).toHaveCount(1);
    await expect(page.locator('[data-testid^="progress-exercise-"]').filter({ hasText: 'プランク' })).toHaveCount(0);
  });
});

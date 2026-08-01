import { test, expect, Page } from '@playwright/test';
import { openApp, openTab, acceptDialogs } from './helpers';

/**
 * expo-router のWeb実装ではタブを切り替えても前の画面のDOMが残る。
 * そのため画面をまたいで同じ文字列が複数ヒットしうるので、
 * 必ず画面コンテナのtestIDでスコープを切ってから探す。
 */
const routinesScreen = (page: Page) => page.getByTestId('routines-screen');
const homeScreen = (page: Page) => page.getByTestId('home-screen');

test.describe('ルーティン管理', () => {
  test.beforeEach(async ({ page }) => {
    await openApp(page);
    await openTab(page, 'ルーティン');
    await expect(routinesScreen(page)).toBeVisible();
  });

  test('初期ルーティンが一覧に出る', async ({ page }) => {
    await expect(page.getByTestId('routines-list')).toBeVisible();
    await expect(routinesScreen(page).getByText('いつものルーティン')).toBeVisible();
  });

  test('名前が空だと作成できずエラーが出る', async ({ page }) => {
    await page.getByTestId('routines-fab').click();
    await expect(page.getByTestId('routine-form')).toBeVisible();

    await page.getByTestId('routine-submit').click();

    await expect(page.getByTestId('error-message')).toContainText('ルーティン名');
    // フォームが開いたまま = 保存されていない
    await expect(page.getByTestId('routine-form')).toBeVisible();
  });

  test('種目が空だと作成できない', async ({ page }) => {
    await page.getByTestId('routines-fab').click();
    await page.getByTestId('routine-name-input').fill('種目なしルーティン');

    await page.getByTestId('routine-submit').click();

    await expect(page.getByTestId('error-message')).toContainText('種目');
  });

  test('曜日指定で曜日未選択だと作成できない', async ({ page }) => {
    await page.getByTestId('routines-fab').click();
    await page.getByTestId('routine-name-input').fill('週次ルーティン');
    await page.getByTestId('frequency-weekly').click();

    await page.getByTestId('add-exercise-button').click();
    await page.getByTestId('exercise-picker').getByText('スクワット').click();

    await page.getByTestId('routine-submit').click();

    await expect(page.getByTestId('error-message')).toContainText('曜日');
  });

  test('ルーティンを新規作成すると一覧とホームに出る', async ({ page }) => {
    await page.getByTestId('routines-fab').click();

    await page.getByTestId('routine-name-input').fill('夜の腹筋メニュー');
    await page.getByTestId('add-exercise-button').click();
    await page.getByTestId('exercise-picker').getByText('プランク').click();

    await expect(page.getByTestId('exercise-row-0')).toContainText('プランク');

    await page.getByTestId('routine-submit').click();

    await expect(routinesScreen(page).getByText('夜の腹筋メニュー')).toBeVisible();

    await openTab(page, 'ホーム');
    await expect(homeScreen(page).getByText('夜の腹筋メニュー')).toBeVisible();
  });

  test('種目の並び替えと削除ができる', async ({ page }) => {
    await page.getByTestId('routines-fab').click();
    await page.getByTestId('routine-name-input').fill('並び替えテスト');

    await page.getByTestId('add-exercise-button').click();
    await page.getByTestId('exercise-picker').getByText('スクワット').click();
    await page.getByTestId('add-exercise-button').click();
    await page.getByTestId('exercise-picker').getByText('プランク').click();

    await expect(page.getByTestId('exercise-row-0')).toContainText('スクワット');
    await expect(page.getByTestId('exercise-row-1')).toContainText('プランク');

    await page.getByTestId('exercise-down-0').click();
    await expect(page.getByTestId('exercise-row-0')).toContainText('プランク');

    await page.getByTestId('exercise-remove-1').click();
    await expect(page.getByTestId('exercise-row-1')).toHaveCount(0);
  });

  test('既存ルーティンを編集すると内容が保存される', async ({ page }) => {
    await page.locator('[data-testid^="routine-edit-"]').first().click();
    await expect(page.getByTestId('routine-form')).toBeVisible();

    await page.getByTestId('routine-name-input').fill('朝の全身メニュー');
    await page.getByTestId('routine-submit').click();

    await expect(routinesScreen(page).getByText('朝の全身メニュー')).toBeVisible();
    await expect(routinesScreen(page).getByText('いつものルーティン')).toHaveCount(0);
  });

  test('編集画面から削除できる', async ({ page }) => {
    acceptDialogs(page);

    await page.locator('[data-testid^="routine-edit-"]').first().click();
    await page.getByTestId('routine-delete').click();

    await expect(page.getByTestId('routines-empty')).toBeVisible();
  });

  test('一覧から削除できる', async ({ page }) => {
    acceptDialogs(page);

    await expect(routinesScreen(page).getByText('いつものルーティン')).toBeVisible();
    await page.locator('[data-testid^="routine-delete-"]').first().click();

    await expect(page.getByTestId('routines-empty')).toBeVisible();
    await expect(routinesScreen(page).getByText('いつものルーティン')).toHaveCount(0);
  });

  test('停止したルーティンはホームに出ない', async ({ page }) => {
    await page.locator('[data-testid^="routine-toggle-"]').first().click();
    await expect(routinesScreen(page).getByText('停止中')).toBeVisible();

    await openTab(page, 'ホーム');
    await expect(page.getByTestId('home-empty')).toBeVisible();
  });
});

import { test, expect, Page } from '@playwright/test';
import { openApp, openTab, acceptDialogs } from './helpers';

const homeScreen = (page: Page) => page.getByTestId('home-screen');

/** 初期ルーティンを開始して、ワークアウト画面が出るまで待つ */
const startWorkout = async (page: Page) => {
  await homeScreen(page).getByText('いつものルーティン').click();
  await expect(page.getByTestId('workout-screen')).toBeVisible();
};

/** 現在の種目の全セットを完了にする */
const completeCurrentExercise = async (page: Page) => {
  const checks = page.locator('[data-testid^="set-check-"]');
  const count = await checks.count();
  for (let i = 0; i < count; i++) {
    await checks.nth(i).click();
  }
};

test.describe('ワークアウト実行', () => {
  test.beforeEach(async ({ page }) => {
    await openApp(page);
  });

  test('ホームから開始でき、1種目目が表示される', async ({ page }) => {
    await startWorkout(page);

    await expect(page.getByTestId('workout-exercise-name')).toContainText('1/4');
    await expect(page.getByTestId('workout-exercise-name')).toContainText('腕立て伏せ');
    await expect(page.getByTestId('workout-elapsed')).toBeVisible();
  });

  test('セットを完了にすると休憩タイマーが自動で始まる', async ({ page }) => {
    await startWorkout(page);

    await expect(page.getByTestId('rest-timer')).toHaveCount(0);
    await page.getByTestId('set-check-0-1').click();

    await expect(page.getByTestId('rest-timer')).toBeVisible();
    await expect(page.getByTestId('rest-timer')).toContainText('休憩中');
  });

  test('休憩タイマーはタップでスキップできる', async ({ page }) => {
    await startWorkout(page);
    await page.getByTestId('set-check-0-1').click();
    await expect(page.getByTestId('rest-timer')).toBeVisible();

    await page.getByTestId('rest-timer').click();
    await expect(page.getByTestId('rest-timer')).toHaveCount(0);
  });

  test('重量と回数を入力できる', async ({ page }) => {
    await startWorkout(page);

    await page.getByTestId('set-weight-0-1').fill('42');
    await page.getByTestId('set-reps-0-1').fill('12');

    await expect(page.getByTestId('set-weight-0-1')).toHaveValue('42');
    await expect(page.getByTestId('set-reps-0-1')).toHaveValue('12');
  });

  test('セットを増減できる', async ({ page }) => {
    await startWorkout(page);

    await expect(page.locator('[data-testid^="set-row-0-"]')).toHaveCount(3);

    await page.getByTestId('add-set').click();
    await expect(page.locator('[data-testid^="set-row-0-"]')).toHaveCount(4);

    await page.getByTestId('remove-set').click();
    await expect(page.locator('[data-testid^="set-row-0-"]')).toHaveCount(3);
  });

  test('種目を移動できる', async ({ page }) => {
    await startWorkout(page);

    await page.getByTestId('workout-next').click();
    await expect(page.getByTestId('workout-exercise-name')).toContainText('2/4');
    await expect(page.getByTestId('workout-exercise-name')).toContainText('スクワット');

    await page.getByTestId('workout-prev').click();
    await expect(page.getByTestId('workout-exercise-name')).toContainText('1/4');
  });

  test('種目タブから直接ジャンプできる', async ({ page }) => {
    await startWorkout(page);

    await page.getByTestId('workout-tab-3').click();
    await expect(page.getByTestId('workout-exercise-name')).toContainText('4/4');
    await expect(page.getByTestId('workout-exercise-name')).toContainText('プランク');
  });

  test('時間種目は秒数の入力欄になる', async ({ page }) => {
    await startWorkout(page);
    await page.getByTestId('workout-tab-3').click(); // プランク

    await expect(page.getByTestId('set-duration-3-1')).toBeVisible();
    await expect(page.getByTestId('set-reps-3-1')).toHaveCount(0);
  });

  test('全セット完了して終わるとサマリーが出る', async ({ page }) => {
    await startWorkout(page);

    for (let i = 0; i < 4; i++) {
      await page.getByTestId(`workout-tab-${i}`).click();
      await completeCurrentExercise(page);
    }

    await page.getByTestId('workout-finish').click();

    await expect(page.getByTestId('summary-screen')).toBeVisible();
    await expect(page.getByTestId('summary-status')).toHaveText('コンプリート！');
    await expect(page.getByTestId('summary-sets')).toHaveText('11/11');
    await expect(page.getByTestId('summary-streak')).toHaveText('1 日');
  });

  test('一部だけ完了した場合は途中記録として保存される', async ({ page }) => {
    await startWorkout(page);

    await page.getByTestId('set-check-0-1').click();
    await page.getByTestId('workout-finish').click();

    await expect(page.getByTestId('summary-status')).toHaveText('記録しました');
    await expect(page.getByTestId('summary-sets')).toHaveText('1/11');
  });

  test('完了後にホームへ戻ると完了扱いになり、ストリークが増える', async ({ page }) => {
    await startWorkout(page);
    await completeCurrentExercise(page);
    await page.getByTestId('workout-finish').click();

    await expect(page.getByTestId('summary-screen')).toBeVisible();
    await page.getByTestId('summary-home').click();

    await expect(homeScreen(page)).toBeVisible();
    await expect(homeScreen(page).getByText('今日は完了しました')).toBeVisible();
    await expect(page.getByTestId('streak-count')).toHaveText('1 日');
  });

  test('中断すると記録が残らない', async ({ page }) => {
    acceptDialogs(page);

    await startWorkout(page);
    await page.getByTestId('set-check-0-1').click();
    await page.getByTestId('workout-cancel').click();

    await expect(homeScreen(page)).toBeVisible();
    await expect(page.getByTestId('streak-count')).toHaveText('0 日');

    await openTab(page, '進捗');
    await expect(page.getByTestId('progress-empty')).toBeVisible();
  });

  test('前回の記録が次回の初期値になる', async ({ page }) => {
    await startWorkout(page);
    await page.getByTestId('set-weight-0-1').fill('37');
    await page.getByTestId('set-check-0-1').click();
    await page.getByTestId('workout-finish').click();
    await page.getByTestId('summary-home').click();

    await startWorkout(page);

    await expect(page.getByTestId('set-weight-0-1')).toHaveValue('37');
    await expect(page.getByTestId('workout-previous-hint')).toContainText('前回');
  });

  test('リロードしても記録は消えない', async ({ page }) => {
    await startWorkout(page);
    await completeCurrentExercise(page);
    await page.getByTestId('workout-finish').click();
    await page.getByTestId('summary-home').click();

    await page.reload();
    await expect(homeScreen(page)).toBeVisible({ timeout: 30_000 });

    await expect(page.getByTestId('streak-count')).toHaveText('1 日');
  });
});

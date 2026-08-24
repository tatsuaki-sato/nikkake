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

test.describe('ワークアウト', () => {
  test.beforeEach(async ({ page }) => {
    await freshVisit(page);
  });

  test('タップ・クリック無しで、ホームを開いた瞬間から全種目のチェック欄が見える', async ({ page }) => {
    await expect(page.getByTestId('workout-screen')).toBeVisible();
    await expect(page.getByTestId('workout-exercise-name-0')).toContainText('1/4');
    await expect(page.getByTestId('workout-exercise-name-0')).toContainText('腕立て伏せ');

    // 4種目目まで、タブ切り替え無しでスクロールだけで見える
    await expect(page.getByTestId('workout-exercise-name-3')).toContainText('プランク');
    await expect(page.getByTestId('set-check-3-1')).toBeVisible();
  });

  test('タイマーは「開始」を押すまで進まず、一時停止できる', async ({ page }) => {
    await expect(page.getByTestId('workout-elapsed')).toHaveText('0:00');
    await page.waitForTimeout(1200);
    await expect(page.getByTestId('workout-elapsed')).toHaveText('0:00');

    await page.getByTestId('workout-timer-toggle').click();
    await page.waitForTimeout(1200);
    await expect(page.getByTestId('workout-elapsed')).not.toHaveText('0:00');

    await page.getByTestId('workout-timer-toggle').click();
    const pausedAt = await page.getByTestId('workout-elapsed').textContent();
    await page.waitForTimeout(1200);
    await expect(page.getByTestId('workout-elapsed')).toHaveText(pausedAt ?? '');
  });

  test('セットを完了にすると休憩タイマーが自動で始まる', async ({ page }) => {
    await page.getByTestId('workout-timer-toggle').click();
    await expect(page.getByTestId('rest-timer')).toHaveCount(0);
    await page.getByTestId('set-check-0-1').click();
    await expect(page.getByTestId('rest-timer')).toBeVisible();

    // タップでスキップできる
    await page.getByTestId('rest-timer').click();
    await expect(page.getByTestId('rest-timer')).toHaveCount(0);
  });

  test('時間計測の種目は秒の入力欄になる', async ({ page }) => {
    await expect(page.getByTestId('set-duration-3-1')).toBeVisible();
    await expect(page.getByTestId('set-reps-3-1')).toHaveCount(0);
  });

  test('有酸素・ゲーム系の種目は重量(kg)欄が無い', async ({ page }) => {
    // 「いつものルーティン」は全部ジム系(STRENGTH)なので、重量欄が出ている
    await expect(page.getByTestId('set-weight-0-1')).toBeVisible();

    // ゲーム系(Just Dance)の種目を持つルーティンを作ると、重量欄が無い
    await openTab(page, 'ルーティン');
    await page.getByTestId('routines-fab').click();
    await page.getByTestId('routine-name-input').fill('ゲームで運動');
    await page.getByTestId('add-exercise-button').click();
    await page.getByTestId('exercise-picker').getByText('Just Dance').click();
    await page.getByTestId('routine-submit').click();
    await expect(page.getByTestId('routines-screen')).toBeVisible();

    await openTab(page, 'ホーム');
    await expect(page.getByText('ゲームで運動')).toBeVisible();
    // このルーティンには種目が1つだけなので、そのWorkoutの中ではindex 0。
    // 重量欄が無い分、set-weight-0-1は「いつものルーティン」側の1つだけになる
    await expect(page.getByTestId('set-duration-0-1')).toBeVisible();
    await expect(page.getByTestId('set-weight-0-1')).toHaveCount(1);
  });

  test('セットを増減できる。1本未満にはならない', async ({ page }) => {
    await expect(page.locator('[data-testid^="set-row-0-"]')).toHaveCount(3);
    await page.getByTestId('add-set-0').click();
    await expect(page.locator('[data-testid^="set-row-0-"]')).toHaveCount(4);

    for (let i = 0; i < 5; i++) await page.getByTestId('remove-set-0').click();
    await expect(page.locator('[data-testid^="set-row-0-"]')).toHaveCount(1);
  });

  test('休憩タイマーは操作した種目自身の休憩時間を使う', async ({ page }) => {
    await expect(page.getByTestId('rest-timer')).toHaveCount(0);
    await page.getByTestId('set-check-3-1').click(); // プランク（先頭ではない種目）
    await expect(page.getByTestId('rest-timer')).toBeVisible();
  });

  test('記録すると、別画面へ飛ばずその場に結果が出て、ホームで完了扱いになる', async ({ page }) => {
    await page.getByTestId('set-weight-0-1').fill('42');
    await page.getByTestId('set-check-0-1').click();
    await page.getByTestId('workout-finish').click();

    // 別画面へは飛ばない。ホームのまま
    await expect(page.getByTestId('home-screen')).toBeVisible();
    // 全セットではないので PARTIAL
    await expect(page.getByTestId('workout-result')).toBeVisible();
    await expect(page.getByTestId('workout-result-status')).toContainText('記録しました');
    await expect(page.getByTestId('workout-result-sets')).toContainText('1/11セット');

    await expect(page.getByText('今日は完了しました')).toBeVisible();
    await expect(page.getByTestId('streak-count')).toHaveText('1 日');
  });

  test('前回の記録が次回の初期値になる（サーバが解決する）', async ({ page }) => {
    await page.getByTestId('set-weight-0-1').fill('37');
    await page.getByTestId('set-check-0-1').click();
    await page.getByTestId('workout-finish').click();

    await expect(page.getByTestId('set-weight-0-1')).toHaveValue('37');
    await expect(page.getByTestId('workout-previous-hint-0')).toContainText('前回');
  });

  test('記録は進捗画面に反映される', async ({ page }) => {
    await openTab(page, '進捗');
    await expect(page.getByTestId('progress-empty')).toBeVisible();

    await openTab(page, 'ホーム');
    await page.getByTestId('set-check-0-1').click();
    await page.getByTestId('workout-finish').click();

    await openTab(page, '進捗');
    await expect(page.getByTestId('progress-total')).toHaveText('1回');
    await expect(page.getByTestId('progress-streak')).toHaveText('1日');
    await expect(page.getByTestId('progress-chart')).toBeVisible();
    await expect(page.getByTestId('progress-calendar')).toBeVisible();
  });
});

test.describe('オフライン記録', () => {
  test('圏外でも記録でき、復帰時に送信される', async ({ page, context }) => {
    await freshVisit(page);
    await page.getByTestId('set-check-0-1').click();

    // ここから圏外
    await context.setOffline(true);
    await page.getByTestId('workout-finish').click();

    // サーバが集計できないので結果はオフライン表示になる
    await expect(page.getByTestId('workout-result')).toContainText('オフラインのため');

    // キューに1件溜まっている
    const pending = await page.evaluate(() => {
      const raw = localStorage.getItem('nikkake:v2:queue');
      return raw ? JSON.parse(raw).length : 0;
    });
    expect(pending).toBe(1);

    // オンラインへ復帰すると送信される
    // （setOfflineの解除がブラウザのネットワーク層に反映されるまで一瞬かかることがある）
    await context.setOffline(false);
    await page.waitForTimeout(300);
    await page.reload();
    await expect(page.getByTestId('home-screen')).toBeVisible({ timeout: 20_000 });

    await expect(page.getByText('今日は完了しました')).toBeVisible();
    await expect(page.getByTestId('streak-count')).toHaveText('1 日');

    const remaining = await page.evaluate(() => {
      const raw = localStorage.getItem('nikkake:v2:queue');
      return raw ? JSON.parse(raw).length : 0;
    });
    expect(remaining).toBe(0);
  });
});

/**
 * オフラインで何ができて何ができないか。
 *
 * 記録はできる（キューに積む）が、ルーティンの作成・編集はできない。
 * 圏外で作れると、サーバの採番や検証を通っていないルーティンに対して
 * 記録が積まれ、整合を取る手段が無くなるため。
 * これは移行で失った機能なので、仕様として固定しておく。
 */
test.describe('オフラインでのルーティン作成', () => {
  test('圏外では保存できず、理由が出る。入力は消えない', async ({ page, context }) => {
    await freshVisit(page);

    await openTab(page, 'ルーティン');
    await page.getByTestId('routines-fab').click();
    await page.getByTestId('routine-name-input').fill('圏外で作ろうとしたルーティン');
    await page.getByTestId('add-exercise-button').click();
    await page.getByTestId('exercise-picker').getByText('スクワット').first().click();

    await context.setOffline(true);
    await page.getByTestId('routine-submit').click();

    await expect(page.getByTestId('error-message')).toContainText('オフラインのため保存できません');

    // 保存ボタンが押せる状態に戻っていること（「保存中…」で固まらない）
    await expect(page.getByTestId('routine-submit')).toBeEnabled();
    // 入力し直しにならないこと
    await expect(page.getByTestId('routine-name-input')).toHaveValue('圏外で作ろうとしたルーティン');

    // 復帰したら保存できる
    await context.setOffline(false);
    await page.getByTestId('routine-submit').click();

    await expect(page.getByTestId('routines-screen')).toContainText('圏外で作ろうとしたルーティン');
  });
});

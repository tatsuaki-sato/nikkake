import { test, expect } from '@playwright/test';
import { openApp, openTab, acceptDialogs } from './helpers';

test.describe('設定とデータの保存先', () => {
  test.beforeEach(async ({ page }) => {
    await openApp(page);
    await openTab(page, '設定');
    await expect(page.getByTestId('settings-screen')).toBeVisible();
  });

  test('未サインインでは端末保存中と表示され、バックアップは任意だと分かる', async ({ page }) => {
    const card = page.getByTestId('settings-local-card');

    await expect(card).toBeVisible();
    await expect(card).toContainText('この端末にだけ保存中');
    await expect(card).toContainText('サインインしなくても全機能が使えます');
    await expect(page.getByTestId('settings-enable-backup')).toBeVisible();
  });

  test('保存されているデータの件数が出る', async ({ page }) => {
    await expect(page.getByTestId('count-routines')).toHaveText('1');
    await expect(page.getByTestId('count-exercises')).toHaveText('25');
    await expect(page.getByTestId('count-logs')).toHaveText('0');
  });

  test('バックアップを有効にするとサインイン画面が開く', async ({ page }) => {
    await page.getByTestId('settings-enable-backup').click();

    await expect(page.getByTestId('login-screen')).toBeVisible();
    await expect(page.getByTestId('login-optional-notice')).toContainText('サインインは任意です');
  });

  test('サインイン画面はあとで設定するで閉じられる', async ({ page }) => {
    await page.getByTestId('settings-enable-backup').click();
    await expect(page.getByTestId('login-screen')).toBeVisible();

    await page.getByTestId('login-skip').click();
    await expect(page.getByTestId('settings-screen')).toBeVisible();
  });

  test('未入力のままサインインしようとするとエラーになる', async ({ page }) => {
    await page.getByTestId('settings-enable-backup').click();
    await page.getByTestId('login-submit').click();

    await expect(page.getByTestId('error-message')).toContainText('メールアドレスとパスワード');
  });

  test('アカウント作成画面に進める', async ({ page }) => {
    await page.getByTestId('settings-enable-backup').click();
    await page.getByTestId('login-to-register').click();

    await expect(page.getByTestId('register-screen')).toBeVisible();
  });

  test('パスワードが短いとアカウントを作れない', async ({ page }) => {
    await page.getByTestId('settings-enable-backup').click();
    await page.getByTestId('login-to-register').click();

    await page.getByTestId('register-email').fill('test@example.com');
    await page.getByTestId('register-password').fill('123');
    await page.getByTestId('register-submit').click();

    await expect(page.getByTestId('error-message')).toContainText('6文字以上');
  });

  test('データを初期化すると初期状態に戻る', async ({ page }) => {
    acceptDialogs(page);

    // ルーティンを増やしてから初期化する
    await openTab(page, 'ルーティン');
    await page.getByTestId('routines-fab').click();
    await page.getByTestId('routine-name-input').fill('消えるはずのルーティン');
    await page.getByTestId('add-exercise-button').click();
    await page.getByTestId('exercise-picker').getByText('スクワット').click();
    await page.getByTestId('routine-submit').click();
    await expect(page.getByTestId('routines-screen').getByText('消えるはずのルーティン')).toBeVisible();

    await openTab(page, '設定');
    await expect(page.getByTestId('count-routines')).toHaveText('2');

    await page.getByTestId('settings-reset').click();

    await expect(page.getByTestId('count-routines')).toHaveText('1');

    await openTab(page, 'ルーティン');
    await expect(page.getByTestId('routines-screen').getByText('消えるはずのルーティン')).toHaveCount(0);
    await expect(page.getByTestId('routines-screen').getByText('いつものルーティン')).toBeVisible();
  });
});

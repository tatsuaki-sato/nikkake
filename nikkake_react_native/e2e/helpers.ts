import { Page, expect } from '@playwright/test';

/**
 * E2E共通のヘルパー。
 * このアプリはログインを必要としないので、認証のセットアップは一切無い。
 */

/** アプリを開いて、初期化（シード投入）が終わるまで待つ */
export const openApp = async (page: Page, path = '/') => {
  await page.goto(path);
  // ブートストラップ中はスピナーだけが出るので、ホームが描画されるまで待つ
  await expect(page.getByTestId('home-screen')).toBeVisible({ timeout: 30_000 });
};

/**
 * タブバーの項目を開く。
 * expo-router のWeb実装ではタブは `<a role="tab">` として描画される。
 */
export const openTab = async (page: Page, label: string) => {
  await page.getByRole('tab', { name: label }).click();
};

/** 保存済みデータを消して初回起動状態に戻す */
export const clearStorage = async (page: Page) => {
  await page.evaluate(() => {
    Object.keys(window.localStorage)
      .filter(k => k.startsWith('nikkake:'))
      .forEach(k => window.localStorage.removeItem(k));
  });
};

/** ダイアログ(confirm)を自動で承認する。削除系の操作で使う */
export const acceptDialogs = (page: Page) => {
  page.on('dialog', dialog => void dialog.accept());
};

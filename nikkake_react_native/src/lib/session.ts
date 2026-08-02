import { BACKEND } from '../config';

/**
 * どちらの実装でデータを読み書きするか、という実行時の状態。
 *
 * サーバモードでも、サーバに登録して端末のデータを預け終わるまでは
 * ローカル実装を使う。これが遅延登録の要点で、こうしないと
 * インストール直後の1回目の起動で圏外だとホームが空になる。
 *
 * 「サーバモードかどうか」はビルド時に決まるが、
 * 「サーバを使ってよいか」は実行時に変わる。混同しないこと。
 */

let serverReady = false;
const listeners = new Set<() => void>();

/** サーバの応答を使ってよいか。false のあいだはローカル実装で動く */
export const isServerReady = (): boolean => BACKEND === 'server' && serverReady;

/**
 * サーバ登録と初回の預け入れが完了した。
 * 以降サーバが真実の源になるので、画面が持っているキャッシュは捨てさせる。
 */
export const markServerReady = (): void => {
  if (serverReady) return;
  serverReady = true;
  listeners.forEach(listener => listener());
};

/** 切り替わったことを画面へ伝える。戻り値を呼ぶと購読を解除する */
export const onServerReady = (listener: () => void): (() => void) => {
  if (serverReady) {
    listener();
    return () => undefined;
  }

  listeners.add(listener);
  return () => void listeners.delete(listener);
};

/** テスト用 */
export const resetSessionState = (): void => {
  serverReady = false;
  listeners.clear();
};

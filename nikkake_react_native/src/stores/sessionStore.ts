import { create } from 'zustand';
import type { Viewer } from '@nikkake/api-client';
import { StorageMode } from '../../types';
import { isServerReady } from '../lib/session';
import { pendingCount } from '../lib/repository';

/**
 * アカウントの状態。
 *
 * サインインは「任意」で、意味は**端末を変えてもデータが残ること**だけです。
 * サインインしていなくても全機能が使えるので、このストアが画面をブロックすることはありません。
 *
 * 匿名でも記録はサーバに預けられています。違いは取り戻す手段だけで、
 * 匿名だとこの端末のトークンを失った時点で辿り着けなくなります。
 *
 * **メール登録でデータは1件も移動しません。** 匿名アカウントに
 * メールとパスワードを足すだけで `user.id` が変わらないためです。
 * 移行前にあった claimLocalRows のような引き取り処理は不要になりました。
 */

interface SessionStoreState {
  viewer: Viewer | null;
  /** local = この端末専用 / cloud = メール登録済み */
  mode: StorageMode;
  /** 初回確認が終わったか。画面表示のブロックには使わない */
  initialized: boolean;
  /** 送信待ちの記録の件数 */
  pending: number;
  lastError: string | null;

  initialize: () => Promise<void>;
  refresh: () => Promise<void>;
  signIn: (email: string, password: string) => Promise<{ error: string | null }>;
  signUp: (email: string, password: string, displayName?: string) => Promise<{ error: string | null }>;
  signOut: () => Promise<void>;
  flushNow: () => Promise<void>;
}

/** ローカルモードでは api を読み込まない（Supabase 時代と違い import 自体が通信を含まない） */
const loadApi = async () => (await import('../lib/repository.server')).api;

export const useSessionStore = create<SessionStoreState>((set, get) => ({
  viewer: null,
  mode: 'local',
  initialized: false,
  pending: 0,
  lastError: null,

  initialize: async () => {
    await get().refresh();
    set({ initialized: true });
  },

  refresh: async () => {
    set({ pending: await pendingCount() });

    // サーバに登録できていないあいだは、そもそも聞きに行く相手がいない
    if (!isServerReady()) {
      set({ viewer: null, mode: 'local' });
      return;
    }

    try {
      const api = await loadApi();
      const viewer = await api.viewer();
      set({ viewer, mode: viewer.isAnonymous ? 'local' : 'cloud' });
    } catch {
      // 圏外でも画面は出す。次に開いたときに取り直す
      set({ viewer: null, mode: 'local' });
    }
  },

  /**
   * 既にあるアカウントに切り替える。
   * この端末の匿名データをどう扱うかは merge で決める（既定は取り込まない）。
   */
  signIn: async (email, password) => {
    try {
      const api = await loadApi();
      const result = await api.linkExistingAccount(email, password, false);

      if (result.userErrors.length > 0) {
        return { error: result.userErrors[0].message };
      }

      await get().refresh();
      return { error: null };
    } catch {
      return { error: 'サーバに接続できませんでした。電波の良いところで試してください。' };
    }
  },

  /**
   * いま使っている匿名アカウントにメールとパスワードを足す。
   * 新しいアカウントを作るのではないので、記録はそのまま残る。
   */
  signUp: async (email, password, displayName) => {
    try {
      const api = await loadApi();
      const result = await api.attachEmailPassword(email, password, displayName ?? null);

      if (result.userErrors.length > 0) {
        return { error: result.userErrors[0].message };
      }

      await get().refresh();
      return { error: null };
    } catch {
      return { error: 'サーバに接続できませんでした。電波の良いところで試してください。' };
    }
  },

  /**
   * サインアウトしても記録は消えません。
   * この端末から見えなくなるだけで、同じアカウントで入り直せば戻ります。
   */
  signOut: async () => {
    try {
      const api = await loadApi();
      await api.signOut();
    } finally {
      set({ viewer: null, mode: 'local' });
    }
  },

  flushNow: async () => {
    try {
      const api = await loadApi();
      await api.flushQueue();
      set({ pending: await pendingCount(), lastError: null });
    } catch (error) {
      set({ lastError: error instanceof Error ? error.message : String(error) });
    }
  },
}));

import { create } from 'zustand';
import { Session, User } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import { claimLocalRows, trySync } from '../lib/sync';
import { getMeta } from '../lib/localDb';
import { StorageMode, SyncState } from '../../types';

/**
 * 認証は「任意」。
 *
 * このアプリはサインインしなくても全機能が使える。
 * サインインの意味は「端末を変えてもデータが残る」ことだけなので、
 * このストアが未サインインでも画面は一切ブロックしない。
 */

interface AuthStoreState {
  user: User | null;
  session: Session | null;
  /** local = 端末内のみ / cloud = バックアップ有効 */
  mode: StorageMode;
  /** 認証状態の初回確認が終わったか。画面表示のブロックには使わない */
  initialized: boolean;
  sync: SyncState;

  initialize: () => Promise<void>;
  signIn: (email: string, password: string) => Promise<{ error: string | null }>;
  signUp: (email: string, password: string, displayName?: string) => Promise<{ error: string | null }>;
  signOut: () => Promise<void>;
  syncNow: () => Promise<void>;
}

const IDLE_SYNC: SyncState = { status: 'idle', lastSyncedAt: null, lastError: null };

export const useAuthStore = create<AuthStoreState>((set, get) => ({
  user: null,
  session: null,
  mode: 'local',
  initialized: false,
  sync: IDLE_SYNC,

  initialize: async () => {
    const meta = await getMeta();
    set({ sync: { ...IDLE_SYNC, lastSyncedAt: meta.lastSyncedAt } });

    let session: Session | null = null;
    try {
      const result = await supabase.auth.getSession();
      session = result.data.session;
    } catch {
      // セッション復元に失敗してもローカルモードで動けばよい
      session = null;
    }

    set({
      session,
      user: session?.user ?? null,
      mode: session?.user ? 'cloud' : 'local',
      initialized: true,
    });

    supabase.auth.onAuthStateChange((_event, nextSession) => {
      set({
        session: nextSession,
        user: nextSession?.user ?? null,
        mode: nextSession?.user ? 'cloud' : 'local',
      });
    });

    if (session?.user) {
      void get().syncNow();
    }
  },

  signIn: async (email, password) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return { error: error.message };

    set({ session: data.session, user: data.user, mode: 'cloud' });
    await get().syncNow();
    return { error: null };
  },

  signUp: async (email, password, displayName) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: displayName ? { display_name: displayName } : undefined },
    });
    if (error) return { error: error.message };

    // メール確認が必要な設定の場合、この時点ではセッションが無い
    if (data.session?.user) {
      set({ session: data.session, user: data.user, mode: 'cloud' });
      await get().syncNow();
    }
    return { error: null };
  },

  /**
   * サインアウトしてもローカルのデータは消さない。
   * 「バックアップをやめる」だけであって、記録を捨てる操作ではないため。
   */
  signOut: async () => {
    await supabase.auth.signOut();
    set({ session: null, user: null, mode: 'local' });
  },

  syncNow: async () => {
    const { user } = get();
    if (!user) return;

    set(state => ({ sync: { ...state.sync, status: 'syncing', lastError: null } }));

    // サインイン前に作ったローカルのレコードをこのアカウントのものにする
    await claimLocalRows(user.id);

    const result = await trySync(user.id);
    set({ sync: result });
  },
}));

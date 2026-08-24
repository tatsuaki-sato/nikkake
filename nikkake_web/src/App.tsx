import { useEffect, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import type { WorkoutSummary } from '@nikkake/api-client';
import { api } from './lib';
import { Home } from './routes/Home';
import { Routines } from './routes/Routines';
import { RoutineForm } from './routes/RoutineForm';
import { Summary } from './routes/Summary';
import { Progress } from './routes/Progress';
import { Settings } from './routes/Settings';

type Tab = 'home' | 'routines' | 'progress' | 'settings';
/** 編集中のルーティン（無ければ新規作成） */
type RoutineFormRoute = { routineId: string | null } | null;

const TABS: Array<{ id: Tab; label: string; icon: string }> = [
  { id: 'home', label: 'ホーム', icon: '🏠' },
  { id: 'routines', label: 'ルーティン', icon: '📋' },
  { id: 'progress', label: '進捗', icon: '📈' },
  { id: 'settings', label: '設定', icon: '⚙️' },
];

/**
 * URLとタブ／overlayを対応させる。ブラウザの戻る・進む・直接URLを開く、が
 * ちゃんと動くようにするための唯一の変換場所（他ではこの対応を持たない）。
 *
 * タブは末尾に`/`を付けたディレクトリ形式にする（`/routines/`）。
 * vite.config.tsのビルド時に`dist/routines/index.html`を実ファイルとして
 * 複製しているので、ホスティング先の設定に頼らず直接開ける。
 * ルーティン編集はパスを増やさず、`/routines/`にクエリパラメータを乗せる
 * （`?new=1` / `?edit=<id>`）。動的なパス（ルーティンIDごとのURL）は
 * 実ファイルを用意できないため。
 */
const pathForTab = (t: Tab) => (t === 'home' ? '/' : `/${t}/`);
const pathForRoutineForm = (routineId: string | null) =>
  routineId ? `/routines/?edit=${encodeURIComponent(routineId)}` : '/routines/?new=1';

const parseLocation = (pathname: string, search: string): { tab: Tab; routineForm: RoutineFormRoute } => {
  const tab: Tab = pathname === '/routines/' ? 'routines'
    : pathname === '/progress/' ? 'progress'
    : pathname === '/settings/' ? 'settings'
    : 'home';

  if (tab === 'routines') {
    const params = new URLSearchParams(search);
    if (params.has('new')) return { tab, routineForm: { routineId: null } };
    const editId = params.get('edit');
    if (editId) return { tab, routineForm: { routineId: editId } };
  }
  return { tab, routineForm: null };
};

export const App = () => {
  const qc = useQueryClient();
  const [{ tab, routineForm }, setRoute] = useState(
    () => parseLocation(window.location.pathname, window.location.search),
  );
  // ワークアウト完了直後の一覧画面。URLには対応させない
  // （リロードで復元する意味の無い、一度きりの結果表示のため）
  const [summary, setSummary] = useState<{ summary: WorkoutSummary | null } | null>(null);

  // ブラウザの戻る・進むボタンに追従する
  useEffect(() => {
    const onPopState = () => setRoute(parseLocation(window.location.pathname, window.location.search));
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, []);

  const navigate = (path: string) => {
    const url = new URL(path, window.location.origin);
    if (url.pathname + url.search !== window.location.pathname + window.location.search) {
      window.history.pushState(null, '', path);
    }
    setRoute(parseLocation(url.pathname, url.search));
  };

  // 未送信の記録を送るタイミング:
  // オンライン復帰 / タブがフォアグラウンドに戻ったとき / 起動直後
  useEffect(() => {
    const flush = async () => {
      const result = await api.flushQueue();
      if (result.sent > 0) await qc.invalidateQueries();
    };

    void flush();
    window.addEventListener('online', flush);
    document.addEventListener('visibilitychange', flush);
    return () => {
      window.removeEventListener('online', flush);
      document.removeEventListener('visibilitychange', flush);
    };
  }, [qc]);

  const closeRoutineForm = async () => {
    navigate('/routines/');
    await qc.invalidateQueries();
  };

  const closeSummary = async () => {
    setSummary(null);
    await qc.invalidateQueries();
  };

  if (summary) {
    return (
      <Shell tab={tab} onTab={t => navigate(pathForTab(t))} hideNav>
        <Summary summary={summary.summary} onHome={closeSummary} />
      </Shell>
    );
  }

  if (routineForm) {
    return (
      <Shell tab={tab} onTab={t => navigate(pathForTab(t))}>
        <RoutineForm routineId={routineForm.routineId} onDone={closeRoutineForm} />
      </Shell>
    );
  }

  return (
    <Shell tab={tab} onTab={t => navigate(pathForTab(t))} wide={tab === 'progress'}>
      {tab === 'home' && (
        <Home
          onWorkoutFinished={s => setSummary({ summary: s })}
          onCreateRoutine={() => navigate(pathForRoutineForm(null))}
        />
      )}
      {tab === 'routines' && (
        <Routines
          onEdit={id => navigate(pathForRoutineForm(id))}
          onCreate={() => navigate(pathForRoutineForm(null))}
        />
      )}
      {tab === 'progress' && <Progress />}
      {tab === 'settings' && <Settings />}
    </Shell>
  );
};

/** SP は下タブ、PC は左サイドバー。CSS のブレークポイントで切り替わる */
const Shell = ({ children, tab, onTab, hideNav, wide }: {
  children: React.ReactNode;
  tab: Tab;
  onTab: (t: Tab) => void;
  hideNav?: boolean;
  wide?: boolean;
}) => (
  <div className="shell">
    {!hideNav && (
      <nav className="tabbar">
        {TABS.map(t => (
          <button key={t.id} className="tabbar__item" role="tab"
                  aria-current={tab === t.id ? 'page' : undefined}
                  onClick={() => onTab(t.id)}>
            <span className="tabbar__icon">{t.icon}</span>
            <span>{t.label}</span>
          </button>
        ))}
      </nav>
    )}
    <div className="shell__body">
      <div className={`shell__content${wide ? ' shell__content--wide' : ''}`}>{children}</div>
    </div>
  </div>
);

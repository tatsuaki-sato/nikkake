import { useEffect, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import type { WorkoutSummary } from '@nikkake/api-client';
import { api } from './lib';
import { Home } from './routes/Home';
import { Routines } from './routes/Routines';
import { RoutineForm } from './routes/RoutineForm';
import { Workout } from './routes/Workout';
import { Summary } from './routes/Summary';
import { Progress } from './routes/Progress';
import { Settings } from './routes/Settings';

type Tab = 'home' | 'routines' | 'progress' | 'settings';
type Overlay =
  | { kind: 'none' }
  | { kind: 'routineForm'; routineId: string | null }
  | { kind: 'workout'; routineId: string }
  | { kind: 'summary'; summary: WorkoutSummary | null };

const TABS: Array<{ id: Tab; label: string; icon: string }> = [
  { id: 'home', label: 'ホーム', icon: '🏠' },
  { id: 'routines', label: 'ルーティン', icon: '📋' },
  { id: 'progress', label: '進捗', icon: '📈' },
  { id: 'settings', label: '設定', icon: '⚙️' },
];

export const App = () => {
  const qc = useQueryClient();
  const [tab, setTab] = useState<Tab>('home');
  const [overlay, setOverlay] = useState<Overlay>({ kind: 'none' });

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

  const closeOverlay = async () => {
    setOverlay({ kind: 'none' });
    await qc.invalidateQueries();
  };

  if (overlay.kind === 'workout') {
    return (
      <Shell tab={tab} onTab={setTab} hideNav>
        <Workout
          routineId={overlay.routineId}
          onFinished={summary => setOverlay({ kind: 'summary', summary })}
          onCancel={() => {
            if (confirm('ワークアウトを中断しますか？記録は保存されません。')) void closeOverlay();
          }}
        />
      </Shell>
    );
  }

  if (overlay.kind === 'summary') {
    return (
      <Shell tab={tab} onTab={setTab} hideNav>
        <Summary summary={overlay.summary} onHome={closeOverlay} />
      </Shell>
    );
  }

  if (overlay.kind === 'routineForm') {
    return (
      <Shell tab={tab} onTab={setTab}>
        <RoutineForm routineId={overlay.routineId} onDone={closeOverlay} />
      </Shell>
    );
  }

  return (
    <Shell tab={tab} onTab={setTab} wide={tab === 'progress'}>
      {tab === 'home' && (
        <Home
          onOpenWorkout={id => setOverlay({ kind: 'workout', routineId: id })}
          onCreateRoutine={() => setOverlay({ kind: 'routineForm', routineId: null })}
        />
      )}
      {tab === 'routines' && (
        <Routines
          onEdit={id => setOverlay({ kind: 'routineForm', routineId: id })}
          onCreate={() => setOverlay({ kind: 'routineForm', routineId: null })}
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

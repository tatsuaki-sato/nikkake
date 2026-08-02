import { formatDuration } from '@nikkake/domain';
import type { WorkoutSummary } from '@nikkake/api-client';
import { Button, Card, EmptyState } from '../components/ui';

/**
 * 完了直後のサマリー。
 * オフラインで記録した場合 summary は null になる（サーバが計算できないため）。
 * その場合も「記録した」ことは伝える。
 */
export const Summary = ({ summary, onHome }: {
  summary: WorkoutSummary | null; onHome: () => void;
}) => {
  if (!summary) {
    return (
      <div data-testid="summary-screen">
        <EmptyState
          testId="summary-offline"
          icon="📥"
          title="記録しました"
          message="オフラインのため、まだサーバへ送れていません。オンラインになったら自動で送信されます。"
          action={<Button label="ホームに戻る" onClick={onHome} testId="summary-home" />}
        />
      </div>
    );
  }

  const label =
    summary.status === 'COMPLETED' ? 'コンプリート！' :
    summary.status === 'PARTIAL' ? '記録しました' : '記録なし';

  return (
    <div data-testid="summary-screen" style={{ textAlign: 'center' }}>
      <div style={{ fontSize: 64, marginTop: 'var(--sp-5)' }}>
        {summary.status === 'COMPLETED' ? '🎉' : '💪'}
      </div>
      <h1 className="h1" data-testid="summary-status">{label}</h1>
      <div className="muted">{summary.routineName}</div>

      <div style={{ marginTop: 'var(--sp-5)' }}>
        <Card>
          <div className="row" style={{ justifyContent: 'space-around' }}>
            <Stat label="時間" value={formatDuration(summary.durationSec)} testId="summary-duration" />
            <Stat label="セット" value={`${summary.completedSets}/${summary.totalSets}`} testId="summary-sets" />
            <Stat label="総重量" value={summary.totalVolume > 0 ? `${Math.round(summary.totalVolume)} kg` : '—'} testId="summary-volume" />
          </div>
        </Card>
      </div>

      <div style={{ marginTop: 'var(--sp-5)' }}>
        <Button label="ホームに戻る" onClick={onHome} testId="summary-home" />
      </div>
    </div>
  );
};

const Stat = ({ label, value, testId }: { label: string; value: string; testId: string }) => (
  <div>
    <div className="muted">{label}</div>
    <div data-testid={testId} style={{ fontSize: 20, fontWeight: 'bold' }}>{value}</div>
  </div>
);

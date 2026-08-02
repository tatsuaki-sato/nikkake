import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib';
import { Button, Card, ErrorText, Loading } from '../components/ui';

/**
 * 設定。バックアップ（サインイン）は任意機能であることを明示する。
 *
 * 匿名アカウントはサーバ発行なので、未登録でもデータはクラウドにある。
 * ただし端末を変えると引き継げないので、メール登録を勧める。
 */
export const Settings = () => {
  const qc = useQueryClient();
  const { data, isLoading, refetch } = useQuery({ queryKey: ['viewer'], queryFn: () => api.viewer() });

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const pending = api.queue.pending().length;
  const dead = api.queue.dead().length;

  if (isLoading || !data) return <Loading />;

  const attach = async () => {
    setBusy(true);
    setError(null);
    const result = await api.attachEmailPassword(email.trim(), password);
    setBusy(false);

    if (result.userErrors.length > 0) {
      setError(result.userErrors[0].message);
      return;
    }
    setEmail('');
    setPassword('');
    await refetch();
  };

  const signOut = async () => {
    if (!confirm('サインアウトしても、サーバ上の記録は消えません。この端末からアクセスできなくなるだけです。')) return;
    await api.signOut();
    await qc.invalidateQueries();
    location.reload();
  };

  const reset = async () => {
    if (!confirm('ルーティンと記録をすべて削除して初期状態に戻します。取り消せません。')) return;
    await api.resetData();
    await qc.invalidateQueries();
  };

  return (
    <div className="stack" data-testid="settings-screen">
      <h2 className="section-title" style={{ marginTop: 0 }}>データの保存先</h2>

      {data.isAnonymous ? (
        <Card testId="settings-anonymous-card">
          <div className="row">
            <span style={{ fontSize: 28 }}>☁️</span>
            <div>
              <div style={{ fontWeight: 'bold' }}>バックアップ中（アカウント未登録）</div>
              <div className="muted">
                サインインしなくても全機能が使えます。ただしこの端末を失うと引き継げません。
                メールアドレスを登録すると、機種変更しても記録を引き継げます。
              </div>
            </div>
          </div>

          <div className="stack" style={{ marginTop: 'var(--sp-3)' }}>
            <ErrorText message={error} />
            <input className="set-input" style={{ textAlign: 'left' }} placeholder="example@email.com"
                   value={email} onChange={e => setEmail(e.target.value)} data-testid="settings-email" />
            <input className="set-input" style={{ textAlign: 'left' }} type="password" placeholder="パスワード（6文字以上）"
                   value={password} onChange={e => setPassword(e.target.value)} data-testid="settings-password" />
            <Button label="このアカウントを登録する" onClick={attach} disabled={busy}
                    testId="settings-attach-email" />
          </div>
        </Card>
      ) : (
        <Card testId="settings-registered-card">
          <div className="row">
            <span style={{ fontSize: 28 }}>✅</span>
            <div>
              <div style={{ fontWeight: 'bold' }}>登録済み</div>
              <div className="muted" data-testid="settings-viewer-email">{data.email}</div>
            </div>
          </div>
          <div style={{ marginTop: 'var(--sp-3)' }}>
            <Button label="サインアウト" variant="ghost" onClick={signOut} testId="settings-sign-out" />
          </div>
        </Card>
      )}

      <h2 className="section-title">同期の状態</h2>
      <Card testId="settings-queue">
        <Row label="未送信の記録" value={String(pending)} testId="queue-pending" />
        <Row label="送信できなかった記録" value={String(dead)} testId="queue-dead" />
        {pending > 0 && (
          <div style={{ marginTop: 'var(--sp-2)' }}>
            <Button label="今すぐ送信" variant="secondary" testId="queue-flush"
                    onClick={async () => { await api.flushQueue(); await qc.invalidateQueries(); }} />
          </div>
        )}
      </Card>

      <h2 className="section-title">保存されているデータ</h2>
      <Card testId="settings-counts">
        <Row label="ルーティン" value={String(data.counts.routines)} testId="count-routines" />
        <Row label="種目" value={String(data.counts.exercises)} testId="count-exercises" />
        <Row label="ワークアウト記録" value={String(data.counts.routineLogs)} testId="count-logs" />
        <Row label="セット記録" value={String(data.counts.exerciseLogs)} testId="count-sets" />
      </Card>

      <h2 className="section-title">危険な操作</h2>
      <Card>
        <div className="muted">ルーティンと記録をすべて削除して初期状態に戻します。</div>
        <div style={{ marginTop: 'var(--sp-3)' }}>
          <Button label="データを初期化" variant="danger" onClick={reset} testId="settings-reset" />
        </div>
      </Card>
    </div>
  );
};

const Row = ({ label, value, testId }: { label: string; value: string; testId: string }) => (
  <div className="row" style={{ justifyContent: 'space-between', padding: 'var(--sp-2) 0' }}>
    <span className="muted">{label}</span>
    <span data-testid={testId} style={{ fontWeight: 'bold' }}>{value}</span>
  </div>
);

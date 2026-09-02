import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib';
import { Button, EmptyState, Loading } from '../components/ui';

export const Routines = ({ onEdit, onCreate }: {
  onEdit: (id: string) => void; onCreate: () => void;
}) => {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({ queryKey: ['routines'], queryFn: () => api.routines() });

  const invalidate = () => qc.invalidateQueries();

  const toggle = useMutation({
    mutationFn: (v: { id: string; isActive: boolean }) => api.setRoutineActive(v.id, v.isActive),
    onSuccess: invalidate,
  });
  const remove = useMutation({
    mutationFn: (id: string) => api.deleteRoutine(id),
    onSuccess: invalidate,
  });
  const reorder = useMutation({
    mutationFn: (ids: string[]) => api.reorderRoutines(ids),
    onSuccess: invalidate,
  });

  if (isLoading || !data) return <Loading />;

  const move = (index: number, dir: -1 | 1) => {
    const target = index + dir;
    if (target < 0 || target >= data.length) return;
    const next = [...data];
    [next[index], next[target]] = [next[target], next[index]];
    reorder.mutate(next.map(r => r.id));
  };

  return (
    <div data-testid="routines-screen">
      {data.length === 0 ? (
        <EmptyState
          testId="routines-empty"
          icon="📋"
          title="ルーティンがありません"
          message="よくやるメニューを登録しておくと、次からは1タップで始められます。"
          action={<Button label="ルーティンを作る" onClick={onCreate} testId="routines-empty-create" />}
        />
      ) : (
        <div data-testid="routines-list">
          {data.map((r, i) => (
            <div key={r.id} className={`routine-card${r.isActive ? '' : ' routine-card--muted'}`}
                 style={{ flexDirection: 'column', alignItems: 'stretch' }}
                 data-testid={`routine-row-${r.id}`}>
              <button className="row" style={{ background: 'none', border: 'none', color: 'inherit', textAlign: 'left', width: '100%' }}
                      onClick={() => onEdit(r.id)} data-testid={`routine-edit-${r.id}`}>
                <span className="routine-card__icon" style={{ backgroundColor: r.color }}>{r.icon}</span>
                <span className="routine-card__body">
                  <span className="routine-card__name">{r.name}</span>
                  <div className="muted">
                    {r.routineExercises.length}種目{r.isActive ? '' : ' ・ 停止中'}
                  </div>
                </span>
              </button>
              <div className="row" style={{ justifyContent: 'space-between', marginTop: 'var(--sp-2)' }}>
                <div className="row" style={{ gap: 'var(--sp-2)' }}>
                  <button className="btn btn--ghost" style={{ width: 'auto', minHeight: 28, padding: '0 var(--sp-2)' }}
                          aria-label="上へ移動" disabled={i === 0}
                          onClick={() => move(i, -1)} data-testid={`routine-move-up-${r.id}`}>▲</button>
                  <button className="btn btn--ghost" style={{ width: 'auto', minHeight: 28, padding: '0 var(--sp-2)' }}
                          aria-label="下へ移動" disabled={i === data.length - 1}
                          onClick={() => move(i, 1)} data-testid={`routine-move-down-${r.id}`}>▼</button>
                </div>
                <div className="row" style={{ gap: 'var(--sp-2)' }}>
                  <button className="btn btn--ghost" style={{ width: 'auto', minHeight: 28 }}
                          aria-label={r.isActive ? 'ホームから一時的に外す' : 'ホームに戻す'}
                          onClick={() => toggle.mutate({ id: r.id, isActive: !r.isActive })}
                          data-testid={`routine-toggle-${r.id}`}>
                    {r.isActive ? '⏸ 停止' : '▶ 再開'}
                  </button>
                  <button className="btn btn--ghost" style={{ width: 'auto', minHeight: 28 }} aria-label="削除する"
                          onClick={() => {
                            if (confirm(`「${r.name}」を削除しますか？これまでの記録は残ります。`)) remove.mutate(r.id);
                          }}
                          data-testid={`routine-delete-${r.id}`}>
                    🗑
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <div style={{ marginTop: 'var(--sp-4)' }}>
        <Button label="＋ 新しいルーティン" onClick={onCreate} testId="routines-fab" />
      </div>
    </div>
  );
};

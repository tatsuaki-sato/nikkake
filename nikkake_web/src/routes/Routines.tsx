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

  if (isLoading || !data) return <Loading />;

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
          {data.map(r => (
            <div key={r.id} className={`routine-card${r.isActive ? '' : ' routine-card--muted'}`}
                 data-testid={`routine-row-${r.id}`}>
              <button className="row" style={{ flex: 1, background: 'none', border: 'none', color: 'inherit', textAlign: 'left' }}
                      onClick={() => onEdit(r.id)} data-testid={`routine-edit-${r.id}`}>
                <span className="routine-card__icon" style={{ backgroundColor: r.color }}>{r.icon}</span>
                <span className="routine-card__body">
                  <span className="routine-card__name">{r.name}</span>
                  <div className="muted">
                    {r.routineExercises.length}種目{r.isActive ? '' : ' ・ 停止中'}
                  </div>
                </span>
              </button>
              <button className="btn btn--ghost" style={{ width: 'auto', minHeight: 32 }}
                      aria-label={r.isActive ? '停止する' : '再開する'}
                      onClick={() => toggle.mutate({ id: r.id, isActive: !r.isActive })}
                      data-testid={`routine-toggle-${r.id}`}>
                {r.isActive ? '⏸' : '▶'}
              </button>
              <button className="btn btn--ghost" style={{ width: 'auto', minHeight: 32 }} aria-label="削除する"
                      onClick={() => {
                        if (confirm(`「${r.name}」を削除しますか？これまでの記録は残ります。`)) remove.mutate(r.id);
                      }}
                      data-testid={`routine-delete-${r.id}`}>
                🗑
              </button>
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

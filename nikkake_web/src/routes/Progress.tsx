import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { addDays, formatDuration, formatWeight, getDateString } from '@nikkake/domain';
import { api } from '../lib';
import { Card, Chip, EmptyState, Loading } from '../components/ui';

/**
 * 進捗。集計はすべてサーバが返す。
 * グラフはライブラリを使わず矩形の高さと色だけで描く（4実装で見た目を揃えやすい）。
 */
export const Progress = () => {
  const today = getDateString();
  const [range, setRange] = useState(7);
  const [exerciseId, setExerciseId] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['progress', today, range],
    queryFn: () => api.progress(today, range),
  });

  const activeId = exerciseId ?? data?.exercisesWithLogs[0]?.id ?? null;
  const detail = useQuery({
    queryKey: ['exerciseProgress', activeId],
    queryFn: () => api.exerciseProgress(activeId!),
    enabled: activeId !== null,
  });

  if (isLoading || !data) return <Loading />;

  if (data.overall.totalWorkouts === 0) {
    return (
      <div data-testid="progress-screen">
        <EmptyState testId="progress-empty" icon="📈" title="まだ記録がありません"
                    message="ワークアウトを1回完了すると、ここに推移が出ます。" />
      </div>
    );
  }

  const maxCount = Math.max(1, ...data.dailyStats.map(d => d.completedCount));
  const done = new Set(data.completedDates);

  return (
    <div data-testid="progress-screen">
      <Card>
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <Stat label="通算" value={`${data.overall.totalWorkouts}回`} testId="progress-total" />
          <Stat label="今週" value={`${data.overall.thisWeekCount}回`} testId="progress-week" />
          <Stat label="連続" value={`${data.streak.current}日`} testId="progress-streak" />
          <Stat label="総時間" value={formatDuration(data.overall.totalDurationSec)} testId="progress-duration" />
        </div>
      </Card>

      <div className="row" style={{ justifyContent: 'space-between', marginTop: 'var(--sp-4)' }}>
        <h2 className="section-title" style={{ margin: 0 }}>実施状況</h2>
        <div className="row">
          {[7, 30].map(v => (
            <Chip key={v} label={`${v}日`} selected={range === v} onClick={() => setRange(v)}
                  testId={`progress-range-${v}`} />
          ))}
        </div>
      </div>

      <Card testId="progress-chart">
        <div className="bar-chart">
          {data.dailyStats.map(d => (
            <div key={d.date} className="bar-chart__col">
              <div className={`bar-chart__bar${d.completedCount > 0 ? ' bar-chart__bar--on' : ''}`}
                   style={{ height: Math.max(4, (d.completedCount / maxCount) * 96) }} />
              {range === 7 && <div className="bar-chart__label">{d.date.slice(8)}</div>}
            </div>
          ))}
        </div>
      </Card>

      <h2 className="section-title">カレンダー</h2>
      <Card testId="progress-calendar"><MonthGrid doneDates={done} /></Card>

      <h2 className="section-title">種目ごとの推移</h2>
      {data.exercisesWithLogs.length === 0 ? (
        <Card><div className="muted">セット記録が貯まるとここに種目別の推移が出ます。</div></Card>
      ) : (
        <>
          <div className="row" style={{ overflowX: 'auto' }}>
            {data.exercisesWithLogs.map(e => (
              <Chip key={e.id} label={e.name} selected={activeId === e.id}
                    onClick={() => setExerciseId(e.id)} testId={`progress-exercise-${e.id}`} />
            ))}
          </div>
          <div style={{ marginTop: 'var(--sp-3)' }}>
            <Card testId="progress-exercise-detail">
              {(detail.data ?? []).slice().reverse().map(p => (
                <div key={p.date} className="row" style={{ justifyContent: 'space-between', padding: 'var(--sp-2) 0', borderBottom: '1px solid var(--border)' }}>
                  <span className="muted">{p.date.slice(5)}</span>
                  <span style={{ fontWeight: 'bold' }}>
                    {p.maxWeight > 0 ? `最大 ${formatWeight(p.maxWeight)}` : `${p.totalReps} 回`}
                  </span>
                  <span className="muted">
                    {p.totalVolume > 0 ? `${Math.round(p.totalVolume)}kg` : `計 ${p.totalReps}回`}
                  </span>
                </div>
              ))}
            </Card>
          </div>
        </>
      )}
    </div>
  );
};

const Stat = ({ label, value, testId }: { label: string; value: string; testId: string }) => (
  <div style={{ textAlign: 'center' }}>
    <div className="muted" style={{ fontSize: 11 }}>{label}</div>
    <div data-testid={testId} style={{ fontWeight: 'bold' }}>{value}</div>
  </div>
);

/** 当月のカレンダー。実施した日を塗る */
const MonthGrid = ({ doneDates }: { doneDates: Set<string> }) => {
  const today = new Date();
  const first = new Date(today.getFullYear(), today.getMonth(), 1);
  const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
  const todayString = getDateString(today);

  const cells: (string | null)[] = [
    ...Array<null>(first.getDay()).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => getDateString(addDays(first, i))),
  ];

  return (
    <>
      <div style={{ textAlign: 'center', fontWeight: 'bold', marginBottom: 'var(--sp-2)' }}>
        {today.getFullYear()}年{today.getMonth() + 1}月
      </div>
      <div className="calendar">
        {['日', '月', '火', '水', '木', '金', '土'].map(d => (
          <div key={d} className="muted" style={{ textAlign: 'center', fontSize: 11 }}>{d}</div>
        ))}
        {cells.map((date, i) => (
          <div key={date ?? `blank-${i}`}
               className={`calendar__cell${date && doneDates.has(date) ? ' calendar__cell--done' : ''}${date === todayString ? ' calendar__cell--today' : ''}`}>
            {date ? Number(date.slice(8)) : ''}
          </div>
        ))}
      </div>
    </>
  );
};

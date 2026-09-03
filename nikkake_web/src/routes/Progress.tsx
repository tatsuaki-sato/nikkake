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
  const [selectedDate, setSelectedDate] = useState<string | null>(null);

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
      <Card testId="progress-calendar">
        <MonthGrid doneDates={done} selected={selectedDate}
                   onSelect={d => setSelectedDate(d === selectedDate ? null : d)} />
      </Card>
      {selectedDate && <DayDetail date={selectedDate} onClose={() => setSelectedDate(null)} />}

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

/** カレンダー。実施した日を塗り、日をタップするとその日の内容を開く。◀▶ で前月・翌月へ */
const MonthGrid = ({ doneDates, selected, onSelect }: {
  doneDates: Set<string>;
  selected: string | null;
  onSelect: (date: string) => void;
}) => {
  const today = new Date();
  const [monthsBack, setMonthsBack] = useState(0);

  const view = new Date(today.getFullYear(), today.getMonth() - monthsBack, 1);
  const daysInMonth = new Date(view.getFullYear(), view.getMonth() + 1, 0).getDate();
  const todayString = getDateString(today);

  const cells: (string | null)[] = [
    ...Array<null>(view.getDay()).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => getDateString(addDays(view, i))),
  ];

  return (
    <>
      <div className="calendar__head">
        <button className="calendar__nav" data-testid="calendar-prev"
                onClick={() => setMonthsBack(m => m + 1)} aria-label="前の月">◀</button>
        <div className="calendar__title">{view.getFullYear()}年{view.getMonth() + 1}月</div>
        <button className="calendar__nav" data-testid="calendar-next" disabled={monthsBack === 0}
                onClick={() => setMonthsBack(m => Math.max(0, m - 1))} aria-label="次の月">▶</button>
      </div>
      <div className="calendar">
        {['日', '月', '火', '水', '木', '金', '土'].map(d => (
          <div key={d} className="muted" style={{ textAlign: 'center', fontSize: 11 }}>{d}</div>
        ))}
        {cells.map((date, i) => {
          if (!date) return <div key={`blank-${i}`} className="calendar__cell" />;
          const done = doneDates.has(date);
          const cls = `calendar__cell${done ? ' calendar__cell--done' : ''}`
            + `${date === todayString ? ' calendar__cell--today' : ''}`
            + `${date === selected ? ' calendar__cell--selected' : ''}`;
          return (
            <button key={date} className={cls} onClick={() => onSelect(date)}
                    data-testid={`calendar-day-${date}`}>
              {Number(date.slice(8))}
            </button>
          );
        })}
      </div>
    </>
  );
};

/** カレンダーで選んだ日のワークアウト内容。集計と同じくサーバが整形して返す */
const DayDetail = ({ date, onClose }: { date: string; onClose: () => void }) => {
  const { data, isLoading } = useQuery({
    queryKey: ['day', date],
    queryFn: () => api.day(date),
  });

  return (
    <Card testId="progress-day-detail">
      <div className="calendar__head">
        <span style={{ fontWeight: 'bold' }}>{date.slice(5).replace('-', '/')} の記録</span>
        <button className="calendar__nav" onClick={onClose} aria-label="閉じる">✕</button>
      </div>
      {isLoading ? (
        <div className="muted">読み込み中…</div>
      ) : !data || data.workouts.length === 0 ? (
        <div className="muted">この日の記録はありません。</div>
      ) : (
        data.workouts.map(w => (
          <div key={w.routineLogId} style={{ padding: 'var(--sp-2) 0', borderTop: '1px solid var(--border)' }}>
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <span style={{ fontWeight: 'bold' }}>{w.routineName}</span>
              {w.durationSec != null && <span className="muted">{formatDuration(w.durationSec)}</span>}
            </div>
            {w.exercises.map((e, i) => (
              <div key={i} className="row" style={{ justifyContent: 'space-between', fontSize: 13 }}>
                <span className="muted">{e.exerciseName}</span>
                <span>{e.setsLabel ?? '—'}</span>
              </div>
            ))}
          </div>
        ))
      )}
    </Card>
  );
};

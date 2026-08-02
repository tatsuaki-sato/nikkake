import type { ReactNode } from 'react';

export const Card = ({ children, elevated, testId }: {
  children: ReactNode; elevated?: boolean; testId?: string;
}) => (
  <div className={`card${elevated ? ' card--elevated' : ''}`} data-testid={testId}>{children}</div>
);

export const Button = ({ label, onClick, variant = 'primary', disabled, testId }: {
  label: string;
  onClick: () => void;
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  disabled?: boolean;
  testId?: string;
}) => (
  <button
    className={`btn${variant === 'primary' ? '' : ` btn--${variant}`}`}
    onClick={onClick}
    disabled={disabled}
    data-testid={testId}
  >
    {label}
  </button>
);

export const EmptyState = ({ icon, title, message, action, testId }: {
  icon: string; title: string; message: string; action?: ReactNode; testId?: string;
}) => (
  <div className="empty" data-testid={testId}>
    <div className="empty__icon">{icon}</div>
    <div className="empty__title">{title}</div>
    <div className="muted">{message}</div>
    {action ? <div style={{ marginTop: 'var(--sp-4)' }}>{action}</div> : null}
  </div>
);

export const ErrorText = ({ message }: { message?: string | null }) =>
  message ? <div className="error" data-testid="error-message" role="alert">{message}</div> : null;

export const Chip = ({ label, selected, onClick, testId }: {
  label: string; selected: boolean; onClick: () => void; testId?: string;
}) => (
  <button className="chip" aria-pressed={selected} onClick={onClick} data-testid={testId}>
    {label}
  </button>
);

export const Loading = () => (
  <div className="empty" data-testid="loading"><div className="muted">読み込み中…</div></div>
);

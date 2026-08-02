import type { KeyValueStore } from './storage';
import { isPermanent } from './errors';

/**
 * オフライン記録のキュー。
 *
 * 記録だけがオフライン可（ルーティンの作成・編集はオンライン必須）。
 * id は clientMutationId としてそのままサーバへ送るので、
 * 再送しても mutation_receipts とクライアント生成UUIDの主キー衝突で吸収される。
 */
export interface QueuedOp {
  id: string;
  kind: 'recordWorkout' | 'deleteRoutineLog';
  payload: Record<string, unknown>;
  createdAt: string;
  attempts: number;
  nextAttemptAt: string;
  lastError: string | null;
}

const KEY = 'nikkake:v2:queue';
const DEAD_KEY = 'nikkake:v2:queue_dead';
const MAX_BACKOFF_MS = 5 * 60 * 1000;

export class OfflineQueue {
  constructor(private readonly store: KeyValueStore) {}

  private read(key: string): QueuedOp[] {
    const raw = this.store.get(key);
    if (!raw) return [];
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      // 壊れたJSONで記録できなくなるのが最悪なので、握りつぶして空で復旧する
      return [];
    }
  }

  private write(key: string, ops: QueuedOp[]): void {
    this.store.set(key, JSON.stringify(ops));
  }

  pending(): QueuedOp[] {
    return this.read(KEY);
  }

  /** 送信できなかったもの。設定画面に出して手動対応させる */
  dead(): QueuedOp[] {
    return this.read(DEAD_KEY);
  }

  enqueue(op: Pick<QueuedOp, 'id' | 'kind' | 'payload'>): void {
    const ops = this.pending();
    if (ops.some(o => o.id === op.id)) return;

    ops.push({
      ...op,
      createdAt: new Date().toISOString(),
      attempts: 0,
      nextAttemptAt: new Date().toISOString(),
      lastError: null,
    });
    this.write(KEY, ops);
  }

  /**
   * 直列に送る。失敗したら以降は次回に回して順序を守る。
   * オフライン記録は少数なので並列化する必要がない。
   */
  async flush(send: (op: QueuedOp) => Promise<void>): Promise<{ sent: number; remaining: number }> {
    let sent = 0;

    for (const op of this.pending()) {
      if (Date.parse(op.nextAttemptAt) > Date.now()) continue;

      try {
        await send(op);
        this.remove(op.id);
        sent++;
      } catch (error) {
        if (isPermanent(error)) {
          this.moveToDead(op, error);
        } else {
          this.backoff(op, error);
        }
        break;
      }
    }

    return { sent, remaining: this.pending().length };
  }

  remove(id: string): void {
    this.write(KEY, this.pending().filter(o => o.id !== id));
  }

  clearDead(): void {
    this.write(DEAD_KEY, []);
  }

  /** 死んだキューを手動で再試行する */
  retryDead(): void {
    const revived = this.dead().map(o => ({
      ...o,
      attempts: 0,
      nextAttemptAt: new Date().toISOString(),
      lastError: null,
    }));
    this.write(KEY, [...this.pending(), ...revived]);
    this.clearDead();
  }

  private moveToDead(op: QueuedOp, error: unknown): void {
    this.remove(op.id);
    this.write(DEAD_KEY, [
      ...this.dead(),
      { ...op, lastError: error instanceof Error ? error.message : String(error) },
    ]);
  }

  private backoff(op: QueuedOp, error: unknown): void {
    const attempts = op.attempts + 1;
    const delay = Math.min(MAX_BACKOFF_MS, 1000 * 2 ** op.attempts);

    this.write(
      KEY,
      this.pending().map(o =>
        o.id === op.id
          ? {
              ...o,
              attempts,
              nextAttemptAt: new Date(Date.now() + delay).toISOString(),
              lastError: error instanceof Error ? error.message : String(error),
            }
          : o,
      ),
    );
  }
}

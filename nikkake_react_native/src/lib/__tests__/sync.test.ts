import { COLLECTIONS, insert, list, getMeta, setMeta, resetDatabase, listRaw } from '../localDb';
import { Routine, RoutineLog } from '../../../types';

/**
 * Supabaseクライアントをチェーン可能なモックに差し替える。
 * 実ネットワークを叩かずに、同期が「何をどの順で送り、何を取り込むか」を検証する。
 */
const mockRemoteRows: Record<string, any[]> = {};
const mockPushed: { table: string; rows: any[] }[] = [];
let mockFailOn: string | null = null;
let mockFailMessage = 'boom';

jest.mock('../supabase', () => ({
  supabase: {
    from: (table: string) => {
      const filters: { gt?: string; eq?: string } = {};

      const builder: any = {
        upsert: async (rows: any[]) => {
          if (mockFailOn === table) return { error: { message: mockFailMessage } };
          mockPushed.push({ table, rows });
          return { error: null };
        },
        select: () => builder,
        gt: (_column: string, value: string) => {
          filters.gt = value;
          return builder;
        },
        eq: (_column: string, value: string) => {
          filters.eq = value;
          return builder;
        },
        then: (resolve: (v: any) => void) => {
          if (mockFailOn === table) {
            return Promise.resolve({ data: null, error: { message: mockFailMessage } }).then(resolve);
          }
          let data = mockRemoteRows[table] ?? [];
          if (filters.gt) {
            data = data.filter(r => new Date(r.updated_at).getTime() > new Date(filters.gt!).getTime());
          }
          return Promise.resolve({ data, error: null }).then(resolve);
        },
      };

      return builder;
    },
  },
}));

// モック定義後に読み込む必要がある
const { runSync, trySync, claimLocalRows, getPendingCount, SyncError } = require('../sync');

const newRoutine = (name: string) => ({
  user_id: null,
  name,
  description: null,
  color: '#6C5CE7',
  icon: '💪',
  frequency_type: 'daily' as const,
  frequency_value: 1,
  frequency_days: [],
  preferred_time: null,
  is_active: true,
  sort_order: 0,
});

beforeEach(async () => {
  await resetDatabase();
  mockPushed.length = 0;
  mockFailOn = null;
  for (const key of Object.keys(mockRemoteRows)) delete mockRemoteRows[key];
});

describe('claimLocalRows', () => {
  it('サインイン前に作ったデータをそのアカウントのものにする', async () => {
    await insert<Routine>(COLLECTIONS.routines, newRoutine('サインイン前のルーティン'));

    const claimed = await claimLocalRows('user-1');

    expect(claimed).toBe(1);
    const routines = await list<Routine>(COLLECTIONS.routines);
    expect(routines[0].user_id).toBe('user-1');
  });

  it('既に同じユーザーのものは触らない', async () => {
    await insert<Routine>(COLLECTIONS.routines, { ...newRoutine('既存'), user_id: 'user-1' });
    expect(await claimLocalRows('user-1')).toBe(0);
  });

  it('ログも同じように引き取る', async () => {
    await insert<RoutineLog>(COLLECTIONS.routineLogs, {
      routine_id: 'r1',
      user_id: null,
      log_date: '2026-08-01',
      status: 'completed',
      duration_sec: 100,
      notes: null,
      started_at: null,
      completed_at: null,
    } as any);

    expect(await claimLocalRows('user-1')).toBe(1);
  });
});

describe('runSync', () => {
  it('ローカルの変更をpushし、同期カーソルを進める', async () => {
    await insert<Routine>(COLLECTIONS.routines, newRoutine('送るルーティン'));

    const result = await runSync('user-1');

    expect(result.pushed).toBe(1);
    expect(mockPushed.find(p => p.table === COLLECTIONS.routines)?.rows).toHaveLength(1);

    const meta = await getMeta();
    expect(meta.lastSyncedAt).toBe(result.syncedAt);
    expect(meta.syncUserId).toBe('user-1');
  });

  it('プリセット種目はサーバの共有マスタなのでpushしない', async () => {
    await insert(COLLECTIONS.exercises, {
      id: 'preset-1',
      name: 'ベンチプレス',
      category: 'strength',
      description: null,
      icon: '🏋️',
      is_preset: true,
      created_by: null,
    } as any);

    await insert(COLLECTIONS.exercises, {
      name: '自作種目',
      category: 'custom',
      description: null,
      icon: '🌟',
      is_preset: false,
      created_by: null,
    } as any);

    const result = await runSync('user-1');

    const exercisePush = mockPushed.find(p => p.table === COLLECTIONS.exercises);
    expect(exercisePush?.rows).toHaveLength(1);
    expect(exercisePush?.rows[0].name).toBe('自作種目');
    expect(result.pushed).toBe(1);
  });

  it('リモートの新しい行を取り込む', async () => {
    mockRemoteRows[COLLECTIONS.routines] = [
      {
        ...newRoutine('リモート発ルーティン'),
        id: 'remote-1',
        user_id: 'user-1',
        created_at: '2026-08-01T00:00:00.000Z',
        updated_at: '2026-08-01T00:00:00.000Z',
        deleted_at: null,
      },
    ];

    const result = await runSync('user-1');

    expect(result.pulled).toBe(1);
    const routines = await list<Routine>(COLLECTIONS.routines);
    expect(routines.map(r => r.name)).toContain('リモート発ルーティン');
  });

  it('リモートの論理削除がローカルにも反映される', async () => {
    const local = await insert<Routine>(COLLECTIONS.routines, newRoutine('消される'));

    mockRemoteRows[COLLECTIONS.routines] = [
      { ...local, user_id: 'user-1', deleted_at: '2099-01-01T00:00:00.000Z', updated_at: '2099-01-01T00:00:00.000Z' },
    ];

    await runSync('user-1');

    expect(await list<Routine>(COLLECTIONS.routines)).toHaveLength(0);
    expect(await listRaw<Routine>(COLLECTIONS.routines)).toHaveLength(1);
  });

  it('ローカルの方が新しければリモートの値で上書きしない', async () => {
    const local = await insert<Routine>(COLLECTIONS.routines, newRoutine('ローカル優先'));

    mockRemoteRows[COLLECTIONS.routines] = [
      { ...local, name: '古いリモート値', updated_at: '2000-01-01T00:00:00.000Z' },
    ];

    await runSync('user-1');

    const routines = await list<Routine>(COLLECTIONS.routines);
    expect(routines[0].name).toBe('ローカル優先');
  });

  it('別アカウントでサインインし直すとカーソルを捨てて全件取り直す', async () => {
    await setMeta({ lastSyncedAt: '2099-01-01T00:00:00.000Z', syncUserId: 'user-1' });

    mockRemoteRows[COLLECTIONS.routines] = [
      {
        ...newRoutine('別アカウントのデータ'),
        id: 'remote-2',
        user_id: 'user-2',
        created_at: '2026-01-01T00:00:00.000Z',
        updated_at: '2026-01-01T00:00:00.000Z',
        deleted_at: null,
      },
    ];

    // カーソルを引き継いでいたら updated_at が古いので0件になるはず
    const result = await runSync('user-2');
    expect(result.pulled).toBe(1);
  });

  it('親テーブルを子テーブルより先にpushする', async () => {
    await insert<Routine>(COLLECTIONS.routines, newRoutine('親'));
    await insert(COLLECTIONS.routineExercises, {
      routine_id: 'r1',
      exercise_id: 'e1',
      sort_order: 0,
      target_sets: 3,
      target_reps: 10,
      target_weight: null,
      target_duration_sec: null,
      rest_sec: 60,
      notes: null,
    } as any);

    await runSync('user-1');

    const tables = mockPushed.map(p => p.table);
    expect(tables.indexOf(COLLECTIONS.routines)).toBeLessThan(tables.indexOf(COLLECTIONS.routineExercises));
  });
});

describe('エラー処理', () => {
  it('runSync は失敗を例外で伝える', async () => {
    await insert<Routine>(COLLECTIONS.routines, newRoutine('失敗する'));
    mockFailOn = COLLECTIONS.routines;

    await expect(runSync('user-1')).rejects.toThrow(SyncError);
  });

  it('trySync は例外を投げずに状態として返す', async () => {
    await insert<Routine>(COLLECTIONS.routines, newRoutine('失敗する'));
    mockFailOn = COLLECTIONS.routines;
    mockFailMessage = 'permission denied';

    const state = await trySync('user-1');

    expect(state.status).toBe('error');
    expect(state.lastError).toBe('permission denied');
    mockFailMessage = 'boom';
  });

  it('ネットワーク起因の失敗はofflineとして扱う', async () => {
    await insert<Routine>(COLLECTIONS.routines, newRoutine('圏外'));
    mockFailOn = COLLECTIONS.routines;
    mockFailMessage = 'Failed to fetch';

    const state = await trySync('user-1');

    expect(state.status).toBe('offline');
    mockFailMessage = 'boom';
  });

  it('同期に失敗してもローカルのデータは保持される', async () => {
    await insert<Routine>(COLLECTIONS.routines, newRoutine('残るはず'));
    mockFailOn = COLLECTIONS.routines;

    await trySync('user-1');

    expect(await list<Routine>(COLLECTIONS.routines)).toHaveLength(1);
  });
});

describe('getPendingCount', () => {
  it('未送信の変更件数を数える', async () => {
    await insert<Routine>(COLLECTIONS.routines, newRoutine('未送信'));
    expect(await getPendingCount()).toBe(1);

    await runSync('user-1');
    expect(await getPendingCount()).toBe(0);
  });
});

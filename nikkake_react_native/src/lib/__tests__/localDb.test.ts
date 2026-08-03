import {
  COLLECTIONS,
  insert,
  insertMany,
  list,
  listRaw,
  find,
  where,
  update,
  softDelete,
  softDeleteWhere,
  getMeta,
  setMeta,
  resetDatabase,
} from '../localDb';
import { Routine } from '../../../types';

const newRoutine = (name: string): Omit<Routine, 'id' | 'updated_at' | 'deleted_at' | 'created_at'> => ({
  user_id: null,
  name,
  description: null,
  color: '#6C5CE7',
  icon: '💪',
  frequency_type: 'daily',
  frequency_value: 1,
  frequency_days: [],
  preferred_time: null,
  is_active: true,
  sort_order: 0,
});

beforeEach(async () => {
  await resetDatabase();
});

describe('基本のCRUD', () => {
  it('insert はIDとタイムスタンプを自動で埋める', async () => {
    const row = await insert<Routine>(COLLECTIONS.routines, newRoutine('朝トレ'));

    expect(row.id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(row.deleted_at).toBeNull();
    expect(row.created_at).toBeTruthy();
    expect(row.updated_at).toBeTruthy();
  });

  it('明示的に渡したIDは尊重される（プリセットの固定IDのため）', async () => {
    const row = await insert<Routine>(COLLECTIONS.routines, { ...newRoutine('固定'), id: 'fixed-id' });
    expect(row.id).toBe('fixed-id');
  });

  it('find / where で絞り込める', async () => {
    await insertMany<Routine>(COLLECTIONS.routines, [newRoutine('A'), newRoutine('B')]);
    const all = await list<Routine>(COLLECTIONS.routines);

    expect(all).toHaveLength(2);
    expect(await find<Routine>(COLLECTIONS.routines, all[0].id)).not.toBeNull();
    expect(await where<Routine>(COLLECTIONS.routines, r => r.name === 'B')).toHaveLength(1);
  });

  it('update は updated_at を進める', async () => {
    const row = await insert<Routine>(COLLECTIONS.routines, newRoutine('元の名前'));
    await new Promise(r => setTimeout(r, 5));

    const updated = await update<Routine>(COLLECTIONS.routines, row.id, { name: '新しい名前' });

    expect(updated?.name).toBe('新しい名前');
    expect(new Date(updated!.updated_at).getTime()).toBeGreaterThanOrEqual(new Date(row.updated_at).getTime());
  });

  it('存在しないIDのupdateはnullを返す', async () => {
    expect(await update<Routine>(COLLECTIONS.routines, 'missing', { name: 'x' })).toBeNull();
  });
});

describe('論理削除', () => {
  it('softDelete した行は list から消えるが、生データには残る', async () => {
    const row = await insert<Routine>(COLLECTIONS.routines, newRoutine('消す'));

    expect(await softDelete(COLLECTIONS.routines, row.id)).toBe(true);
    expect(await list<Routine>(COLLECTIONS.routines)).toHaveLength(0);

    // 削除されたという事実が同期先に伝わる必要があるので、行自体は残す
    const raw = await listRaw<Routine>(COLLECTIONS.routines);
    expect(raw).toHaveLength(1);
    expect(raw[0].deleted_at).not.toBeNull();
  });

  it('softDeleteWhere は条件に合う行だけ消し、件数を返す', async () => {
    await insertMany<Routine>(COLLECTIONS.routines, [newRoutine('残す'), newRoutine('消す'), newRoutine('消す')]);

    const count = await softDeleteWhere(COLLECTIONS.routines, row => (row as any).name === '消す');

    expect(count).toBe(2);
    expect(await list<Routine>(COLLECTIONS.routines)).toHaveLength(1);
  });

  it('削除済みの行を再度softDeleteしても二重に数えない', async () => {
    await insert<Routine>(COLLECTIONS.routines, newRoutine('消す'));
    await softDeleteWhere(COLLECTIONS.routines, () => true);

    expect(await softDeleteWhere(COLLECTIONS.routines, () => true)).toBe(0);
  });
});

describe('メタ情報', () => {
  it('初期値を返し、部分更新できる', async () => {
    const meta = await getMeta();
    expect(meta.seeded).toBe(false);

    await setMeta({ seeded: true });
    const updated = await getMeta();

    expect(updated.seeded).toBe(true);
    expect(updated.schemaVersion).toBe(meta.schemaVersion);
  });
});

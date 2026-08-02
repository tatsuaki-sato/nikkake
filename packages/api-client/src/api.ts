import { GraphQLClient } from './client';
import { OfflineQueue, type QueuedOp } from './queue';
import type { KeyValueStore } from './storage';
import * as ops from './operations';
import type {
  Exercise, ExerciseProgressPoint, HomeView, ProgressView, RecordedSetInput,
  Routine, RoutineExerciseInput, UserError, Viewer, WorkoutSession, WorkoutSummary, Streak,
} from './types';
import { currentTimeZone, getDateString, uuid } from '@nikkake/domain';

const TOKEN_KEY = 'nikkake:v2:token';

export interface MutationResult<T> {
  data: T | null;
  userErrors: UserError[];
}

/**
 * 画面が触る唯一のAPI。
 *
 * 遅延登録（ensureSession）を内蔵している。初回起動時にサーバへ匿名アカウントを
 * 作りに行くが、失敗してもここでは例外にせず、次の操作で再試行する。
 * そうしないとアプリを入れた直後に圏外だと1歩も動かない。
 */
export class NikkakeApi {
  readonly queue: OfflineQueue;
  private readonly client: GraphQLClient;
  private sessionPromise: Promise<string | null> | null = null;
  private withStarterRoutine = true;

  constructor(
    private readonly store: KeyValueStore,
    endpoint = '/graphql',
  ) {
    this.queue = new OfflineQueue(store);
    this.client = new GraphQLClient({
      endpoint,
      getToken: () => this.store.get(TOKEN_KEY),
      credentials: 'include',
    });
  }

  get token(): string | null {
    return this.store.get(TOKEN_KEY);
  }

  hasSession(): boolean {
    return this.token !== null;
  }

  /**
   * トークンが無ければ匿名アカウントを作る。
   * 同時に何度呼ばれても1回しか作らない（並行実行で複数アカウントを作らないため）。
   */
  async ensureSession(): Promise<string | null> {
    const existing = this.token;
    if (existing) return existing;

    this.sessionPromise ??= this.createAnonymousSession().finally(() => {
      this.sessionPromise = null;
    });

    return this.sessionPromise;
  }

  /**
   * 初期ルーティンをサーバに作らせない。
   * ネイティブは端末側でシードしてから importSnapshot するので、
   * 両方で作ると「いつものルーティン」が2つ並ぶ。
   * ensureSession より前に呼ぶこと。
   */
  suppressStarterRoutine(): void {
    this.withStarterRoutine = false;
  }

  private async createAnonymousSession(): Promise<string | null> {
    try {
      const data = await this.client.request<{
        createAnonymousAccount: { token: string | null; userErrors: UserError[] };
      }>(ops.CREATE_ANONYMOUS_ACCOUNT, {
        timeZone: currentTimeZone(),
        withStarterRoutine: this.withStarterRoutine,
      });

      const token = data.createAnonymousAccount.token;
      if (token) this.store.set(TOKEN_KEY, token);
      return token;
    } catch {
      // 圏外でもアプリは動く。次の操作で再試行する
      return null;
    }
  }

  clearSession(): void {
    this.store.remove(TOKEN_KEY);
  }

  // ---------- 参照 ----------

  async home(today = getDateString()): Promise<HomeView> {
    await this.ensureSession();
    const data = await this.client.request<{ home: HomeView }>(ops.HOME, {
      today,
      timeZone: currentTimeZone(),
    });
    return data.home;
  }

  async routines(): Promise<Routine[]> {
    await this.ensureSession();
    return (await this.client.request<{ routines: Routine[] }>(ops.ROUTINES)).routines;
  }

  async routine(id: string): Promise<Routine | null> {
    await this.ensureSession();
    return (await this.client.request<{ routine: Routine | null }>(ops.ROUTINE, { id })).routine;
  }

  async exercises(): Promise<Exercise[]> {
    await this.ensureSession();
    return (await this.client.request<{ exercises: Exercise[] }>(ops.EXERCISES)).exercises;
  }

  async workoutSession(routineId: string): Promise<WorkoutSession> {
    await this.ensureSession();
    const data = await this.client.request<{ workoutSession: WorkoutSession }>(
      ops.WORKOUT_SESSION, { routineId },
    );
    return data.workoutSession;
  }

  async progress(today = getDateString(), rangeDays = 7): Promise<ProgressView> {
    await this.ensureSession();
    const data = await this.client.request<{ progress: ProgressView }>(ops.PROGRESS, {
      today, timeZone: currentTimeZone(), rangeDays,
    });
    return data.progress;
  }

  async exerciseProgress(exerciseId: string, limit = 8): Promise<ExerciseProgressPoint[]> {
    await this.ensureSession();
    const data = await this.client.request<{ exerciseProgress: ExerciseProgressPoint[] }>(
      ops.EXERCISE_PROGRESS, { exerciseId, limit },
    );
    return data.exerciseProgress;
  }

  async viewer(): Promise<Viewer> {
    await this.ensureSession();
    return (await this.client.request<{ viewer: Viewer }>(ops.VIEWER)).viewer;
  }

  // ---------- 更新（オンライン必須） ----------

  async createRoutine(input: {
    name: string; description?: string | null; icon: string; color: string;
    frequencyType: Routine['frequencyType']; frequencyValue?: number; frequencyDays?: number[];
    exercises: RoutineExerciseInput[];
  }): Promise<MutationResult<Routine>> {
    await this.ensureSession();
    const data = await this.client.request<{
      createRoutine: { routine: Routine | null; userErrors: UserError[] };
    }>(ops.CREATE_ROUTINE, { id: uuid(), frequencyValue: 1, frequencyDays: [], ...input });

    return { data: data.createRoutine.routine, userErrors: data.createRoutine.userErrors };
  }

  async updateRoutine(input: {
    id: string; name: string; description?: string | null; icon: string; color: string;
    frequencyType: Routine['frequencyType']; frequencyValue?: number; frequencyDays?: number[];
    isActive?: boolean; lockVersion: number; exercises: RoutineExerciseInput[];
  }): Promise<MutationResult<Routine>> {
    await this.ensureSession();
    const data = await this.client.request<{
      updateRoutine: { routine: Routine | null; userErrors: UserError[] };
    }>(ops.UPDATE_ROUTINE, { frequencyValue: 1, frequencyDays: [], isActive: true, ...input });

    return { data: data.updateRoutine.routine, userErrors: data.updateRoutine.userErrors };
  }

  async deleteRoutine(id: string): Promise<MutationResult<{ id: string }>> {
    await this.ensureSession();
    const data = await this.client.request<{
      deleteRoutine: { routine: { id: string } | null; userErrors: UserError[] };
    }>(ops.DELETE_ROUTINE, { id });

    return { data: data.deleteRoutine.routine, userErrors: data.deleteRoutine.userErrors };
  }

  async setRoutineActive(id: string, isActive: boolean): Promise<MutationResult<Routine>> {
    await this.ensureSession();
    const data = await this.client.request<{
      setRoutineActive: { routine: Routine | null; userErrors: UserError[] };
    }>(ops.SET_ROUTINE_ACTIVE, { id, isActive });

    return { data: data.setRoutineActive.routine, userErrors: data.setRoutineActive.userErrors };
  }

  async createCustomExercise(input: {
    name: string; category: Exercise['category']; icon?: string | null;
  }): Promise<MutationResult<Exercise>> {
    await this.ensureSession();
    const data = await this.client.request<{
      createCustomExercise: { exercise: Exercise | null; userErrors: UserError[] };
    }>(ops.CREATE_CUSTOM_EXERCISE, { id: uuid(), icon: null, ...input });

    return {
      data: data.createCustomExercise.exercise,
      userErrors: data.createCustomExercise.userErrors,
    };
  }

  // ---------- 記録（オフライン可） ----------

  /**
   * ワークアウトを記録する。
   * オフラインならキューに積み、オンライン復帰時に送る。
   * id はクライアント生成なので、再送しても二重登録されない。
   */
  async recordWorkout(input: {
    routineId: string; logDate: string; startedAt: string;
    durationSec: number; totalSets: number; sets: RecordedSetInput[];
  }): Promise<MutationResult<{ summary: WorkoutSummary; streak: Streak }>> {
    const id = uuid();
    const variables = {
      id, ...input, timeZone: currentTimeZone(), clientMutationId: id,
    };

    try {
      await this.ensureSession();
      const data = await this.client.request<{
        recordWorkout: {
          summary: WorkoutSummary | null; streak: Streak | null; userErrors: UserError[];
        };
      }>(ops.RECORD_WORKOUT, variables);

      const payload = data.recordWorkout;
      if (payload.userErrors.length > 0) return { data: null, userErrors: payload.userErrors };

      return {
        data: { summary: payload.summary!, streak: payload.streak! },
        userErrors: [],
      };
    } catch {
      // 送れなかったのでキューへ。画面は成功として進める（記録は失われない）
      this.queue.enqueue({ id, kind: 'recordWorkout', payload: variables });
      return { data: null, userErrors: [] };
    }
  }

  /** キューを送る。フォアグラウンド復帰・オンライン復帰・記録直後に呼ぶ */
  async flushQueue(): Promise<{ sent: number; remaining: number }> {
    if (!this.hasSession()) {
      const token = await this.ensureSession();
      if (!token) return { sent: 0, remaining: this.queue.pending().length };
    }

    return this.queue.flush(async (op: QueuedOp) => {
      if (op.kind === 'recordWorkout') {
        await this.client.request(ops.RECORD_WORKOUT, op.payload);
      }
    });
  }

  // ---------- アカウント ----------

  /**
   * いま使っている匿名アカウントにメールとパスワードを足す。
   * 新しいアカウントを作るのではないので user.id は変わらず、記録は1件も移動しない。
   */
  async attachEmailPassword(
    email: string, password: string, displayName?: string | null,
  ): Promise<MutationResult<Viewer>> {
    await this.ensureSession();
    const data = await this.client.request<{
      attachEmailPassword: { viewer: Viewer | null; userErrors: UserError[] };
    }>(ops.ATTACH_EMAIL_PASSWORD, { email, password, displayName: displayName ?? null });

    return { data: data.attachEmailPassword.viewer, userErrors: data.attachEmailPassword.userErrors };
  }

  async linkExistingAccount(
    email: string, password: string, merge: boolean,
  ): Promise<MutationResult<Viewer>> {
    await this.ensureSession();
    const data = await this.client.request<{
      linkExistingAccount: { token: string | null; viewer: Viewer | null; userErrors: UserError[] };
    }>(ops.LINK_EXISTING_ACCOUNT, { email, password, merge });

    const payload = data.linkExistingAccount;
    if (payload.token) this.store.set(TOKEN_KEY, payload.token);

    return { data: payload.viewer, userErrors: payload.userErrors };
  }

  /**
   * 端末に溜まっているデータをサーバへ丸ごと預ける。遅延登録の後半。
   * 主キーはクライアント生成なので、二重に呼んでも増えない（ON CONFLICT で吸収）。
   */
  async importSnapshot(snapshot: {
    exercises?: unknown[]; routines?: unknown[]; routineExercises?: unknown[];
    routineLogs?: unknown[]; exerciseLogs?: unknown[];
  }): Promise<{ imported: Record<string, number>; userErrors: UserError[] }> {
    await this.ensureSession();
    const data = await this.client.request<{
      importSnapshot: { imported: Record<string, number>; userErrors: UserError[] };
    }>(ops.IMPORT_SNAPSHOT, {
      exercises: [], routines: [], routineExercises: [],
      routineLogs: [], exerciseLogs: [], ...snapshot,
    });

    return data.importSnapshot;
  }

  async signOut(): Promise<void> {
    try {
      await this.client.request(ops.SIGN_OUT);
    } finally {
      this.clearSession();
    }
  }

  async resetData(): Promise<void> {
    await this.ensureSession();
    await this.client.request(ops.RESET_DATA);
  }
}

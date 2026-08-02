import '../models/models.dart';
import 'local_db.dart';
import 'nikkake_repository.dart';
import 'repository.dart';
import 'server_repository.dart';
import 'time_zone.dart';

/// データの取得元。
///
/// local  : 端末のストレージが真実の源。ネットワークを一切使わない（移行前の挙動）
/// server : Rails の GraphQL が真実の源。集計もサーバが返す
///
///     flutter run --dart-define=BACKEND=server
///
/// 移行中は両方を残し、同じテストが両方で通ることを
/// 「挙動が変わっていない」ことの証明にしている。
const backend = String.fromEnvironment('BACKEND', defaultValue: 'local');

/// 既定は 127.0.0.1。実機やエミュレータから見るときは
/// --dart-define=API_ENDPOINT=... で上書きする（端末から見た localhost は端末自身）。
const apiEndpoint =
    String.fromEnvironment('API_ENDPOINT', defaultValue: 'http://127.0.0.1:3000/graphql');

bool get isServerBackend => backend == 'server';

/// 実行時の切り替えを担う。
///
/// サーバモードでも、サーバへの登録と端末データの預け入れが済むまでは
/// ローカル実装で動く（遅延登録）。こうしないと、アプリを入れた直後に
/// 圏外だとホームが空になる。
///
/// **実装を起動時に固定してはいけない。** 固定するとローカルのまま戻らない。
/// そのため自身が NikkakeRepository として振る舞い、呼び出しのたびに
/// current へ委譲する。画面もストアも切り替えを意識しなくてよい。
class BackendSwitch implements NikkakeRepository {
  BackendSwitch({required this.db, ServerRepository? server})
      : local = Repository(db) {
    this.server = isServerBackend
        ? (server ?? ServerRepository(db: db, local: local, endpoint: apiEndpoint))
        : null;
  }

  final LocalDb db;
  final Repository local;
  late final ServerRepository? server;

  bool _ready = false;

  /// サーバの応答を使ってよいか。false のあいだはローカル実装で動く
  bool get isServerReady => _ready && server != null;

  NikkakeRepository get current => isServerReady ? server! : local;

  /// 画面を出すのに必要な準備。ネットワークを使わないので必ず終わる
  Future<void> prepareLocalData() async {
    // タイムゾーンの解決はプラットフォームチャネル越しなので、
    // 記録のたびに呼ばず起動時に1回だけ引く
    await DeviceTimeZone.resolve();
    await local.seedIfNeeded();
  }

  /// サーバへの遅延登録。呼び出し側は結果を待たない。
  /// 失敗しても例外を投げない（起動を巻き添えにしない）。
  Future<bool> registerInBackground() async {
    final api = server;
    if (api == null) return false;

    try {
      // 端末側でシード済みなので、サーバにもう1つ作らせない。
      // 両方で作ると「いつものルーティン」が2つ並ぶ
      api.suppressStarterRoutine();

      final token = await api.ensureSession();
      if (token == null) return false;

      await api.importSnapshot();

      // ここから先はサーバが真実の源
      _ready = true;

      // 切り替えの直前に端末へ書かれた分を拾う。
      // 登録が終わる前でもユーザーは操作できる（それがこの設計の目的）ので、
      // 1回目の預け入れと切り替えのあいだに書かれた記録が取り残される。
      // ID は端末生成で ON CONFLICT DO NOTHING に吸収されるため再送は安全。
      await Future<void>.delayed(Duration.zero);
      await api.importSnapshot(force: true);

      // 圏外中に溜まった記録を送る
      unawaited(api.flushQueue());

      return true;
    } catch (_) {
      // 圏外・サーバ停止・不正な応答。次の起動で再試行する
      return false;
    }
  }

  // ==============================
  // 委譲
  // ==============================
  //
  // 呼び出しのたびに current を引く。ここを変数に束ねてはいけない。

  @override
  Future<bool> seedIfNeeded() => current.seedIfNeeded();

  @override
  Future<HomeView> getHome([DateTime? now]) => current.getHome(now);

  @override
  Future<ProgressView> getProgress({int rangeDays = 7, DateTime? now}) =>
      current.getProgress(rangeDays: rangeDays, now: now);

  @override
  Future<List<ExerciseProgressPoint>> getExerciseProgressPoints(
    String exerciseId, {
    int limit = 8,
  }) =>
      current.getExerciseProgressPoints(exerciseId, limit: limit);

  @override
  Future<WorkoutSessionView?> getWorkoutSession(String routineId) =>
      current.getWorkoutSession(routineId);

  @override
  Future<List<Exercise>> listExercises() => current.listExercises();

  @override
  Future<List<RoutineWithExercises>> listRoutinesWithExercises() =>
      current.listRoutinesWithExercises();

  @override
  Future<RoutineWithExercises?> getRoutineWithExercises(String routineId) =>
      current.getRoutineWithExercises(routineId);

  @override
  Future<Exercise> createCustomExercise({
    required String name,
    required ExerciseCategory category,
    String? icon,
  }) =>
      current.createCustomExercise(name: name, category: category, icon: icon);

  @override
  Future<Routine> createRoutine(RoutineInput input) => current.createRoutine(input);

  @override
  Future<Routine?> updateRoutine(String routineId, RoutineInput input) =>
      current.updateRoutine(routineId, input);

  @override
  Future<void> setRoutineActive(String routineId, bool isActive) =>
      current.setRoutineActive(routineId, isActive);

  @override
  Future<void> deleteRoutine(String routineId) => current.deleteRoutine(routineId);

  @override
  Future<WorkoutSummary> saveWorkout({
    required String routineId,
    required DateTime startedAt,
    required int durationSec,
    required List<SaveWorkoutExercise> exercises,
    String? notes,
  }) =>
      current.saveWorkout(
        routineId: routineId,
        startedAt: startedAt,
        durationSec: durationSec,
        exercises: exercises,
        notes: notes,
      );

  @override
  Future<DataCounts> getCounts() => current.getCounts();

  @override
  Future<void> resetAll() => current.resetAll();

  @override
  Future<int> pendingCount() => current.pendingCount();
}

/// 結果を待たないことを明示する
void unawaited(Future<void> future) {}

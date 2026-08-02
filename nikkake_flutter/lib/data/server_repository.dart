import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../domain/date_utils.dart';
import '../models/models.dart';
import 'graphql_client.dart';
import 'local_db.dart';
import 'time_zone.dart';
import 'nikkake_repository.dart';
import 'offline_queue.dart';
import 'operations.dart' as ops;
import 'repository.dart';

/// Rails の GraphQL を真実の源とする実装。
///
/// 集計は一切しない。getHome / getProgress / getWorkoutSession は
/// サーバが組み立てたものをそのまま画面へ渡す。
/// ここに計算が生えたら、それはサーバへ移すべきロジックが漏れている合図。
///
/// 例外はワークアウト記録で、圏外のときだけ手元で暫定のサマリーを作る。
/// サーバの応答を待たないと結果画面が出せない、という状態を避けるため。
class ServerRepository implements NikkakeRepository {
  ServerRepository({
    required this.db,
    required this.local,
    required String endpoint,
    GraphQLClient? client,
  }) : queue = OfflineQueue(db) {
    _client = client ??
        GraphQLClient(endpoint: endpoint, readToken: () => db.getMeta().apiToken);
  }

  static const _uuid = Uuid();

  final LocalDb db;

  /// 端末シードと、未登録のあいだの読み書きを担う。捨てない
  final Repository local;
  final OfflineQueue queue;
  late final GraphQLClient _client;

  bool _withStarterRoutine = true;

  String? get token => db.getMeta().apiToken;
  bool get hasSession => token != null;

  /// 初期ルーティンをサーバに作らせない。
  /// 端末側でシードしてから預けるので、両方で作ると2つ並ぶ。
  void suppressStarterRoutine() => _withStarterRoutine = false;

  // ==============================
  // 遅延登録
  // ==============================

  @override
  Future<bool> seedIfNeeded() => local.seedIfNeeded();

  /// 匿名アカウントを作る。圏外なら null を返すだけで、例外にしない。
  /// ここで投げるとアプリを入れた直後に圏外だと1歩も動かなくなる。
  Future<String?> ensureSession() async {
    final existing = token;
    if (existing != null) return existing;

    try {
      final data = await _client.request(ops.createAnonymousAccount, {
        'timeZone': DeviceTimeZone.name,
        'withStarterRoutine': _withStarterRoutine,
      });

      final issued =
          (data['createAnonymousAccount'] as Map<String, dynamic>)['token'] as String?;
      if (issued != null) await db.setMeta(apiToken: issued);
      return issued;
    } catch (_) {
      return null;
    }
  }

  /// 端末のデータをまるごとサーバへ預ける。
  ///
  /// 起動のたびに送ってはいけない。以降の書き込みはサーバが正になるので、
  /// 繰り返すとサーバ側で消したルーティンが端末のコピーから復活する。
  /// force は「切り替え直前に書かれたぶんを拾う」ためだけに使う。
  Future<bool> importSnapshot({bool force = false}) async {
    if (db.getMeta().snapshotImportedAt != null && !force) return false;

    final exercises = db
        .listRaw(Collections.exercises)
        // プリセット種目はサーバが持っている。送ると is_preset を上書きしてしまう
        .where((e) => e['is_preset'] != true)
        .toList();

    final data = await _client.request(ops.importSnapshot, {
      'exercises': exercises,
      'routines': db.listRaw(Collections.routines),
      'routineExercises': db.listRaw(Collections.routineExercises),
      'routineLogs': db.listRaw(Collections.routineLogs),
      'exerciseLogs': db.listRaw(Collections.exerciseLogs),
    });

    final errors =
        (data['importSnapshot'] as Map<String, dynamic>)['userErrors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) return false;

    await db.setMeta(snapshotImportedAt: DateTime.now().toUtc().toIso8601String());
    return true;
  }

  /// 圏外中に溜まった記録を送る
  Future<int> flushQueue() => queue.flush((op) async {
        await _client.request(ops.recordWorkout, op.payload);
      });

  // ==============================
  // サーバ表現 → 端末表現
  // ==============================

  static DateTime get _now => DateTime.now().toUtc();

  static Exercise _exercise(Map<String, dynamic> e) => Exercise(
        id: e['id'] as String,
        name: e['name'] as String,
        category: exerciseCategoryFrom((e['category'] as String).toLowerCase()),
        icon: e['icon'] as String?,
        isPreset: e['isPreset'] as bool? ?? false,
        createdAt: _now,
        updatedAt: _now,
      );

  static RoutineWithExercises _routine(Map<String, dynamic> r) {
    final routine = Routine(
      id: r['id'] as String,
      name: r['name'] as String,
      description: r['description'] as String?,
      color: r['color'] as String,
      icon: r['icon'] as String,
      frequencyType: frequencyTypeFrom((r['frequencyType'] as String).toLowerCase()),
      frequencyValue: r['frequencyValue'] as int? ?? 1,
      frequencyDays: ((r['frequencyDays'] as List?) ?? const []).cast<int>(),
      isActive: r['isActive'] as bool? ?? true,
      sortOrder: r['sortOrder'] as int? ?? 0,
      createdAt: _now,
      updatedAt: _now,
    );

    final links = ((r['routineExercises'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((l) {
      final exercise = _exercise(l['exercise'] as Map<String, dynamic>);
      return RoutineExerciseWithExercise(
        link: RoutineExercise(
          id: l['id'] as String,
          routineId: routine.id,
          exerciseId: exercise.id,
          sortOrder: l['sortOrder'] as int? ?? 0,
          targetSets: l['targetSets'] as int? ?? 3,
          targetReps: l['targetReps'] as int?,
          targetWeight: (l['targetWeight'] as num?)?.toDouble(),
          targetDurationSec: l['targetDurationSec'] as int?,
          restSec: l['restSec'] as int?,
          createdAt: _now,
          updatedAt: _now,
        ),
        exercise: exercise,
      );
    }).toList();

    return RoutineWithExercises(routine: routine, exercises: links);
  }

  static TodayRoutine _todayRoutine(Map<String, dynamic> t) => TodayRoutine(
        routine: _routine(t['routine'] as Map<String, dynamic>),
        isDueToday: t['isDueToday'] as bool? ?? false,
        isCompleted: t['isCompleted'] as bool? ?? false,
        frequencyLabel: t['frequencyLabel'] as String? ?? '',
      );

  static StreakInfo _streak(Map<String, dynamic>? s) => StreakInfo(
        current: s?['current'] as int? ?? 0,
        longest: s?['longest'] as int? ?? 0,
        lastCompletedDate: s?['lastCompletedDate'] as String?,
      );

  /// 楽観ロック用。サーバが返した版を覚えておく
  final Map<String, int> _lockVersions = {};

  Map<String, dynamic> _remember(Map<String, dynamic> r) {
    _lockVersions[r['id'] as String] = r['lockVersion'] as int? ?? 0;
    return r;
  }

  // ==============================
  // 参照
  // ==============================

  @override
  Future<HomeView> getHome([DateTime? now]) async {
    final data = await _client.request(ops.home, {
      // 「今日」は必ず端末が決める。サーバに求めさせるとTZで1日ずれる
      'today': getDateString(now),
      'timeZone': DeviceTimeZone.name,
    });

    final view = data['home'] as Map<String, dynamic>;
    List<TodayRoutine> group(String key) => ((view[key] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_todayRoutine)
        .toList();

    return HomeView(
      today: view['today'] as String,
      streak: _streak(view['streak'] as Map<String, dynamic>?),
      due: group('due'),
      notScheduled: group('notScheduled'),
      completed: group('completed'),
    );
  }

  @override
  Future<ProgressView> getProgress({int rangeDays = 7, DateTime? now}) async {
    final data = await _client.request(ops.progress, {
      'today': getDateString(now),
      'timeZone': DeviceTimeZone.name,
      'rangeDays': rangeDays,
    });

    final view = data['progress'] as Map<String, dynamic>;
    final overall = view['overall'] as Map<String, dynamic>;

    return ProgressView(
      overall: OverallStats(
        totalWorkouts: overall['totalWorkouts'] as int? ?? 0,
        thisWeekCount: overall['thisWeekCount'] as int? ?? 0,
        totalDurationSec: overall['totalDurationSec'] as int? ?? 0,
        totalSets: overall['totalSets'] as int? ?? 0,
      ),
      streak: _streak(view['streak'] as Map<String, dynamic>?),
      dailyStats: ((view['dailyStats'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((d) => DailyStats(
                date: d['date'] as String,
                completedCount: d['completedCount'] as int? ?? 0,
                totalCount: d['totalCount'] as int? ?? 0,
              ))
          .toList(),
      completedDates: ((view['completedDates'] as List?) ?? const []).cast<String>().toSet(),
      exercisesWithLogs: ((view['exercisesWithLogs'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_exercise)
          .toList(),
    );
  }

  @override
  Future<List<ExerciseProgressPoint>> getExerciseProgressPoints(
    String exerciseId, {
    int limit = 8,
  }) async {
    final data = await _client
        .request(ops.exerciseProgress, {'exerciseId': exerciseId, 'limit': limit});

    return ((data['exerciseProgress'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((p) => ExerciseProgressPoint(
              date: p['date'] as String,
              maxWeight: (p['maxWeight'] as num?)?.toDouble() ?? 0,
              totalReps: p['totalReps'] as int? ?? 0,
              totalVolume: (p['totalVolume'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  @override
  Future<WorkoutSessionView?> getWorkoutSession(String routineId) async {
    final data = await _client.request(ops.workoutSession, {'routineId': routineId});
    final session = data['workoutSession'] as Map<String, dynamic>?;
    if (session == null) return null;

    final routine = _remember(session['routine'] as Map<String, dynamic>);

    return WorkoutSessionView(
      routine: _routine(routine),
      exercises: ((session['exercises'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((e) => WorkoutSessionEntry(
                routineExerciseId: e['routineExerciseId'] as String,
                exercise: _exercise(e['exercise'] as Map<String, dynamic>),
                targetSets: e['targetSets'] as int? ?? 3,
                targetReps: e['targetReps'] as int?,
                targetWeight: (e['targetWeight'] as num?)?.toDouble(),
                targetDurationSec: e['targetDurationSec'] as int?,
                restSec: e['restSec'] as int? ?? 60,
                previousSets: ((e['previousSets'] as List?) ?? const [])
                    .cast<Map<String, dynamic>>()
                    .map((s) => WorkoutSet(
                          setNumber: s['setNumber'] as int,
                          reps: s['reps'] as int?,
                          weight: (s['weight'] as num?)?.toDouble(),
                          durationSec: s['durationSec'] as int?,
                          completed: true,
                        ))
                    .toList(),
                previousLabel: e['previousLabel'] as String?,
              ))
          .toList(),
    );
  }

  @override
  Future<List<Exercise>> listExercises() async {
    final data = await _client.request(ops.exercises);
    return ((data['exercises'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_exercise)
        .toList();
  }

  @override
  Future<List<RoutineWithExercises>> listRoutinesWithExercises() async {
    final data = await _client.request(ops.routines);
    return ((data['routines'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((r) => _routine(_remember(r)))
        .toList();
  }

  @override
  Future<RoutineWithExercises?> getRoutineWithExercises(String routineId) async {
    for (final r in await listRoutinesWithExercises()) {
      if (r.id == routineId) return r;
    }
    return null;
  }

  // ==============================
  // 更新（オンライン必須）
  // ==============================
  //
  // 記録と違ってキューに積まない。
  // 圏外でルーティンを作れると、サーバの採番や検証を通っていない
  // ルーティンに対して記録が積まれ、整合を取る手段が無くなる。

  /// userErrors をそのまま例外に変える。message はそのまま画面に出せる日本語
  static Map<String, dynamic> _unwrap(Map<String, dynamic> payload, String key) {
    final errors = (payload['userErrors'] as List?) ?? const [];
    if (errors.isNotEmpty) {
      throw PermanentFailure(
        (errors.first as Map<String, dynamic>)['message'] as String? ?? '保存できませんでした',
      );
    }

    final value = payload[key] as Map<String, dynamic>?;
    if (value == null) throw const PermanentFailure('保存できませんでした');
    return value;
  }

  static List<Map<String, dynamic>> _exerciseInputs(RoutineInput input) => input.exercises
      .map((e) => {
            'id': _uuid.v4(),
            'exerciseId': e.exerciseId,
            'targetSets': e.targetSets,
            'targetReps': e.targetReps,
            'targetWeight': e.targetWeight,
            'targetDurationSec': e.targetDurationSec,
            'restSec': e.restSec,
          })
      .toList();

  @override
  Future<Routine> createRoutine(RoutineInput input) async {
    final data = await _client.request(ops.createRoutine, {
      'id': _uuid.v4(),
      'name': input.name,
      'description': input.description,
      'icon': input.icon,
      'color': input.color,
      'frequencyType': frequencyTypeToJson(input.frequencyType).toUpperCase(),
      'frequencyValue': input.frequencyValue,
      'frequencyDays': input.frequencyDays,
      'exercises': _exerciseInputs(input),
    });

    final routine = _unwrap(data['createRoutine'] as Map<String, dynamic>, 'routine');
    return _routine(_remember(routine)).routine;
  }

  @override
  Future<Routine?> updateRoutine(String routineId, RoutineInput input) async {
    final data = await _client.request(ops.updateRoutine, {
      'id': routineId,
      'name': input.name,
      'description': input.description,
      'icon': input.icon,
      'color': input.color,
      'frequencyType': frequencyTypeToJson(input.frequencyType).toUpperCase(),
      'frequencyValue': input.frequencyValue,
      'frequencyDays': input.frequencyDays,
      'isActive': input.isActive,
      // 直前に読んだ版を送る。他端末が先に更新していれば CONFLICT で弾かれる
      'lockVersion': _lockVersions[routineId] ?? 0,
      'exercises': _exerciseInputs(input),
    });

    final routine = _unwrap(data['updateRoutine'] as Map<String, dynamic>, 'routine');
    return _routine(_remember(routine)).routine;
  }

  @override
  Future<void> setRoutineActive(String routineId, bool isActive) async {
    final data = await _client
        .request(ops.setRoutineActive, {'id': routineId, 'isActive': isActive});
    _unwrap(data['setRoutineActive'] as Map<String, dynamic>, 'routine');
  }

  @override
  Future<void> deleteRoutine(String routineId) async {
    final data = await _client.request(ops.deleteRoutine, {'id': routineId});
    _unwrap(data['deleteRoutine'] as Map<String, dynamic>, 'routine');
    _lockVersions.remove(routineId);
  }

  @override
  Future<Exercise> createCustomExercise({
    required String name,
    required ExerciseCategory category,
    String? icon,
  }) async {
    final data = await _client.request(ops.createCustomExercise, {
      'id': _uuid.v4(),
      'name': name,
      'category': category.name.toUpperCase(),
      'icon': icon,
    });

    return _exercise(_unwrap(data['createCustomExercise'] as Map<String, dynamic>, 'exercise'));
  }

  // ==============================
  // 記録（オフライン可）
  // ==============================

  @override
  Future<WorkoutSummary> saveWorkout({
    required String routineId,
    required DateTime startedAt,
    required int durationSec,
    required List<SaveWorkoutExercise> exercises,
    String? notes,
  }) async {
    final tally = tallyWorkout(exercises);
    final id = _uuid.v4();

    final sets = <Map<String, dynamic>>[];
    for (final exercise in exercises) {
      for (final set in exercise.sets.where((s) => s.completed)) {
        sets.add({
          'id': _uuid.v4(),
          'routineExerciseId': exercise.routineExerciseId,
          'exerciseId': exercise.exerciseId,
          'setNumber': set.setNumber,
          'actualReps': set.reps,
          'actualWeight': set.weight,
          'actualDurationSec': set.durationSec,
        });
      }
    }

    final variables = {
      'id': id,
      'routineId': routineId,
      // 「今日」は必ず端末が決める
      'logDate': getDateString(startedAt.toLocal()),
      'timeZone': DeviceTimeZone.name,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'durationSec': durationSec,
      'totalSets': tally.totalSets,
      'sets': sets,
      'clientMutationId': id,
    };

    try {
      final data = await _client.request(ops.recordWorkout, variables);
      final payload = data['recordWorkout'] as Map<String, dynamic>;
      final summary = _unwrap(payload, 'summary');

      return WorkoutSummary(
        routineLogId: summary['routineLogId'] as String,
        routineName: summary['routineName'] as String? ?? '',
        durationSec: summary['durationSec'] as int? ?? durationSec,
        completedSets: summary['completedSets'] as int? ?? tally.completedSets,
        totalSets: summary['totalSets'] as int? ?? tally.totalSets,
        totalVolume: (summary['totalVolume'] as num?)?.toDouble() ?? tally.totalVolume,
        status: logStatusFrom((summary['status'] as String).toLowerCase()),
      );
    } on NetworkFailure {
      // 圏外。キューに積むので記録は失われない。
      // 結果画面を出すぶんの数字だけ手元で作る（サーバの判定と同じ基準）
      await queue.enqueue(id, variables);

      return WorkoutSummary(
        routineLogId: id,
        routineName: '',
        durationSec: durationSec,
        completedSets: tally.completedSets,
        totalSets: tally.totalSets,
        totalVolume: tally.totalVolume,
        status: resolveWorkoutStatus(tally.completedSets, tally.totalSets),
      );
    }
  }

  // ==============================
  // 設定
  // ==============================

  @override
  Future<DataCounts> getCounts() async {
    final data = await _client.request(ops.viewer);
    final counts =
        (data['viewer'] as Map<String, dynamic>)['counts'] as Map<String, dynamic>;

    return DataCounts(
      routines: counts['routines'] as int? ?? 0,
      exercises: counts['exercises'] as int? ?? 0,
      routineLogs: counts['routineLogs'] as int? ?? 0,
      exerciseLogs: counts['exerciseLogs'] as int? ?? 0,
    );
  }

  /// サーバのデータを全部消して初期状態に戻す。
  ///
  /// 端末側も一緒に作り直す。サーバだけ消すと、
  /// 次の起動で端末のコピーが預け直されて復活してしまう。
  @override
  Future<void> resetAll() async {
    await _client.request(ops.resetData);
    await local.resetAll();
    await importSnapshot(force: true);
  }

  @override
  Future<int> pendingCount() async => queue.pending().length;

  void close() => _client.close();
}

/// JSON をそのまま埋め込むためのユーティリティ（デバッグ用）
String debugJson(Object? value) => const JsonEncoder.withIndent('  ').convert(value);

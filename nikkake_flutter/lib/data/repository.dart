import '../constants/exercises.dart';
import '../domain/date_utils.dart';
import '../models/models.dart';
import 'local_db.dart';

/// ルーティン内の1種目の設定値
class RoutineExerciseInput {
  final String exerciseId;
  final int targetSets;
  final int? targetReps;
  final double? targetWeight;
  final int? targetDurationSec;
  final int? restSec;

  const RoutineExerciseInput({
    required this.exerciseId,
    this.targetSets = 3,
    this.targetReps,
    this.targetWeight,
    this.targetDurationSec,
    this.restSec,
  });
}

class RoutineInput {
  final String name;
  final String? description;
  final String icon;
  final String color;
  final FrequencyType frequencyType;
  final int frequencyValue;
  final List<int> frequencyDays;
  final bool isActive;
  final List<RoutineExerciseInput> exercises;

  const RoutineInput({
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    this.frequencyType = FrequencyType.daily,
    this.frequencyValue = 1,
    this.frequencyDays = const [],
    this.isActive = true,
    this.exercises = const [],
  });
}

class SaveWorkoutExercise {
  final String routineExerciseId;
  final String exerciseId;
  final List<WorkoutSet> sets;

  const SaveWorkoutExercise({
    required this.routineExerciseId,
    required this.exerciseId,
    required this.sets,
  });
}

/// 画面が直接触るデータAPI。
///
/// 参照も更新も必ずローカルストレージに対して行い、ネットワークは介在しない。
/// サインインしている場合は SyncService がバックグラウンドでSupabaseへ複製するが、
/// 画面はその成否を待たないので、オフラインでも常に即座に応答する。
class Repository {
  final LocalDb db;

  Repository(this.db);

  // ==============================
  // 初期データ
  // ==============================

  /// 初回起動時のデータ投入。
  /// サインインなしで即使えるよう、起動時点で「今日やるルーティン」を1つ用意する。
  /// ユーザーが消したあとに復活すると鬱陶しいので、投入は meta.seeded で1度だけ。
  Future<bool> seedIfNeeded() async {
    final meta = db.getMeta();
    await _syncPresetExercises();

    if (meta.seeded) return false;

    await _createStarterRoutine();
    await db.setMeta(seeded: true);
    return true;
  }

  /// アプリ側の定義に存在してローカルに無いプリセット種目を足す
  Future<int> _syncPresetExercises() async {
    final existingIds = db.listRaw(Collections.exercises).map((r) => r['id'] as String).toSet();
    final missing = presetExercises.where((p) => !existingIds.contains(p.id)).toList();
    if (missing.isEmpty) return 0;

    await db.insertMany(
      Collections.exercises,
      missing
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'category': p.category.name,
                'description': null,
                'icon': p.icon,
                'is_preset': true,
                'created_by': null,
              })
          .toList(),
    );

    return missing.length;
  }

  /// 初期ルーティンのIDは端末ごとに採番する（固定値にしない）。
  ///
  /// ローカルだけで完結していた頃は固定でも無害だったが、
  /// サーバへ預ける今は全端末が同じIDを送ることになり、
  /// 主キー衝突で2人目以降の初期ルーティンが黙って消える。
  Future<void> _createStarterRoutine() async {
    final routineId = LocalDb.newId();

    await db.insert(Collections.routines, {
      'id': routineId,
      'user_id': null,
      'name': starterRoutineName,
      'description': '器具なしで今すぐ始められる基本メニューです。自由に編集してください。',
      'color': routineColors.first,
      'icon': routineIcons.first,
      'frequency_type': 'daily',
      'frequency_value': 1,
      'frequency_days': <int>[],
      'preferred_time': null,
      'is_active': true,
      'sort_order': 0,
    });

    var index = 0;
    await db.insertMany(
      Collections.routineExercises,
      starterRoutineExercises.map((e) {
        final row = {
          'routine_id': routineId,
          'exercise_id': e.exerciseId,
          'sort_order': index,
          'target_sets': e.sets,
          'target_reps': e.reps,
          'target_weight': null,
          'target_duration_sec': e.durationSec,
          'rest_sec': e.restSec,
          'notes': null,
        };
        index++;
        return row;
      }).toList(),
    );
  }

  // ==============================
  // Exercises
  // ==============================

  List<Exercise> listExercises() {
    final rows = db.list(Collections.exercises).map(Exercise.fromJson).toList();
    rows.sort((a, b) {
      if (a.category != b.category) return a.category.index.compareTo(b.category.index);
      return a.name.compareTo(b.name);
    });
    return rows;
  }

  Future<Exercise> createCustomExercise({
    required String name,
    required ExerciseCategory category,
    String? icon,
  }) async {
    final row = await db.insert(Collections.exercises, {
      'name': name,
      'category': category.name,
      'description': null,
      'icon': icon,
      'is_preset': false,
      'created_by': null,
    });
    return Exercise.fromJson(row);
  }

  // ==============================
  // Routines
  // ==============================

  List<Routine> listRoutines() {
    final rows = db.list(Collections.routines).map(Routine.fromJson).toList();
    rows.sort((a, b) {
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return a.createdAt.compareTo(b.createdAt);
    });
    return rows;
  }

  List<RoutineWithExercises> listRoutinesWithExercises() {
    final routines = listRoutines();
    final links = db.list(Collections.routineExercises).map(RoutineExercise.fromJson).toList();
    final exerciseById = {for (final e in listExercises()) e.id: e};

    return routines.map((routine) {
      final own = links.where((l) => l.routineId == routine.id).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return RoutineWithExercises(
        routine: routine,
        exercises: own
            // 種目が削除済みのリンクが残っていても画面を落とさない
            .where((l) => exerciseById.containsKey(l.exerciseId))
            .map((l) => RoutineExerciseWithExercise(link: l, exercise: exerciseById[l.exerciseId]!))
            .toList(),
      );
    }).toList();
  }

  RoutineWithExercises? getRoutineWithExercises(String routineId) {
    for (final r in listRoutinesWithExercises()) {
      if (r.id == routineId) return r;
    }
    return null;
  }

  Future<Routine> createRoutine(RoutineInput input) async {
    final existing = listRoutines();

    final row = await db.insert(Collections.routines, {
      'user_id': null,
      'name': input.name,
      'description': input.description,
      'color': input.color,
      'icon': input.icon,
      'frequency_type': frequencyTypeToJson(input.frequencyType),
      'frequency_value': input.frequencyValue,
      'frequency_days': input.frequencyDays,
      'preferred_time': null,
      'is_active': input.isActive,
      'sort_order': existing.length,
    });

    final routine = Routine.fromJson(row);
    await _replaceRoutineExercises(routine.id, input.exercises);
    return routine;
  }

  Future<Routine?> updateRoutine(String routineId, RoutineInput input) async {
    final row = await db.update(Collections.routines, routineId, {
      'name': input.name,
      'description': input.description,
      'color': input.color,
      'icon': input.icon,
      'frequency_type': frequencyTypeToJson(input.frequencyType),
      'frequency_value': input.frequencyValue,
      'frequency_days': input.frequencyDays,
      'is_active': input.isActive,
    });
    if (row == null) return null;

    await _replaceRoutineExercises(routineId, input.exercises);
    return Routine.fromJson(row);
  }

  /// ルーティン内の種目構成を丸ごと差し替える。
  /// 差分更新にすると並び順の入れ替えが厄介なので、既存リンクを論理削除して作り直す。
  /// 過去のログは exercise_id でも引けるので、作り直しても履歴グラフは途切れない。
  Future<void> _replaceRoutineExercises(
    String routineId,
    List<RoutineExerciseInput> exercises,
  ) async {
    await db.softDeleteWhere(
      Collections.routineExercises,
      (row) => row['routine_id'] == routineId,
    );

    if (exercises.isEmpty) return;

    var index = 0;
    await db.insertMany(
      Collections.routineExercises,
      exercises.map((e) {
        final row = {
          'routine_id': routineId,
          'exercise_id': e.exerciseId,
          'sort_order': index,
          'target_sets': e.targetSets,
          'target_reps': e.targetReps,
          'target_weight': e.targetWeight,
          'target_duration_sec': e.targetDurationSec,
          'rest_sec': e.restSec ?? defaultRestSec,
          'notes': null,
        };
        index++;
        return row;
      }).toList(),
    );
  }

  Future<void> setRoutineActive(String routineId, bool isActive) async {
    await db.update(Collections.routines, routineId, {'is_active': isActive});
  }

  Future<void> deleteRoutine(String routineId) async {
    await db.softDeleteWhere(
      Collections.routineExercises,
      (row) => row['routine_id'] == routineId,
    );
    await db.softDelete(Collections.routines, routineId);
  }

  // ==============================
  // Logs
  // ==============================

  List<RoutineLog> listRoutineLogs() =>
      db.list(Collections.routineLogs).map(RoutineLog.fromJson).toList();

  List<ExerciseLog> listExerciseLogs() =>
      db.list(Collections.exerciseLogs).map(ExerciseLog.fromJson).toList();

  List<RoutineLog> getTodayLogs() {
    final today = getDateString();
    return listRoutineLogs().where((l) => l.logDate == today).toList();
  }

  /// ホーム画面用。ルーティンごとに「今日やるべきか」「今日もう終わったか」を解決して返す
  List<TodayRoutine> getTodayRoutines([DateTime? now]) {
    final today = getDateString(now);
    final logs = listRoutineLogs();

    return listRoutinesWithExercises().where((r) => r.routine.isActive).map((routine) {
      final routineLogs = logs.where((l) => l.routineId == routine.id).toList()
        ..sort((a, b) => b.logDate.compareTo(a.logDate));

      RoutineLog? todayLog;
      RoutineLog? lastLog;
      for (final log in routineLogs) {
        if (todayLog == null && log.logDate == today) todayLog = log;
        if (lastLog == null && log.status != LogStatus.skipped) lastLog = log;
      }

      return TodayRoutine(
        routine: routine,
        // 全セット完了でなくても、記録を残した時点で今日の分は済んだものとして扱う。
        // ストリークの判定(stats.didWorkout)と基準を揃えている。
        isCompleted: todayLog != null && todayLog.status != LogStatus.skipped,
        isDueToday: isRoutineDueToday(routine.routine, lastLog, now),
        lastLog: lastLog,
      );
    }).toList();
  }

  /// ワークアウト1回分の保存
  Future<RoutineLog> saveWorkout({
    required String routineId,
    required DateTime startedAt,
    required int durationSec,
    required LogStatus status,
    required List<SaveWorkoutExercise> exercises,
    String? notes,
  }) async {
    final row = await db.insert(Collections.routineLogs, {
      'routine_id': routineId,
      'user_id': null,
      'log_date': getDateString(startedAt.toLocal()),
      'status': status.name,
      'duration_sec': durationSec,
      'notes': notes,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });

    final routineLog = RoutineLog.fromJson(row);

    final exerciseLogs = <Map<String, dynamic>>[];
    for (final exercise in exercises) {
      for (final set in exercise.sets.where((s) => s.completed)) {
        exerciseLogs.add({
          'routine_log_id': routineLog.id,
          'routine_exercise_id': exercise.routineExerciseId,
          'exercise_id': exercise.exerciseId,
          'set_number': set.setNumber,
          'actual_reps': set.reps,
          'actual_weight': set.weight,
          'actual_duration_sec': set.durationSec,
          'notes': null,
        });
      }
    }

    await db.insertMany(Collections.exerciseLogs, exerciseLogs);
    return routineLog;
  }

  Future<void> deleteRoutineLog(String routineLogId) async {
    await db.softDeleteWhere(
      Collections.exerciseLogs,
      (row) => row['routine_log_id'] == routineLogId,
    );
    await db.softDelete(Collections.routineLogs, routineLogId);
  }

  /// 前回のワークアウトで各種目を何kg×何回やったか。
  /// ワークアウト画面で「前回の記録」を初期値に出すために使う。
  Map<String, List<WorkoutSet>> getLastSetsByExercise(String routineId) {
    final logs = listRoutineLogs()
        .where((l) => l.routineId == routineId && l.status != LogStatus.skipped)
        .toList();
    if (logs.isEmpty) return {};

    logs.sort((a, b) {
      final aAt = a.startedAt ?? a.createdAt;
      final bAt = b.startedAt ?? b.createdAt;
      return bAt.compareTo(aAt);
    });

    final latest = logs.first;
    final result = <String, List<WorkoutSet>>{};

    for (final log in listExerciseLogs().where((l) => l.routineLogId == latest.id)) {
      result.putIfAbsent(log.exerciseId, () => []).add(WorkoutSet(
            setNumber: log.setNumber,
            reps: log.actualReps,
            weight: log.actualWeight,
            durationSec: log.actualDurationSec,
            completed: true,
          ));
    }

    for (final sets in result.values) {
      sets.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    }
    return result;
  }

  /// 設定画面に出すローカル件数
  Map<String, int> getLocalCounts() => {
        for (final c in Collections.all) c: db.list(c).length,
      };

  Future<void> resetAll() async {
    await db.reset();
    await seedIfNeeded();
  }
}

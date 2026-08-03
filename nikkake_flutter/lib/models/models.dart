// ============================================
// nikkake - ドメインモデル (Flutter)
// ============================================
//
// サーバに登録できていないあいだは端末ローカルが真実の源。
// 全エンティティが updatedAt / deletedAt を持つ（deletedAt は論理削除用）。
//
// JSONのキーは Rails の列名(snake_case)に合わせてある。
// 遅延登録で預けるとき(importSnapshot)に変換が要らない。

enum ExerciseCategory { strength, cardio, game, custom }

ExerciseCategory exerciseCategoryFrom(String? value) => ExerciseCategory.values
    .firstWhere((c) => c.name == value, orElse: () => ExerciseCategory.custom);

enum FrequencyType { daily, everyNDays, weekly }

/// DB側は snake_case の文字列なので明示的に対応付ける
const _frequencyToJson = {
  FrequencyType.daily: 'daily',
  FrequencyType.everyNDays: 'every_n_days',
  FrequencyType.weekly: 'weekly',
};

String frequencyTypeToJson(FrequencyType type) => _frequencyToJson[type]!;

FrequencyType frequencyTypeFrom(String? value) => _frequencyToJson.entries
    .firstWhere((e) => e.value == value, orElse: () => const MapEntry(FrequencyType.daily, 'daily'))
    .key;

enum LogStatus { completed, partial, skipped }

LogStatus logStatusFrom(String? value) =>
    LogStatus.values.firstWhere((s) => s.name == value, orElse: () => LogStatus.completed);

/// 端末ローカルのみか、クラウドへバックアップ中か
enum StorageMode { local, cloud }

/// 全エンティティ共通の同期用インターフェース
abstract class SyncEntity {
  String get id;
  DateTime get updatedAt;
  DateTime? get deletedAt;
  Map<String, dynamic> toJson();
}

DateTime _parseDate(dynamic value) =>
    value == null ? DateTime.now().toUtc() : DateTime.parse(value as String).toUtc();

DateTime? _parseNullableDate(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

class Exercise implements SyncEntity {
  @override
  final String id;
  final String name;
  final ExerciseCategory category;
  final String? description;
  final String? icon;
  final bool isPreset;
  final String? createdBy;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.icon,
    this.isPreset = false,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        category: exerciseCategoryFrom(json['category'] as String?),
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        isPreset: json['is_preset'] as bool? ?? false,
        createdBy: json['created_by'] as String?,
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
        deletedAt: _parseNullableDate(json['deleted_at']),
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'description': description,
        'icon': icon,
        'is_preset': isPreset,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };
}

class Routine implements SyncEntity {
  @override
  final String id;

  /// ローカル専用データは null。サインイン後の同期で埋まる
  final String? userId;
  final String name;
  final String? description;
  final String color;
  final String icon;
  final FrequencyType frequencyType;
  final int frequencyValue;
  final List<int> frequencyDays;
  final String? preferredTime;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  const Routine({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    required this.color,
    required this.icon,
    this.frequencyType = FrequencyType.daily,
    this.frequencyValue = 1,
    this.frequencyDays = const [],
    this.preferredTime,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        color: json['color'] as String? ?? '#6C5CE7',
        icon: json['icon'] as String? ?? '💪',
        frequencyType: frequencyTypeFrom(json['frequency_type'] as String?),
        frequencyValue: (json['frequency_value'] as num?)?.toInt() ?? 1,
        frequencyDays:
            ((json['frequency_days'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
        preferredTime: json['preferred_time'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
        deletedAt: _parseNullableDate(json['deleted_at']),
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'description': description,
        'color': color,
        'icon': icon,
        'frequency_type': frequencyTypeToJson(frequencyType),
        'frequency_value': frequencyValue,
        'frequency_days': frequencyDays,
        'preferred_time': preferredTime,
        'is_active': isActive,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };
}

class RoutineExercise implements SyncEntity {
  @override
  final String id;
  final String routineId;
  final String exerciseId;
  final int sortOrder;
  final int targetSets;
  final int? targetReps;
  final double? targetWeight;
  final int? targetDurationSec;
  final int? restSec;
  final String? notes;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  const RoutineExercise({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    this.sortOrder = 0,
    this.targetSets = 3,
    this.targetReps,
    this.targetWeight,
    this.targetDurationSec,
    this.restSec,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> json) => RoutineExercise(
        id: json['id'] as String,
        routineId: json['routine_id'] as String,
        exerciseId: json['exercise_id'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        targetSets: (json['target_sets'] as num?)?.toInt() ?? 3,
        targetReps: (json['target_reps'] as num?)?.toInt(),
        targetWeight: (json['target_weight'] as num?)?.toDouble(),
        targetDurationSec: (json['target_duration_sec'] as num?)?.toInt(),
        restSec: (json['rest_sec'] as num?)?.toInt(),
        notes: json['notes'] as String?,
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
        deletedAt: _parseNullableDate(json['deleted_at']),
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'routine_id': routineId,
        'exercise_id': exerciseId,
        'sort_order': sortOrder,
        'target_sets': targetSets,
        'target_reps': targetReps,
        'target_weight': targetWeight,
        'target_duration_sec': targetDurationSec,
        'rest_sec': restSec,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };
}

class RoutineLog implements SyncEntity {
  @override
  final String id;
  final String routineId;
  final String? userId;

  /// 'YYYY-MM-DD'。日跨ぎの判定はこの値で行う
  final String logDate;
  final LogStatus status;
  final int? durationSec;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  const RoutineLog({
    required this.id,
    required this.routineId,
    this.userId,
    required this.logDate,
    required this.status,
    this.durationSec,
    this.notes,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory RoutineLog.fromJson(Map<String, dynamic> json) => RoutineLog(
        id: json['id'] as String,
        routineId: json['routine_id'] as String,
        userId: json['user_id'] as String?,
        logDate: json['log_date'] as String,
        status: logStatusFrom(json['status'] as String?),
        durationSec: (json['duration_sec'] as num?)?.toInt(),
        notes: json['notes'] as String?,
        startedAt: _parseNullableDate(json['started_at']),
        completedAt: _parseNullableDate(json['completed_at']),
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
        deletedAt: _parseNullableDate(json['deleted_at']),
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'routine_id': routineId,
        'user_id': userId,
        'log_date': logDate,
        'status': status.name,
        'duration_sec': durationSec,
        'notes': notes,
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };
}

class ExerciseLog implements SyncEntity {
  @override
  final String id;
  final String routineLogId;
  final String? routineExerciseId;

  /// ルーティン編集で routine_exercises が作り直されても履歴を辿れるように持つ
  final String exerciseId;
  final int setNumber;
  final int? actualReps;
  final double? actualWeight;
  final int? actualDurationSec;
  final String? notes;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  const ExerciseLog({
    required this.id,
    required this.routineLogId,
    this.routineExerciseId,
    required this.exerciseId,
    required this.setNumber,
    this.actualReps,
    this.actualWeight,
    this.actualDurationSec,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
        id: json['id'] as String,
        routineLogId: json['routine_log_id'] as String,
        routineExerciseId: json['routine_exercise_id'] as String?,
        exerciseId: json['exercise_id'] as String,
        setNumber: (json['set_number'] as num).toInt(),
        actualReps: (json['actual_reps'] as num?)?.toInt(),
        actualWeight: (json['actual_weight'] as num?)?.toDouble(),
        actualDurationSec: (json['actual_duration_sec'] as num?)?.toInt(),
        notes: json['notes'] as String?,
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
        deletedAt: _parseNullableDate(json['deleted_at']),
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'routine_log_id': routineLogId,
        'routine_exercise_id': routineExerciseId,
        'exercise_id': exerciseId,
        'set_number': setNumber,
        'actual_reps': actualReps,
        'actual_weight': actualWeight,
        'actual_duration_sec': actualDurationSec,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };
}

// ============================================
// UI用の合成型
// ============================================

class RoutineExerciseWithExercise {
  final RoutineExercise link;
  final Exercise exercise;

  const RoutineExerciseWithExercise({required this.link, required this.exercise});
}

class RoutineWithExercises {
  final Routine routine;
  final List<RoutineExerciseWithExercise> exercises;

  const RoutineWithExercises({required this.routine, required this.exercises});

  String get id => routine.id;
  String get name => routine.name;
}

class TodayRoutine {
  final RoutineWithExercises routine;
  final bool isCompleted;
  final bool isDueToday;

  /// 「毎日」「3日ごと」。サーバが返す文言をそのまま出す。
  /// クライアントで組み立てると4実装で表記が割れる
  final String frequencyLabel;

  const TodayRoutine({
    required this.routine,
    required this.isCompleted,
    required this.isDueToday,
    this.frequencyLabel = '',
  });
}

class WorkoutSet {
  final int setNumber;
  final int? reps;
  final double? weight;
  final int? durationSec;
  final bool completed;

  const WorkoutSet({
    required this.setNumber,
    this.reps,
    this.weight,
    this.durationSec,
    this.completed = false,
  });

  /// null を明示的に入れたい場合があるので clearXxx フラグを別途持たせている
  WorkoutSet copyWith({
    int? reps,
    double? weight,
    int? durationSec,
    bool? completed,
    bool clearReps = false,
    bool clearWeight = false,
    bool clearDuration = false,
  }) =>
      WorkoutSet(
        setNumber: setNumber,
        reps: clearReps ? null : (reps ?? this.reps),
        weight: clearWeight ? null : (weight ?? this.weight),
        durationSec: clearDuration ? null : (durationSec ?? this.durationSec),
        completed: completed ?? this.completed,
      );
}

class WorkoutExerciseState {
  final String routineExerciseId;
  final Exercise exercise;
  final int targetSets;
  final int? targetReps;
  final double? targetWeight;
  final int? targetDurationSec;
  final int restSec;
  final List<WorkoutSet> sets;
  final List<WorkoutSet> previousSets;

  const WorkoutExerciseState({
    required this.routineExerciseId,
    required this.exercise,
    required this.targetSets,
    this.targetReps,
    this.targetWeight,
    this.targetDurationSec,
    required this.restSec,
    required this.sets,
    this.previousSets = const [],
  });

  bool get isTimeBased => targetDurationSec != null;

  WorkoutExerciseState copyWith({List<WorkoutSet>? sets}) => WorkoutExerciseState(
        routineExerciseId: routineExerciseId,
        exercise: exercise,
        targetSets: targetSets,
        targetReps: targetReps,
        targetWeight: targetWeight,
        targetDurationSec: targetDurationSec,
        restSec: restSec,
        sets: sets ?? this.sets,
        previousSets: previousSets,
      );
}

class WorkoutSummary {
  final String routineLogId;
  final String routineName;
  final int durationSec;
  final int completedSets;
  final int totalSets;
  final double totalVolume;
  final LogStatus status;

  const WorkoutSummary({
    required this.routineLogId,
    required this.routineName,
    required this.durationSec,
    required this.completedSets,
    required this.totalSets,
    required this.totalVolume,
    required this.status,
  });
}

// ============================================
// 統計
// ============================================

class StreakInfo {
  final int current;
  final int longest;
  final String? lastCompletedDate;

  const StreakInfo({required this.current, required this.longest, this.lastCompletedDate});
}

class DailyStats {
  final String date;
  final int completedCount;
  final int totalCount;

  const DailyStats({required this.date, required this.completedCount, required this.totalCount});
}

class ExerciseProgressPoint {
  final String date;
  final double maxWeight;
  final int totalReps;
  final double totalVolume;

  const ExerciseProgressPoint({
    required this.date,
    required this.maxWeight,
    required this.totalReps,
    required this.totalVolume,
  });
}

class OverallStats {
  final int totalWorkouts;
  final int totalDurationSec;
  final int totalSets;
  final int thisWeekCount;

  const OverallStats({
    required this.totalWorkouts,
    required this.totalDurationSec,
    required this.totalSets,
    required this.thisWeekCount,
  });
}

/// サーバから見た「いまのアカウント」。
///
/// isAnonymous が true なら、記録を取り戻す手段がこの端末のトークンしか無い。
/// メール登録すると false になるが、user.id は変わらないので記録は移動しない。
class Viewer {
  final String id;
  final String? email;
  final String? displayName;
  final bool isAnonymous;
  final bool emailVerified;

  const Viewer({
    required this.id,
    this.email,
    this.displayName,
    this.isAnonymous = true,
    this.emailVerified = false,
  });

  factory Viewer.fromJson(Map<String, dynamic> json) => Viewer(
        id: json['id'] as String,
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
        isAnonymous: json['isAnonymous'] as bool? ?? true,
        emailVerified: json['emailVerified'] as bool? ?? false,
      );
}


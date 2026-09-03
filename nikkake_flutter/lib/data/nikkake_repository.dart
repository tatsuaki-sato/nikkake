import '../models/models.dart';

/// 画面が触るデータAPIの契約。
///
/// 実装は2つある。
///   Repository        端末ストレージが真実の源。ネットワークを使わない
///   ServerRepository  Rails の GraphQL が真実の源。集計もサーバが返す
///
/// どちらを使うかは実行時に決まる（遅延登録。docs/ARCHITECTURE.md 参照）。
/// **片方だけにメソッドを生やさないこと。** ここが両方を縛っているので、
/// 形が食い違えばコンパイルが落ちる。
///
/// 参照がすべて Future なのは、サーバ実装が非同期になるためです。
/// ローカル実装は即座に返しますが、シグネチャは揃えます。
abstract interface class NikkakeRepository {
  /// 端末に初期データを用意する。ネットワークを使わないので必ず終わる
  Future<bool> seedIfNeeded();

  // ---------- 集計済みビュー ----------
  //
  // 対応するサーバ側は HomeViewBuilder / ProgressViewBuilder / WorkoutSessionBuilder。
  // 区分の基準や並び順を変えるときは両方直すこと。

  Future<HomeView> getHome([DateTime? now]);
  Future<ProgressView> getProgress({int rangeDays = 7, DateTime? now});
  Future<List<ExerciseProgressPoint>> getExerciseProgressPoints(String exerciseId, {int limit = 8});

  /// 指定日のワークアウト内容。進捗カレンダーで日をタップしたとき
  Future<DayView> getDay(String date);

  Future<WorkoutSessionView?> getWorkoutSession(String routineId);

  // ---------- 参照 ----------

  Future<List<Exercise>> listExercises();
  Future<List<RoutineWithExercises>> listRoutinesWithExercises();
  Future<RoutineWithExercises?> getRoutineWithExercises(String routineId);

  // ---------- 更新 ----------

  Future<Exercise> createCustomExercise({
    required String name,
    required ExerciseCategory category,
    String? icon,
  });

  Future<Routine> createRoutine(RoutineInput input);
  Future<Routine?> updateRoutine(String routineId, RoutineInput input);
  Future<void> setRoutineActive(String routineId, bool isActive);
  Future<void> deleteRoutine(String routineId);

  // ---------- 記録 ----------

  /// status は受け取らない。完了セット数から実装側が必ず導出する。
  /// 呼び出し側に決めさせると、サーバの判定基準とずれても誰も気づけない。
  Future<WorkoutSummary> saveWorkout({
    required String routineId,
    required DateTime startedAt,
    required int durationSec,
    required List<SaveWorkoutExercise> exercises,
    String? notes,
  });

  // ---------- 設定 ----------

  Future<DataCounts> getCounts();
  Future<void> resetAll();

  /// 送信待ちの記録の件数。ローカル実装では常に0
  Future<int> pendingCount();
}

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

/// ホーム1枚ぶん。区分も連続記録もサーバが決める
class HomeView {
  final String today;
  final StreakInfo streak;
  final List<TodayRoutine> due;
  final List<TodayRoutine> notScheduled;
  final List<TodayRoutine> completed;

  const HomeView({
    required this.today,
    required this.streak,
    this.due = const [],
    this.notScheduled = const [],
    this.completed = const [],
  });

  static const empty = HomeView(
    today: '',
    streak: StreakInfo(current: 0, longest: 0),
  );

  int get total => due.length + notScheduled.length + completed.length;
}

/// 進捗1枚ぶん
class ProgressView {
  final OverallStats overall;
  final StreakInfo streak;
  final List<DailyStats> dailyStats;
  final Set<String> completedDates;
  final List<Exercise> exercisesWithLogs;

  const ProgressView({
    required this.overall,
    required this.streak,
    this.dailyStats = const [],
    this.completedDates = const {},
    this.exercisesWithLogs = const [],
  });

  static const empty = ProgressView(
    overall: OverallStats(
      totalWorkouts: 0,
      thisWeekCount: 0,
      totalDurationSec: 0,
      totalSets: 0,
    ),
    streak: StreakInfo(current: 0, longest: 0),
  );
}

/// 進捗カレンダーで日をタップしたときの、その日のワークアウト内容。
/// 対応するサーバ側は DayViewBuilder。
class DayView {
  final String date;
  final List<DayWorkout> workouts;

  const DayView({required this.date, this.workouts = const []});

  static const empty = DayView(date: '');
}

class DayWorkout {
  final String routineLogId;
  final String routineName;
  final LogStatus status;
  final int? durationSec;
  final List<DayExerciseSummary> exercises;

  const DayWorkout({
    required this.routineLogId,
    required this.routineName,
    required this.status,
    this.durationSec,
    this.exercises = const [],
  });
}

class DayExerciseSummary {
  final String exerciseName;

  /// 「50×10 / 50×8」。文言はサーバが決める。セット記録が無ければ null
  final String? setsLabel;

  const DayExerciseSummary({required this.exerciseName, this.setsLabel});
}

/// ワークアウト実行に必要なもの一式。「前回の記録」も解決済み
class WorkoutSessionView {
  final RoutineWithExercises routine;
  final List<WorkoutSessionEntry> exercises;

  const WorkoutSessionView({required this.routine, required this.exercises});
}

class WorkoutSessionEntry {
  final String routineExerciseId;
  final Exercise exercise;
  final int targetSets;
  final int? targetReps;
  final double? targetWeight;
  final int? targetDurationSec;
  final int restSec;
  final List<WorkoutSet> previousSets;

  /// 「50×10 / 50×9」。サーバが返す文言をそのまま出す
  final String? previousLabel;

  const WorkoutSessionEntry({
    required this.routineExerciseId,
    required this.exercise,
    required this.targetSets,
    this.targetReps,
    this.targetWeight,
    this.targetDurationSec,
    this.restSec = 60,
    this.previousSets = const [],
    this.previousLabel,
  });
}

class DataCounts {
  final int routines;
  final int exercises;
  final int routineLogs;
  final int exerciseLogs;

  const DataCounts({
    this.routines = 0,
    this.exercises = 0,
    this.routineLogs = 0,
    this.exerciseLogs = 0,
  });
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/nikkake_repository.dart';
import '../models/models.dart';

/// 実行中のワークアウトの状態。
/// 保存はローカルストレージへの書き込みなので即座に完了する。
class WorkoutController extends ChangeNotifier {
  final NikkakeRepository repository;

  WorkoutController(this.repository);

  String? _routineId;
  String _routineName = '';
  List<WorkoutExerciseState> _exercises = const [];
  DateTime? _startedAt;
  int _currentIndex = 0;
  int _restTimer = 0;
  bool _restActive = false;
  int _elapsedSec = 0;
  WorkoutSummary? _lastSummary;
  Timer? _ticker;

  bool get isActive => _routineId != null;
  String get routineName => _routineName;
  List<WorkoutExerciseState> get exercises => _exercises;
  int get currentIndex => _currentIndex;
  WorkoutExerciseState? get current =>
      _exercises.isEmpty ? null : _exercises[_currentIndex.clamp(0, _exercises.length - 1)];
  int get restTimer => _restTimer;
  bool get isRestActive => _restActive;
  int get elapsedSec => _elapsedSec;
  WorkoutSummary? get lastSummary => _lastSummary;

  int get completedSetCount =>
      _exercises.fold(0, (sum, e) => sum + e.sets.where((s) => s.completed).length);
  int get totalSetCount => _exercises.fold(0, (sum, e) => sum + e.sets.length);
  double get progress => totalSetCount == 0 ? 0 : completedSetCount / totalSetCount;

  /// 実行を開始する。
  /// 「前回の記録」はセッションに解決済みで入っているので、ここで過去ログを漁らない。
  void start(WorkoutSessionView session) {
    _routineId = session.routine.id;
    _routineName = session.routine.name;
    _currentIndex = 0;
    _startedAt = DateTime.now();
    _elapsedSec = 0;
    _restTimer = 0;
    _restActive = false;
    _lastSummary = null;

    _exercises = session.exercises.map((entry) {
      final previousSets = entry.previousSets;
      final setCount = entry.targetSets < 1 ? 1 : entry.targetSets;

      return WorkoutExerciseState(
        routineExerciseId: entry.routineExerciseId,
        exercise: entry.exercise,
        targetSets: setCount,
        targetReps: entry.targetReps,
        targetWeight: entry.targetWeight,
        targetDurationSec: entry.targetDurationSec,
        restSec: entry.restSec,
        previousSets: previousSets,
        // 前回の記録があればそれを初期値にする。前回と同じ重量から始めることが多いため。
        sets: List.generate(setCount, (i) {
          final prev = previousSets.where((s) => s.setNumber == i + 1).firstOrNull;
          return WorkoutSet(
            setNumber: i + 1,
            reps: prev?.reps ?? entry.targetReps,
            weight: prev?.weight ?? entry.targetWeight,
            durationSec: prev?.durationSec ?? entry.targetDurationSec,
          );
        }),
      );
    }).toList();

    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// 経過時間とレストタイマーを1本のタイマーでまとめて進める
  void tick() {
    if (!isActive) return;

    if (_startedAt != null) {
      _elapsedSec = DateTime.now().difference(_startedAt!).inSeconds;
    }

    if (_restActive) {
      if (_restTimer <= 1) {
        _restTimer = 0;
        _restActive = false;
      } else {
        _restTimer--;
      }
    }

    notifyListeners();
  }

  void goToExercise(int index) {
    if (_exercises.isEmpty) return;
    _currentIndex = index.clamp(0, _exercises.length - 1);
    notifyListeners();
  }

  void nextExercise() => goToExercise(_currentIndex + 1);
  void previousExercise() => goToExercise(_currentIndex - 1);

  void updateSet(int exerciseIndex, int setNumber, WorkoutSet Function(WorkoutSet) transform) {
    if (exerciseIndex < 0 || exerciseIndex >= _exercises.length) return;

    final exercise = _exercises[exerciseIndex];
    final sets = exercise.sets.map((s) => s.setNumber == setNumber ? transform(s) : s).toList();

    _exercises = [..._exercises];
    _exercises[exerciseIndex] = exercise.copyWith(sets: sets);
    notifyListeners();
  }

  void toggleSetComplete(int exerciseIndex, int setNumber) {
    if (exerciseIndex < 0 || exerciseIndex >= _exercises.length) return;

    final target =
        _exercises[exerciseIndex].sets.where((s) => s.setNumber == setNumber).firstOrNull;
    if (target == null) return;

    final willComplete = !target.completed;
    updateSet(exerciseIndex, setNumber, (s) => s.copyWith(completed: willComplete));

    // セットを終えた直後にレストタイマーを自動で回す。手動で押させるとまず押し忘れる。
    if (willComplete) {
      startRestTimer(_exercises[exerciseIndex].restSec);
    } else {
      stopRestTimer();
    }
  }

  void addSet(int exerciseIndex) {
    if (exerciseIndex < 0 || exerciseIndex >= _exercises.length) return;

    final exercise = _exercises[exerciseIndex];
    final last = exercise.sets.isEmpty ? null : exercise.sets.last;

    _exercises = [..._exercises];
    _exercises[exerciseIndex] = exercise.copyWith(sets: [
      ...exercise.sets,
      WorkoutSet(
        setNumber: (last?.setNumber ?? 0) + 1,
        reps: last?.reps ?? exercise.targetReps,
        weight: last?.weight ?? exercise.targetWeight,
        durationSec: last?.durationSec ?? exercise.targetDurationSec,
      ),
    ]);
    notifyListeners();
  }

  void removeSet(int exerciseIndex) {
    if (exerciseIndex < 0 || exerciseIndex >= _exercises.length) return;

    final exercise = _exercises[exerciseIndex];
    // セット0本にすると種目自体が意味を失うので最低1本は残す
    if (exercise.sets.length <= 1) return;

    _exercises = [..._exercises];
    _exercises[exerciseIndex] = exercise.copyWith(sets: exercise.sets.sublist(0, exercise.sets.length - 1));
    notifyListeners();
  }

  void startRestTimer(int seconds) {
    if (seconds <= 0) return;
    _restTimer = seconds;
    _restActive = true;
    notifyListeners();
  }

  void stopRestTimer() {
    _restTimer = 0;
    _restActive = false;
    notifyListeners();
  }

  Future<WorkoutSummary?> finish() async {
    final routineId = _routineId;
    final startedAt = _startedAt;
    if (routineId == null || startedAt == null) return null;

    final durationSec = DateTime.now().difference(startedAt).inSeconds;

    // セット数の集計も status の判定もリポジトリが行う。
    // ここで決めるとサーバの判定基準とずれたときに気づけない。
    final saved = await repository.saveWorkout(
      routineId: routineId,
      startedAt: startedAt,
      durationSec: durationSec,
      exercises: _exercises
          .map((e) => SaveWorkoutExercise(
                routineExerciseId: e.routineExerciseId,
                exerciseId: e.exercise.id,
                sets: e.sets,
              ))
          .toList(),
    );

    // ルーティン名だけは手元のほうが確実。
    // オフラインで記録したときサーバは名前を返せない
    final summary = WorkoutSummary(
      routineLogId: saved.routineLogId,
      routineName: _routineName,
      durationSec: saved.durationSec,
      completedSets: saved.completedSets,
      totalSets: saved.totalSets,
      totalVolume: saved.totalVolume,
      status: saved.status,
    );

    _clear();
    _lastSummary = summary;
    notifyListeners();
    return summary;
  }

  void cancel() {
    _clear();
    notifyListeners();
  }

  void clearSummary() {
    _lastSummary = null;
    notifyListeners();
  }

  void _clear() {
    _ticker?.cancel();
    _ticker = null;
    _routineId = null;
    _routineName = '';
    _exercises = const [];
    _startedAt = null;
    _currentIndex = 0;
    _restTimer = 0;
    _restActive = false;
    _elapsedSec = 0;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

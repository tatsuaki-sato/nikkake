import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/exercises.dart';
import '../data/repository.dart';
import '../models/models.dart';

/// 実行中のワークアウトの状態。
/// 保存はローカルストレージへの書き込みなので即座に完了する。
class WorkoutController extends ChangeNotifier {
  final Repository repository;

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

  void start(RoutineWithExercises routine, {Map<String, List<WorkoutSet>>? lastSets}) {
    final previous = lastSets ?? const {};

    _routineId = routine.id;
    _routineName = routine.name;
    _currentIndex = 0;
    _startedAt = DateTime.now();
    _elapsedSec = 0;
    _restTimer = 0;
    _restActive = false;
    _lastSummary = null;

    _exercises = routine.exercises.map((entry) {
      final link = entry.link;
      final previousSets = previous[link.exerciseId] ?? const <WorkoutSet>[];
      final setCount = link.targetSets < 1 ? 1 : link.targetSets;

      return WorkoutExerciseState(
        routineExerciseId: link.id,
        exercise: entry.exercise,
        targetSets: setCount,
        targetReps: link.targetReps,
        targetWeight: link.targetWeight,
        targetDurationSec: link.targetDurationSec,
        restSec: link.restSec ?? defaultRestSec,
        previousSets: previousSets,
        // 前回の記録があればそれを初期値にする。前回と同じ重量から始めることが多いため。
        sets: List.generate(setCount, (i) {
          final prev = previousSets.where((s) => s.setNumber == i + 1).firstOrNull;
          return WorkoutSet(
            setNumber: i + 1,
            reps: prev?.reps ?? link.targetReps,
            weight: prev?.weight ?? link.targetWeight,
            durationSec: prev?.durationSec ?? link.targetDurationSec,
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

    final completed = completedSetCount;
    final total = totalSetCount;

    var volume = 0.0;
    for (final exercise in _exercises) {
      for (final set in exercise.sets.where((s) => s.completed)) {
        volume += (set.weight ?? 0) * (set.reps ?? 0);
      }
    }

    final status = completed == 0
        ? LogStatus.skipped
        : (completed >= total ? LogStatus.completed : LogStatus.partial);
    final durationSec = DateTime.now().difference(startedAt).inSeconds;

    final log = await repository.saveWorkout(
      routineId: routineId,
      startedAt: startedAt,
      durationSec: durationSec,
      status: status,
      exercises: _exercises
          .map((e) => SaveWorkoutExercise(
                routineExerciseId: e.routineExerciseId,
                exerciseId: e.exercise.id,
                sets: e.sets,
              ))
          .toList(),
    );

    final summary = WorkoutSummary(
      routineLogId: log.id,
      routineName: _routineName,
      durationSec: durationSec,
      completedSets: completed,
      totalSets: total,
      totalVolume: volume,
      status: status,
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

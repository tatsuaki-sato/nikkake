import 'package:flutter/foundation.dart';
import '../data/repository.dart';
import '../models/models.dart';

/// ルーティンとログの読み取り状態をまとめて持つ。
///
/// 参照はすべてローカルストレージなので取得コストが安い。
/// キャッシュを細かく持つより、変更のたびに再読込して通知する方が
/// 画面間の不整合が出ずに単純になる。
class AppState extends ChangeNotifier {
  final Repository repository;

  AppState(this.repository);

  List<RoutineWithExercises> _routines = const [];
  List<TodayRoutine> _todayRoutines = const [];
  List<RoutineLog> _routineLogs = const [];
  List<ExerciseLog> _exerciseLogs = const [];
  List<Exercise> _exercises = const [];
  bool _loaded = false;

  List<RoutineWithExercises> get routines => _routines;
  List<TodayRoutine> get todayRoutines => _todayRoutines;
  List<RoutineLog> get routineLogs => _routineLogs;
  List<ExerciseLog> get exerciseLogs => _exerciseLogs;
  List<Exercise> get exercises => _exercises;
  bool get loaded => _loaded;

  /// 初回起動時のシード投入を含む立ち上げ。
  /// これが終わればサインインの有無に関係なくアプリは完全に使える。
  Future<void> bootstrap() async {
    await repository.seedIfNeeded();
    refresh();
  }

  void refresh() {
    _routines = repository.listRoutinesWithExercises();
    _todayRoutines = repository.getTodayRoutines();
    _routineLogs = repository.listRoutineLogs();
    _exerciseLogs = repository.listExerciseLogs();
    _exercises = repository.listExercises();
    _loaded = true;
    notifyListeners();
  }

  RoutineWithExercises? findRoutine(String id) {
    for (final r in _routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> createRoutine(RoutineInput input) async {
    await repository.createRoutine(input);
    refresh();
  }

  Future<void> updateRoutine(String id, RoutineInput input) async {
    await repository.updateRoutine(id, input);
    refresh();
  }

  Future<void> deleteRoutine(String id) async {
    await repository.deleteRoutine(id);
    refresh();
  }

  Future<void> setRoutineActive(String id, bool isActive) async {
    await repository.setRoutineActive(id, isActive);
    refresh();
  }

  Future<void> resetAll() async {
    await repository.resetAll();
    refresh();
  }

  Map<String, int> get localCounts => repository.getLocalCounts();
}

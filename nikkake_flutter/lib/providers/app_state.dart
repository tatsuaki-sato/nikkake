import 'package:flutter/foundation.dart';
import '../data/nikkake_repository.dart';
import '../models/models.dart';

/// 画面が読む状態をまとめて持つ。
///
/// 保持しているのは**サーバが組み立てた集計済みビュー**で、
/// 生のログは持ちません。画面側で集計し直すと、
/// サーバと基準がずれても誰も気づけないためです。
///
/// 変更のたびに全部読み直して通知します。細かくキャッシュを持つより
/// 画面間の不整合が出ずに単純です。
class AppState extends ChangeNotifier {
  final NikkakeRepository repository;

  AppState(this.repository);

  HomeView _home = HomeView.empty;
  ProgressView _progress = ProgressView.empty;
  List<RoutineWithExercises> _routines = const [];
  List<Exercise> _exercises = const [];
  DataCounts _counts = const DataCounts();
  int _progressRangeDays = 7;
  bool _loaded = false;

  HomeView get home => _home;
  ProgressView get progress => _progress;
  List<RoutineWithExercises> get routines => _routines;
  List<Exercise> get exercises => _exercises;
  DataCounts get counts => _counts;
  int get progressRangeDays => _progressRangeDays;
  bool get loaded => _loaded;

  /// 初回起動時のシード投入を含む立ち上げ。
  /// ネットワークを使わないので必ず終わる。
  /// サーバへの登録はここでは待たない（docs/ARCHITECTURE.md の遅延登録）。
  Future<void> bootstrap() async {
    await repository.seedIfNeeded();
    await refresh();
  }

  Future<void> refresh() async {
    final results = await Future.wait([
      repository.getHome(),
      repository.getProgress(rangeDays: _progressRangeDays),
      repository.listRoutinesWithExercises(),
      repository.listExercises(),
      repository.getCounts(),
    ]);

    _home = results[0] as HomeView;
    _progress = results[1] as ProgressView;
    _routines = results[2] as List<RoutineWithExercises>;
    _exercises = results[3] as List<Exercise>;
    _counts = results[4] as DataCounts;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setProgressRange(int days) async {
    if (_progressRangeDays == days) return;
    _progressRangeDays = days;
    _progress = await repository.getProgress(rangeDays: days);
    notifyListeners();
  }

  Future<List<ExerciseProgressPoint>> exerciseProgress(String exerciseId) =>
      repository.getExerciseProgressPoints(exerciseId);

  Future<DayView> day(String date) => repository.getDay(date);

  RoutineWithExercises? findRoutine(String id) {
    for (final r in _routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> createRoutine(RoutineInput input) async {
    await repository.createRoutine(input);
    await refresh();
  }

  Future<void> updateRoutine(String id, RoutineInput input) async {
    await repository.updateRoutine(id, input);
    await refresh();
  }

  Future<void> deleteRoutine(String id) async {
    await repository.deleteRoutine(id);
    await refresh();
  }

  Future<void> setRoutineActive(String id, bool isActive) async {
    await repository.setRoutineActive(id, isActive);
    await refresh();
  }

  Future<void> resetAll() async {
    await repository.resetAll();
    await refresh();
  }
}

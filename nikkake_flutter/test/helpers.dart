import 'package:flutter_test/flutter_test.dart';
import 'package:nikkake_flutter/data/local_db.dart';
import 'package:nikkake_flutter/data/local_store.dart';
import 'package:nikkake_flutter/data/repository.dart';
import 'package:nikkake_flutter/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テスト用のインメモリなDB。
/// SharedPreferences.setMockInitialValues でメモリ実装に差し替えるので、
/// 実機のストレージには一切書かない。
Future<LocalDb> createTestDb() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  return LocalDb(await LocalStore.open());
}

Future<Repository> createSeededRepository() async {
  final repository = Repository(await createTestDb());
  await repository.seedIfNeeded();
  return repository;
}

RoutineInput sampleRoutineInput({
  String name = 'テストルーティン',
  List<RoutineExerciseInput>? exercises,
  FrequencyType frequencyType = FrequencyType.daily,
  List<int> frequencyDays = const [],
}) {
  return RoutineInput(
    name: name,
    icon: '💪',
    color: '#6C5CE7',
    frequencyType: frequencyType,
    frequencyDays: frequencyDays,
    exercises: exercises ??
        const [
          RoutineExerciseInput(
            exerciseId: '00000000-0000-4000-8000-000000000003',
            targetSets: 3,
            targetReps: 10,
            restSec: 60,
          ),
        ],
  );
}

RoutineLog buildLog(String logDate, {LogStatus status = LogStatus.completed, int durationSec = 600}) {
  final now = DateTime.now().toUtc();
  return RoutineLog(
    id: 'log-$logDate-${status.name}',
    routineId: 'r1',
    logDate: logDate,
    status: status,
    durationSec: durationSec,
    createdAt: now,
    updatedAt: now,
  );
}

ExerciseLog buildExerciseLog({
  required String routineLogId,
  required String exerciseId,
  required int setNumber,
  int? reps,
  double? weight,
}) {
  final now = DateTime.now().toUtc();
  return ExerciseLog(
    id: '$routineLogId-$exerciseId-$setNumber',
    routineLogId: routineLogId,
    exerciseId: exerciseId,
    setNumber: setNumber,
    actualReps: reps,
    actualWeight: weight,
    createdAt: now,
    updatedAt: now,
  );
}

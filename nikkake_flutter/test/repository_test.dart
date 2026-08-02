import 'package:flutter_test/flutter_test.dart';
import 'package:nikkake_flutter/constants/exercises.dart';
import 'package:nikkake_flutter/data/nikkake_repository.dart';
import 'package:nikkake_flutter/data/repository.dart';
import 'package:nikkake_flutter/domain/date_utils.dart';
import 'package:nikkake_flutter/models/models.dart';
import 'helpers.dart';

void main() {
  late Repository repository;

  setUp(() async {
    repository = await createSeededRepository();
  });

  group('初期状態', () {
    test('サインインしなくても、起動直後にすぐ始められるルーティンがある', () async {
      final routines = await repository.listRoutinesWithExercises();

      expect(routines.length, 1);
      expect(routines.first.name, starterRoutineName);
      expect(routines.first.exercises, isNotEmpty);
    });

    test('プリセット種目が全件入っている', () async {
      expect((await repository.listExercises()).length, presetExercises.length);
    });

    test('2回目の起動では初期ルーティンを作り直さない', () async {
      await repository.seedIfNeeded();
      expect(repository.listRoutines().length, 1);
    });
  });

  group('ルーティンのCRUD', () {
    test('作成すると種目の紐付けごと保存される', () async {
      final routine = await repository.createRoutine(sampleRoutineInput(name: '新しいメニュー'));
      final loaded = await repository.getRoutineWithExercises(routine.id);

      expect(loaded?.name, '新しいメニュー');
      expect(loaded?.exercises.length, 1);
      expect(loaded?.exercises.first.link.targetSets, 3);
      expect(loaded?.exercises.first.link.restSec, 60);
    });

    test('更新すると種目構成が丸ごと差し替わり、並び順も入力どおりになる', () async {
      final routine = await repository.createRoutine(sampleRoutineInput());

      await repository.updateRoutine(
        routine.id,
        sampleRoutineInput(
          name: '更新後',
          exercises: [
            RoutineExerciseInput(exerciseId: presetExercises[8].id, targetSets: 5, targetReps: 20),
            RoutineExerciseInput(exerciseId: presetExercises[0].id, targetSets: 4, targetReps: 8),
          ],
        ),
      );

      final loaded = await repository.getRoutineWithExercises(routine.id);

      expect(loaded?.name, '更新後');
      expect(loaded?.exercises.length, 2);
      expect(loaded?.exercises[0].exercise.id, presetExercises[8].id);
      expect(loaded?.exercises[1].exercise.id, presetExercises[0].id);
    });

    test('削除すると一覧から消える', () async {
      final routine = await repository.createRoutine(sampleRoutineInput());
      await repository.deleteRoutine(routine.id);

      expect(await repository.getRoutineWithExercises(routine.id), isNull);
      expect(repository.listRoutines().where((r) => r.id == routine.id), isEmpty);
    });

    test('停止したルーティンは今日の一覧に出ない', () async {
      final routine = await repository.createRoutine(sampleRoutineInput());
      await repository.setRoutineActive(routine.id, false);

      expect(
        repository.getTodayRoutines().where((t) => t.routine.id == routine.id),
        isEmpty,
      );
    });

    test('作成順にsortOrderが振られる', () async {
      final first = await repository.createRoutine(sampleRoutineInput(name: '1つ目'));
      final second = await repository.createRoutine(sampleRoutineInput(name: '2つ目'));

      final routines = repository.listRoutines();
      final a = routines.firstWhere((r) => r.id == first.id);
      final b = routines.firstWhere((r) => r.id == second.id);

      expect(a.sortOrder < b.sortOrder, isTrue);
    });
  });

  group('カスタム種目', () {
    test('追加した種目が一覧に出る', () async {
      await repository.createCustomExercise(
        name: '自作トレ',
        category: ExerciseCategory.custom,
        icon: '🌟',
      );

      final created =
          (await repository.listExercises()).firstWhere((e) => e.name == '自作トレ');
      expect(created.isPreset, isFalse);
    });
  });

  group('ワークアウトの保存', () {
    Future<(Routine, RoutineExerciseWithExercise)> setUpWorkout() async {
      final routine = await repository.createRoutine(sampleRoutineInput());
      final loaded = (await repository.getRoutineWithExercises(routine.id))!;
      return (routine, loaded.exercises.first);
    }

    test('完了したセットだけがログに残る', () async {
      final (routine, link) = await setUpWorkout();

      await repository.saveWorkout(
        routineId: routine.id,
        startedAt: DateTime.now(),
        durationSec: 600,
        exercises: [
          SaveWorkoutExercise(
            routineExerciseId: link.link.id,
            exerciseId: link.exercise.id,
            sets: const [
              WorkoutSet(setNumber: 1, reps: 10, weight: 50, completed: true),
              WorkoutSet(setNumber: 2, reps: 10, weight: 50, completed: true),
              WorkoutSet(setNumber: 3, reps: 10, weight: 50),
            ],
          ),
        ],
      );

      final logs = repository.listExerciseLogs();
      expect(logs.length, 2);
      expect(logs.every((l) => l.exerciseId == link.exercise.id), isTrue);
    });

    test('保存したワークアウトは今日のログとして引ける', () async {
      final (routine, link) = await setUpWorkout();

      await repository.saveWorkout(
        routineId: routine.id,
        startedAt: DateTime.now(),
        durationSec: 300,
        exercises: [
          SaveWorkoutExercise(
            routineExerciseId: link.link.id,
            exerciseId: link.exercise.id,
            sets: const [],
          ),
        ],
      );

      final todayLogs = repository.getTodayLogs();
      expect(todayLogs.length, 1);
      expect(todayLogs.first.logDate, getDateString());
    });

    test('全セット完了なら completed になり、今日の一覧でも完了扱いになる', () async {
      final (routine, link) = await setUpWorkout();

      // status は入力せず、完了セット数から導出される
      final summary = await repository.saveWorkout(
        routineId: routine.id,
        startedAt: DateTime.now(),
        durationSec: 300,
        exercises: [
          SaveWorkoutExercise(
            routineExerciseId: link.link.id,
            exerciseId: link.exercise.id,
            sets: const [
              WorkoutSet(setNumber: 1, reps: 10, weight: 50, completed: true),
              WorkoutSet(setNumber: 2, reps: 10, weight: 50, completed: true),
            ],
          ),
        ],
      );

      expect(summary.status, LogStatus.completed);
      expect(summary.completedSets, 2);
      expect(summary.totalVolume, 1000);

      final today = repository.getTodayRoutines().firstWhere((t) => t.routine.id == routine.id);
      expect(today.isCompleted, isTrue);
    });

    test('途中までの記録でも今日の分は済んだ扱いになる', () async {
      final (routine, link) = await setUpWorkout();

      await repository.saveWorkout(
        routineId: routine.id,
        startedAt: DateTime.now(),
        durationSec: 120,
        exercises: [
          SaveWorkoutExercise(
            routineExerciseId: link.link.id,
            exerciseId: link.exercise.id,
            sets: const [WorkoutSet(setNumber: 1, reps: 10, weight: 50, completed: true)],
          ),
        ],
      );

      final today = repository.getTodayRoutines().firstWhere((t) => t.routine.id == routine.id);
      expect(today.isCompleted, isTrue);
    });

    test('中断した記録だけなら今日の分は未実施のまま', () async {
      final (routine, link) = await setUpWorkout();

      await repository.saveWorkout(
        routineId: routine.id,
        startedAt: DateTime.now(),
        durationSec: 10,
        exercises: [
          SaveWorkoutExercise(
            routineExerciseId: link.link.id,
            exerciseId: link.exercise.id,
            sets: const [],
          ),
        ],
      );

      final today = repository.getTodayRoutines().firstWhere((t) => t.routine.id == routine.id);
      expect(today.isCompleted, isFalse);
    });

    test('前回の記録を種目ごとに引ける（次回の初期値に使う）', () async {
      final (routine, link) = await setUpWorkout();

      await repository.saveWorkout(
        routineId: routine.id,
        startedAt: DateTime.now(),
        durationSec: 300,
        exercises: [
          SaveWorkoutExercise(
            routineExerciseId: link.link.id,
            exerciseId: link.exercise.id,
            sets: const [
              WorkoutSet(setNumber: 1, reps: 12, weight: 55, completed: true),
              WorkoutSet(setNumber: 2, reps: 10, weight: 60, completed: true),
            ],
          ),
        ],
      );

      final lastSets = repository.getLastSetsByExercise(routine.id);

      expect(lastSets[link.exercise.id]?.length, 2);
      expect(lastSets[link.exercise.id]?.first.reps, 12);
      expect(lastSets[link.exercise.id]?.first.weight, 55);
    });

    test('ルーティンを編集しても過去のセット記録は残る', () async {
      final (routine, link) = await setUpWorkout();

      await repository.saveWorkout(
        routineId: routine.id,
        startedAt: DateTime.now(),
        durationSec: 300,
        exercises: [
          SaveWorkoutExercise(
            routineExerciseId: link.link.id,
            exerciseId: link.exercise.id,
            sets: const [WorkoutSet(setNumber: 1, reps: 10, weight: 50, completed: true)],
          ),
        ],
      );

      // 編集で routine_exercises は作り直されるが、exercise_id 経由で履歴は辿れる
      await repository.updateRoutine(routine.id, sampleRoutineInput(name: '編集後'));

      final logs = repository.listExerciseLogs();
      expect(logs.length, 1);
      expect(logs.first.exerciseId, link.exercise.id);
    });

    test('ログを削除するとセット記録も一緒に消える', () async {
      final (routine, link) = await setUpWorkout();

      final log = await repository.saveWorkout(
        routineId: routine.id,
        startedAt: DateTime.now(),
        durationSec: 300,
        exercises: [
          SaveWorkoutExercise(
            routineExerciseId: link.link.id,
            exerciseId: link.exercise.id,
            sets: const [WorkoutSet(setNumber: 1, reps: 10, weight: 50, completed: true)],
          ),
        ],
      );

      expect(repository.listExerciseLogs().length, 1);

      await repository.deleteRoutineLog(log.routineLogId);

      expect(repository.listExerciseLogs(), isEmpty);
      expect(repository.listRoutineLogs(), isEmpty);
    });
  });

  group('初期化', () {
    test('resetAll でデータが消えて初期状態に戻る', () async {
      await repository.createRoutine(sampleRoutineInput(name: '消えるルーティン'));
      expect(repository.listRoutines().length, 2);

      await repository.resetAll();

      final routines = repository.listRoutines();
      expect(routines.length, 1);
      expect(routines.first.name, starterRoutineName);
    });
  });
}

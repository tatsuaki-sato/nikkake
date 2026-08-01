import 'package:flutter_test/flutter_test.dart';
import 'package:nikkake_flutter/constants/exercises.dart';
import 'package:nikkake_flutter/data/repository.dart';
import 'package:nikkake_flutter/models/models.dart';
import 'package:nikkake_flutter/providers/workout_controller.dart';
import 'helpers.dart';

void main() {
  late Repository repository;
  late WorkoutController controller;
  late RoutineWithExercises routine;

  setUp(() async {
    repository = await createSeededRepository();
    controller = WorkoutController(repository);

    final created = await repository.createRoutine(sampleRoutineInput(
      exercises: [
        RoutineExerciseInput(
          exerciseId: presetExercises[2].id,
          targetSets: 2,
          targetReps: 10,
          targetWeight: 50,
          restSec: 60,
        ),
        RoutineExerciseInput(
          exerciseId: presetExercises[8].id,
          targetSets: 1,
          targetReps: 15,
          restSec: 30,
        ),
      ],
    ));

    routine = repository.getRoutineWithExercises(created.id)!;
  });

  tearDown(() => controller.dispose());

  group('ワークアウトの開始', () {
    test('目標値をそのままセットの初期値にする', () {
      controller.start(routine);

      expect(controller.exercises.length, 2);
      expect(controller.exercises[0].sets.length, 2);
      expect(controller.exercises[0].sets[0].reps, 10);
      expect(controller.exercises[0].sets[0].weight, 50);
      expect(controller.exercises[0].sets[0].completed, isFalse);
      expect(controller.currentIndex, 0);
    });

    test('前回の記録があればそちらを初期値にする', () {
      final exerciseId = routine.exercises.first.exercise.id;

      controller.start(routine, lastSets: {
        exerciseId: const [
          WorkoutSet(setNumber: 1, reps: 12, weight: 65, completed: true),
          WorkoutSet(setNumber: 2, reps: 11, weight: 65, completed: true),
        ],
      });

      expect(controller.exercises[0].sets[0].reps, 12);
      expect(controller.exercises[0].sets[0].weight, 65);
      expect(controller.exercises[0].previousSets.length, 2);
    });
  });

  group('セットの操作', () {
    setUp(() => controller.start(routine));

    test('値を編集できる', () {
      controller.updateSet(0, 1, (s) => s.copyWith(weight: 70, reps: 8));

      expect(controller.exercises[0].sets[0].weight, 70);
      expect(controller.exercises[0].sets[0].reps, 8);
    });

    test('完了にするとレストタイマーが自動で走る', () {
      controller.toggleSetComplete(0, 1);

      expect(controller.exercises[0].sets[0].completed, isTrue);
      expect(controller.isRestActive, isTrue);
      expect(controller.restTimer, 60);
    });

    test('完了を取り消すとレストタイマーも止まる', () {
      controller.toggleSetComplete(0, 1);
      controller.toggleSetComplete(0, 1);

      expect(controller.exercises[0].sets[0].completed, isFalse);
      expect(controller.isRestActive, isFalse);
    });

    test('レストタイマーは0で自動停止し、マイナスにならない', () {
      controller.start(routine);
      controller.startRestTimer(2);

      controller.tick();
      expect(controller.restTimer, 1);

      controller.tick();
      expect(controller.restTimer, 0);
      expect(controller.isRestActive, isFalse);

      controller.tick();
      expect(controller.restTimer, 0);
    });

    test('セットを増減できる', () {
      controller.addSet(0);
      expect(controller.exercises[0].sets.length, 3);

      controller.removeSet(0);
      expect(controller.exercises[0].sets.length, 2);
    });

    test('セットは1本未満にはできない', () {
      controller.removeSet(1); // 元々1セットの種目
      expect(controller.exercises[1].sets.length, 1);
    });

    test('種目の移動は範囲外に出ない', () {
      controller.previousExercise();
      expect(controller.currentIndex, 0);

      controller.nextExercise();
      controller.nextExercise();
      expect(controller.currentIndex, 1);
    });
  });

  group('ワークアウトの完了', () {
    test('全セット完了なら completed として保存される', () async {
      controller.start(routine);
      controller.toggleSetComplete(0, 1);
      controller.toggleSetComplete(0, 2);
      controller.toggleSetComplete(1, 1);

      final summary = await controller.finish();

      expect(summary, isNotNull);
      expect(summary!.status, LogStatus.completed);
      expect(summary.completedSets, 3);
      expect(summary.totalSets, 3);
      // 50kg × 10回 × 2セット（2種目目は自重なので0）
      expect(summary.totalVolume, 1000);

      expect(repository.listRoutineLogs().length, 1);
      expect(repository.listExerciseLogs().length, 3);
    });

    test('一部だけなら partial になる', () async {
      controller.start(routine);
      controller.toggleSetComplete(0, 1);

      final summary = await controller.finish();

      expect(summary!.status, LogStatus.partial);
      expect(summary.completedSets, 1);
      expect(repository.listExerciseLogs().length, 1);
    });

    test('1つも完了していなければ skipped になる', () async {
      controller.start(routine);

      final summary = await controller.finish();

      expect(summary!.status, LogStatus.skipped);
      expect(repository.listExerciseLogs(), isEmpty);
    });

    test('完了後は実行中の状態がクリアされ、サマリーが残る', () async {
      controller.start(routine);
      await controller.finish();

      expect(controller.isActive, isFalse);
      expect(controller.isRestActive, isFalse);
      expect(controller.lastSummary, isNotNull);
    });

    test('中断すると何も保存されない', () async {
      controller.start(routine);
      controller.toggleSetComplete(0, 1);
      controller.cancel();

      expect(controller.isActive, isFalse);
      expect(repository.listRoutineLogs(), isEmpty);
    });

    test('実行中でなければ finish は null を返す', () async {
      expect(await controller.finish(), isNull);
    });
  });
}

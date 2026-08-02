package com.myapplication.common

import com.myapplication.common.constants.STARTER_ROUTINE_NAME
import com.myapplication.common.constants.presetExercises
import com.myapplication.common.data.ExerciseCategory
import com.myapplication.common.data.LogStatus
import com.myapplication.common.data.Repository
import com.myapplication.common.data.RoutineExerciseInput
import com.myapplication.common.data.SaveWorkoutExercise
import com.myapplication.common.data.WorkoutSet
import com.myapplication.common.domain.getDateString
import com.myapplication.common.domain.nowIso
import com.myapplication.common.domain.today
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class RepositoryTest {

    private suspend fun repo() = createSeededRepository()

    // status は渡さない。完了セット数から実装が導出する
    private suspend fun saveOneWorkout(
        repository: Repository,
        routineId: String,
        linkId: String,
        exerciseId: String,
        sets: List<WorkoutSet>,
    ) = repository.saveWorkout(
        routineId = routineId,
        startedAt = nowIso(),
        durationSec = 600,
        exercises = listOf(SaveWorkoutExercise(linkId, exerciseId, sets)),
    )

    // ------------------------------------------
    // 初期状態
    // ------------------------------------------

    @Test
    fun サインインしなくても起動直後にすぐ始められるルーティンがある() = runTest {
        val routines = repo().listRoutinesWithExercises()

        assertEquals(1, routines.size)
        assertEquals(STARTER_ROUTINE_NAME, routines.first().name)
        assertTrue(routines.first().exercises.isNotEmpty())
    }

    @Test
    fun プリセット種目が全件入っている() = runTest {
        assertEquals(presetExercises.size, repo().listExercises().size)
    }

    @Test
    fun 二回目の起動では初期ルーティンを作り直さない() = runTest {
        val repository = repo()
        repository.seedIfNeeded()
        assertEquals(1, repository.listRoutinesLocal().size)
    }

    // ------------------------------------------
    // ルーティンのCRUD
    // ------------------------------------------

    @Test
    fun 作成すると種目の紐付けごと保存される() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput(name = "新しいメニュー"))
        val loaded = repository.getRoutineWithExercises(routine.id)

        assertEquals("新しいメニュー", loaded?.name)
        assertEquals(1, loaded?.exercises?.size)
        assertEquals(3, loaded?.exercises?.first()?.link?.targetSets)
        assertEquals(60, loaded?.exercises?.first()?.link?.restSec)
    }

    @Test
    fun 更新すると種目構成が丸ごと差し替わり並び順も入力どおりになる() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())

        repository.updateRoutine(
            routine.id,
            sampleRoutineInput(
                name = "更新後",
                exercises = listOf(
                    RoutineExerciseInput(SQUAT_ID, targetSets = 5, targetReps = 20),
                    RoutineExerciseInput(BENCH_PRESS_ID, targetSets = 4, targetReps = 8),
                ),
            ),
        )

        val loaded = repository.getRoutineWithExercises(routine.id)
        assertEquals("更新後", loaded?.name)
        assertEquals(2, loaded?.exercises?.size)
        assertEquals(SQUAT_ID, loaded?.exercises?.get(0)?.exercise?.id)
        assertEquals(BENCH_PRESS_ID, loaded?.exercises?.get(1)?.exercise?.id)
    }

    @Test
    fun 削除すると一覧から消える() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())

        repository.deleteRoutine(routine.id)

        assertNull(repository.getRoutineWithExercises(routine.id))
        assertTrue(repository.listRoutinesLocal().none { it.id == routine.id })
    }

    @Test
    fun 停止したルーティンは今日の一覧に出ない() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())

        repository.setRoutineActive(routine.id, false)

        assertTrue(repository.getTodayRoutines().none { it.routine.id == routine.id })
    }

    @Test
    fun 作成順にsortOrderが振られる() = runTest {
        val repository = repo()
        val first = repository.createRoutine(sampleRoutineInput(name = "1つ目"))
        val second = repository.createRoutine(sampleRoutineInput(name = "2つ目"))

        val routines = repository.listRoutinesLocal()
        val a = routines.first { it.id == first.id }
        val b = routines.first { it.id == second.id }

        assertTrue(a.sortOrder < b.sortOrder)
    }

    @Test
    fun カスタム種目を追加できる() = runTest {
        val repository = repo()
        repository.createCustomExercise("自作トレ", ExerciseCategory.CUSTOM, "🌟")

        val created = repository.listExercises().first { it.name == "自作トレ" }
        assertFalse(created.isPreset)
    }

    // ------------------------------------------
    // ワークアウトの保存
    // ------------------------------------------

    @Test
    fun 完了したセットだけがログに残る() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())
        val link = repository.getRoutineWithExercises(routine.id)!!.exercises.first()

        saveOneWorkout(
            repository, routine.id, link.link.id, link.exercise.id,
            listOf(
                WorkoutSet(1, reps = 10, weight = 50.0, completed = true),
                WorkoutSet(2, reps = 10, weight = 50.0, completed = true),
                WorkoutSet(3, reps = 10, weight = 50.0, completed = false),
            ),
        )

        val logs = repository.listExerciseLogs()
        assertEquals(2, logs.size)
        assertTrue(logs.all { it.exerciseId == link.exercise.id })
    }

    @Test
    fun 保存したワークアウトは今日のログとして引ける() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())
        val link = repository.getRoutineWithExercises(routine.id)!!.exercises.first()

        saveOneWorkout(repository, routine.id, link.link.id, link.exercise.id, emptyList())

        val todayLogs = repository.getTodayLogs()
        assertEquals(1, todayLogs.size)
        assertEquals(getDateString(), todayLogs.first().logDate)
    }

    @Test
    fun 全セット完了ならcompletedになり今日の一覧でも完了扱いになる() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())
        val link = repository.getRoutineWithExercises(routine.id)!!.exercises.first()

        // status は入力せず、完了セット数から導出される
        val summary = saveOneWorkout(
            repository, routine.id, link.link.id, link.exercise.id,
            listOf(
                WorkoutSet(1, reps = 10, weight = 50.0, completed = true),
                WorkoutSet(2, reps = 10, weight = 50.0, completed = true),
            ),
        )

        assertEquals(LogStatus.COMPLETED, summary.status)
        assertEquals(2, summary.completedSets)
        assertEquals(1000.0, summary.totalVolume)

        val today = repository.getTodayRoutines().first { it.routine.id == routine.id }
        assertTrue(today.isCompleted)
    }

    @Test
    fun 途中までの記録でも今日の分は済んだ扱いになる() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())
        val link = repository.getRoutineWithExercises(routine.id)!!.exercises.first()

        // 一部だけ完了 → partial（status は実装が導出する）
        val summary = saveOneWorkout(
            repository, routine.id, link.link.id, link.exercise.id,
            listOf(
                WorkoutSet(1, reps = 10, weight = 50.0, completed = true),
                WorkoutSet(2, reps = 10, weight = 50.0, completed = false),
            ),
        )
        assertEquals(LogStatus.PARTIAL, summary.status)

        val today = repository.getTodayRoutines().first { it.routine.id == routine.id }
        assertTrue(today.isCompleted)
    }

    @Test
    fun 中断した記録だけなら今日の分は未実施のまま() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())
        val link = repository.getRoutineWithExercises(routine.id)!!.exercises.first()

        // 完了セット0 → skipped（status は実装が導出する）
        val summary = saveOneWorkout(
            repository, routine.id, link.link.id, link.exercise.id,
            listOf(WorkoutSet(1, reps = 10, weight = 50.0, completed = false)),
        )
        assertEquals(LogStatus.SKIPPED, summary.status)

        val today = repository.getTodayRoutines().first { it.routine.id == routine.id }
        assertFalse(today.isCompleted)
    }

    @Test
    fun 前回の記録を種目ごとに引ける() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())
        val link = repository.getRoutineWithExercises(routine.id)!!.exercises.first()

        saveOneWorkout(
            repository, routine.id, link.link.id, link.exercise.id,
            listOf(
                WorkoutSet(1, reps = 12, weight = 55.0, completed = true),
                WorkoutSet(2, reps = 10, weight = 60.0, completed = true),
            ),
        )

        val lastSets = repository.getLastSetsByExercise(routine.id)
        val sets = assertNotNull(lastSets[link.exercise.id])

        assertEquals(2, sets.size)
        assertEquals(12, sets.first().reps)
        assertEquals(55.0, sets.first().weight)
    }

    @Test
    fun ルーティンを編集しても過去のセット記録は残る() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())
        val link = repository.getRoutineWithExercises(routine.id)!!.exercises.first()

        saveOneWorkout(
            repository, routine.id, link.link.id, link.exercise.id,
            listOf(WorkoutSet(1, reps = 10, weight = 50.0, completed = true)),
        )

        // 編集で routine_exercises は作り直されるが、exercise_id 経由で履歴は辿れる
        repository.updateRoutine(routine.id, sampleRoutineInput(name = "編集後"))

        val logs = repository.listExerciseLogs()
        assertEquals(1, logs.size)
        assertEquals(link.exercise.id, logs.first().exerciseId)
    }

    @Test
    fun ログを削除するとセット記録も一緒に消える() = runTest {
        val repository = repo()
        val routine = repository.createRoutine(sampleRoutineInput())
        val link = repository.getRoutineWithExercises(routine.id)!!.exercises.first()

        val log = saveOneWorkout(
            repository, routine.id, link.link.id, link.exercise.id,
            listOf(WorkoutSet(1, reps = 10, weight = 50.0, completed = true)),
        )
        assertEquals(1, repository.listExerciseLogs().size)

        repository.deleteRoutineLog(log.routineLogId)

        assertTrue(repository.listExerciseLogs().isEmpty())
        assertTrue(repository.listRoutineLogs().isEmpty())
    }

    @Test
    fun 初期化するとデータが消えて初期状態に戻る() = runTest {
        val repository = repo()
        repository.createRoutine(sampleRoutineInput(name = "消えるルーティン"))
        assertEquals(2, repository.listRoutinesLocal().size)

        repository.resetAll()

        val routines = repository.listRoutinesLocal()
        assertEquals(1, routines.size)
        assertEquals(STARTER_ROUTINE_NAME, routines.first().name)
    }
}

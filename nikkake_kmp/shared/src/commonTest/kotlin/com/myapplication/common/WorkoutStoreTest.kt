package com.myapplication.common

import com.myapplication.common.data.LogStatus
import com.myapplication.common.data.Repository
import com.myapplication.common.data.RoutineExerciseInput
import com.myapplication.common.data.WorkoutSessionView
import com.myapplication.common.data.WorkoutSet
import com.myapplication.common.store.WorkoutStore
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class WorkoutStoreTest {

    /** 2種目（重量あり2セット / 自重1セット）のルーティンで統一して検証する */
    private suspend fun setUp(): Triple<Repository, WorkoutStore, WorkoutSessionView> {
        val repository = createSeededRepository()
        val store = WorkoutStore(repository)

        val created = repository.createRoutine(
            sampleRoutineInput(
                exercises = listOf(
                    RoutineExerciseInput(PUSH_UP_ID, targetSets = 2, targetReps = 10, targetWeight = 50.0, restSec = 60),
                    RoutineExerciseInput(SQUAT_ID, targetSets = 1, targetReps = 15, restSec = 30),
                ),
            ),
        )

        return Triple(repository, store, repository.getWorkoutSession(created.id)!!)
    }

    @Test
    fun 目標値をそのままセットの初期値にする() = runTest {
        val (_, store, session) = setUp()
        store.start(session)

        assertEquals(2, store.exercises.size)
        assertEquals(2, store.exercises[0].sets.size)
        assertEquals(10, store.exercises[0].sets[0].reps)
        assertEquals(50.0, store.exercises[0].sets[0].weight)
        assertFalse(store.exercises[0].sets[0].completed)
        assertEquals(0, store.currentIndex)
    }

    @Test
    fun 前回の記録があればそちらを初期値にする() = runTest {
        val (_, store, session) = setUp()
        // 前回の記録はサーバ（ローカル実装なら getWorkoutSession）が解決して渡してくる
        val withPrevious = session.copy(
            exercises = listOf(
                session.exercises.first().copy(
                    previousSets = listOf(
                        WorkoutSet(1, reps = 12, weight = 65.0, completed = true),
                        WorkoutSet(2, reps = 11, weight = 65.0, completed = true),
                    ),
                ),
            ) + session.exercises.drop(1),
        )

        store.start(withPrevious)

        assertEquals(12, store.exercises[0].sets[0].reps)
        assertEquals(65.0, store.exercises[0].sets[0].weight)
        assertEquals(2, store.exercises[0].previousSets.size)
    }

    @Test
    fun セットの値を編集できる() = runTest {
        val (_, store, session) = setUp()
        store.start(session)

        store.updateSet(0, 1) { it.copy(weight = 70.0, reps = 8) }

        assertEquals(70.0, store.exercises[0].sets[0].weight)
        assertEquals(8, store.exercises[0].sets[0].reps)
    }

    @Test
    fun 完了にするとレストタイマーが自動で走る() = runTest {
        val (_, store, session) = setUp()
        store.start(session)

        store.toggleSetComplete(0, 1)

        assertTrue(store.exercises[0].sets[0].completed)
        assertTrue(store.isRestActive)
        assertEquals(60, store.restTimer)
    }

    @Test
    fun 完了を取り消すとレストタイマーも止まる() = runTest {
        val (_, store, session) = setUp()
        store.start(session)

        store.toggleSetComplete(0, 1)
        store.toggleSetComplete(0, 1)

        assertFalse(store.exercises[0].sets[0].completed)
        assertFalse(store.isRestActive)
    }

    @Test
    fun レストタイマーは0で自動停止しマイナスにならない() = runTest {
        val (_, store, session) = setUp()
        store.start(session)
        store.startRestTimer(2)

        store.tick()
        assertEquals(1, store.restTimer)

        store.tick()
        assertEquals(0, store.restTimer)
        assertFalse(store.isRestActive)

        store.tick()
        assertEquals(0, store.restTimer)
    }

    @Test
    fun セットを増減できる() = runTest {
        val (_, store, session) = setUp()
        store.start(session)

        store.addSet(0)
        assertEquals(3, store.exercises[0].sets.size)

        store.removeSet(0)
        assertEquals(2, store.exercises[0].sets.size)
    }

    @Test
    fun セットは1本未満にはできない() = runTest {
        val (_, store, session) = setUp()
        store.start(session)

        store.removeSet(1) // 元々1セットの種目
        assertEquals(1, store.exercises[1].sets.size)
    }

    @Test
    fun 種目の移動は範囲外に出ない() = runTest {
        val (_, store, session) = setUp()
        store.start(session)

        store.previousExercise()
        assertEquals(0, store.currentIndex)

        store.nextExercise()
        store.nextExercise()
        assertEquals(1, store.currentIndex)
    }

    @Test
    fun 全セット完了ならcompletedとして保存される() = runTest {
        val (repository, store, session) = setUp()
        store.start(session)

        store.toggleSetComplete(0, 1)
        store.toggleSetComplete(0, 2)
        store.toggleSetComplete(1, 1)

        val summary = assertNotNull(store.finish())

        assertEquals(LogStatus.COMPLETED, summary.status)
        assertEquals(3, summary.completedSets)
        assertEquals(3, summary.totalSets)
        // 50kg × 10回 × 2セット（2種目目は自重なので0）
        assertEquals(1000.0, summary.totalVolume)

        assertEquals(1, repository.listRoutineLogs().size)
        assertEquals(3, repository.listExerciseLogs().size)
    }

    @Test
    fun 一部だけならpartialになる() = runTest {
        val (repository, store, session) = setUp()
        store.start(session)
        store.toggleSetComplete(0, 1)

        val summary = assertNotNull(store.finish())

        assertEquals(LogStatus.PARTIAL, summary.status)
        assertEquals(1, summary.completedSets)
        assertEquals(1, repository.listExerciseLogs().size)
    }

    @Test
    fun 一つも完了していなければskippedになる() = runTest {
        val (repository, store, session) = setUp()
        store.start(session)

        val summary = assertNotNull(store.finish())

        assertEquals(LogStatus.SKIPPED, summary.status)
        assertTrue(repository.listExerciseLogs().isEmpty())
    }

    @Test
    fun 完了後は実行中の状態がクリアされサマリーが残る() = runTest {
        val (_, store, session) = setUp()
        store.start(session)
        store.finish()

        assertFalse(store.isActive)
        assertFalse(store.isRestActive)
        assertNotNull(store.lastSummary)
    }

    @Test
    fun 中断すると何も保存されない() = runTest {
        val (repository, store, session) = setUp()
        store.start(session)
        store.toggleSetComplete(0, 1)

        store.cancel()

        assertFalse(store.isActive)
        assertTrue(repository.listRoutineLogs().isEmpty())
    }

    @Test
    fun 実行中でなければfinishはnullを返す() = runTest {
        val (_, store, _) = setUp()
        assertNull(store.finish())
    }
}

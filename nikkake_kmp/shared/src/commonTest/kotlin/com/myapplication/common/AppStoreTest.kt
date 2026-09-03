package com.myapplication.common

import com.myapplication.common.data.DataCounts
import com.myapplication.common.data.Exercise
import com.myapplication.common.data.ExerciseProgressPoint
import com.myapplication.common.data.HomeView
import com.myapplication.common.data.NetworkFailure
import com.myapplication.common.data.NikkakeRepository
import com.myapplication.common.data.ProgressView
import com.myapplication.common.data.RoutineInput
import com.myapplication.common.data.RoutineWithExercises
import com.myapplication.common.data.SaveWorkoutExercise
import com.myapplication.common.data.WorkoutSessionView
import com.myapplication.common.data.WorkoutSummary
import com.myapplication.common.store.AppStore
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * AppStore の書き込み系が、圏外の失敗を握りつぶさずに呼び出し元へ返すことの確認。
 *
 * 圏外でルーティンを作れると、サーバの採番や検証を通っていないルーティンに
 * 記録が積まれ、整合を取る手段が無くなる。画面が「保存中…」のまま固まらないためには、
 * ここで例外が伝播することが前提になる。
 */
class AppStoreTest {

    /** createRoutine/updateRoutine/resetAll だけ好きに失敗させられる最小の偽実装 */
    private class FailingRepository(private val failOn: MutableSet<String> = mutableSetOf()) :
        NikkakeRepository {

        var reloadCount = 0
            private set

        fun failNext(vararg ops: String) {
            failOn.addAll(ops)
        }

        override suspend fun seedIfNeeded(): Boolean = true

        override suspend fun getHome(todayDate: LocalDate?): HomeView {
            reloadCount++
            return HomeView()
        }

        override suspend fun getProgress(rangeDays: Int, todayDate: LocalDate?): ProgressView = ProgressView()

        override suspend fun getExerciseProgressPoints(
            exerciseId: String,
            limit: Int,
        ): List<ExerciseProgressPoint> = emptyList()

        override suspend fun getDay(date: String): com.myapplication.common.data.DayView =
            com.myapplication.common.data.DayView(date = date)

        override suspend fun getWorkoutSession(routineId: String): WorkoutSessionView? = null

        override suspend fun listExercises(): List<Exercise> = emptyList()

        override suspend fun listRoutinesWithExercises(): List<RoutineWithExercises> = emptyList()

        override suspend fun getRoutineWithExercises(routineId: String): RoutineWithExercises? = null

        override suspend fun createCustomExercise(name: String, category: String, icon: String?): Exercise =
            error("未使用")

        override suspend fun createRoutine(input: RoutineInput): com.myapplication.common.data.Routine {
            if ("createRoutine" in failOn) throw NetworkFailure("圏外")
            return buildRoutine()
        }

        override suspend fun updateRoutine(
            routineId: String,
            input: RoutineInput,
        ): com.myapplication.common.data.Routine? {
            if ("updateRoutine" in failOn) throw NetworkFailure("圏外")
            return buildRoutine()
        }

        override suspend fun setRoutineActive(routineId: String, isActive: Boolean) = Unit

        override suspend fun deleteRoutine(routineId: String) = Unit

        override suspend fun saveWorkout(
            routineId: String,
            startedAt: String,
            durationSec: Int,
            exercises: List<SaveWorkoutExercise>,
            notes: String?,
        ): WorkoutSummary = error("未使用")

        override suspend fun getCounts(): DataCounts = DataCounts()

        override suspend fun resetAll() {
            if ("resetAll" in failOn) throw NetworkFailure("圏外")
        }

        override suspend fun pendingCount(): Int = 0
    }

    @Test
    fun createRoutineが圏外なら例外がそのまま伝わる() = runTest {
        val repo = FailingRepository().apply { failNext("createRoutine") }
        val store = AppStore(repo, scope = TestScope(StandardTestDispatcher(testScheduler)))

        assertFailsWith<NetworkFailure> {
            store.createRoutine(RoutineInput(name = "テスト", icon = "💪", color = "#6C5CE7"))
        }
        // 失敗したので reload は走っていない（画面のキャッシュが壊れたデータで上書きされない）
        assertTrue(repo.reloadCount == 0)
    }

    @Test
    fun updateRoutineが圏外なら例外がそのまま伝わる() = runTest {
        val repo = FailingRepository().apply { failNext("updateRoutine") }
        val store = AppStore(repo, scope = TestScope(StandardTestDispatcher(testScheduler)))

        assertFailsWith<NetworkFailure> {
            store.updateRoutine("r1", RoutineInput(name = "テスト", icon = "💪", color = "#6C5CE7"))
        }
    }

    @Test
    fun resetAllが圏外なら例外がそのまま伝わる() = runTest {
        val repo = FailingRepository().apply { failNext("resetAll") }
        val store = AppStore(repo, scope = TestScope(StandardTestDispatcher(testScheduler)))

        assertFailsWith<NetworkFailure> { store.resetAll() }
    }

    @Test
    fun 成功時は保存してから読み直す() = runTest {
        val repo = FailingRepository()
        val store = AppStore(repo, scope = TestScope(StandardTestDispatcher(testScheduler)))

        store.createRoutine(RoutineInput(name = "テスト", icon = "💪", color = "#6C5CE7"))

        assertTrue(repo.reloadCount > 0)
    }

    private fun buildRoutine() = com.myapplication.common.data.Routine(
        id = "r1",
        name = "テスト",
        color = "#6C5CE7",
        icon = "💪",
        createdAt = "2026-01-01T00:00:00Z",
        updatedAt = "2026-01-01T00:00:00Z",
    )
}

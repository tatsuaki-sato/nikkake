package com.myapplication.common.store

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.myapplication.common.data.DataCounts
import com.myapplication.common.data.DayView
import com.myapplication.common.data.Exercise
import com.myapplication.common.data.ExerciseProgressPoint
import com.myapplication.common.data.HomeView
import com.myapplication.common.data.NikkakeRepository
import com.myapplication.common.data.ProgressView
import com.myapplication.common.data.RoutineInput
import com.myapplication.common.data.RoutineWithExercises
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * 画面が読む状態をまとめて持つ。
 *
 * 保持しているのは**サーバが組み立てた集計済みビュー**で、生のログは持たない。
 * 画面側で集計し直すと、サーバと基準がずれても誰も気づけないため。
 *
 * リポジトリは suspend だが、公開する関数は非 suspend にして中で launch する。
 * こうしないと Compose の各コールバックに毎回スコープを引き回すことになり、
 * 画面側が「どこで待つか」を意識させられる。
 */
class AppStore(
    val repository: NikkakeRepository,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main),
) {

    var home by mutableStateOf(HomeView())
        private set
    var progress by mutableStateOf(ProgressView())
        private set
    var routines by mutableStateOf<List<RoutineWithExercises>>(emptyList())
        private set
    var exercises by mutableStateOf<List<Exercise>>(emptyList())
        private set
    var counts by mutableStateOf(DataCounts())
        private set
    var progressRangeDays by mutableStateOf(7)
        private set
    var loaded by mutableStateOf(false)
        private set

    /**
     * 初回起動時のシード投入を含む立ち上げ。
     * ネットワークを使わないので必ず終わる。
     * サーバへの登録はここでは待たない（docs/ARCHITECTURE.md の遅延登録）。
     */
    fun bootstrap() {
        scope.launch {
            repository.seedIfNeeded()
            reload()
        }
    }

    fun refresh() {
        scope.launch { reload() }
    }

    private suspend fun reload() {
        home = repository.getHome()
        progress = repository.getProgress(rangeDays = progressRangeDays)
        routines = repository.listRoutinesWithExercises()
        exercises = repository.listExercises()
        counts = repository.getCounts()
        loaded = true
    }

    fun setProgressRange(days: Int) {
        if (progressRangeDays == days) return
        progressRangeDays = days
        scope.launch { progress = repository.getProgress(rangeDays = days) }
    }

    suspend fun exerciseProgress(exerciseId: String): List<ExerciseProgressPoint> =
        repository.getExerciseProgressPoints(exerciseId)

    suspend fun day(date: String): DayView = repository.getDay(date)

    fun findRoutine(id: String): RoutineWithExercises? = routines.firstOrNull { it.id == id }

    /**
     * 圏外でルーティンを作れると、サーバの採番や検証を通っていない
     * ルーティンに対して記録が積まれ、整合を取る手段が無くなる。
     *
     * suspend にして例外をそのまま呼び出し元へ伝える。ここで握りつぶすと、
     * 画面側が失敗を知る手段が無くなり「保存中…」のまま固まる。
     */
    suspend fun createRoutine(input: RoutineInput) {
        repository.createRoutine(input)
        reload()
    }

    suspend fun updateRoutine(id: String, input: RoutineInput) {
        repository.updateRoutine(id, input)
        reload()
    }

    fun deleteRoutine(id: String) {
        scope.launch {
            repository.deleteRoutine(id)
            reload()
        }
    }

    fun setRoutineActive(id: String, isActive: Boolean) {
        scope.launch {
            repository.setRoutineActive(id, isActive)
            reload()
        }
    }

    suspend fun resetAll() {
        repository.resetAll()
        reload()
    }
}

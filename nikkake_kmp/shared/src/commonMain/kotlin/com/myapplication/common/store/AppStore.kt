package com.myapplication.common.store

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.myapplication.common.data.Exercise
import com.myapplication.common.data.ExerciseLog
import com.myapplication.common.data.Repository
import com.myapplication.common.data.RoutineInput
import com.myapplication.common.data.RoutineLog
import com.myapplication.common.data.RoutineWithExercises
import com.myapplication.common.data.TodayRoutine

/**
 * ルーティンとログの読み取り状態をまとめて持つ。
 *
 * 参照はすべてローカルストレージなので取得コストが安い。
 * キャッシュを細かく持つより、変更のたびに再読込する方が
 * 画面間の不整合が出ずに単純になる。
 */
class AppStore(val repository: Repository) {

    var routines by mutableStateOf<List<RoutineWithExercises>>(emptyList())
        private set
    var todayRoutines by mutableStateOf<List<TodayRoutine>>(emptyList())
        private set
    var routineLogs by mutableStateOf<List<RoutineLog>>(emptyList())
        private set
    var exerciseLogs by mutableStateOf<List<ExerciseLog>>(emptyList())
        private set
    var exercises by mutableStateOf<List<Exercise>>(emptyList())
        private set
    var loaded by mutableStateOf(false)
        private set

    /**
     * 初回起動時のシード投入を含む立ち上げ。
     * これが終わればサインインの有無に関係なくアプリは完全に使える。
     */
    fun bootstrap() {
        repository.seedIfNeeded()
        refresh()
    }

    fun refresh() {
        routines = repository.listRoutinesWithExercises()
        todayRoutines = repository.getTodayRoutines()
        routineLogs = repository.listRoutineLogs()
        exerciseLogs = repository.listExerciseLogs()
        exercises = repository.listExercises()
        loaded = true
    }

    fun findRoutine(id: String): RoutineWithExercises? = routines.firstOrNull { it.id == id }

    fun createRoutine(input: RoutineInput) {
        repository.createRoutine(input)
        refresh()
    }

    fun updateRoutine(id: String, input: RoutineInput) {
        repository.updateRoutine(id, input)
        refresh()
    }

    fun deleteRoutine(id: String) {
        repository.deleteRoutine(id)
        refresh()
    }

    fun setRoutineActive(id: String, isActive: Boolean) {
        repository.setRoutineActive(id, isActive)
        refresh()
    }

    fun resetAll() {
        repository.resetAll()
        refresh()
    }

    val localCounts: Map<String, Int> get() = repository.getLocalCounts()
}

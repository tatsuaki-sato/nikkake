package com.myapplication.common.store

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.myapplication.common.constants.DEFAULT_REST_SEC
import com.myapplication.common.data.LogStatus
import com.myapplication.common.data.Repository
import com.myapplication.common.data.WorkoutSessionView
import com.myapplication.common.data.SaveWorkoutExercise
import com.myapplication.common.data.WorkoutExerciseState
import com.myapplication.common.data.WorkoutSet
import com.myapplication.common.data.WorkoutSummary
import com.myapplication.common.domain.today
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

/**
 * 実行中のワークアウトの状態。
 * 保存はローカルストレージへの書き込みなので即座に完了する。
 */
class WorkoutStore(private val repository: Repository) {

    var routineId by mutableStateOf<String?>(null)
        private set
    var routineName by mutableStateOf("")
        private set
    var exercises by mutableStateOf<List<WorkoutExerciseState>>(emptyList())
        private set
    var currentIndex by mutableStateOf(0)
        private set
    var restTimer by mutableStateOf(0)
        private set
    var isRestActive by mutableStateOf(false)
        private set
    var elapsedSec by mutableStateOf(0)
        private set
    var lastSummary by mutableStateOf<WorkoutSummary?>(null)
        private set

    private var startedAtInstant: Instant? = null
    private var startedOn: LocalDate = today()

    val isActive: Boolean get() = routineId != null
    val current: WorkoutExerciseState?
        get() = exercises.getOrNull(currentIndex.coerceIn(0, maxOf(0, exercises.size - 1)))

    val completedSetCount: Int get() = exercises.sumOf { e -> e.sets.count { it.completed } }
    val totalSetCount: Int get() = exercises.sumOf { it.sets.size }
    val progress: Float get() = if (totalSetCount == 0) 0f else completedSetCount.toFloat() / totalSetCount

    /**
     * 実行を開始する。
     * 「前回の記録」はセッションに解決済みで入っているので、ここで過去ログを漁らない。
     */
    fun start(session: WorkoutSessionView) {
        routineId = session.routine.id
        routineName = session.routine.name
        currentIndex = 0
        startedAtInstant = Clock.System.now()
        startedOn = today()
        elapsedSec = 0
        restTimer = 0
        isRestActive = false
        lastSummary = null

        exercises = session.exercises.map { entry ->
            val previousSets = entry.previousSets
            val setCount = maxOf(1, entry.targetSets)

            WorkoutExerciseState(
                routineExerciseId = entry.routineExerciseId,
                exercise = entry.exercise,
                targetSets = setCount,
                targetReps = entry.targetReps,
                targetWeight = entry.targetWeight,
                targetDurationSec = entry.targetDurationSec,
                restSec = entry.restSec,
                previousSets = previousSets,
                // 前回の記録があればそれを初期値にする。前回と同じ重量から始めることが多いため。
                sets = (1..setCount).map { number ->
                    val previous = previousSets.firstOrNull { it.setNumber == number }
                    WorkoutSet(
                        setNumber = number,
                        reps = previous?.reps ?: entry.targetReps,
                        weight = previous?.weight ?: entry.targetWeight,
                        durationSec = previous?.durationSec ?: entry.targetDurationSec,
                    )
                },
            )
        }
    }

    /** 経過時間とレストタイマーを1秒ごとにまとめて進める */
    fun tick() {
        if (!isActive) return

        startedAtInstant?.let { elapsedSec = (Clock.System.now() - it).inWholeSeconds.toInt() }

        if (isRestActive) {
            if (restTimer <= 1) {
                restTimer = 0
                isRestActive = false
            } else {
                restTimer--
            }
        }
    }

    fun goToExercise(index: Int) {
        if (exercises.isEmpty()) return
        currentIndex = index.coerceIn(0, exercises.size - 1)
    }

    fun nextExercise() = goToExercise(currentIndex + 1)
    fun previousExercise() = goToExercise(currentIndex - 1)

    fun updateSet(exerciseIndex: Int, setNumber: Int, transform: (WorkoutSet) -> WorkoutSet) {
        val exercise = exercises.getOrNull(exerciseIndex) ?: return

        exercises = exercises.toMutableList().also { list ->
            list[exerciseIndex] = exercise.copy(
                sets = exercise.sets.map { if (it.setNumber == setNumber) transform(it) else it },
            )
        }
    }

    fun toggleSetComplete(exerciseIndex: Int, setNumber: Int) {
        val exercise = exercises.getOrNull(exerciseIndex) ?: return
        val target = exercise.sets.firstOrNull { it.setNumber == setNumber } ?: return

        val willComplete = !target.completed
        updateSet(exerciseIndex, setNumber) { it.copy(completed = willComplete) }

        // セットを終えた直後にレストタイマーを自動で回す。手動で押させるとまず押し忘れる。
        if (willComplete) startRestTimer(exercise.restSec) else stopRestTimer()
    }

    fun addSet(exerciseIndex: Int) {
        val exercise = exercises.getOrNull(exerciseIndex) ?: return
        val last = exercise.sets.lastOrNull()

        exercises = exercises.toMutableList().also { list ->
            list[exerciseIndex] = exercise.copy(
                sets = exercise.sets + WorkoutSet(
                    setNumber = (last?.setNumber ?: 0) + 1,
                    reps = last?.reps ?: exercise.targetReps,
                    weight = last?.weight ?: exercise.targetWeight,
                    durationSec = last?.durationSec ?: exercise.targetDurationSec,
                ),
            )
        }
    }

    fun removeSet(exerciseIndex: Int) {
        val exercise = exercises.getOrNull(exerciseIndex) ?: return
        // セット0本にすると種目自体が意味を失うので最低1本は残す
        if (exercise.sets.size <= 1) return

        exercises = exercises.toMutableList().also { list ->
            list[exerciseIndex] = exercise.copy(sets = exercise.sets.dropLast(1))
        }
    }

    fun startRestTimer(seconds: Int) {
        if (seconds <= 0) return
        restTimer = seconds
        isRestActive = true
    }

    fun stopRestTimer() {
        restTimer = 0
        isRestActive = false
    }

    /**
     * 記録を確定する。
     *
     * suspend なのはサーバへ送るため。圏外ならリポジトリ側でキューに積まれ、
     * 画面には暫定のサマリーが返るので、ここで待っても止まらない。
     */
    suspend fun finish(): WorkoutSummary? {
        val id = routineId ?: return null
        val startedAt = startedAtInstant ?: return null

        val completed = completedSetCount
        val total = totalSetCount
        val volume = exercises.sumOf { e ->
            e.sets.filter { it.completed }.sumOf { (it.weight ?: 0.0) * (it.reps ?: 0) }
        }

        val durationSec = (Clock.System.now() - startedAt).inWholeSeconds.toInt()

        // セット数の集計も status の判定もリポジトリが行う。
        // ここで決めるとサーバの判定基準とずれたときに気づけない。
        val saved = repository.saveWorkout(
            routineId = id,
            startedAt = startedAt.toString(),
            durationSec = durationSec,
            exercises = exercises.map {
                SaveWorkoutExercise(
                    routineExerciseId = it.routineExerciseId,
                    exerciseId = it.exercise.id,
                    sets = it.sets,
                )
            },
        )

        // ルーティン名だけは手元のほうが確実。
        // オフラインで記録したときサーバは名前を返せない
        val summary = saved.copy(routineName = routineName)

        clear()
        lastSummary = summary
        return summary
    }

    fun cancel() = clear()

    fun clearSummary() {
        lastSummary = null
    }

    private fun clear() {
        routineId = null
        routineName = ""
        exercises = emptyList()
        startedAtInstant = null
        currentIndex = 0
        restTimer = 0
        isRestActive = false
        elapsedSec = 0
    }
}

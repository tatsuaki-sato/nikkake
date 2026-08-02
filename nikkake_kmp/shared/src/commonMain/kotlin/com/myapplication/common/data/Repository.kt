package com.myapplication.common.data

import com.myapplication.common.constants.DEFAULT_REST_SEC
import com.myapplication.common.constants.STARTER_ROUTINE_NAME
import com.myapplication.common.constants.presetExercises
import com.myapplication.common.constants.routineColors
import com.myapplication.common.constants.routineIcons
import com.myapplication.common.constants.starterRoutineExercises
import com.myapplication.common.domain.getDateString
import com.myapplication.common.domain.isRoutineDueToday
import com.myapplication.common.domain.nowIso
import com.myapplication.common.domain.parseDateString
import com.myapplication.common.domain.today
import kotlinx.datetime.LocalDate

data class RoutineExerciseInput(
    val exerciseId: String,
    val targetSets: Int = 3,
    val targetReps: Int? = null,
    val targetWeight: Double? = null,
    val targetDurationSec: Int? = null,
    val restSec: Int? = null,
)

data class RoutineInput(
    val name: String,
    val description: String? = null,
    val icon: String,
    val color: String,
    val frequencyType: String = FrequencyType.DAILY,
    val frequencyValue: Int = 1,
    val frequencyDays: List<Int> = emptyList(),
    val isActive: Boolean = true,
    val exercises: List<RoutineExerciseInput> = emptyList(),
)

data class SaveWorkoutExercise(
    val routineExerciseId: String,
    val exerciseId: String,
    val sets: List<WorkoutSet>,
)

/**
 * 画面が直接触るデータAPI。
 *
 * 参照も更新も必ずローカルストレージに対して行い、ネットワークは介在しない。
 * サインインしている場合は SyncService がバックグラウンドでSupabaseへ複製するが、
 * 画面はその成否を待たないので、オフラインでも常に即座に応答する。
 */
class Repository(val db: LocalDb) {

    // ------------------------------------------
    // 初期データ
    // ------------------------------------------

    /**
     * 初回起動時のデータ投入。
     * サインインなしで即使えるよう、起動時点で「今日やるルーティン」を1つ用意する。
     * ユーザーが消したあとに復活すると鬱陶しいので、投入は meta.seeded で1度だけ。
     */
    fun seedIfNeeded(): Boolean {
        val seeded = db.getMeta().seeded
        syncPresetExercises()

        if (seeded) return false

        createStarterRoutine()
        db.setMeta(seeded = true)
        return true
    }

    /** アプリ側の定義に存在してローカルに無いプリセット種目を足す */
    private fun syncPresetExercises(): Int {
        val existingIds = db.readRaw(Collections.EXERCISES, Exercise.serializer()).map { it.id }.toSet()
        val missing = presetExercises.filter { it.id !in existingIds }
        if (missing.isEmpty()) return 0

        val timestamp = nowIso()
        db.insertMany(
            Collections.EXERCISES,
            Exercise.serializer(),
            missing.map {
                Exercise(
                    id = it.id,
                    name = it.name,
                    category = it.category,
                    icon = it.icon,
                    isPreset = true,
                    createdAt = timestamp,
                    updatedAt = timestamp,
                )
            },
        )
        return missing.size
    }

    /**
     * 初期ルーティンのIDは端末ごとに採番する（固定値にしない）。
     *
     * ローカルだけで完結していた頃は固定でも無害だったが、
     * サーバへ預ける今は全端末が同じIDを送ることになり、
     * 主キー衝突で2人目以降の初期ルーティンが黙って消える。
     */
    private fun createStarterRoutine() {
        val timestamp = nowIso()
        val routineId = Uuid.v4()

        db.insert(
            Collections.ROUTINES,
            Routine.serializer(),
            Routine(
                id = routineId,
                name = STARTER_ROUTINE_NAME,
                description = "器具なしで今すぐ始められる基本メニューです。自由に編集してください。",
                color = routineColors.first(),
                icon = routineIcons.first(),
                frequencyType = FrequencyType.DAILY,
                createdAt = timestamp,
                updatedAt = timestamp,
            ),
        )

        db.insertMany(
            Collections.ROUTINE_EXERCISES,
            RoutineExercise.serializer(),
            starterRoutineExercises.mapIndexed { index, e ->
                RoutineExercise(
                    id = Uuid.v4(),
                    routineId = routineId,
                    exerciseId = e.exerciseId,
                    sortOrder = index,
                    targetSets = e.sets,
                    targetReps = e.reps,
                    targetDurationSec = e.durationSec,
                    restSec = e.restSec,
                    createdAt = timestamp,
                    updatedAt = timestamp,
                )
            },
        )
    }

    // ------------------------------------------
    // Exercises
    // ------------------------------------------

    fun listExercises(): List<Exercise> =
        db.list(Collections.EXERCISES, Exercise.serializer())
            .sortedWith(compareBy({ ExerciseCategory.all.indexOf(it.category) }, { it.name }))

    fun createCustomExercise(name: String, category: String, icon: String?): Exercise {
        val timestamp = nowIso()
        return db.insert(
            Collections.EXERCISES,
            Exercise.serializer(),
            Exercise(
                id = Uuid.v4(),
                name = name,
                category = category,
                icon = icon,
                isPreset = false,
                createdAt = timestamp,
                updatedAt = timestamp,
            ),
        )
    }

    // ------------------------------------------
    // Routines
    // ------------------------------------------

    fun listRoutines(): List<Routine> =
        db.list(Collections.ROUTINES, Routine.serializer())
            .sortedWith(compareBy({ it.sortOrder }, { it.createdAt }))

    fun listRoutinesWithExercises(): List<RoutineWithExercises> {
        val links = db.list(Collections.ROUTINE_EXERCISES, RoutineExercise.serializer())
        val exerciseById = listExercises().associateBy { it.id }

        return listRoutines().map { routine ->
            RoutineWithExercises(
                routine = routine,
                exercises = links
                    .filter { it.routineId == routine.id }
                    .sortedBy { it.sortOrder }
                    // 種目が削除済みのリンクが残っていても画面を落とさない
                    .mapNotNull { link ->
                        exerciseById[link.exerciseId]?.let { RoutineExerciseWithExercise(link, it) }
                    },
            )
        }
    }

    fun getRoutineWithExercises(routineId: String): RoutineWithExercises? =
        listRoutinesWithExercises().firstOrNull { it.id == routineId }

    fun createRoutine(input: RoutineInput): Routine {
        val timestamp = nowIso()

        val routine = db.insert(
            Collections.ROUTINES,
            Routine.serializer(),
            Routine(
                id = Uuid.v4(),
                name = input.name,
                description = input.description,
                color = input.color,
                icon = input.icon,
                frequencyType = input.frequencyType,
                frequencyValue = input.frequencyValue,
                frequencyDays = input.frequencyDays,
                isActive = input.isActive,
                sortOrder = listRoutines().size,
                createdAt = timestamp,
                updatedAt = timestamp,
            ),
        )

        replaceRoutineExercises(routine.id, input.exercises)
        return routine
    }

    fun updateRoutine(routineId: String, input: RoutineInput): Routine? {
        val updated = db.update(Collections.ROUTINES, Routine.serializer(), routineId) {
            it.copy(
                name = input.name,
                description = input.description,
                color = input.color,
                icon = input.icon,
                frequencyType = input.frequencyType,
                frequencyValue = input.frequencyValue,
                frequencyDays = input.frequencyDays,
                isActive = input.isActive,
            )
        } ?: return null

        replaceRoutineExercises(routineId, input.exercises)
        return updated
    }

    /**
     * ルーティン内の種目構成を丸ごと差し替える。
     * 差分更新にすると並び順の入れ替えが厄介なので、既存リンクを論理削除して作り直す。
     * 過去のログは exercise_id でも引けるので、作り直しても履歴グラフは途切れない。
     */
    private fun replaceRoutineExercises(routineId: String, exercises: List<RoutineExerciseInput>) {
        db.softDeleteWhere(Collections.ROUTINE_EXERCISES, RoutineExercise.serializer()) {
            it.routineId == routineId
        }
        if (exercises.isEmpty()) return

        val timestamp = nowIso()
        db.insertMany(
            Collections.ROUTINE_EXERCISES,
            RoutineExercise.serializer(),
            exercises.mapIndexed { index, e ->
                RoutineExercise(
                    id = Uuid.v4(),
                    routineId = routineId,
                    exerciseId = e.exerciseId,
                    sortOrder = index,
                    targetSets = e.targetSets,
                    targetReps = e.targetReps,
                    targetWeight = e.targetWeight,
                    targetDurationSec = e.targetDurationSec,
                    restSec = e.restSec ?: DEFAULT_REST_SEC,
                    createdAt = timestamp,
                    updatedAt = timestamp,
                )
            },
        )
    }

    fun setRoutineActive(routineId: String, isActive: Boolean) {
        db.update(Collections.ROUTINES, Routine.serializer(), routineId) { it.copy(isActive = isActive) }
    }

    fun deleteRoutine(routineId: String) {
        db.softDeleteWhere(Collections.ROUTINE_EXERCISES, RoutineExercise.serializer()) {
            it.routineId == routineId
        }
        db.softDelete(Collections.ROUTINES, Routine.serializer(), routineId)
    }

    // ------------------------------------------
    // Logs
    // ------------------------------------------

    fun listRoutineLogs(): List<RoutineLog> = db.list(Collections.ROUTINE_LOGS, RoutineLog.serializer())

    fun listExerciseLogs(): List<ExerciseLog> = db.list(Collections.EXERCISE_LOGS, ExerciseLog.serializer())

    fun getTodayLogs(todayDate: LocalDate = today()): List<RoutineLog> {
        val date = getDateString(todayDate)
        return listRoutineLogs().filter { it.logDate == date }
    }

    /** ホーム画面用。ルーティンごとに「今日やるべきか」「今日もう終わったか」を解決して返す */
    fun getTodayRoutines(todayDate: LocalDate = today()): List<TodayRoutine> {
        val date = getDateString(todayDate)
        val logs = listRoutineLogs()

        return listRoutinesWithExercises().filter { it.routine.isActive }.map { routine ->
            val routineLogs = logs.filter { it.routineId == routine.id }.sortedByDescending { it.logDate }
            val todayLog = routineLogs.firstOrNull { it.logDate == date }
            val lastLog = routineLogs.firstOrNull { it.status != LogStatus.SKIPPED }

            TodayRoutine(
                routine = routine,
                // 全セット完了でなくても、記録を残した時点で今日の分は済んだものとして扱う。
                // ストリークの判定(Stats.didWorkout)と基準を揃えている。
                isCompleted = todayLog != null && todayLog.status != LogStatus.SKIPPED,
                isDueToday = isRoutineDueToday(routine.routine, lastLog, todayDate),
                lastLog = lastLog,
            )
        }
    }

    /** ワークアウト1回分の保存 */
    fun saveWorkout(
        routineId: String,
        startedAt: String,
        startedOn: LocalDate,
        durationSec: Int,
        status: String,
        exercises: List<SaveWorkoutExercise>,
        notes: String? = null,
    ): RoutineLog {
        val timestamp = nowIso()

        val routineLog = db.insert(
            Collections.ROUTINE_LOGS,
            RoutineLog.serializer(),
            RoutineLog(
                id = Uuid.v4(),
                routineId = routineId,
                logDate = getDateString(startedOn),
                status = status,
                durationSec = durationSec,
                notes = notes,
                startedAt = startedAt,
                completedAt = timestamp,
                createdAt = timestamp,
                updatedAt = timestamp,
            ),
        )

        val exerciseLogs = exercises.flatMap { exercise ->
            exercise.sets.filter { it.completed }.map { set ->
                ExerciseLog(
                    id = Uuid.v4(),
                    routineLogId = routineLog.id,
                    routineExerciseId = exercise.routineExerciseId,
                    exerciseId = exercise.exerciseId,
                    setNumber = set.setNumber,
                    actualReps = set.reps,
                    actualWeight = set.weight,
                    actualDurationSec = set.durationSec,
                    createdAt = timestamp,
                    updatedAt = timestamp,
                )
            }
        }

        db.insertMany(Collections.EXERCISE_LOGS, ExerciseLog.serializer(), exerciseLogs)
        return routineLog
    }

    fun deleteRoutineLog(routineLogId: String) {
        db.softDeleteWhere(Collections.EXERCISE_LOGS, ExerciseLog.serializer()) {
            it.routineLogId == routineLogId
        }
        db.softDelete(Collections.ROUTINE_LOGS, RoutineLog.serializer(), routineLogId)
    }

    /**
     * 前回のワークアウトで各種目を何kg×何回やったか。
     * ワークアウト画面で「前回の記録」を初期値に出すために使う。
     */
    fun getLastSetsByExercise(routineId: String): Map<String, List<WorkoutSet>> {
        val latest = listRoutineLogs()
            .filter { it.routineId == routineId && it.status != LogStatus.SKIPPED }
            .maxByOrNull { it.startedAt ?: it.createdAt }
            ?: return emptyMap()

        return listExerciseLogs()
            .filter { it.routineLogId == latest.id }
            .groupBy { it.exerciseId }
            .mapValues { (_, logs) ->
                logs.sortedBy { it.setNumber }.map {
                    WorkoutSet(
                        setNumber = it.setNumber,
                        reps = it.actualReps,
                        weight = it.actualWeight,
                        durationSec = it.actualDurationSec,
                        completed = true,
                    )
                }
            }
    }

    /** 設定画面に出すローカル件数 */
    fun getLocalCounts(): Map<String, Int> = mapOf(
        Collections.EXERCISES to listExercises().size,
        Collections.ROUTINES to listRoutines().size,
        Collections.ROUTINE_EXERCISES to db.list(Collections.ROUTINE_EXERCISES, RoutineExercise.serializer()).size,
        Collections.ROUTINE_LOGS to listRoutineLogs().size,
        Collections.EXERCISE_LOGS to listExerciseLogs().size,
    )

    fun resetAll() {
        db.reset()
        seedIfNeeded()
    }

    /** ログの日付文字列をLocalDateに戻すヘルパー（画面から使う） */
    fun logDateOf(log: RoutineLog): LocalDate = parseDateString(log.logDate)
}

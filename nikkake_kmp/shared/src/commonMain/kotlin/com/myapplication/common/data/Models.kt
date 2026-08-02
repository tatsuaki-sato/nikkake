package com.myapplication.common.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================
// nikkake - ドメインモデル (KMP)
// ============================================
//
// データはすべて端末ローカルが真実の源。サインインしている場合のみ
// 同じ形のレコードがSupabaseへ複製される。
// そのため全エンティティが updated_at / deleted_at を持ち、
// 同期は updated_at による last-write-wins で解決する。
//
// @SerialName はSupabaseの列名(snake_case)に合わせてある。
// ローカル保存にも同じシリアライズを使うので、同期時の変換が要らない。

/**
 * 同期に必要な共通フィールド。
 *
 * 自己型パラメータ T を取っているのは、LocalDb が型を失わずに
 * updated_at / deleted_at を書き換えられるようにするため
 * （非ジェネリックにするとキャストが必要になる）。
 */
interface SyncEntity<T : SyncEntity<T>> {
    val id: String
    val updatedAt: String
    val deletedAt: String?

    fun touched(updatedAt: String = this.updatedAt, deletedAt: String? = this.deletedAt): T
}

@Serializable
data class Exercise(
    override val id: String,
    val name: String,
    val category: String,
    val description: String? = null,
    val icon: String? = null,
    @SerialName("is_preset") val isPreset: Boolean = false,
    @SerialName("created_by") val createdBy: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") override val updatedAt: String,
    @SerialName("deleted_at") override val deletedAt: String? = null,
) : SyncEntity<Exercise> {
    override fun touched(updatedAt: String, deletedAt: String?) =
        copy(updatedAt = updatedAt, deletedAt = deletedAt)
}

@Serializable
data class Routine(
    override val id: String,
    /** ローカル専用データは null。サインイン後の同期で埋まる */
    @SerialName("user_id") val userId: String? = null,
    val name: String,
    val description: String? = null,
    val color: String = "#6C5CE7",
    val icon: String = "💪",
    @SerialName("frequency_type") val frequencyType: String = "daily",
    @SerialName("frequency_value") val frequencyValue: Int = 1,
    @SerialName("frequency_days") val frequencyDays: List<Int> = emptyList(),
    @SerialName("preferred_time") val preferredTime: String? = null,
    @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("sort_order") val sortOrder: Int = 0,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") override val updatedAt: String,
    @SerialName("deleted_at") override val deletedAt: String? = null,
) : SyncEntity<Routine> {
    override fun touched(updatedAt: String, deletedAt: String?) =
        copy(updatedAt = updatedAt, deletedAt = deletedAt)
}

@Serializable
data class RoutineExercise(
    override val id: String,
    @SerialName("routine_id") val routineId: String,
    @SerialName("exercise_id") val exerciseId: String,
    @SerialName("sort_order") val sortOrder: Int = 0,
    @SerialName("target_sets") val targetSets: Int = 3,
    @SerialName("target_reps") val targetReps: Int? = null,
    @SerialName("target_weight") val targetWeight: Double? = null,
    @SerialName("target_duration_sec") val targetDurationSec: Int? = null,
    @SerialName("rest_sec") val restSec: Int? = null,
    val notes: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") override val updatedAt: String,
    @SerialName("deleted_at") override val deletedAt: String? = null,
) : SyncEntity<RoutineExercise> {
    override fun touched(updatedAt: String, deletedAt: String?) =
        copy(updatedAt = updatedAt, deletedAt = deletedAt)
}

@Serializable
data class RoutineLog(
    override val id: String,
    @SerialName("routine_id") val routineId: String,
    @SerialName("user_id") val userId: String? = null,
    /** 'YYYY-MM-DD'。日跨ぎの判定はこの値で行う */
    @SerialName("log_date") val logDate: String,
    val status: String,
    @SerialName("duration_sec") val durationSec: Int? = null,
    val notes: String? = null,
    @SerialName("started_at") val startedAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") override val updatedAt: String,
    @SerialName("deleted_at") override val deletedAt: String? = null,
) : SyncEntity<RoutineLog> {
    override fun touched(updatedAt: String, deletedAt: String?) =
        copy(updatedAt = updatedAt, deletedAt = deletedAt)
}

@Serializable
data class ExerciseLog(
    override val id: String,
    @SerialName("routine_log_id") val routineLogId: String,
    @SerialName("routine_exercise_id") val routineExerciseId: String? = null,
    /** ルーティン編集で routine_exercises が作り直されても履歴を辿れるように持つ */
    @SerialName("exercise_id") val exerciseId: String,
    @SerialName("set_number") val setNumber: Int,
    @SerialName("actual_reps") val actualReps: Int? = null,
    @SerialName("actual_weight") val actualWeight: Double? = null,
    @SerialName("actual_duration_sec") val actualDurationSec: Int? = null,
    val notes: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") override val updatedAt: String,
    @SerialName("deleted_at") override val deletedAt: String? = null,
) : SyncEntity<ExerciseLog> {
    override fun touched(updatedAt: String, deletedAt: String?) =
        copy(updatedAt = updatedAt, deletedAt = deletedAt)
}

// ============================================
// 列挙相当（DBは文字列で持つ）
// ============================================

object FrequencyType {
    const val DAILY = "daily"
    const val EVERY_N_DAYS = "every_n_days"
    const val WEEKLY = "weekly"
}

object LogStatus {
    const val COMPLETED = "completed"
    const val PARTIAL = "partial"
    const val SKIPPED = "skipped"
}

object ExerciseCategory {
    const val STRENGTH = "strength"
    const val CARDIO = "cardio"
    const val GAME = "game"
    const val CUSTOM = "custom"

    val all = listOf(STRENGTH, CARDIO, GAME, CUSTOM)
}

// ============================================
// UI用の合成型
// ============================================

data class RoutineExerciseWithExercise(
    val link: RoutineExercise,
    val exercise: Exercise,
)

data class RoutineWithExercises(
    val routine: Routine,
    val exercises: List<RoutineExerciseWithExercise>,
) {
    val id: String get() = routine.id
    val name: String get() = routine.name
}

data class TodayRoutine(
    val routine: RoutineWithExercises,
    val isCompleted: Boolean,
    val isDueToday: Boolean,
    /**
     * 「毎日」「3日ごと」。サーバが返す文言をそのまま出す。
     * クライアントで組み立てると4実装で表記が割れる
     */
    val frequencyLabel: String = "",
)

data class WorkoutSet(
    val setNumber: Int,
    val reps: Int? = null,
    val weight: Double? = null,
    val durationSec: Int? = null,
    val completed: Boolean = false,
)

data class WorkoutExerciseState(
    val routineExerciseId: String,
    val exercise: Exercise,
    val targetSets: Int,
    val targetReps: Int?,
    val targetWeight: Double?,
    val targetDurationSec: Int?,
    val restSec: Int,
    val sets: List<WorkoutSet>,
    val previousSets: List<WorkoutSet> = emptyList(),
) {
    val isTimeBased: Boolean get() = targetDurationSec != null
}

data class WorkoutSummary(
    val routineLogId: String,
    val routineName: String,
    val durationSec: Int,
    val completedSets: Int,
    val totalSets: Int,
    val totalVolume: Double,
    val status: String,
)

// ============================================
// 統計
// ============================================

data class StreakInfo(
    val current: Int,
    val longest: Int,
    val lastCompletedDate: String? = null,
)

data class DailyStats(
    val date: String,
    val completedCount: Int,
    val totalCount: Int,
)

data class ExerciseProgressPoint(
    val date: String,
    val maxWeight: Double,
    val totalReps: Int,
    val totalVolume: Double,
)

data class OverallStats(
    val totalWorkouts: Int = 0,
    val totalDurationSec: Int = 0,
    val totalSets: Int = 0,
    val thisWeekCount: Int = 0,
)

// ============================================
// 同期
// ============================================

enum class StorageMode { LOCAL, CLOUD }

enum class SyncStatus { IDLE, SYNCING, ERROR, OFFLINE }

data class SyncState(
    val status: SyncStatus = SyncStatus.IDLE,
    val lastSyncedAt: String? = null,
    val lastError: String? = null,
)

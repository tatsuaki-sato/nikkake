package com.myapplication.common.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Profile(
    val id: String,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class Exercise(
    val id: String,
    val name: String,
    val category: String,
    val description: String? = null,
    val icon: String? = null,
    @SerialName("is_preset") val isPreset: Boolean,
    @SerialName("created_by") val createdBy: String? = null,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class Routine(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String,
    val description: String? = null,
    val color: String,
    val icon: String,
    @SerialName("frequency_type") val frequencyType: String,
    @SerialName("frequency_value") val frequencyValue: Int,
    @SerialName("frequency_days") val frequencyDays: List<Int>? = null,
    @SerialName("preferred_time") val preferredTime: String? = null,
    @SerialName("is_active") val isActive: Boolean,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class RoutineExercise(
    val id: String,
    @SerialName("routine_id") val routineId: String,
    @SerialName("exercise_id") val exerciseId: String,
    @SerialName("sort_order") val sortOrder: Int,
    @SerialName("target_sets") val targetSets: Int,
    @SerialName("target_reps") val targetReps: Int? = null,
    @SerialName("target_weight") val targetWeight: Double? = null,
    @SerialName("target_duration_sec") val targetDurationSec: Int? = null,
    val notes: String? = null,
    @SerialName("created_at") val createdAt: String,
    val exercise: Exercise? = null
)

@Serializable
data class RoutineWithExercises(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String,
    val description: String? = null,
    val color: String,
    val icon: String,
    @SerialName("frequency_type") val frequencyType: String,
    @SerialName("frequency_value") val frequencyValue: Int,
    @SerialName("frequency_days") val frequencyDays: List<Int>? = null,
    @SerialName("preferred_time") val preferredTime: String? = null,
    @SerialName("is_active") val isActive: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("routine_exercises") val routineExercises: List<RoutineExercise> = emptyList()
)

@Serializable
data class RoutineLog(
    val id: String,
    @SerialName("routine_id") val routineId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("log_date") val logDate: String,
    val status: String,
    @SerialName("duration_sec") val durationSec: Int? = null,
    val notes: String? = null,
    @SerialName("started_at") val startedAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("created_at") val createdAt: String,
    val routine: Routine? = null,
    @SerialName("exercise_logs") val exerciseLogs: List<ExerciseLog> = emptyList()
)

@Serializable
data class ExerciseLog(
    val id: String,
    @SerialName("routine_log_id") val routineLogId: String,
    @SerialName("routine_exercise_id") val routineExerciseId: String,
    @SerialName("set_number") val setNumber: Int,
    @SerialName("actual_reps") val actualReps: Int? = null,
    @SerialName("actual_weight") val actualWeight: Double? = null,
    @SerialName("actual_duration_sec") val actualDurationSec: Int? = null,
    val notes: String? = null,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class RoutineLogInsert(
    @SerialName("routine_id") val routineId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("log_date") val logDate: String,
    val status: String,
    @SerialName("duration_sec") val durationSec: Int? = null,
    val notes: String? = null,
    @SerialName("started_at") val startedAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null
)

@Serializable
data class ExerciseLogInsert(
    @SerialName("routine_log_id") val routineLogId: String,
    @SerialName("routine_exercise_id") val routineExerciseId: String,
    @SerialName("set_number") val setNumber: Int,
    @SerialName("actual_reps") val actualReps: Int? = null,
    @SerialName("actual_weight") val actualWeight: Double? = null,
    @SerialName("actual_duration_sec") val actualDurationSec: Int? = null,
    val notes: String? = null
)

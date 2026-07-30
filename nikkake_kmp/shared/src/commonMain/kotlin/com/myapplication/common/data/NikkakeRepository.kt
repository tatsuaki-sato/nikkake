package com.myapplication.common.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order

class NikkakeRepository(private val client: SupabaseClient = supabaseClient) {

    suspend fun fetchRoutines(userId: String): List<Routine> {
        return client.from("routines")
            .select {
                filter { eq("user_id", userId) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Routine>()
    }

    suspend fun fetchRoutineWithExercises(routineId: String): RoutineWithExercises {
        val result = client.from("routines")
            .select(columns = Columns.raw("*, routine_exercises(*, exercise:exercises(*))")) {
                filter { eq("id", routineId) }
            }
            .decodeSingle<RoutineWithExercises>()
            
        return result.copy(
            routineExercises = result.routineExercises.sortedBy { it.sortOrder }
        )
    }

    suspend fun fetchExercises(userId: String? = null): List<Exercise> {
        return client.from("exercises")
            .select {
                filter {
                    if (userId != null) {
                        // The 'or' method takes a string argument
                        or("is_preset.eq.true,created_by.eq.$userId")
                    } else {
                        eq("is_preset", true)
                    }
                }
                order("category", Order.ASCENDING)
                order("name", Order.ASCENDING)
            }
            .decodeList<Exercise>()
    }

    suspend fun saveWorkoutLog(
        routineId: String,
        durationSec: Int?,
        status: String,
        notes: String?,
        exerciseLogs: List<ExerciseLogInsert>
    ) {
        @kotlinx.serialization.Serializable
        data class SaveWorkoutLogRequest(
            @kotlinx.serialization.SerialName("p_routine_id") val routineId: String,
            @kotlinx.serialization.SerialName("p_duration_sec") val durationSec: Int?,
            @kotlinx.serialization.SerialName("p_status") val status: String,
            @kotlinx.serialization.SerialName("p_notes") val notes: String?,
            @kotlinx.serialization.SerialName("p_exercise_logs") val exerciseLogs: List<ExerciseLogInsert>
        )
        
        val request = SaveWorkoutLogRequest(routineId, durationSec, status, notes, exerciseLogs)
        io.github.jan.supabase.postgrest.postgrest(client).rpc("save_workout_log", request)
    }

    suspend fun fetchRoutineHistory(routineId: String): String {
        @kotlinx.serialization.Serializable
        data class FetchHistoryRequest(
            @kotlinx.serialization.SerialName("p_routine_id") val routineId: String
        )
        
        val result = io.github.jan.supabase.postgrest.postgrest(client).rpc("get_last_workout_logs", FetchHistoryRequest(routineId))
        return result.data
    }

    suspend fun fetchRecentRoutineLog(routineId: String, userId: String): RoutineLog? {
        return client.from("routine_logs")
            .select {
                filter {
                    eq("routine_id", routineId)
                    eq("user_id", userId)
                }
                order("log_date", Order.DESCENDING)
                limit(1)
            }
            .decodeSingleOrNull<RoutineLog>()
    }

    suspend fun fetchTodayLogs(userId: String, today: String): List<RoutineLog> {
        return client.from("routine_logs")
            .select {
                filter {
                    eq("user_id", userId)
                    eq("log_date", today)
                }
            }
            .decodeList<RoutineLog>()
    }
}

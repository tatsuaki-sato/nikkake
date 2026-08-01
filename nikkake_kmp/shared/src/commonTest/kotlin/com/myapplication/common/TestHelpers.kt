package com.myapplication.common

import com.myapplication.common.data.ExerciseLog
import com.myapplication.common.data.LocalDb
import com.myapplication.common.data.LogStatus
import com.myapplication.common.data.Repository
import com.myapplication.common.data.Routine
import com.myapplication.common.data.RoutineExerciseInput
import com.myapplication.common.data.RoutineInput
import com.myapplication.common.data.RoutineLog
import com.myapplication.common.data.StorageAdapter
import com.myapplication.common.domain.nowIso

/**
 * テスト用のインメモリDB。
 * 端末のストレージに触らないので、テスト間で状態が漏れない。
 */
fun createTestDb(): LocalDb = LocalDb(StorageAdapter.inMemory())

fun createSeededRepository(): Repository = Repository(createTestDb()).also { it.seedIfNeeded() }

const val PUSH_UP_ID = "00000000-0000-4000-8000-000000000003"
const val SQUAT_ID = "00000000-0000-4000-8000-000000000009"
const val BENCH_PRESS_ID = "00000000-0000-4000-8000-000000000001"

fun sampleRoutineInput(
    name: String = "テストルーティン",
    exercises: List<RoutineExerciseInput> = listOf(
        RoutineExerciseInput(exerciseId = PUSH_UP_ID, targetSets = 3, targetReps = 10, restSec = 60),
    ),
    frequencyType: String = com.myapplication.common.data.FrequencyType.DAILY,
    frequencyDays: List<Int> = emptyList(),
) = RoutineInput(
    name = name,
    icon = "💪",
    color = "#6C5CE7",
    frequencyType = frequencyType,
    frequencyDays = frequencyDays,
    exercises = exercises,
)

fun buildRoutine(
    id: String = "r1",
    frequencyType: String = com.myapplication.common.data.FrequencyType.DAILY,
    frequencyValue: Int = 1,
    frequencyDays: List<Int> = emptyList(),
    isActive: Boolean = true,
): Routine {
    val timestamp = nowIso()
    return Routine(
        id = id,
        name = "テスト",
        color = "#6C5CE7",
        icon = "💪",
        frequencyType = frequencyType,
        frequencyValue = frequencyValue,
        frequencyDays = frequencyDays,
        isActive = isActive,
        createdAt = timestamp,
        updatedAt = timestamp,
    )
}

fun buildLog(
    logDate: String,
    status: String = LogStatus.COMPLETED,
    durationSec: Int = 600,
): RoutineLog {
    val timestamp = nowIso()
    return RoutineLog(
        id = "log-$logDate-$status",
        routineId = "r1",
        logDate = logDate,
        status = status,
        durationSec = durationSec,
        createdAt = timestamp,
        updatedAt = timestamp,
    )
}

fun buildExerciseLog(
    routineLogId: String,
    exerciseId: String,
    setNumber: Int,
    reps: Int? = null,
    weight: Double? = null,
): ExerciseLog {
    val timestamp = nowIso()
    return ExerciseLog(
        id = "$routineLogId-$exerciseId-$setNumber",
        routineLogId = routineLogId,
        exerciseId = exerciseId,
        setNumber = setNumber,
        actualReps = reps,
        actualWeight = weight,
        createdAt = timestamp,
        updatedAt = timestamp,
    )
}

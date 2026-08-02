package com.myapplication.common

import com.myapplication.common.data.LogStatus
import com.myapplication.common.data.Routine
import com.myapplication.common.data.RoutineLog
import com.myapplication.common.data.ExerciseLog
import com.myapplication.common.domain.calculateDailyStats
import com.myapplication.common.domain.calculateExerciseProgress
import com.myapplication.common.domain.calculateOverallStats
import com.myapplication.common.domain.calculateStreak
import com.myapplication.common.domain.formatDuration
import com.myapplication.common.domain.formatFrequency
import com.myapplication.common.domain.formatWeight
import com.myapplication.common.domain.greetingForHour
import com.myapplication.common.domain.isRoutineDueToday
import com.myapplication.common.domain.parseDateString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * packages/contract/domain_cases.json を唯一の期待値として検証する。
 *
 * Ruby / TypeScript / Dart が同じ JSON を読んでおり、
 * 4言語が同じ答えを返すことを CI で機械的に保証するのが目的。
 *
 * commonTest ではなく desktopTest に置いているのは、
 * 共通コードからはファイルを読めないため。
 *
 * ここが落ちたら、まず Kotlin 側の実装を疑うこと。
 * 期待値を書き換えて通すのは、仕様変更だと確信できるときだけ。
 */
class ContractTest {

    // Gradle が渡す絶対パス。作業ディレクトリに依存しないようにする
    private val contractDir: String =
        System.getProperty("nikkake.contractDir")
            ?: error("nikkake.contractDir が未設定です。shared/build.gradle.kts を確認してください")

    private val cases: JsonObject = Json.parseToJsonElement(
        File(contractDir, "domain_cases.json").readText(Charsets.UTF_8)
    ).jsonObject

    private fun casesOf(key: String): List<JsonObject> =
        cases.getValue(key).jsonObject.getValue("cases").jsonArray.map { it.jsonObject }

    private fun JsonObject.str(key: String): String = getValue(key).jsonPrimitive.content
    private fun JsonObject.strOrNull(key: String): String? = this[key]?.jsonPrimitive?.contentOrNull
    private fun JsonObject.int(key: String): Int = getValue(key).jsonPrimitive.int
    private fun JsonObject.intOrNull(key: String): Int? = this[key]?.jsonPrimitive?.intOrNull
    private fun JsonObject.arr(key: String): JsonArray = getValue(key).jsonArray

    private val now = "2026-01-01T00:00:00Z"

    private fun buildLog(raw: JsonObject) = RoutineLog(
        id = raw.strOrNull("id") ?: "log-${raw.str("log_date")}-${raw.strOrNull("status")}",
        routineId = "r1",
        logDate = raw.str("log_date"),
        status = raw.strOrNull("status") ?: LogStatus.COMPLETED,
        durationSec = raw.intOrNull("duration_sec"),
        createdAt = now,
        updatedAt = now,
    )

    private fun buildSetLog(raw: JsonObject) = ExerciseLog(
        id = "${raw.str("routine_log_id")}-${raw.str("exercise_id")}-${raw.int("set_number")}",
        routineLogId = raw.str("routine_log_id"),
        exerciseId = raw.str("exercise_id"),
        setNumber = raw.int("set_number"),
        actualReps = raw.intOrNull("actual_reps"),
        actualWeight = raw["actual_weight"]?.jsonPrimitive?.let {
            if (it.contentOrNull == null) null else it.double
        },
        createdAt = now,
        updatedAt = now,
    )

    private fun buildRoutine(raw: JsonObject) = Routine(
        id = "r1",
        name = "テスト",
        color = "#6C5CE7",
        icon = "💪",
        frequencyType = raw.str("frequency_type"),
        frequencyValue = raw.intOrNull("frequency_value") ?: 1,
        frequencyDays = raw.arr("frequency_days").map { it.jsonPrimitive.int },
        isActive = raw["is_active"]?.jsonPrimitive?.booleanOrNull ?: true,
        createdAt = now,
        updatedAt = now,
    )

    @Test
    fun streak() {
        for (c in casesOf("streak")) {
            val expected = c.getValue("expect").jsonObject
            val result = calculateStreak(
                c.arr("logs").map { buildLog(it.jsonObject) },
                parseDateString(c.str("today")),
            )

            assertEquals(expected.int("current"), result.current, c.str("name"))
            assertEquals(expected.int("longest"), result.longest, c.str("name"))
            assertEquals(
                expected["lastCompletedDate"]?.jsonPrimitive?.contentOrNull,
                result.lastCompletedDate,
                c.str("name"),
            )
        }
    }

    @Test
    fun dueToday() {
        for (c in casesOf("dueToday")) {
            val lastLog = (c["lastLog"] as? JsonObject)?.let { buildLog(it) }
            val result = isRoutineDueToday(
                buildRoutine(c.getValue("routine").jsonObject),
                lastLog,
                parseDateString(c.str("today")),
            )

            assertEquals(c.getValue("expect").jsonPrimitive.boolean, result, c.str("name"))
        }
    }

    @Test
    fun dailyStats() {
        for (c in casesOf("dailyStats")) {
            val result = calculateDailyStats(
                c.arr("logs").map { buildLog(it.jsonObject) },
                c.int("days"),
                parseDateString(c.str("today")),
            )
            val expected = c.arr("expect").map { it.jsonObject }

            assertEquals(expected.size, result.size, c.str("name"))
            expected.forEachIndexed { i, want ->
                assertEquals(want.str("date"), result[i].date, c.str("name"))
                assertEquals(want.int("completedCount"), result[i].completedCount, c.str("name"))
                assertEquals(want.int("totalCount"), result[i].totalCount, c.str("name"))
            }
        }
    }

    @Test
    fun exerciseProgress() {
        for (c in casesOf("exerciseProgress")) {
            val result = calculateExerciseProgress(
                c.str("exerciseId"),
                c.arr("routineLogs").map { buildLog(it.jsonObject) },
                c.arr("exerciseLogs").map { buildSetLog(it.jsonObject) },
            )
            val expected = c.arr("expect").map { it.jsonObject }

            assertEquals(expected.size, result.size, c.str("name"))
            expected.forEachIndexed { i, want ->
                assertEquals(want.str("date"), result[i].date, c.str("name"))
                assertEquals(
                    want.getValue("maxWeight").jsonPrimitive.double, result[i].maxWeight, c.str("name")
                )
                assertEquals(want.int("totalReps"), result[i].totalReps, c.str("name"))
                assertEquals(
                    want.getValue("totalVolume").jsonPrimitive.double, result[i].totalVolume, c.str("name")
                )
            }
        }
    }

    @Test
    fun overallStats() {
        for (c in casesOf("overallStats")) {
            val result = calculateOverallStats(
                c.arr("routineLogs").map { buildLog(it.jsonObject) },
                c.arr("exerciseLogs").map { buildSetLog(it.jsonObject) },
                parseDateString(c.str("today")),
            )
            val expected = c.getValue("expect").jsonObject

            assertEquals(expected.int("totalWorkouts"), result.totalWorkouts, c.str("name"))
            assertEquals(expected.int("totalDurationSec"), result.totalDurationSec, c.str("name"))
            assertEquals(expected.int("totalSets"), result.totalSets, c.str("name"))
            assertEquals(expected.int("thisWeekCount"), result.thisWeekCount, c.str("name"))
        }
    }

    @Test
    fun formatting() {
        for (c in casesOf("formatDuration")) {
            assertEquals(c.str("expect"), formatDuration(c.intOrNull("seconds")), c.str("name"))
        }
        for (c in casesOf("formatWeight")) {
            val weight = c["weight"]?.jsonPrimitive?.let {
                if (it.contentOrNull == null) null else it.double
            }
            assertEquals(c.str("expect"), formatWeight(weight), c.str("name"))
        }
        for (c in casesOf("formatFrequency")) {
            assertEquals(
                c.str("expect"),
                formatFrequency(buildRoutine(c.getValue("routine").jsonObject)),
                c.str("name"),
            )
        }
        for (c in casesOf("greetingForHour")) {
            assertEquals(c.str("expect"), greetingForHour(c.int("hour")), c.str("name"))
        }
    }
}

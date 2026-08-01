package com.myapplication.common

import com.myapplication.common.data.LogStatus
import com.myapplication.common.domain.calculateDailyStats
import com.myapplication.common.domain.calculateExerciseProgress
import com.myapplication.common.domain.calculateOverallStats
import com.myapplication.common.domain.calculateStreak
import com.myapplication.common.domain.calculateVolume
import com.myapplication.common.domain.completedDateSet
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class StatsTest {

    private val today = LocalDate(2026, 8, 5)

    @Test
    fun 記録が無ければストリークは0() {
        val result = calculateStreak(emptyList(), today)
        assertEquals(0, result.current)
        assertEquals(0, result.longest)
        assertEquals(null, result.lastCompletedDate)
    }

    @Test
    fun 今日まで連続していれば日数を数える() {
        val logs = listOf(buildLog("2026-08-03"), buildLog("2026-08-04"), buildLog("2026-08-05"))
        assertEquals(3, calculateStreak(logs, today).current)
    }

    @Test
    fun 昨日までやっていればストリークは継続扱い() {
        val logs = listOf(buildLog("2026-08-03"), buildLog("2026-08-04"))
        assertEquals(2, calculateStreak(logs, today).current)
    }

    @Test
    fun 二日以上空いていればストリークは切れる() {
        val logs = listOf(buildLog("2026-08-01"), buildLog("2026-08-02"))
        assertEquals(0, calculateStreak(logs, today).current)
    }

    @Test
    fun 中断はストリークに数えない() {
        val logs = listOf(buildLog("2026-08-04"), buildLog("2026-08-05", LogStatus.SKIPPED))
        val result = calculateStreak(logs, today)
        assertEquals(1, result.current)
        assertEquals("2026-08-04", result.lastCompletedDate)
    }

    @Test
    fun やりきれなかった日もストリークは途切れない() {
        // 4種目中3種目で終えた日にストリークが切れると習慣化の妨げになる
        val logs = listOf(buildLog("2026-08-04"), buildLog("2026-08-05", LogStatus.PARTIAL))
        assertEquals(2, calculateStreak(logs, today).current)
    }

    @Test
    fun 過去の最長ストリークを保持する() {
        val logs = listOf(
            buildLog("2026-07-01"),
            buildLog("2026-07-02"),
            buildLog("2026-07-03"),
            buildLog("2026-07-04"),
            buildLog("2026-08-05"),
        )
        val result = calculateStreak(logs, today)
        assertEquals(4, result.longest)
        assertEquals(1, result.current)
    }

    @Test
    fun 日別集計は記録の無い日も0で埋める() {
        val stats = calculateDailyStats(listOf(buildLog("2026-08-05"), buildLog("2026-08-03")), 3, today)

        assertEquals(listOf("2026-08-03", "2026-08-04", "2026-08-05"), stats.map { it.date })
        assertEquals(listOf(1, 0, 1), stats.map { it.completedCount })
    }

    @Test
    fun 日別集計はpartialを実施として数えskippedは数えない() {
        val partial = calculateDailyStats(listOf(buildLog("2026-08-05", LogStatus.PARTIAL)), 1, today)
        assertEquals(1, partial.first().completedCount)

        val skipped = calculateDailyStats(listOf(buildLog("2026-08-05", LogStatus.SKIPPED)), 1, today)
        assertEquals(0, skipped.first().completedCount)
        assertEquals(1, skipped.first().totalCount)
    }

    @Test
    fun 種目ごとの推移を日付単位で集計する() {
        val logA = buildLog("2026-08-01")
        val logB = buildLog("2026-08-03")

        val exerciseLogs = listOf(
            buildExerciseLog(logA.id, "ex1", 1, reps = 10, weight = 60.0),
            buildExerciseLog(logA.id, "ex1", 2, reps = 8, weight = 65.0),
            buildExerciseLog(logB.id, "ex1", 1, reps = 10, weight = 70.0),
            buildExerciseLog(logB.id, "ex2", 1, reps = 12, weight = 20.0),
        )

        val progress = calculateExerciseProgress("ex1", listOf(logA, logB), exerciseLogs)

        assertEquals(2, progress.size)
        assertEquals("2026-08-01", progress[0].date)
        assertEquals(65.0, progress[0].maxWeight)
        assertEquals(18, progress[0].totalReps)
        assertEquals(10 * 60.0 + 8 * 65.0, progress[0].totalVolume)
        assertEquals(70.0, progress[1].maxWeight)
    }

    @Test
    fun 対象種目が無ければ推移は空() {
        assertTrue(calculateExerciseProgress("none", listOf(buildLog("2026-08-01")), emptyList()).isEmpty())
    }

    @Test
    fun 自重種目のボリュームは0として扱う() {
        val logs = listOf(
            buildExerciseLog("l1", "ex1", 1, reps = 10),
            buildExerciseLog("l1", "ex1", 2, reps = 10, weight = 50.0),
        )
        assertEquals(500.0, calculateVolume(logs))
    }

    @Test
    fun 実施した日の集合はskippedを除く() {
        val set = completedDateSet(listOf(buildLog("2026-08-01"), buildLog("2026-08-02", LogStatus.SKIPPED)))
        assertTrue(set.contains("2026-08-01"))
        assertFalse(set.contains("2026-08-02"))
    }

    @Test
    fun 全体集計は直近7日の回数を含む() {
        val logs = listOf(buildLog("2026-08-05"), buildLog("2026-08-01"), buildLog("2026-07-01"))
        val stats = calculateOverallStats(
            logs,
            listOf(buildExerciseLog("l1", "ex1", 1, reps = 10, weight = 50.0)),
            today,
        )

        assertEquals(3, stats.totalWorkouts)
        assertEquals(2, stats.thisWeekCount)
        assertEquals(1800, stats.totalDurationSec)
        assertEquals(1, stats.totalSets)
    }
}

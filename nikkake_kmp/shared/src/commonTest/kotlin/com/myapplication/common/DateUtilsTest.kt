package com.myapplication.common

import com.myapplication.common.data.FrequencyType
import com.myapplication.common.domain.addDays
import com.myapplication.common.domain.daysBetween
import com.myapplication.common.domain.formatDuration
import com.myapplication.common.domain.formatFrequency
import com.myapplication.common.domain.formatWeight
import com.myapplication.common.domain.getDateString
import com.myapplication.common.domain.greetingForHour
import com.myapplication.common.domain.isRoutineDueToday
import com.myapplication.common.domain.parseDateString
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class DateUtilsTest {

    // 2026-08-01 は土曜日
    private val today = LocalDate(2026, 8, 1)

    @Test
    fun getDateStringは常に2桁ゼロ埋めで返す() {
        assertEquals("2026-08-01", getDateString(LocalDate(2026, 8, 1)))
        assertEquals("2026-01-09", getDateString(LocalDate(2026, 1, 9)))
    }

    @Test
    fun parseDateStringは日付を正しく復元する() {
        val parsed = parseDateString("2026-08-01")
        assertEquals(2026, parsed.year)
        assertEquals(8, parsed.monthNumber)
        assertEquals(1, parsed.dayOfMonth)
    }

    @Test
    fun daysBetweenは日数差を返す() {
        assertEquals(1, daysBetween(LocalDate(2026, 8, 1), LocalDate(2026, 8, 2)))
        assertEquals(0, daysBetween(LocalDate(2026, 8, 1), LocalDate(2026, 8, 1)))
        assertEquals(-4, daysBetween(LocalDate(2026, 8, 5), LocalDate(2026, 8, 1)))
    }

    @Test
    fun addDaysは月をまたいでも正しく進む() {
        assertEquals("2026-08-02", getDateString(addDays(LocalDate(2026, 7, 30), 3)))
    }

    @Test
    fun 停止中のルーティンは今日の対象外() {
        assertFalse(isRoutineDueToday(buildRoutine(isActive = false), null, today))
    }

    @Test
    fun 毎日のルーティンは常に対象() {
        assertTrue(isRoutineDueToday(buildRoutine(), buildLog("2026-07-31"), today))
    }

    @Test
    fun N日ごとは前回からの間隔で判定する() {
        val routine = buildRoutine(frequencyType = FrequencyType.EVERY_N_DAYS, frequencyValue = 3)
        assertTrue(isRoutineDueToday(routine, buildLog("2026-07-29"), today))
        assertFalse(isRoutineDueToday(routine, buildLog("2026-07-30"), today))
    }

    @Test
    fun N日ごとで未実施なら今日から始められる() {
        val routine = buildRoutine(frequencyType = FrequencyType.EVERY_N_DAYS, frequencyValue = 7)
        assertTrue(isRoutineDueToday(routine, null, today))
    }

    @Test
    fun 曜日指定は日曜を0として判定する() {
        // 土曜 = 6
        assertTrue(
            isRoutineDueToday(
                buildRoutine(frequencyType = FrequencyType.WEEKLY, frequencyDays = listOf(6)),
                null,
                today,
            ),
        )
        assertFalse(
            isRoutineDueToday(
                buildRoutine(frequencyType = FrequencyType.WEEKLY, frequencyDays = listOf(1, 3)),
                null,
                today,
            ),
        )

        val sunday = LocalDate(2026, 8, 2)
        assertTrue(
            isRoutineDueToday(
                buildRoutine(frequencyType = FrequencyType.WEEKLY, frequencyDays = listOf(0)),
                null,
                sunday,
            ),
        )
    }

    @Test
    fun 曜日未設定の曜日指定は毎日扱い() {
        assertTrue(isRoutineDueToday(buildRoutine(frequencyType = FrequencyType.WEEKLY), null, today))
    }

    @Test
    fun formatDurationは時間分秒を切り替える() {
        assertEquals("0:00", formatDuration(0))
        assertEquals("1:05", formatDuration(65))
        assertEquals("1:02:05", formatDuration(3725))
        assertEquals("--:--", formatDuration(null))
    }

    @Test
    fun formatWeightは不要な小数を落とす() {
        assertEquals("60 kg", formatWeight(60.0))
        assertEquals("62.5 kg", formatWeight(62.5))
        assertEquals("-- kg", formatWeight(null))
    }

    @Test
    fun formatFrequencyは頻度を日本語にする() {
        assertEquals("毎日", formatFrequency(buildRoutine()))
        assertEquals(
            "3日ごと",
            formatFrequency(buildRoutine(frequencyType = FrequencyType.EVERY_N_DAYS, frequencyValue = 3)),
        )
        assertEquals(
            "毎日",
            formatFrequency(buildRoutine(frequencyType = FrequencyType.EVERY_N_DAYS, frequencyValue = 1)),
        )
        assertEquals(
            "月・水",
            formatFrequency(buildRoutine(frequencyType = FrequencyType.WEEKLY, frequencyDays = listOf(3, 1))),
        )
    }

    @Test
    fun greetingForHourは時間帯に応じた挨拶を返す() {
        assertEquals("おつかれさま", greetingForHour(3))
        assertEquals("おはよう！", greetingForHour(9))
        assertEquals("こんにちは！", greetingForHour(14))
        assertEquals("こんばんは！", greetingForHour(21))
    }
}

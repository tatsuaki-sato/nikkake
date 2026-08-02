package com.myapplication.common.domain

import com.myapplication.common.data.FrequencyType
import com.myapplication.common.data.Routine
import com.myapplication.common.data.RoutineLog
import kotlinx.datetime.Clock
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.daysUntil
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime

/**
 * 日付と表示フォーマット。
 * すべて純粋関数なのでストレージ無しで単体テストできる。
 */

fun today(timeZone: TimeZone = TimeZone.currentSystemDefault()): LocalDate =
    Clock.System.now().toLocalDateTime(timeZone).date

fun nowIso(): String = Clock.System.now().toString()

fun getDateString(date: LocalDate = today()): String {
    val month = date.monthNumber.toString().padStart(2, '0')
    val day = date.dayOfMonth.toString().padStart(2, '0')
    return "${date.year}-$month-$day"
}

fun parseDateString(value: String): LocalDate = LocalDate.parse(value)

fun daysBetween(from: LocalDate, to: LocalDate): Int = from.daysUntil(to)

fun addDays(date: LocalDate, days: Int): LocalDate = date.plus(DatePeriod(days = days))

/**
 * DBは 日=0..土=6 で曜日を持つ。
 * DayOfWeek.ordinal は 月=0..日=6 なので +1 して 7 で割った余りに落とす。
 */
fun dbWeekday(date: LocalDate): Int = (date.dayOfWeek.ordinal + 1) % 7

/**
 * そのルーティンを今日やる予定かどうか。
 * 「今日もう終わったか」は別で判定するので、ここでは予定だけを見る。
 */
fun isRoutineDueToday(routine: Routine, lastLog: RoutineLog?, today: LocalDate = today()): Boolean {
    if (!routine.isActive) return false

    return when (routine.frequencyType) {
        FrequencyType.DAILY -> true

        // 曜日が未設定なら毎日扱いにする
        FrequencyType.WEEKLY ->
            routine.frequencyDays.isEmpty() || routine.frequencyDays.contains(dbWeekday(today))

        FrequencyType.EVERY_N_DAYS -> {
            // 一度もやっていなければ今日から始める
            if (lastLog == null) true
            else daysBetween(parseDateString(lastLog.logDate), today) >= maxOf(1, routine.frequencyValue)
        }

        else -> false
    }
}

fun formatDuration(seconds: Int?): String {
    if (seconds == null) return "--:--"

    val total = maxOf(0, seconds)
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60

    return if (h > 0) {
        "$h:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}"
    } else {
        "$m:${s.toString().padStart(2, '0')}"
    }
}

fun formatWeight(weight: Double?): String {
    if (weight == null) return "-- kg"
    return "${formatWeightNumber(weight)} kg"
}

/** 単位なしの重量。小数第1位まで、.0 は省く */
fun formatWeightNumber(weight: Double): String {
    val rounded = kotlin.math.round(weight * 10) / 10
    return if (rounded == kotlin.math.floor(rounded)) rounded.toInt().toString() else rounded.toString()
}

/** 前回表示に必要な最小限。ExerciseLog からも API 応答からも作れる */
data class PreviousSetLike(
    val reps: Int? = null,
    val weight: Double? = null,
    val durationSec: Int? = null,
)

/**
 * ワークアウト画面の「前回: …」に出す文字列。
 *
 * packages/contract/domain_cases.json の formatPreviousSets が正で、
 * Ruby の Domain::Stats.format_previous_sets と同じ答えを返さなければならない。
 */
fun formatPreviousSets(sets: List<PreviousSetLike>): String = sets.joinToString(" / ") { set ->
    if (set.durationSec != null) {
        "${set.durationSec}秒"
    } else {
        val label = set.weight?.let { formatWeightNumber(it) } ?: "自重"
        "$label×${set.reps ?: "-"}"
    }
}

private val dayNames = listOf("日", "月", "火", "水", "木", "金", "土")

fun formatFrequency(routine: Routine): String = when (routine.frequencyType) {
    FrequencyType.DAILY -> "毎日"
    FrequencyType.EVERY_N_DAYS ->
        if (routine.frequencyValue <= 1) "毎日" else "${routine.frequencyValue}日ごと"
    FrequencyType.WEEKLY ->
        if (routine.frequencyDays.isEmpty()) "毎日"
        else routine.frequencyDays.sorted().joinToString("・") { dayNames[it] }
    else -> ""
}

fun greetingForHour(hour: Int): String = when {
    hour < 5 -> "おつかれさま"
    hour < 12 -> "おはよう！"
    hour < 18 -> "こんにちは！"
    else -> "こんばんは！"
}

fun currentHour(timeZone: TimeZone = TimeZone.currentSystemDefault()): Int =
    Clock.System.now().toLocalDateTime(timeZone).hour

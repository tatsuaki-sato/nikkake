package com.myapplication.common.domain

import com.myapplication.common.data.DailyStats
import com.myapplication.common.data.ExerciseLog
import com.myapplication.common.data.ExerciseProgressPoint
import com.myapplication.common.data.LogStatus
import com.myapplication.common.data.OverallStats
import com.myapplication.common.data.RoutineLog
import com.myapplication.common.data.StreakInfo
import kotlinx.datetime.LocalDate

/**
 * 進捗画面の集計。すべて純粋関数。
 */

/**
 * その日「やった」と数える基準。
 *
 * 全セット完了(completed)だけを対象にすると、4種目のうち3種目やった日が
 * ノーカウントになりストリークが切れる。習慣化アプリとしてそれは逆効果なので、
 * 中断(skipped)以外はすべて実施した日として扱う。
 */
fun didWorkout(log: RoutineLog): Boolean = log.status != LogStatus.SKIPPED

/**
 * 連続日数。
 * 「今日まだやっていない」だけで途切れた表示になるのは体験が悪いので、
 * 最終実施日が今日か昨日ならストリークは生きているものとして数える。
 */
fun calculateStreak(logs: List<RoutineLog>, todayDate: LocalDate = today()): StreakInfo {
    val dates = logs.filter(::didWorkout).map { it.logDate }.distinct().sorted()
    if (dates.isEmpty()) return StreakInfo(current = 0, longest = 0)

    var longest = 1
    var run = 1
    for (i in 1 until dates.size) {
        val gap = daysBetween(parseDateString(dates[i - 1]), parseDateString(dates[i]))
        run = if (gap == 1) run + 1 else 1
        if (run > longest) longest = run
    }

    val lastDate = dates.last()
    val gapFromToday = daysBetween(parseDateString(lastDate), todayDate)

    var current = 0
    if (gapFromToday <= 1) {
        current = 1
        for (i in dates.size - 1 downTo 1) {
            val gap = daysBetween(parseDateString(dates[i - 1]), parseDateString(dates[i]))
            if (gap != 1) break
            current++
        }
    }

    return StreakInfo(current = current, longest = longest, lastCompletedDate = lastDate)
}

/** 直近n日分の実施状況。記録の無い日も0で埋めて返す */
fun calculateDailyStats(
    logs: List<RoutineLog>,
    days: Int,
    todayDate: LocalDate = today(),
): List<DailyStats> {
    val byDate = logs.groupBy { it.logDate }

    return (days - 1 downTo 0).map { offset ->
        val date = getDateString(addDays(todayDate, -offset))
        val dayLogs = byDate[date].orEmpty()
        DailyStats(
            date = date,
            completedCount = dayLogs.count(::didWorkout),
            totalCount = dayLogs.size,
        )
    }
}

/** カレンダー用の「実施した日」の集合 */
fun completedDateSet(logs: List<RoutineLog>): Set<String> =
    logs.filter(::didWorkout).map { it.logDate }.toSet()

/** 種目ごとの推移。重量種目は最大重量、回数・時間種目は合計が伸びを表す */
fun calculateExerciseProgress(
    exerciseId: String,
    routineLogs: List<RoutineLog>,
    exerciseLogs: List<ExerciseLog>,
): List<ExerciseProgressPoint> {
    val dateByLogId = routineLogs.associate { it.id to it.logDate }

    return exerciseLogs
        .filter { it.exerciseId == exerciseId && dateByLogId.containsKey(it.routineLogId) }
        .groupBy { dateByLogId.getValue(it.routineLogId) }
        .map { (date, sets) ->
            ExerciseProgressPoint(
                date = date,
                maxWeight = sets.maxOf { it.actualWeight ?: 0.0 },
                totalReps = sets.sumOf { it.actualReps ?: 0 },
                totalVolume = sets.sumOf { (it.actualWeight ?: 0.0) * (it.actualReps ?: 0) },
            )
        }
        .sortedBy { it.date }
}

/** そのワークアウトの総挙上量(kg×回)。自重種目は0になる */
fun calculateVolume(logs: List<ExerciseLog>): Double =
    logs.sumOf { (it.actualWeight ?: 0.0) * (it.actualReps ?: 0) }

fun calculateOverallStats(
    routineLogs: List<RoutineLog>,
    exerciseLogs: List<ExerciseLog>,
    todayDate: LocalDate = today(),
): OverallStats {
    val done = routineLogs.filter(::didWorkout)
    val weekAgo = getDateString(addDays(todayDate, -6))

    return OverallStats(
        totalWorkouts = done.size,
        totalDurationSec = done.sumOf { it.durationSec ?: 0 },
        totalSets = exerciseLogs.size,
        thisWeekCount = done.count { it.logDate >= weekAgo },
    )
}

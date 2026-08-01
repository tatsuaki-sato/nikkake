package com.myapplication.common.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.myapplication.common.domain.addDays
import com.myapplication.common.domain.calculateDailyStats
import com.myapplication.common.domain.calculateExerciseProgress
import com.myapplication.common.domain.calculateOverallStats
import com.myapplication.common.domain.calculateStreak
import com.myapplication.common.domain.completedDateSet
import com.myapplication.common.domain.formatDuration
import com.myapplication.common.domain.formatWeight
import com.myapplication.common.domain.getDateString
import com.myapplication.common.domain.today
import com.myapplication.common.store.AppStore
import com.myapplication.common.ui.components.AppCard
import com.myapplication.common.ui.components.EmptyState
import com.myapplication.common.ui.components.SectionTitle
import com.myapplication.common.ui.components.SelectableChip
import com.myapplication.common.ui.components.StatBlock
import com.myapplication.common.ui.components.tag
import com.myapplication.common.ui.theme.LocalPalette
import com.myapplication.common.ui.theme.Radii
import com.myapplication.common.ui.theme.Spacing
import kotlinx.datetime.LocalDate
import kotlin.math.roundToInt

/**
 * 進捗。
 * グラフ描画ライブラリは使わず、Boxの高さと色だけで表現している。
 * 3プラットフォームで同じ見た目を再現しやすく、依存も増えないため。
 */
@Composable
fun ProgressScreen(appStore: AppStore) {
    val palette = LocalPalette.current
    var range by remember { mutableStateOf(7) }
    var selectedExerciseId by remember { mutableStateOf<String?>(null) }

    val routineLogs = appStore.routineLogs
    val exerciseLogs = appStore.exerciseLogs

    if (routineLogs.isEmpty()) {
        Box(Modifier.fillMaxSize().background(palette.background), Alignment.Center) {
            EmptyState(
                modifier = Modifier.tag("progress-empty"),
                icon = "📈",
                title = "まだ記録がありません",
                message = "ワークアウトを1回完了すると、ここに推移が出ます。",
            )
        }
        return
    }

    val overall = calculateOverallStats(routineLogs, exerciseLogs)
    val streak = calculateStreak(routineLogs)
    val daily = calculateDailyStats(routineLogs, range)
    val doneDates = completedDateSet(routineLogs)

    // 記録が残っている種目だけを選択肢にする
    val loggedIds = exerciseLogs.map { it.exerciseId }.toSet()
    val loggedExercises = appStore.exercises.filter { it.id in loggedIds }

    val activeExerciseId = selectedExerciseId ?: loggedExercises.firstOrNull()?.id
    val progress = activeExerciseId
        ?.let { calculateExerciseProgress(it, routineLogs, exerciseLogs) }
        .orEmpty()

    val maxCount = maxOf(1, daily.maxOfOrNull { it.completedCount } ?: 1)

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(palette.background).tag("progress-screen"),
        contentPadding = PaddingValues(Spacing.md),
    ) {
        item {
            AppCard {
                Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween) {
                    StatBlock("通算", "${overall.totalWorkouts}回", "progress-total", Modifier.weight(1f))
                    StatBlock("今週", "${overall.thisWeekCount}回", "progress-week", Modifier.weight(1f))
                    StatBlock("連続", "${streak.current}日", "progress-streak", Modifier.weight(1f))
                    StatBlock(
                        "総時間",
                        formatDuration(overall.totalDurationSec),
                        "progress-duration",
                        Modifier.weight(1f),
                    )
                }
            }
            Spacer(Modifier.height(Spacing.lg))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SectionTitle("実施状況")
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                    listOf(7, 30).forEach { value ->
                        SelectableChip(
                            label = "${value}日",
                            selected = range == value,
                            onClick = { range = value },
                            modifier = Modifier.tag("progress-range-$value"),
                        )
                    }
                }
            }
            Spacer(Modifier.height(Spacing.sm))

            AppCard(modifier = Modifier.tag("progress-chart")) {
                Row(
                    modifier = Modifier.fillMaxWidth().height(120.dp),
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    daily.forEach { day ->
                        Column(
                            modifier = Modifier.weight(1f),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Bottom,
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height((day.completedCount.toFloat() / maxCount * 96f).coerceIn(4f, 96f).dp)
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(if (day.completedCount > 0) palette.success else palette.border),
                            )
                            if (range == 7) {
                                Text(
                                    day.date.substring(8),
                                    fontSize = 9.sp,
                                    color = palette.textSecondary,
                                )
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.height(Spacing.lg))

            SectionTitle("カレンダー")
            AppCard(modifier = Modifier.tag("progress-calendar")) { MonthGrid(doneDates) }
            Spacer(Modifier.height(Spacing.lg))

            SectionTitle("種目ごとの推移")
        }

        if (loggedExercises.isEmpty()) {
            item {
                AppCard {
                    Text(
                        "セット記録が貯まるとここに種目別の推移が出ます。",
                        fontSize = 13.sp,
                        color = palette.textSecondary,
                    )
                }
            }
        } else {
            item {
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    loggedExercises.forEach { exercise ->
                        SelectableChip(
                            label = exercise.name,
                            selected = activeExerciseId == exercise.id,
                            onClick = { selectedExerciseId = exercise.id },
                            modifier = Modifier.tag("progress-exercise-${exercise.id}"),
                        )
                    }
                }
                Spacer(Modifier.height(Spacing.md))

                AppCard(modifier = Modifier.tag("progress-exercise-detail")) {
                    Column {
                        if (progress.isEmpty()) {
                            Text("記録がありません。", fontSize = 13.sp, color = palette.textSecondary)
                        } else {
                            progress.reversed().take(8).forEach { point ->
                                Row(
                                    modifier = Modifier.fillMaxWidth().padding(vertical = Spacing.sm),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        point.date.substring(5),
                                        modifier = Modifier.width(56.dp),
                                        fontSize = 12.sp,
                                        color = palette.textSecondary,
                                    )
                                    Text(
                                        if (point.maxWeight > 0) "最大 ${formatWeight(point.maxWeight)}"
                                        else "${point.totalReps} 回",
                                        modifier = Modifier.weight(1f),
                                        textAlign = TextAlign.Center,
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = palette.textPrimary,
                                    )
                                    Text(
                                        if (point.totalVolume > 0) "${point.totalVolume.roundToInt()}kg"
                                        else "計 ${point.totalReps}回",
                                        modifier = Modifier.width(72.dp),
                                        textAlign = TextAlign.End,
                                        fontSize = 12.sp,
                                        color = palette.textSecondary,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        item { Spacer(Modifier.height(Spacing.xl)) }
    }
}

/** 当月のカレンダー。実施した日を塗る */
@Composable
private fun MonthGrid(doneDates: Set<String>) {
    val palette = LocalPalette.current
    val todayDate = today()
    val firstOfMonth = LocalDate(todayDate.year, todayDate.monthNumber, 1)
    val daysInMonth = firstOfMonth.let { first ->
        val nextMonth = if (first.monthNumber == 12) LocalDate(first.year + 1, 1, 1)
        else LocalDate(first.year, first.monthNumber + 1, 1)
        com.myapplication.common.domain.daysBetween(first, nextMonth)
    }
    // 日曜始まりにするので、DayOfWeek.ordinal(月=0) を +1 して 7 で割る
    val leadingBlanks = (firstOfMonth.dayOfWeek.ordinal + 1) % 7
    val todayString = getDateString(todayDate)

    val cells: List<String?> =
        List(leadingBlanks) { null } + (0 until daysInMonth).map { getDateString(addDays(firstOfMonth, it)) }

    Column(Modifier.fillMaxWidth()) {
        Text(
            "${todayDate.year}年${todayDate.monthNumber}月",
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
            fontWeight = FontWeight.Bold,
            color = palette.textPrimary,
        )
        Spacer(Modifier.height(Spacing.sm))

        Row(Modifier.fillMaxWidth()) {
            listOf("日", "月", "火", "水", "木", "金", "土").forEach { label ->
                Text(
                    label,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center,
                    fontSize = 11.sp,
                    color = palette.textSecondary,
                )
            }
        }
        Spacer(Modifier.height(Spacing.xs))

        cells.chunked(7).forEach { week ->
            Row(Modifier.fillMaxWidth()) {
                repeat(7) { position ->
                    val date = week.getOrNull(position)
                    val done = date != null && date in doneDates

                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .padding(2.dp)
                            .clip(RoundedCornerShape(Radii.sm))
                            .background(if (done) palette.success else Color.Transparent)
                            .then(
                                if (date == todayString) {
                                    Modifier.border(1.dp, palette.primaryLight, RoundedCornerShape(Radii.sm))
                                } else Modifier,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            date?.substring(8)?.trimStart('0').orEmpty(),
                            fontSize = 12.sp,
                            fontWeight = if (done) FontWeight.Bold else FontWeight.Normal,
                            color = if (done) palette.background else palette.textSecondary,
                        )
                    }
                }
            }
        }
    }
}

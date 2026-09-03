package com.myapplication.common.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.runtime.LaunchedEffect
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
import com.myapplication.common.domain.formatDuration
import com.myapplication.common.domain.formatWeight
import com.myapplication.common.domain.getDateString
import com.myapplication.common.domain.today
import com.myapplication.common.data.DayView
import com.myapplication.common.data.ExerciseProgressPoint
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
    var selectedDate by remember { mutableStateOf<String?>(null) }

    val view = appStore.progress

    if (view.overall.totalWorkouts == 0) {
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

    // 数字はすべてサーバが集計したものを表示するだけ。
    // ここに計算を書き足したら、それはサーバへ移すべきロジックが漏れている。
    val overall = view.overall
    val streak = view.streak
    val daily = view.dailyStats
    val doneDates = view.completedDates

    // 記録が残っている種目だけが返ってくる
    val loggedExercises = view.exercisesWithLogs

    val activeExerciseId = selectedExerciseId ?: loggedExercises.firstOrNull()?.id

    // 種目別の推移はサーバへの別クエリなので、取れたぶんだけ持っておく
    var progress by remember { mutableStateOf(emptyList<ExerciseProgressPoint>()) }
    LaunchedEffect(activeExerciseId) {
        progress = activeExerciseId?.let { appStore.exerciseProgress(it) }.orEmpty()
    }

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
                            onClick = { range = value; appStore.setProgressRange(value) },
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
            AppCard(modifier = Modifier.tag("progress-calendar")) {
                MonthGrid(
                    doneDates = doneDates,
                    selectedDate = selectedDate,
                    onSelectDate = { date -> selectedDate = if (selectedDate == date) null else date },
                )
            }
            if (selectedDate != null) {
                Spacer(Modifier.height(Spacing.md))
                DayDetail(
                    appStore = appStore,
                    date = selectedDate!!,
                    onClose = { selectedDate = null },
                )
            }
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

/** カレンダー。実施した日を塗る。◀▶ で前月・翌月へ移動でき、日をタップするとその日の内容を開く */
@Composable
private fun MonthGrid(
    doneDates: Set<String>,
    selectedDate: String?,
    onSelectDate: (String) -> Unit,
) {
    val palette = LocalPalette.current
    val todayDate = today()
    var monthsBack by remember { mutableStateOf(0) }

    // 月の引き算は年跨ぎを通し番号で処理する
    val baseMonths = todayDate.year * 12 + (todayDate.monthNumber - 1) - monthsBack
    val firstOfMonth = LocalDate(baseMonths / 12, baseMonths % 12 + 1, 1)
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
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "◀",
                modifier = Modifier
                    .clip(RoundedCornerShape(Radii.sm))
                    .clickable { monthsBack += 1 }
                    .tag("calendar-prev")
                    .padding(horizontal = Spacing.sm, vertical = Spacing.xs),
                fontSize = 15.sp,
                color = palette.primaryLight,
            )
            Text(
                "${firstOfMonth.year}年${firstOfMonth.monthNumber}月",
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.Bold,
                color = palette.textPrimary,
            )
            Text(
                "▶",
                modifier = Modifier
                    .clip(RoundedCornerShape(Radii.sm))
                    .clickable(enabled = monthsBack > 0) { if (monthsBack > 0) monthsBack -= 1 }
                    .tag("calendar-next")
                    .padding(horizontal = Spacing.sm, vertical = Spacing.xs),
                fontSize = 15.sp,
                color = if (monthsBack > 0) palette.primaryLight else palette.border,
            )
        }
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
                    val border = when {
                        date == selectedDate -> Modifier.border(2.dp, palette.primary, RoundedCornerShape(Radii.sm))
                        date == todayString -> Modifier.border(1.dp, palette.primaryLight, RoundedCornerShape(Radii.sm))
                        else -> Modifier
                    }

                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .padding(2.dp)
                            .clip(RoundedCornerShape(Radii.sm))
                            .then(if (date != null) Modifier.clickable { onSelectDate(date) } else Modifier)
                            .background(if (done) palette.success else Color.Transparent)
                            .then(border)
                            .then(if (date != null) Modifier.tag("calendar-day-$date") else Modifier),
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

/** カレンダーで選んだ日のワークアウト内容。集計と同じくサーバが整形して返す */
@Composable
private fun DayDetail(appStore: AppStore, date: String, onClose: () -> Unit) {
    val palette = LocalPalette.current
    var day by remember(date) { mutableStateOf<DayView?>(null) }
    LaunchedEffect(date) { day = appStore.day(date) }

    AppCard(modifier = Modifier.tag("progress-day-detail")) {
        Column(Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${date.substring(5).replaceFirst('-', '/')} の記録",
                    fontWeight = FontWeight.Bold,
                    color = palette.textPrimary,
                    fontSize = 14.sp,
                )
                Text(
                    "✕",
                    modifier = Modifier.clickable { onClose() }.padding(Spacing.xs),
                    color = palette.textSecondary,
                )
            }
            Spacer(Modifier.height(Spacing.sm))

            val workouts = day?.workouts
            when {
                day == null -> Text("読み込み中…", fontSize = 13.sp, color = palette.textSecondary)
                workouts.isNullOrEmpty() ->
                    Text("この日の記録はありません。", fontSize = 13.sp, color = palette.textSecondary)
                else -> workouts.forEach { workout ->
                    Column(Modifier.fillMaxWidth().padding(top = Spacing.sm)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text(
                                workout.routineName,
                                fontWeight = FontWeight.Bold,
                                color = palette.textPrimary,
                                fontSize = 14.sp,
                            )
                            workout.durationSec?.let {
                                Text(formatDuration(it), fontSize = 13.sp, color = palette.textSecondary)
                            }
                        }
                        workout.exercises.forEach { exercise ->
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(top = 2.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Text(exercise.exerciseName, fontSize = 13.sp, color = palette.textSecondary)
                                Text(exercise.setsLabel ?: "—", fontSize = 13.sp, color = palette.textPrimary)
                            }
                        }
                    }
                }
            }
        }
    }
}

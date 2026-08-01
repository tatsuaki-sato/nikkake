package com.myapplication.common.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.myapplication.common.data.StreakInfo
import com.myapplication.common.data.TodayRoutine
import com.myapplication.common.domain.calculateStreak
import com.myapplication.common.domain.currentHour
import com.myapplication.common.domain.formatFrequency
import com.myapplication.common.domain.greetingForHour
import com.myapplication.common.domain.today
import com.myapplication.common.store.AppStore
import com.myapplication.common.ui.Destination
import com.myapplication.common.ui.Navigation
import com.myapplication.common.ui.components.AppButton
import com.myapplication.common.ui.components.AppCard
import com.myapplication.common.ui.components.EmptyState
import com.myapplication.common.ui.components.tag
import com.myapplication.common.ui.theme.LocalPalette
import com.myapplication.common.ui.theme.Spacing
import com.myapplication.common.ui.theme.hexToColor

/**
 * ホーム。アプリを開いた直後に見る画面。
 * サインインの有無に関係なく、ここに「今日やるルーティン」が並んでいて
 * 1タップで開始できる状態にしておくことがこの画面の唯一の役目。
 */
@Composable
fun HomeScreen(appStore: AppStore, navigation: Navigation) {
    val palette = LocalPalette.current
    val streak = calculateStreak(appStore.routineLogs)

    val todayRoutines = appStore.todayRoutines
    val due = todayRoutines.filter { it.isDueToday && !it.isCompleted }
    val later = todayRoutines.filter { !it.isDueToday && !it.isCompleted }
    val done = todayRoutines.filter { it.isCompleted }

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(palette.background).tag("home-screen"),
        contentPadding = PaddingValues(Spacing.md),
    ) {
        item {
            val date = today()
            Column {
                Text(
                    greetingForHour(currentHour()),
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = palette.textPrimary,
                )
                Text(
                    "${date.monthNumber}月${date.dayOfMonth}日",
                    modifier = Modifier.padding(top = Spacing.xs),
                    fontSize = 14.sp,
                    color = palette.textSecondary,
                )
            }
            Spacer(Modifier.height(Spacing.lg))
            StreakBanner(streak)
            Spacer(Modifier.height(Spacing.xl))
            Text(
                "今日のルーティン",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = palette.textPrimary,
            )
            Spacer(Modifier.height(Spacing.md))
        }

        if (todayRoutines.isEmpty()) {
            item {
                Box(Modifier.tag("home-empty")) {
                    EmptyState(
                        icon = "📋",
                        title = "ルーティンがありません",
                        message = "まずは1つ作ってみましょう。作ったその日から記録が残ります。",
                        action = {
                            AppButton("ルーティンを作る", onClick = {
                                navigation.push(Destination.RoutineForm())
                            })
                        },
                    )
                }
            }
        } else if (due.isEmpty() && later.isEmpty()) {
            item {
                Box(Modifier.tag("home-all-done")) {
                    EmptyState(
                        icon = "🎉",
                        title = "今日の分は完了です",
                        message = "おつかれさま。この調子で続けましょう。",
                    )
                }
            }
        }

        items(due, key = { it.routine.id }) { item ->
            RoutineCard(item, CardState.DUE) { navigation.push(Destination.Workout(item.routine.id)) }
        }

        if (later.isNotEmpty()) {
            item { SubTitle("今日は予定なし") }
            items(later, key = { it.routine.id }) { item ->
                RoutineCard(item, CardState.LATER) { navigation.push(Destination.Workout(item.routine.id)) }
            }
        }

        if (done.isNotEmpty()) {
            item { SubTitle("完了") }
            items(done, key = { it.routine.id }) { item ->
                RoutineCard(item, CardState.DONE) { navigation.push(Destination.Workout(item.routine.id)) }
            }
        }
    }
}

@Composable
private fun StreakBanner(streak: StreakInfo) {
    val palette = LocalPalette.current

    AppCard(modifier = Modifier.tag("streak-banner"), color = palette.surfaceElevated) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (streak.current > 0) "🔥" else "🌱", fontSize = 32.sp)
            Spacer(Modifier.size(Spacing.md))
            Column(Modifier.weight(1f)) {
                Text("連続記録", fontSize = 12.sp, color = palette.textSecondary)
                Text(
                    "${streak.current} 日",
                    modifier = Modifier.tag("streak-count"),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = palette.accent,
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text("最長", fontSize = 12.sp, color = palette.textSecondary)
                Text(
                    "${streak.longest} 日",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = palette.textPrimary,
                )
            }
        }
    }
}

@Composable
private fun SubTitle(text: String) {
    Text(
        text,
        modifier = Modifier.padding(top = Spacing.md, bottom = Spacing.sm),
        fontSize = 13.sp,
        fontWeight = FontWeight.Bold,
        color = LocalPalette.current.textSecondary,
    )
}

private enum class CardState { DUE, LATER, DONE }

@Composable
private fun RoutineCard(item: TodayRoutine, state: CardState, onClick: () -> Unit) {
    val palette = LocalPalette.current
    val routine = item.routine.routine

    Box(
        modifier = Modifier
            .padding(bottom = Spacing.sm)
            .alpha(if (state == CardState.DUE) 1f else 0.55f)
            .tag("routine-card-${routine.id}")
            .clickable(onClick = onClick),
    ) {
        AppCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .background(hexToColor(routine.color), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(routine.icon, fontSize = 24.sp)
                }
                Spacer(Modifier.size(Spacing.md))
                Column(Modifier.weight(1f)) {
                    Text(
                        routine.name,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = palette.textPrimary,
                    )
                    Text(
                        if (state == CardState.DONE) "今日は完了しました"
                        else "${formatFrequency(routine)} ・ ${item.routine.exercises.size}種目",
                        fontSize = 12.sp,
                        color = palette.textSecondary,
                    )
                }
                Text(
                    if (state == CardState.DONE) "✅" else "▶",
                    fontSize = 18.sp,
                    color = if (state == CardState.DONE) palette.textPrimary else palette.primaryLight,
                )
            }
        }
    }
}

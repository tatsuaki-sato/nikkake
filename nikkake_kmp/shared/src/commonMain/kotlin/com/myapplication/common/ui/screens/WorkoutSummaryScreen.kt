package com.myapplication.common.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.myapplication.common.data.LogStatus
import com.myapplication.common.domain.calculateStreak
import com.myapplication.common.domain.formatDuration
import com.myapplication.common.store.AppStore
import com.myapplication.common.store.WorkoutStore
import com.myapplication.common.ui.Navigation
import com.myapplication.common.ui.components.AppButton
import com.myapplication.common.ui.components.AppCard
import com.myapplication.common.ui.components.EmptyState
import com.myapplication.common.ui.components.StatBlock
import com.myapplication.common.ui.components.tag
import com.myapplication.common.ui.theme.LocalPalette
import com.myapplication.common.ui.theme.Spacing
import kotlin.math.roundToInt

/**
 * ワークアウト完了直後のサマリー。
 * 「今やった分がちゃんと記録された」ことを見せて、連続記録が伸びたことを返す画面。
 */
@Composable
fun WorkoutSummaryScreen(appStore: AppStore, workoutStore: WorkoutStore, navigation: Navigation) {
    val palette = LocalPalette.current
    val summary = workoutStore.lastSummary
    val streak = calculateStreak(appStore.routineLogs)

    val goHome = {
        workoutStore.clearSummary()
        // スタックの一番下(タブ画面)まで戻る。pushで積み直すとタブが二重になる
        navigation.popToRoot()
    }

    if (summary == null) {
        Box(Modifier.fillMaxSize().background(palette.background), Alignment.Center) {
            EmptyState(
                modifier = Modifier.tag("summary-empty"),
                icon = "🤔",
                title = "表示できる記録がありません",
                message = "ワークアウトを完了するとここに結果が出ます。",
                action = { AppButton("ホームへ", onClick = goHome) },
            )
        }
        return
    }

    val statusLabel = when (summary.status) {
        LogStatus.COMPLETED -> "コンプリート！"
        LogStatus.PARTIAL -> "記録しました"
        else -> "記録なし"
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(palette.background).tag("summary-screen"),
        contentPadding = PaddingValues(Spacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        item {
            Spacer(Modifier.height(Spacing.xl))
            Text(if (summary.status == LogStatus.COMPLETED) "🎉" else "💪", fontSize = 64.sp)
            Spacer(Modifier.height(Spacing.md))
            Text(
                statusLabel,
                modifier = Modifier.tag("summary-status"),
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = palette.textPrimary,
            )
            Text(summary.routineName, fontSize = 15.sp, color = palette.textSecondary)
            Spacer(Modifier.height(Spacing.xl))

            AppCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceAround,
                ) {
                    StatBlock("時間", formatDuration(summary.durationSec), "summary-duration")
                    StatBlock("セット", "${summary.completedSets}/${summary.totalSets}", "summary-sets")
                    StatBlock(
                        "総重量",
                        if (summary.totalVolume > 0) "${summary.totalVolume.roundToInt()} kg" else "—",
                        "summary-volume",
                    )
                }
            }
            Spacer(Modifier.height(Spacing.md))

            AppCard(color = palette.surfaceElevated) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(if (streak.current > 0) "🔥" else "🌱", fontSize = 32.sp)
                    Spacer(Modifier.size(Spacing.md))
                    Column {
                        Text("連続記録", fontSize = 12.sp, color = palette.textSecondary)
                        Text(
                            "${streak.current} 日",
                            modifier = Modifier.tag("summary-streak"),
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            color = palette.accent,
                        )
                    }
                }
            }
            Spacer(Modifier.height(Spacing.xl))

            AppButton("ホームに戻る", onClick = goHome, modifier = Modifier.tag("summary-home"))
        }
    }
}

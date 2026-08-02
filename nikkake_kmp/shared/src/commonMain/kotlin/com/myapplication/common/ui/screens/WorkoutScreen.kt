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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.LinearProgressIndicator
import androidx.compose.material.OutlinedTextField
import androidx.compose.material.Text
import androidx.compose.material.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
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
import com.myapplication.common.domain.formatDuration
import com.myapplication.common.data.WorkoutSessionView
import com.myapplication.common.store.AppStore
import com.myapplication.common.store.WorkoutStore
import com.myapplication.common.ui.Destination
import com.myapplication.common.ui.Navigation
import com.myapplication.common.ui.components.AppButton
import com.myapplication.common.ui.components.AppCard
import com.myapplication.common.ui.components.ButtonVariant
import com.myapplication.common.ui.components.ConfirmDialog
import com.myapplication.common.ui.components.EmptyState
import com.myapplication.common.ui.components.SelectableChip
import com.myapplication.common.ui.components.tag
import com.myapplication.common.ui.theme.LocalPalette
import com.myapplication.common.ui.theme.Radii
import com.myapplication.common.ui.theme.Spacing
import kotlinx.coroutines.delay

/**
 * ワークアウト実行画面。
 * 記録はすべてローカルなので、電波が無い場所（ジムの地下など）でも完全に動く。
 */
@Composable
fun WorkoutScreen(
    appStore: AppStore,
    workoutStore: WorkoutStore,
    navigation: Navigation,
    routineId: String,
) {
    // finish() はサーバへ送るので suspend。ここで待つためのスコープ
    val scope = rememberCoroutineScope()
    val palette = LocalPalette.current
    var confirmCancel by remember { mutableStateOf(false) }
    // 種目・目標値・前回の記録がまとめて1本で返る
    var notFound by remember(routineId) { mutableStateOf(false) }

    LaunchedEffect(routineId) {
        val loaded = runCatching { appStore.repository.getWorkoutSession(routineId) }.getOrNull()

        if (loaded == null || loaded.exercises.isEmpty()) {
            notFound = true
        } else {
            workoutStore.start(loaded)
        }
    }

    // 経過時間とレストタイマーを1本のループでまとめて進める
    LaunchedEffect(workoutStore.isActive) {
        while (workoutStore.isActive) {
            delay(1000)
            workoutStore.tick()
        }
    }

    if (notFound) {
        Box(Modifier.fillMaxSize().background(palette.background), Alignment.Center) {
            EmptyState(
                modifier = Modifier.tag("workout-not-found"),
                icon = "🤔",
                title = "開始できませんでした",
                message = "ルーティンが見つからないか、種目が登録されていません。",
                action = { AppButton("戻る", onClick = navigation::pop) },
            )
        }
        return
    }

    val current = workoutStore.current
    if (!workoutStore.isActive || current == null) {
        Box(Modifier.fillMaxSize().background(palette.background).tag("workout-loading"), Alignment.Center) {
            Text("準備中…", color = palette.textSecondary)
        }
        return
    }

    val index = workoutStore.currentIndex

    Column(Modifier.fillMaxSize().background(palette.background).tag("workout-screen")) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = { confirmCancel = true }, modifier = Modifier.tag("workout-cancel")) {
                Text("中断", color = palette.textSecondary)
            }
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    workoutStore.routineName,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = palette.textPrimary,
                )
                Text(
                    formatDuration(workoutStore.elapsedSec),
                    modifier = Modifier.tag("workout-elapsed"),
                    fontSize = 12.sp,
                    color = palette.textSecondary,
                )
            }
            AppButton(
                label = "完了",
                modifier = Modifier.width(96.dp).tag("workout-finish"),
                onClick = {
                    scope.launch {
                        if (workoutStore.finish() != null) {
                            appStore.refresh()
                            navigation.replace(Destination.WorkoutSummary)
                        }
                    }
                },
            )
        }

        LinearProgressIndicator(
            progress = workoutStore.progress,
            modifier = Modifier.fillMaxWidth().height(4.dp),
            color = palette.success,
            backgroundColor = palette.surface,
        )

        if (workoutStore.isRestActive) {
            Box(
                modifier = Modifier
                    .padding(Spacing.md)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(Radii.md))
                    .background(palette.surfaceElevated)
                    .border(1.dp, palette.accent, RoundedCornerShape(Radii.md))
                    .tag("rest-timer")
                    .clickable { workoutStore.stopRestTimer() }
                    .padding(Spacing.md),
            ) {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("休憩中", fontSize = 12.sp, color = palette.textSecondary)
                    Text(
                        formatDuration(workoutStore.restTimer),
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = palette.accent,
                    )
                    Text("タップでスキップ", fontSize = 11.sp, color = palette.textSecondary)
                }
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(Spacing.md),
        ) {
            item {
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    workoutStore.exercises.forEachIndexed { i, exercise ->
                        SelectableChip(
                            label = (if (exercise.sets.all { it.completed }) "✓ " else "") + exercise.exercise.name,
                            selected = i == index,
                            onClick = { workoutStore.goToExercise(i) },
                            modifier = Modifier.tag("workout-tab-$i"),
                        )
                    }
                }
                Spacer(Modifier.height(Spacing.md))

                Text(
                    "${index + 1}/${workoutStore.exercises.size} ${current.exercise.name}",
                    modifier = Modifier.tag("workout-exercise-name"),
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = palette.textPrimary,
                )

                if (current.previousSets.isNotEmpty()) {
                    Text(
                        "前回: " + current.previousSets.joinToString(" / ") { set ->
                            if (set.durationSec != null) "${set.durationSec}秒"
                            else "${set.weight ?: "自重"}×${set.reps ?: "-"}"
                        },
                        modifier = Modifier.tag("workout-previous-hint").padding(top = Spacing.xs),
                        fontSize = 12.sp,
                        color = palette.textSecondary,
                    )
                }
                Spacer(Modifier.height(Spacing.md))
            }

            item {
                AppCard {
                    Column {
                        Row {
                            ColumnLabel("セット", Modifier.width(48.dp))
                            ColumnLabel("kg", Modifier.weight(1f))
                            ColumnLabel(if (current.isTimeBased) "秒" else "回", Modifier.weight(1f))
                            ColumnLabel("完了", Modifier.width(64.dp))
                        }

                        current.sets.forEach { set ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(if (set.completed) palette.surfaceElevated else Color.Transparent)
                                    .tag("set-row-$index-${set.setNumber}")
                                    .padding(vertical = Spacing.sm),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    "${set.setNumber}",
                                    modifier = Modifier.width(48.dp),
                                    textAlign = TextAlign.Center,
                                    color = palette.textSecondary,
                                )

                                OutlinedTextField(
                                    value = set.weight?.toString() ?: "",
                                    onValueChange = { text ->
                                        workoutStore.updateSet(index, set.setNumber) {
                                            it.copy(weight = text.toDoubleOrNull())
                                        }
                                    },
                                    modifier = Modifier.weight(1f).tag("set-weight-$index-${set.setNumber}"),
                                    placeholder = { Text("自重", color = palette.textSecondary) },
                                    singleLine = true,
                                )
                                Spacer(Modifier.width(Spacing.sm))

                                if (current.isTimeBased) {
                                    OutlinedTextField(
                                        value = set.durationSec?.toString() ?: "",
                                        onValueChange = { text ->
                                            workoutStore.updateSet(index, set.setNumber) {
                                                it.copy(durationSec = text.toIntOrNull())
                                            }
                                        },
                                        modifier = Modifier.weight(1f).tag("set-duration-$index-${set.setNumber}"),
                                        singleLine = true,
                                    )
                                } else {
                                    OutlinedTextField(
                                        value = set.reps?.toString() ?: "",
                                        onValueChange = { text ->
                                            workoutStore.updateSet(index, set.setNumber) {
                                                it.copy(reps = text.toIntOrNull())
                                            }
                                        },
                                        modifier = Modifier.weight(1f).tag("set-reps-$index-${set.setNumber}"),
                                        singleLine = true,
                                    )
                                }

                                Box(Modifier.width(64.dp), contentAlignment = Alignment.Center) {
                                    Box(
                                        modifier = Modifier
                                            .size(width = 40.dp, height = 36.dp)
                                            .clip(RoundedCornerShape(Radii.sm))
                                            .background(if (set.completed) palette.success else palette.background)
                                            .border(
                                                1.dp,
                                                if (set.completed) palette.success else palette.border,
                                                RoundedCornerShape(Radii.sm),
                                            )
                                            .tag("set-check-$index-${set.setNumber}")
                                            .clickable { workoutStore.toggleSetComplete(index, set.setNumber) },
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Text(
                                            if (set.completed) "✓" else "",
                                            color = palette.background,
                                            fontWeight = FontWeight.Bold,
                                        )
                                    }
                                }
                            }
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth().padding(top = Spacing.sm),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            TextButton(
                                onClick = { workoutStore.removeSet(index) },
                                modifier = Modifier.tag("remove-set"),
                            ) {
                                Text("− セットを減らす", color = palette.primaryLight, fontSize = 13.sp)
                            }
                            TextButton(
                                onClick = { workoutStore.addSet(index) },
                                modifier = Modifier.tag("add-set"),
                            ) {
                                Text("＋ セットを追加", color = palette.primaryLight, fontSize = 13.sp)
                            }
                        }
                    }
                }

                Spacer(Modifier.height(Spacing.lg))
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    AppButton(
                        label = "前の種目",
                        variant = ButtonVariant.SECONDARY,
                        enabled = index > 0,
                        onClick = { workoutStore.previousExercise() },
                        modifier = Modifier.weight(1f).tag("workout-prev"),
                    )
                    AppButton(
                        label = "次の種目",
                        variant = ButtonVariant.SECONDARY,
                        enabled = index < workoutStore.exercises.size - 1,
                        onClick = { workoutStore.nextExercise() },
                        modifier = Modifier.weight(1f).tag("workout-next"),
                    )
                }
            }
        }
    }

    if (confirmCancel) {
        ConfirmDialog(
            title = "中断しますか？",
            message = "ここまでの記録は保存されません。",
            confirmLabel = "中断する",
            onConfirm = {
                workoutStore.cancel()
                confirmCancel = false
                navigation.pop()
            },
            onDismiss = { confirmCancel = false },
        )
    }
}

@Composable
private fun ColumnLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        modifier = modifier,
        textAlign = TextAlign.Center,
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold,
        color = LocalPalette.current.textSecondary,
    )
}

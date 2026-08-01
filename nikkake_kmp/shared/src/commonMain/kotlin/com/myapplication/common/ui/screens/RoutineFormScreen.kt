package com.myapplication.common.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.OutlinedTextField
import androidx.compose.material.Text
import androidx.compose.material.TextButton
import androidx.compose.material.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.myapplication.common.constants.DEFAULT_REST_SEC
import com.myapplication.common.constants.categoryLabels
import com.myapplication.common.constants.routineColors
import com.myapplication.common.constants.routineIcons
import com.myapplication.common.data.ExerciseCategory
import com.myapplication.common.data.FrequencyType
import com.myapplication.common.data.RoutineExerciseInput
import com.myapplication.common.data.RoutineInput
import com.myapplication.common.store.AppStore
import com.myapplication.common.ui.Navigation
import com.myapplication.common.ui.components.AppButton
import com.myapplication.common.ui.components.AppCard
import com.myapplication.common.ui.components.ButtonVariant
import com.myapplication.common.ui.components.ConfirmDialog
import com.myapplication.common.ui.components.ErrorText
import com.myapplication.common.ui.components.FieldLabel
import com.myapplication.common.ui.components.SelectableChip
import com.myapplication.common.ui.components.tag
import com.myapplication.common.ui.theme.LocalPalette
import com.myapplication.common.ui.theme.Radii
import com.myapplication.common.ui.theme.Spacing
import com.myapplication.common.ui.theme.hexToColor

/** フォーム上の1種目。入力途中は数値もテキストのまま持つ */
private class ExerciseRow(
    val exerciseId: String,
    val name: String,
    val icon: String?,
    sets: Int = 3,
    reps: Int? = 10,
    weight: Double? = null,
    durationSec: Int? = null,
    restSec: Int = DEFAULT_REST_SEC,
) {
    var setsText by mutableStateOf(sets.toString())
    var repsText by mutableStateOf(reps?.toString() ?: "")
    var weightText by mutableStateOf(weight?.toString() ?: "")
    var durationText by mutableStateOf(durationSec?.toString() ?: "")
    var restText by mutableStateOf(restSec.toString())

    fun toInput() = RoutineExerciseInput(
        exerciseId = exerciseId,
        targetSets = setsText.toIntOrNull()?.coerceIn(1, 99) ?: 1,
        targetReps = repsText.toIntOrNull(),
        targetWeight = weightText.toDoubleOrNull(),
        targetDurationSec = durationText.toIntOrNull(),
        restSec = restText.toIntOrNull() ?: DEFAULT_REST_SEC,
    )
}

/**
 * ルーティンの作成と編集で共通のフォーム。
 * 2画面に分けると入力仕様がすぐズレるので、routineId の有無で振る舞いを変える1画面にしている。
 */
@Composable
fun RoutineFormScreen(appStore: AppStore, navigation: Navigation, routineId: String?) {
    val palette = LocalPalette.current
    val isEdit = routineId != null
    val existing = remember(routineId) { routineId?.let { appStore.findRoutine(it) } }

    var name by remember { mutableStateOf(existing?.routine?.name ?: "") }
    var icon by remember { mutableStateOf(existing?.routine?.icon ?: routineIcons.first()) }
    var color by remember { mutableStateOf(existing?.routine?.color ?: routineColors.first()) }
    var frequencyType by remember { mutableStateOf(existing?.routine?.frequencyType ?: FrequencyType.DAILY) }
    var frequencyValueText by remember { mutableStateOf((existing?.routine?.frequencyValue ?: 2).toString()) }
    val frequencyDays = remember { mutableStateListOf<Int>().also { it.addAll(existing?.routine?.frequencyDays.orEmpty()) } }
    var pickerOpen by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }

    val rows = remember {
        mutableStateListOf<ExerciseRow>().also { list ->
            existing?.exercises?.forEach { entry ->
                list.add(
                    ExerciseRow(
                        exerciseId = entry.exercise.id,
                        name = entry.exercise.name,
                        icon = entry.exercise.icon,
                        sets = entry.link.targetSets,
                        reps = entry.link.targetReps,
                        weight = entry.link.targetWeight,
                        durationSec = entry.link.targetDurationSec,
                        restSec = entry.link.restSec ?: DEFAULT_REST_SEC,
                    ),
                )
            }
        }
    }

    fun submit() {
        when {
            name.isBlank() -> {
                error = "ルーティン名を入力してください"
                return
            }
            rows.isEmpty() -> {
                error = "種目を1つ以上追加してください"
                return
            }
            frequencyType == FrequencyType.WEEKLY && frequencyDays.isEmpty() -> {
                error = "曜日を1つ以上選んでください"
                return
            }
        }
        error = null

        val input = RoutineInput(
            name = name.trim(),
            icon = icon,
            color = color,
            frequencyType = frequencyType,
            frequencyValue = if (frequencyType == FrequencyType.EVERY_N_DAYS) {
                frequencyValueText.toIntOrNull()?.coerceIn(1, 365) ?: 1
            } else 1,
            frequencyDays = if (frequencyType == FrequencyType.WEEKLY) frequencyDays.toList() else emptyList(),
            exercises = rows.map { it.toInput() },
        )

        if (isEdit) appStore.updateRoutine(routineId!!, input) else appStore.createRoutine(input)
        navigation.pop()
    }

    Column(Modifier.fillMaxSize().background(palette.background)) {
        TopAppBar(
            title = { Text(if (isEdit) "ルーティン編集" else "ルーティン作成", color = palette.textPrimary) },
            navigationIcon = {
                TextButton(onClick = navigation::pop) {
                    Text("戻る", color = palette.textSecondary)
                }
            },
            backgroundColor = palette.surface,
            elevation = 0.dp,
        )

        LazyColumn(
            modifier = Modifier.fillMaxSize().tag("routine-form"),
            contentPadding = PaddingValues(Spacing.md),
        ) {
            item {
                ErrorText(error)

                FieldLabel("ルーティン名")
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    modifier = Modifier.fillMaxWidth().tag("routine-name-input"),
                    placeholder = { Text("例: 朝の全身メニュー", color = palette.textSecondary) },
                    singleLine = true,
                )
                Spacer(Modifier.height(Spacing.lg))

                FieldLabel("アイコン")
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    routineIcons.take(6).forEach { candidate ->
                        Box(
                            modifier = Modifier
                                .size(44.dp)
                                .background(palette.surfaceElevated, CircleShape)
                                .border(
                                    2.dp,
                                    if (icon == candidate) palette.primary else Color.Transparent,
                                    CircleShape,
                                )
                                .tag("icon-$candidate")
                                .clickable { icon = candidate },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(candidate, fontSize = 20.sp)
                        }
                    }
                }
                Spacer(Modifier.height(Spacing.lg))

                FieldLabel("カラー")
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    routineColors.take(6).forEach { candidate ->
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .background(hexToColor(candidate), CircleShape)
                                .border(
                                    3.dp,
                                    if (color == candidate) palette.textPrimary else Color.Transparent,
                                    CircleShape,
                                )
                                .tag("color-$candidate")
                                .clickable { color = candidate },
                        )
                    }
                }
                Spacer(Modifier.height(Spacing.lg))

                FieldLabel("頻度")
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    SelectableChip("毎日", frequencyType == FrequencyType.DAILY, {
                        frequencyType = FrequencyType.DAILY
                    }, Modifier.tag("frequency-daily"))
                    SelectableChip("N日ごと", frequencyType == FrequencyType.EVERY_N_DAYS, {
                        frequencyType = FrequencyType.EVERY_N_DAYS
                    }, Modifier.tag("frequency-every_n_days"))
                    SelectableChip("曜日指定", frequencyType == FrequencyType.WEEKLY, {
                        frequencyType = FrequencyType.WEEKLY
                    }, Modifier.tag("frequency-weekly"))
                }

                if (frequencyType == FrequencyType.EVERY_N_DAYS) {
                    Spacer(Modifier.height(Spacing.md))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(
                            value = frequencyValueText,
                            onValueChange = { frequencyValueText = it.filter { c -> c.isDigit() } },
                            modifier = Modifier.width(88.dp).tag("frequency-value-input"),
                            singleLine = true,
                        )
                        Spacer(Modifier.width(Spacing.sm))
                        Text("日ごとに実施", fontSize = 13.sp, color = palette.textSecondary)
                    }
                }

                if (frequencyType == FrequencyType.WEEKLY) {
                    Spacer(Modifier.height(Spacing.md))
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        listOf("日", "月", "火", "水", "木", "金", "土").forEachIndexed { day, label ->
                            SelectableChip(
                                label = label,
                                selected = frequencyDays.contains(day),
                                onClick = {
                                    if (!frequencyDays.remove(day)) frequencyDays.add(day)
                                },
                                modifier = Modifier.tag("day-$day"),
                            )
                        }
                    }
                }

                Spacer(Modifier.height(Spacing.lg))
                FieldLabel("種目")
            }

            itemsIndexedRows(rows) { index, row ->
                Box(Modifier.padding(bottom = Spacing.sm)) {
                    AppCard {
                        Column {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    "${row.icon.orEmpty()} ${row.name}".trim(),
                                    modifier = Modifier.weight(1f).tag("exercise-row-$index"),
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = palette.textPrimary,
                                )
                                MiniButton("↑", "exercise-up-$index") {
                                    if (index > 0) rows.add(index - 1, rows.removeAt(index))
                                }
                                MiniButton("↓", "exercise-down-$index") {
                                    if (index < rows.size - 1) rows.add(index + 1, rows.removeAt(index))
                                }
                                MiniButton("✕", "exercise-remove-$index") { rows.removeAt(index) }
                            }

                            Spacer(Modifier.height(Spacing.md))
                            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                                NumberField("セット", row.setsText, "exercise-sets-$index") { row.setsText = it }
                                NumberField("回数", row.repsText, "exercise-reps-$index") { row.repsText = it }
                                NumberField("重量kg", row.weightText, "exercise-weight-$index") { row.weightText = it }
                            }
                            Spacer(Modifier.height(Spacing.sm))
                            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                                NumberField("秒", row.durationText, "exercise-duration-$index") { row.durationText = it }
                                NumberField("休憩秒", row.restText, "exercise-rest-$index") { row.restText = it }
                            }
                        }
                    }
                }
            }

            item {
                AppButton(
                    label = if (pickerOpen) "種目リストを閉じる" else "＋ 種目を追加",
                    variant = ButtonVariant.SECONDARY,
                    onClick = { pickerOpen = !pickerOpen },
                    modifier = Modifier.tag("add-exercise-button"),
                )

                if (pickerOpen) {
                    Spacer(Modifier.height(Spacing.md))
                    AppCard(modifier = Modifier.tag("exercise-picker")) {
                        Column {
                            ExerciseCategory.all.forEach { category ->
                                val items = appStore.exercises.filter { it.category == category }
                                if (items.isEmpty()) return@forEach

                                Text(
                                    categoryLabels[category] ?: category,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = palette.textSecondary,
                                )
                                Spacer(Modifier.height(Spacing.sm))

                                items.chunked(2).forEach { pair ->
                                    Row(
                                        modifier = Modifier.padding(bottom = Spacing.sm),
                                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                                    ) {
                                        pair.forEach { exercise ->
                                            SelectableChip(
                                                label = "${exercise.icon.orEmpty()} ${exercise.name}".trim(),
                                                selected = false,
                                                onClick = {
                                                    rows.add(
                                                        ExerciseRow(
                                                            exerciseId = exercise.id,
                                                            name = exercise.name,
                                                            icon = exercise.icon,
                                                        ),
                                                    )
                                                    pickerOpen = false
                                                },
                                                modifier = Modifier.tag("pick-exercise-${exercise.id}"),
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(Modifier.height(Spacing.lg))
                AppButton(
                    label = if (isEdit) "保存する" else "作成する",
                    onClick = { submit() },
                    modifier = Modifier.tag("routine-submit"),
                )

                if (isEdit) {
                    Spacer(Modifier.height(Spacing.md))
                    AppButton(
                        label = "このルーティンを削除",
                        variant = ButtonVariant.DANGER,
                        onClick = { confirmDelete = true },
                        modifier = Modifier.tag("routine-delete"),
                    )
                }

                Spacer(Modifier.height(Spacing.xl))
            }
        }
    }

    if (confirmDelete && routineId != null) {
        ConfirmDialog(
            title = "ルーティンを削除",
            message = "このルーティンを削除しますか？これまでの記録は残ります。",
            confirmLabel = "削除",
            onConfirm = {
                appStore.deleteRoutine(routineId)
                confirmDelete = false
                navigation.pop()
            },
            onDismiss = { confirmDelete = false },
        )
    }
}

/** LazyListScope に index 付きで並べるための小さなラッパー */
private fun androidx.compose.foundation.lazy.LazyListScope.itemsIndexedRows(
    rows: List<ExerciseRow>,
    content: @Composable (Int, ExerciseRow) -> Unit,
) {
    rows.forEachIndexed { index, row ->
        item(key = "${row.exerciseId}-$index") { content(index, row) }
    }
}

@Composable
private fun MiniButton(label: String, tagId: String, onClick: () -> Unit) {
    Text(
        label,
        modifier = Modifier.tag(tagId).clickable(onClick = onClick).padding(Spacing.sm),
        fontSize = 16.sp,
        color = LocalPalette.current.textSecondary,
    )
}

@Composable
private fun NumberField(label: String, value: String, tagId: String, onChange: (String) -> Unit) {
    val palette = LocalPalette.current

    Column {
        Text(label, fontSize = 11.sp, color = palette.textSecondary)
        Spacer(Modifier.height(Spacing.xs))
        OutlinedTextField(
            value = value,
            onValueChange = onChange,
            modifier = Modifier.width(88.dp).tag(tagId),
            singleLine = true,
            shape = androidx.compose.foundation.shape.RoundedCornerShape(Radii.sm),
        )
    }
}

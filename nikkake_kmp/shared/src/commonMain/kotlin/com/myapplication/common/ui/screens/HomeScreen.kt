package com.myapplication.common.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
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
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.myapplication.common.data.StreakInfo
import com.myapplication.common.data.TodayRoutine
import com.myapplication.common.domain.currentHour
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
 *
 * 挨拶・日付・連続記録は1行にまとめている。縦幅を食う要素を増やさないため。
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HomeScreen(appStore: AppStore, navigation: Navigation) {
    val palette = LocalPalette.current

    // 区分（今日やる / 予定なし / 完了）も連続記録もサーバが決める。
    // ここで振り分け直すと、サーバと基準がずれても誰も気づけない。
    val home = appStore.home
    val streak = home.streak
    val due = home.due
    val later = home.notScheduled
    val done = home.completed

    val dueOrder = rememberSortableOrder(due.map { it.routine.id })
    val laterOrder = rememberSortableOrder(later.map { it.routine.id })
    val doneOrder = rememberSortableOrder(done.map { it.routine.id })

    val itemsById = remember(due, later, done) {
        (due + later + done).associateBy { it.routine.id }
    }

    // ドラッグ位置の判定に使う。区分ごとの並び替えなのでMapは画面全体で1つ共有してよい
    val itemPositions = remember { mutableMapOf<String, ItemLayout>() }

    // 区分ごとの順序を結合した並びをそのまま送る。区分をまたいだ移動はさせない
    // （「今日やる」か「完了」かはサーバが決めるもので、ドラッグで変えるものではないため）
    val commitOrder: () -> Unit = {
        appStore.reorderRoutines(dueOrder.order + laterOrder.order + doneOrder.order)
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(palette.background).tag("home-screen"),
        contentPadding = PaddingValues(Spacing.md),
    ) {
        item {
            val date = today()
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column {
                    Text(
                        greetingForHour(currentHour()),
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = palette.textPrimary,
                    )
                    Text(
                        "${date.monthNumber}月${date.dayOfMonth}日",
                        modifier = Modifier.padding(top = 2.dp),
                        fontSize = 12.sp,
                        color = palette.textSecondary,
                    )
                }
                StreakBanner(streak)
            }
            Spacer(Modifier.height(Spacing.md))
            Text(
                "今日のルーティン",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = palette.textPrimary,
            )
            Spacer(Modifier.height(Spacing.md))
        }

        if (home.total == 0) {
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

        sortableRoutineSection(
            order = dueOrder,
            itemsById = itemsById,
            state = CardState.DUE,
            itemPositions = itemPositions,
            onCommit = commitOrder,
            navigation = navigation,
        )

        if (laterOrder.order.isNotEmpty()) {
            item { SubTitle("今日は予定なし") }
            sortableRoutineSection(
                order = laterOrder,
                itemsById = itemsById,
                state = CardState.LATER,
                itemPositions = itemPositions,
                onCommit = commitOrder,
                navigation = navigation,
            )
        }

        if (doneOrder.order.isNotEmpty()) {
            item { SubTitle("完了") }
            sortableRoutineSection(
                order = doneOrder,
                itemsById = itemsById,
                state = CardState.DONE,
                itemPositions = itemPositions,
                onCommit = commitOrder,
                navigation = navigation,
            )
        }
    }
}

@Composable
private fun StreakBanner(streak: StreakInfo) {
    val palette = LocalPalette.current

    Row(
        modifier = Modifier.tag("streak-banner"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(if (streak.current > 0) "🔥" else "🌱", fontSize = 20.sp)
        Spacer(Modifier.width(Spacing.xs))
        Text(
            "${streak.current} 日",
            modifier = Modifier.tag("streak-count"),
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = palette.accent,
        )
        Spacer(Modifier.width(Spacing.xs))
        Text(
            "(最長${streak.longest}日)",
            fontSize = 12.sp,
            color = palette.textSecondary,
        )
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

/** ドラッグ中の判定に使う、コンテナ（ウィンドウ）内でのY座標とその高さ */
private data class ItemLayout(val y: Float, val height: Float)

/**
 * 区分（今日やる／予定なし／完了）内での並び順。
 * サーバの応答が変わったら追従するが、ドラッグ中は追従させない
 * （ドラッグの最中に再読み込みが走って手元の並びが飛ぶのを防ぐ）。
 */
private class SortableOrder(
    val order: List<String>,
    val setOrder: (List<String>) -> Unit,
    val dragging: MutableState<Boolean>,
)

@Composable
private fun rememberSortableOrder(ids: List<String>): SortableOrder {
    var order by remember { mutableStateOf(ids) }
    val dragging = remember { mutableStateOf(false) }

    LaunchedEffect(ids) {
        if (!dragging.value) order = ids
    }

    return remember(order) { SortableOrder(order, { order = it }, dragging) }
}

/**
 * 区分の中だけでドラッグ並び替えができるリストを追加する。区分をまたいだ移動はさせない。
 * ⠿ハンドルを長押ししてからドラッグする（detectDragGesturesAfterLongPress）。
 * 通常のタップでルーティンを開く操作と競合しないようにするため。
 */
@OptIn(ExperimentalFoundationApi::class)
private fun LazyListScope.sortableRoutineSection(
    order: SortableOrder,
    itemsById: Map<String, TodayRoutine>,
    state: CardState,
    itemPositions: MutableMap<String, ItemLayout>,
    onCommit: () -> Unit,
    navigation: Navigation,
) {
    items(order.order, key = { it }) { id ->
        val item = itemsById[id]
        if (item != null) {
            SortableRoutineCard(
                id = id,
                item = item,
                state = state,
                order = order,
                itemPositions = itemPositions,
                onCommit = onCommit,
                onClick = { navigation.push(Destination.Workout(id)) },
                modifier = Modifier.animateItemPlacement(),
            )
        }
    }
}

@Composable
private fun SortableRoutineCard(
    id: String,
    item: TodayRoutine,
    state: CardState,
    order: SortableOrder,
    itemPositions: MutableMap<String, ItemLayout>,
    onCommit: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val palette = LocalPalette.current
    val routine = item.routine.routine

    var dragOffsetPx by remember { mutableStateOf(0f) }
    var isDragging by remember { mutableStateOf(false) }

    // orderやonCommitは並び替えのたびに新しいインスタンスになるが、
    // pointerInputはid（変わらない）でキーしているので長押しの最中は再起動しない。
    // rememberUpdatedStateで常に最新の値を読む。
    val latestOrder = rememberUpdatedState(order)
    val latestOnCommit = rememberUpdatedState(onCommit)

    Box(
        modifier = modifier
            .padding(bottom = Spacing.sm)
            .onGloballyPositioned { coordinates ->
                itemPositions[id] = ItemLayout(
                    y = coordinates.positionInWindow().y,
                    height = coordinates.size.height.toFloat(),
                )
            }
            .then(
                if (isDragging) {
                    Modifier.graphicsLayer { translationY = dragOffsetPx }.zIndex(1f)
                } else {
                    Modifier
                }
            ),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .weight(1f)
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
                                else "${item.frequencyLabel} ・ ${item.routine.exercises.size}種目",
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

            Box(
                modifier = Modifier
                    .size(40.dp)
                    .tag("routine-drag-${routine.id}")
                    .pointerInput(id) {
                        var startY = 0f

                        detectDragGesturesAfterLongPress(
                            onDragStart = {
                                startY = itemPositions[id]?.y ?: 0f
                                latestOrder.value.dragging.value = true
                                isDragging = true
                                dragOffsetPx = 0f
                            },
                            onDrag = { change: PointerInputChange, dragAmount: Offset ->
                                change.consume()
                                dragOffsetPx += dragAmount.y

                                val height = itemPositions[id]?.height ?: 0f
                                val pointerMidY = startY + dragOffsetPx + height / 2

                                val currentOrder = latestOrder.value.order
                                val others = currentOrder.filter { it != id }

                                var insertIndex = others.size
                                for (i in others.indices) {
                                    val layout = itemPositions[others[i]] ?: continue
                                    if (pointerMidY < layout.y + layout.height / 2) {
                                        insertIndex = i
                                        break
                                    }
                                }

                                val next = others.toMutableList().apply { add(insertIndex, id) }
                                if (next != currentOrder) latestOrder.value.setOrder(next)
                            },
                            onDragEnd = {
                                isDragging = false
                                latestOrder.value.dragging.value = false
                                latestOnCommit.value()
                            },
                            onDragCancel = {
                                isDragging = false
                                latestOrder.value.dragging.value = false
                                latestOnCommit.value()
                            },
                        )
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text("⠿", fontSize = 18.sp, color = palette.textSecondary)
            }
        }
    }
}

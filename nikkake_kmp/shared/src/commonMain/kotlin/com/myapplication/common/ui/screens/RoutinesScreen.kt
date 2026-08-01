package com.myapplication.common.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.FloatingActionButton
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.myapplication.common.data.RoutineWithExercises
import com.myapplication.common.domain.formatFrequency
import com.myapplication.common.store.AppStore
import com.myapplication.common.ui.Destination
import com.myapplication.common.ui.Navigation
import com.myapplication.common.ui.components.AppButton
import com.myapplication.common.ui.components.AppCard
import com.myapplication.common.ui.components.ConfirmDialog
import com.myapplication.common.ui.components.EmptyState
import com.myapplication.common.ui.components.tag
import com.myapplication.common.ui.theme.LocalPalette
import com.myapplication.common.ui.theme.Spacing
import com.myapplication.common.ui.theme.hexToColor

@Composable
fun RoutinesScreen(appStore: AppStore, navigation: Navigation) {
    val palette = LocalPalette.current
    var pendingDelete by remember { mutableStateOf<RoutineWithExercises?>(null) }

    Box(Modifier.fillMaxSize().background(palette.background).tag("routines-screen")) {
        if (appStore.routines.isEmpty()) {
            Box(Modifier.fillMaxSize().tag("routines-empty"), contentAlignment = Alignment.Center) {
                EmptyState(
                    icon = "📋",
                    title = "ルーティンがありません",
                    message = "よくやるメニューを登録しておくと、次からは1タップで始められます。",
                    action = {
                        AppButton("ルーティンを作る", onClick = { navigation.push(Destination.RoutineForm()) })
                    },
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().tag("routines-list"),
                contentPadding = PaddingValues(start = Spacing.md, end = Spacing.md, top = Spacing.md, bottom = 100.dp),
            ) {
                items(appStore.routines, key = { it.id }) { item ->
                    val routine = item.routine

                    Box(Modifier.padding(bottom = Spacing.sm).alpha(if (routine.isActive) 1f else 0.5f)) {
                        AppCard(padding = PaddingValues(horizontal = Spacing.md, vertical = Spacing.sm)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Row(
                                    modifier = Modifier
                                        .weight(1f)
                                        .tag("routine-edit-${routine.id}")
                                        .clickable {
                                            navigation.push(Destination.RoutineForm(routine.id))
                                        }
                                        .padding(vertical = Spacing.sm),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(48.dp)
                                            .background(hexToColor(routine.color), CircleShape),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Text(routine.icon, fontSize = 24.sp)
                                    }
                                    Spacer(Modifier.size(Spacing.md))
                                    Column {
                                        Text(
                                            routine.name,
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = palette.textPrimary,
                                        )
                                        Text(
                                            "${formatFrequency(routine)} ・ ${item.exercises.size}種目" +
                                                if (routine.isActive) "" else " ・ 停止中",
                                            fontSize = 12.sp,
                                            color = palette.textSecondary,
                                        )
                                    }
                                }

                                Text(
                                    if (routine.isActive) "⏸" else "▶",
                                    modifier = Modifier
                                        .tag("routine-toggle-${routine.id}")
                                        .clickable { appStore.setRoutineActive(routine.id, !routine.isActive) }
                                        .padding(Spacing.sm),
                                    fontSize = 16.sp,
                                )
                                Text(
                                    "🗑",
                                    modifier = Modifier
                                        .tag("routine-delete-${routine.id}")
                                        .clickable { pendingDelete = item }
                                        .padding(Spacing.sm),
                                    fontSize = 16.sp,
                                )
                            }
                        }
                    }
                }
            }
        }

        FloatingActionButton(
            onClick = { navigation.push(Destination.RoutineForm()) },
            modifier = Modifier.align(Alignment.BottomEnd).padding(Spacing.lg).tag("routines-fab"),
            backgroundColor = palette.primary,
        ) {
            Text("＋", fontSize = 24.sp, color = androidx.compose.ui.graphics.Color.White)
        }
    }

    pendingDelete?.let { target ->
        ConfirmDialog(
            title = "ルーティンを削除",
            message = "「${target.name}」を削除しますか？これまでの記録は残ります。",
            confirmLabel = "削除",
            onConfirm = {
                appStore.deleteRoutine(target.id)
                pendingDelete = null
            },
            onDismiss = { pendingDelete = null },
        )
    }
}

package com.myapplication.common.ui.screens

import androidx.compose.foundation.background
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
import androidx.compose.material.Divider
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.myapplication.common.data.Collections
import com.myapplication.common.data.StorageMode
import com.myapplication.common.data.SyncState
import com.myapplication.common.data.SyncStatus
import com.myapplication.common.store.AppStore
import com.myapplication.common.store.AuthStore
import com.myapplication.common.ui.Destination
import com.myapplication.common.ui.Navigation
import com.myapplication.common.ui.components.AppButton
import com.myapplication.common.ui.components.AppCard
import com.myapplication.common.ui.components.ButtonVariant
import com.myapplication.common.ui.components.ConfirmDialog
import com.myapplication.common.ui.components.LabeledRow
import com.myapplication.common.ui.components.SectionTitle
import com.myapplication.common.ui.components.tag
import com.myapplication.common.ui.theme.LocalPalette
import com.myapplication.common.ui.theme.Spacing
import kotlinx.coroutines.launch

/**
 * 設定。
 *
 * この画面の主役は「バックアップするかどうか」の説明。
 * サインインは機能を開放するためのものではなく、
 * 端末を変えたときにデータを引き継ぐためだけのもの、と伝わる文言にしてある。
 *
 * authStore が null なのは Supabase の初期化に失敗した場合。
 * その場合もローカルモードとして通常どおり表示する。
 */
@Composable
fun SettingsScreen(appStore: AppStore, authStore: AuthStore?, navigation: Navigation) {
    val palette = LocalPalette.current
    val scope = rememberCoroutineScope()
    val counts = appStore.counts
    val mode = authStore?.mode ?: StorageMode.LOCAL

    var confirmSignOut by remember { mutableStateOf(false) }
    var confirmReset by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(palette.background).tag("settings-screen"),
        contentPadding = PaddingValues(Spacing.md),
    ) {
        item {
            SectionTitle("データの保存先")

            if (authStore == null || mode == StorageMode.LOCAL) {
                AppCard(modifier = Modifier.tag("settings-local-card")) {
                    Column {
                        Row {
                            Text("📱", fontSize = 28.sp)
                            Spacer(Modifier.size(Spacing.md))
                            Column {
                                Text(
                                    "この端末専用の記録です",
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = palette.textPrimary,
                                )
                                Spacer(Modifier.height(Spacing.xs))
                                Text(
                                    "サインインしなくても全機能が使えます。ただしアプリを削除すると記録も消えます。",
                                    fontSize = 13.sp,
                                    color = palette.textSecondary,
                                )
                            }
                        }

                        Divider(color = palette.border, modifier = Modifier.padding(vertical = Spacing.md))

                        Text(
                            "バックアップを有効にすると、機種変更やアプリの入れ直しをしても記録を引き継げます。" +
                                "今ある記録もそのままクラウドへ引き継がれます。",
                            fontSize = 13.sp,
                            color = palette.textSecondary,
                        )
                        Spacer(Modifier.height(Spacing.md))

                        AppButton(
                            label = "バックアップを有効にする",
                            enabled = authStore != null,
                            onClick = { navigation.push(Destination.Login) },
                            modifier = Modifier.tag("settings-enable-backup"),
                        )
                    }
                }
            } else {
                AppCard(modifier = Modifier.tag("settings-cloud-card")) {
                    Column {
                        Row {
                            Text("☁️", fontSize = 28.sp)
                            Spacer(Modifier.size(Spacing.md))
                            Column {
                                Text(
                                    "バックアップ有効",
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = palette.textPrimary,
                                )
                                Spacer(Modifier.height(Spacing.xs))
                                Text(
                                    authStore.user?.email.orEmpty(),
                                    modifier = Modifier.tag("settings-email"),
                                    fontSize = 13.sp,
                                    color = palette.textSecondary,
                                )
                            }
                        }

                        Divider(color = palette.border, modifier = Modifier.padding(vertical = Spacing.md))

                        Text(
                            syncLabel(authStore.sync),
                            modifier = Modifier.tag("settings-sync-status"),
                            fontSize = 13.sp,
                            color = if (authStore.sync.status == SyncStatus.ERROR) palette.error
                            else palette.textSecondary,
                        )
                        if (authStore.pendingCount > 0) {
                            Text(
                                "未送信の変更: ${authStore.pendingCount} 件",
                                fontSize = 13.sp,
                                color = palette.textSecondary,
                            )
                        }
                        Spacer(Modifier.height(Spacing.md))

                        AppButton(
                            label = "今すぐ同期",
                            variant = ButtonVariant.SECONDARY,
                            loading = authStore.sync.status == SyncStatus.SYNCING,
                            onClick = { scope.launch { authStore.syncNow() } },
                            modifier = Modifier.tag("settings-sync-now"),
                        )
                        Spacer(Modifier.height(Spacing.sm))
                        AppButton(
                            label = "サインアウト",
                            variant = ButtonVariant.GHOST,
                            onClick = { confirmSignOut = true },
                            modifier = Modifier.tag("settings-sign-out"),
                        )
                    }
                }
            }

            Spacer(Modifier.height(Spacing.lg))
            SectionTitle("保存されているデータ")
            AppCard(modifier = Modifier.tag("settings-counts")) {
                Column {
                    LabeledRow("ルーティン", "${counts.routines}", "count-routines")
                    LabeledRow("種目", "${counts.exercises}", "count-exercises")
                    LabeledRow("ワークアウト記録", "${counts.routineLogs}", "count-logs")
                    LabeledRow("セット記録", "${counts.exerciseLogs}", "count-sets")
                }
            }

            Spacer(Modifier.height(Spacing.lg))
            SectionTitle("アプリについて")
            AppCard {
                LabeledRow("バージョン", "1.0.0", "settings-version")
            }

            Spacer(Modifier.height(Spacing.lg))
            SectionTitle("危険な操作")
            AppCard {
                Column {
                    Text(
                        "この端末のデータをすべて消して初期状態に戻します。" +
                            if (mode == StorageMode.CLOUD) "クラウド側のバックアップは残ります。" else "",
                        fontSize = 13.sp,
                        color = palette.textSecondary,
                    )
                    Spacer(Modifier.height(Spacing.md))
                    AppButton(
                        label = "データを初期化",
                        variant = ButtonVariant.DANGER,
                        onClick = { confirmReset = true },
                        modifier = Modifier.tag("settings-reset"),
                    )
                }
            }

            Spacer(Modifier.height(Spacing.xl))
        }
    }

    if (confirmSignOut && authStore != null) {
        ConfirmDialog(
            title = "サインアウト",
            message = "サインアウトしても、この端末の記録は消えません。クラウドへのバックアップが止まるだけです。",
            confirmLabel = "サインアウト",
            onConfirm = {
                scope.launch { authStore.signOut() }
                confirmSignOut = false
            },
            onDismiss = { confirmSignOut = false },
        )
    }

    if (confirmReset) {
        ConfirmDialog(
            title = "データを初期化",
            message = "この端末のルーティンと記録をすべて削除して、初期状態に戻します。取り消せません。",
            confirmLabel = "初期化する",
            onConfirm = {
                appStore.resetAll()
                confirmReset = false
            },
            onDismiss = { confirmReset = false },
        )
    }
}

private fun syncLabel(sync: SyncState): String = when (sync.status) {
    SyncStatus.SYNCING -> "同期中…"
    SyncStatus.OFFLINE -> "オフラインのため未同期"
    SyncStatus.ERROR -> "同期に失敗: ${sync.lastError ?: "不明なエラー"}"
    SyncStatus.IDLE -> sync.lastSyncedAt?.let { "最終同期 $it" } ?: "まだ同期していません"
}

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
 */
@Composable
fun SettingsScreen(appStore: AppStore, authStore: AuthStore, navigation: Navigation) {
    val palette = LocalPalette.current
    val scope = rememberCoroutineScope()
    val counts = appStore.counts
    val mode = authStore.mode

    var confirmSignOut by remember { mutableStateOf(false) }
    var confirmReset by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(palette.background).tag("settings-screen"),
        contentPadding = PaddingValues(Spacing.md),
    ) {
        item {
            SectionTitle("データの保存先")

            if (mode == StorageMode.LOCAL) {
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
                            "メールアドレスを登録すると、機種変更やアプリの入れ直しをしても記録を引き継げます。" +
                                "今ある記録はそのまま残ります（作り直しは起きません）。",
                            fontSize = 13.sp,
                            color = palette.textSecondary,
                        )
                        Spacer(Modifier.height(Spacing.md))

                        AppButton(
                            label = "バックアップを有効にする",
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
                                    authStore.viewer?.email.orEmpty(),
                                    modifier = Modifier.tag("settings-email"),
                                    fontSize = 13.sp,
                                    color = palette.textSecondary,
                                )
                            }
                        }

                        Divider(color = palette.border, modifier = Modifier.padding(vertical = Spacing.md))

                        Text(
                            pendingLabel(authStore),
                            modifier = Modifier.tag("settings-pending-status"),
                            fontSize = 13.sp,
                            color = if (authStore.lastError != null) palette.error else palette.textSecondary,
                        )
                        Spacer(Modifier.height(Spacing.md))

                        AppButton(
                            label = "今すぐ送信",
                            variant = ButtonVariant.SECONDARY,
                            enabled = authStore.pendingCount > 0,
                            onClick = { scope.launch { authStore.flushNow() } },
                            modifier = Modifier.tag("settings-flush-now"),
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
                        "ルーティンと記録をすべて削除して、初期状態に戻します。サーバ側も消えます。",
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

    if (confirmSignOut) {
        ConfirmDialog(
            title = "サインアウト",
            message = "サインアウトしても記録は消えません。この端末から見えなくなるだけで、" +
                "同じアカウントでサインインし直せば戻ります。",
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
                scope.launch { appStore.resetAll() }
                confirmReset = false
            },
            onDismiss = { confirmReset = false },
        )
    }
}

// 「同期」はもう無い。記録がサーバへ送れているかだけを見せる
private fun pendingLabel(authStore: AuthStore): String = when {
    authStore.lastError != null -> "送信に失敗しました: ${authStore.lastError}"
    authStore.pendingCount > 0 -> "未送信の記録: ${authStore.pendingCount} 件"
    else -> "すべて送信済みです"
}

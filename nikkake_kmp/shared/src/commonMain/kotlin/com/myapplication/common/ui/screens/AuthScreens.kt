package com.myapplication.common.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.OutlinedTextField
import androidx.compose.material.Text
import androidx.compose.material.TextButton
import androidx.compose.material.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.myapplication.common.store.AuthStore
import com.myapplication.common.ui.Destination
import com.myapplication.common.ui.Navigation
import com.myapplication.common.ui.components.AppButton
import com.myapplication.common.ui.components.AppCard
import com.myapplication.common.ui.components.ButtonVariant
import com.myapplication.common.ui.components.ErrorText
import com.myapplication.common.ui.components.FieldLabel
import com.myapplication.common.ui.components.tag
import com.myapplication.common.ui.theme.LocalPalette
import com.myapplication.common.ui.theme.Spacing
import kotlinx.coroutines.launch

/**
 * サインイン画面。
 *
 * この画面はアプリの入口ではない。設定から任意で開く「バックアップ設定」であり、
 * ここを飛ばしてもアプリの全機能が使えることを画面上でも明示している。
 */
@Composable
fun LoginScreen(authStore: AuthStore, navigation: Navigation) {
    val palette = LocalPalette.current
    val scope = rememberCoroutineScope()

    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    Column(Modifier.fillMaxSize().background(palette.background)) {
        TopAppBar(
            title = { Text("バックアップを有効にする", color = palette.textPrimary) },
            navigationIcon = {
                TextButton(onClick = navigation::pop) { Text("戻る", color = palette.textSecondary) }
            },
            backgroundColor = palette.surface,
            elevation = 0.dp,
        )

        LazyColumn(
            modifier = Modifier.fillMaxSize().tag("login-screen"),
            contentPadding = PaddingValues(Spacing.lg),
        ) {
            item {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "nikkake",
                        fontSize = 32.sp,
                        fontWeight = FontWeight.Bold,
                        color = palette.primaryLight,
                    )
                    Text("毎日の日課を、習慣に。", fontSize = 14.sp, color = palette.textSecondary)
                }
                Spacer(Modifier.height(Spacing.lg))

                AppCard(modifier = Modifier.tag("login-optional-notice"), color = palette.surfaceElevated) {
                    Text(
                        "サインインは任意です。しなくてもルーティンの作成も記録も全部使えます。" +
                            "機種変更やアプリの入れ直しで記録を失いたくない場合だけ設定してください。",
                        fontSize = 13.sp,
                        color = palette.textSecondary,
                    )
                }
                Spacer(Modifier.height(Spacing.lg))

                ErrorText(error)

                FieldLabel("メールアドレス")
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    modifier = Modifier.fillMaxWidth().tag("login-email"),
                    placeholder = { Text("example@email.com", color = palette.textSecondary) },
                    singleLine = true,
                )
                Spacer(Modifier.height(Spacing.md))

                FieldLabel("パスワード")
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    modifier = Modifier.fillMaxWidth().tag("login-password"),
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                )
                Spacer(Modifier.height(Spacing.lg))

                AppButton(
                    label = "サインイン",
                    loading = loading,
                    modifier = Modifier.tag("login-submit"),
                    onClick = {
                        if (email.isBlank() || password.isBlank()) {
                            error = "メールアドレスとパスワードを入力してください"
                            return@AppButton
                        }

                        loading = true
                        error = null
                        scope.launch {
                            // サーバは userErrors.message にそのまま画面へ出せる日本語を入れて返す
                            val result = authStore.signIn(email.trim(), password)
                            loading = false
                            if (result == null) navigation.pop() else error = result
                        }
                    },
                )
                Spacer(Modifier.height(Spacing.md))

                TextButton(
                    onClick = { navigation.push(Destination.Register) },
                    modifier = Modifier.fillMaxWidth().tag("login-to-register"),
                ) {
                    Text("アカウントを作る", color = palette.primaryLight, textAlign = TextAlign.Center)
                }

                AppButton(
                    label = "あとで設定する",
                    variant = ButtonVariant.GHOST,
                    onClick = navigation::pop,
                    modifier = Modifier.tag("login-skip"),
                )
            }
        }
    }
}

/**
 * アカウント作成。
 *
 * 新しいアカウントを作るのではなく、いま使っている匿名アカウントに
 * メールとパスワードを足す。user.id が変わらないので、
 * **これまでの記録は1件も移動しない**（引き継ぎ処理そのものが要らない）。
 */
@Composable
fun RegisterScreen(authStore: AuthStore, navigation: Navigation) {
    val palette = LocalPalette.current
    val scope = rememberCoroutineScope()

    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var done by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize().background(palette.background)) {
        TopAppBar(
            title = { Text("アカウント作成", color = palette.textPrimary) },
            navigationIcon = {
                TextButton(onClick = navigation::pop) { Text("戻る", color = palette.textSecondary) }
            },
            backgroundColor = palette.surface,
            elevation = 0.dp,
        )

        if (done) {
            AppCard(modifier = Modifier.padding(Spacing.lg).tag("register-done")) {
                Column {
                    Text(
                        "登録が完了しました",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = palette.textPrimary,
                    )
                    Spacer(Modifier.height(Spacing.sm))
                    Text(
                        "これまでの記録はそのまま残っています。" +
                            "機種変更やアプリの入れ直しをしても、このメールアドレスで元に戻せます。",
                        fontSize = 13.sp,
                        color = palette.textSecondary,
                    )
                    Spacer(Modifier.height(Spacing.lg))
                    AppButton(
                        "アプリに戻る",
                        modifier = Modifier.tag("register-back"),
                        // 登録 → サインイン → タブ の2枚を確実に戻す
                        onClick = navigation::popToRoot,
                    )
                }
            }
            return@Column
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize().tag("register-screen"),
            contentPadding = PaddingValues(Spacing.lg),
        ) {
            item {
                AppCard(color = palette.surfaceElevated) {
                    Text(
                        "今この端末にある記録は、登録後もそのまま残ります。",
                        fontSize = 13.sp,
                        color = palette.textSecondary,
                    )
                }
                Spacer(Modifier.height(Spacing.lg))

                ErrorText(error)

                FieldLabel("メールアドレス")
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    modifier = Modifier.fillMaxWidth().tag("register-email"),
                    placeholder = { Text("example@email.com", color = palette.textSecondary) },
                    singleLine = true,
                )
                Spacer(Modifier.height(Spacing.md))

                FieldLabel("パスワード（6文字以上）")
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    modifier = Modifier.fillMaxWidth().tag("register-password"),
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                )
                Spacer(Modifier.height(Spacing.lg))

                AppButton(
                    label = "アカウントを作る",
                    loading = loading,
                    modifier = Modifier.tag("register-submit"),
                    onClick = {
                        when {
                            email.isBlank() || password.isBlank() -> {
                                error = "メールアドレスとパスワードを入力してください"
                                return@AppButton
                            }
                            password.length < 6 -> {
                                error = "パスワードは6文字以上にしてください"
                                return@AppButton
                            }
                        }

                        loading = true
                        error = null
                        scope.launch {
                            val result = authStore.signUp(email.trim(), password)
                            loading = false
                            if (result != null) error = result else done = true
                        }
                    },
                )
            }
        }
    }
}

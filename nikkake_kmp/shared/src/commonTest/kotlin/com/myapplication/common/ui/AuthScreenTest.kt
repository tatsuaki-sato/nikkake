package com.myapplication.common.ui

import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.runComposeUiTest
import cafe.adriel.voyager.navigator.Navigator
import com.myapplication.common.ui.auth.LoginScreen
import com.myapplication.common.ui.theme.NikkakeTheme
import kotlin.test.Test

@OptIn(ExperimentalTestApi::class)
class AuthScreenTest {

    @Test
    fun testLoginScreenInitialDisplayAndEmptyInputError() = runComposeUiTest {
        setContent {
            NikkakeTheme {
                Navigator(LoginScreen())
            }
        }

        // Wait for redirect to login or check text
        onNodeWithText("毎日の日課を、習慣に。").assertExists()

        // Click login button
        onNodeWithText("ログイン").performClick()

        // Check error message
        onNodeWithText("メールアドレスとパスワードを入力してください").assertExists()
    }

    @Test
    fun testNavigateToRegisterAndEmptyInputError() = runComposeUiTest {
        setContent {
            NikkakeTheme {
                Navigator(LoginScreen())
            }
        }

        // Check register link exists
        onNodeWithText("アカウントをお持ちでない方はこちら").assertExists()

        // Click register link
        onNodeWithText("アカウントをお持ちでない方はこちら").performClick()

        // Check register screen is displayed
        onNodeWithText("アカウント作成").assertExists()

        // Click register button
        onNodeWithText("登録して始める").performClick()

        // Check error message
        onNodeWithText("すべての項目を入力してください").assertExists()
    }
}

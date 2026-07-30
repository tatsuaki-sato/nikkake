package com.myapplication.common.ui

import androidx.compose.ui.test.*
import cafe.adriel.voyager.navigator.Navigator
import com.myapplication.common.ui.home.HomeScreen
import com.myapplication.common.ui.progress.ProgressScreen
import com.myapplication.common.ui.theme.NikkakeTheme
import kotlin.test.Test

class WorkoutScreenTest {

    @OptIn(ExperimentalTestApi::class)
    @Test
    fun testWorkoutFlow() = runComposeUiTest {
        setContent {
            NikkakeTheme {
                Navigator(HomeScreen())
            }
        }

        // ホーム画面が表示されているか
        onNodeWithText("今日のルーティン").assertIsDisplayed()
        onNodeWithText("今日のテストルーティン").assertIsDisplayed()

        // 開始するボタンをクリック
        onNodeWithText("開始する").performClick()

        // ワークアウト画面に遷移したか
        onNodeWithText("完了する").assertIsDisplayed()

        // 完了するをクリック
        onNodeWithText("完了する").performClick()

        // サマリー画面が表示されたか
        onNodeWithText("お疲れ様でした！").assertIsDisplayed()
        
        // ホーム画面に戻る
        onNodeWithText("ホームへ戻る").performClick()

        // ホーム画面に戻ったか
        onNodeWithText("今日のルーティン").assertIsDisplayed()
    }

    @OptIn(ExperimentalTestApi::class)
    @Test
    fun testProgressScreen() = runComposeUiTest {
        setContent {
            NikkakeTheme {
                Navigator(ProgressScreen())
            }
        }

        // 進捗画面が表示されているか
        onNodeWithText("進捗状況").assertIsDisplayed()
        onNodeWithText("完了したワークアウト").assertIsDisplayed()
        onNodeWithText("1 回").assertIsDisplayed()
        onNodeWithText("ボリューム推移（モック）").assertIsDisplayed()
    }
}

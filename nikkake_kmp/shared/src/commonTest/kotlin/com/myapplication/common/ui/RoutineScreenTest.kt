package com.myapplication.common.ui

import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.runComposeUiTest
import cafe.adriel.voyager.navigator.Navigator
import com.myapplication.common.domain.Routine
import com.myapplication.common.store.AppStores
import com.myapplication.common.ui.routine.RoutineListScreen
import com.myapplication.common.ui.theme.NikkakeTheme
import kotlin.test.Test
import kotlin.test.assertTrue

class RoutineScreenTest {

    @OptIn(ExperimentalTestApi::class)
    @Test
    fun testRoutineManagementFlow() = runComposeUiTest {
        AppStores.routineStore.setRoutines(
            listOf(
                Routine(
                    id = "1",
                    name = "既存のルーティン",
                    icon = "🏋️",
                    color = "#ff0000",
                    frequencyType = "daily",
                    frequencyValue = 1,
                    isActive = true
                )
            )
        )

        var currentScreenName = ""

        setContent {
            NikkakeTheme {
                Navigator(RoutineListScreen()) { navigator ->
                    currentScreenName = navigator.lastItem::class.simpleName ?: ""
                    cafe.adriel.voyager.transitions.SlideTransition(navigator)
                }
            }
        }

        onNodeWithText("既存のルーティン").assertIsDisplayed()

        onNodeWithText("新しく作る").performClick()

        waitForIdle()
        assertTrue(currentScreenName.contains("RoutineCreateScreen"))

        onNodeWithText("作成する").performClick()

        waitForIdle()
        assertTrue(currentScreenName.contains("RoutineCreateScreen"))
    }
}

package com.myapplication.common.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.padding
import androidx.compose.material.BottomNavigation
import androidx.compose.material.BottomNavigationItem
import androidx.compose.material.Icon
import androidx.compose.material.Scaffold
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import cafe.adriel.voyager.navigator.tab.CurrentTab
import cafe.adriel.voyager.navigator.tab.LocalTabNavigator
import cafe.adriel.voyager.navigator.tab.Tab
import cafe.adriel.voyager.navigator.tab.TabNavigator
import com.myapplication.common.ui.theme.LocalColors

@Composable
fun MainScreen() {
    // Assuming HomeTab, RoutineTab, ProgressTab are created by subagents or we will create them
    TabNavigator(HomeTab) {
        val colors = LocalColors.current
        Scaffold(
            content = { innerPadding ->
                Box(modifier = Modifier.padding(innerPadding)) {
                    CurrentTab()
                }
            },
            bottomBar = {
                BottomNavigation(
                    backgroundColor = colors.surfaceElevated,
                    contentColor = colors.textPrimary
                ) {
                    TabNavigationItem(HomeTab)
                    TabNavigationItem(RoutineTab)
                    TabNavigationItem(ProgressTab)
                }
            }
        )
    }
}

@Composable
private fun RowScope.TabNavigationItem(tab: Tab) {
    val tabNavigator = LocalTabNavigator.current
    val colors = LocalColors.current

    BottomNavigationItem(
        selected = tabNavigator.current == tab,
        onClick = { tabNavigator.current = tab },
        icon = {
            tab.options.icon?.let { icon ->
                Icon(
                    painter = icon,
                    contentDescription = tab.options.title,
                    tint = if (tabNavigator.current == tab) colors.primary else colors.textSecondary
                )
            }
        },
        label = {
            Text(
                text = tab.options.title,
                color = if (tabNavigator.current == tab) colors.primary else colors.textSecondary
            )
        }
    )
}

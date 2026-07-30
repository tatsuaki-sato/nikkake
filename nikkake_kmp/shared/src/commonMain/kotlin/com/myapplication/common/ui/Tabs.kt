package com.myapplication.common.ui

import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Star
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import cafe.adriel.voyager.navigator.Navigator
import cafe.adriel.voyager.navigator.tab.Tab
import cafe.adriel.voyager.navigator.tab.TabOptions
import com.myapplication.common.ui.home.HomeScreen
import com.myapplication.common.ui.routine.RoutineListScreen
import com.myapplication.common.ui.progress.ProgressScreen

object HomeTab : Tab {
    override val options: TabOptions
        @Composable
        get() {
            val icon = rememberVectorPainter(Icons.Default.Home)
            return remember {
                TabOptions(
                    index = 0u,
                    title = "Home",
                    icon = icon
                )
            }
        }

    @Composable
    override fun Content() {
        Navigator(HomeScreen())
    }
}

object RoutineTab : Tab {
    override val options: TabOptions
        @Composable
        get() {
            val icon = rememberVectorPainter(Icons.Default.List)
            return remember {
                TabOptions(
                    index = 1u,
                    title = "Routines",
                    icon = icon
                )
            }
        }

    @Composable
    override fun Content() {
        Navigator(RoutineListScreen())
    }
}

object ProgressTab : Tab {
    override val options: TabOptions
        @Composable
        get() {
            val icon = rememberVectorPainter(Icons.Default.Star)
            return remember {
                TabOptions(
                    index = 2u,
                    title = "Progress",
                    icon = icon
                )
            }
        }

    @Composable
    override fun Content() {
        Navigator(ProgressScreen())
    }
}

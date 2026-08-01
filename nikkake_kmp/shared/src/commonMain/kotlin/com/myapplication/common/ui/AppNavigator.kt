package com.myapplication.common.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.BottomNavigation
import androidx.compose.material.BottomNavigationItem
import androidx.compose.material.CircularProgressIndicator
import androidx.compose.material.Text
import androidx.compose.material.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.myapplication.common.store.AppStore
import com.myapplication.common.store.AuthStore
import com.myapplication.common.store.WorkoutStore
import com.myapplication.common.ui.screens.HomeScreen
import com.myapplication.common.ui.screens.LoginScreen
import com.myapplication.common.ui.screens.ProgressScreen
import com.myapplication.common.ui.screens.RegisterScreen
import com.myapplication.common.ui.screens.RoutineFormScreen
import com.myapplication.common.ui.screens.RoutinesScreen
import com.myapplication.common.ui.screens.SettingsScreen
import com.myapplication.common.ui.screens.WorkoutScreen
import com.myapplication.common.ui.screens.WorkoutSummaryScreen
import com.myapplication.common.ui.theme.LocalPalette

/**
 * 画面遷移。
 *
 * ナビゲーションライブラリを入れていないのは、遷移が
 * 「4タブ ＋ 上に重ねる数枚」だけで、状態1つで足りる規模だから。
 */
sealed interface Destination {
    data object Tabs : Destination
    data class RoutineForm(val routineId: String? = null) : Destination
    data class Workout(val routineId: String) : Destination
    data object WorkoutSummary : Destination
    data object Login : Destination
    data object Register : Destination
}

enum class Tab(val label: String, val icon: String) {
    HOME("ホーム", "🏠"),
    ROUTINES("ルーティン", "📋"),
    PROGRESS("進捗", "📈"),
    SETTINGS("設定", "⚙️"),
}

class Navigation {
    var stack by mutableStateOf<List<Destination>>(listOf(Destination.Tabs))
        private set

    val current: Destination get() = stack.last()

    fun push(destination: Destination) {
        stack = stack + destination
    }

    /** 現在の画面を差し替える。ワークアウト→サマリーのように戻れては困る遷移で使う */
    fun replace(destination: Destination) {
        stack = stack.dropLast(1) + destination
    }

    fun pop() {
        if (stack.size > 1) stack = stack.dropLast(1)
    }

    fun popToRoot() {
        stack = listOf(Destination.Tabs)
    }
}

@Composable
fun AppNavigator(appStore: AppStore, workoutStore: WorkoutStore, authStore: AuthStore?) {
    val palette = LocalPalette.current
    val navigation = remember { Navigation() }
    var selectedTab by remember { mutableStateOf(Tab.HOME) }

    // 初回起動時にプリセット種目と「いつものルーティン」を用意する。
    // これが終わればサインインの有無に関係なくアプリは完全に使える。
    LaunchedEffect(Unit) { appStore.bootstrap() }

    // 認証確認は表示に必須ではないので、UIをブロックせず後追いで走らせる
    LaunchedEffect(authStore) { authStore?.initialize() }

    if (!appStore.loaded) {
        Box(
            modifier = Modifier.fillMaxSize().background(palette.background),
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator(color = palette.primary)
        }
        return
    }

    when (val destination = navigation.current) {
        is Destination.Tabs -> Column(Modifier.fillMaxSize().background(palette.background)) {
            TopAppBar(
                title = { Text(selectedTab.label, color = palette.textPrimary) },
                backgroundColor = palette.surface,
                elevation = 0.dp,
            )

            Box(Modifier.weight(1f)) {
                when (selectedTab) {
                    Tab.HOME -> HomeScreen(appStore, navigation)
                    Tab.ROUTINES -> RoutinesScreen(appStore, navigation)
                    Tab.PROGRESS -> ProgressScreen(appStore)
                    Tab.SETTINGS -> SettingsScreen(appStore, authStore, navigation)
                }
            }

            BottomNavigation(backgroundColor = palette.surface) {
                Tab.values().forEach { tab ->
                    BottomNavigationItem(
                        selected = selectedTab == tab,
                        onClick = {
                            // 他の画面から戻ってきたときに完了状態を即反映させる
                            appStore.refresh()
                            selectedTab = tab
                        },
                        icon = { Text(tab.icon, fontSize = 20.sp) },
                        label = { Text(tab.label, fontSize = 11.sp) },
                        selectedContentColor = palette.primaryLight,
                        unselectedContentColor = palette.textSecondary,
                    )
                }
            }
        }

        is Destination.RoutineForm ->
            RoutineFormScreen(appStore, navigation, routineId = destination.routineId)

        is Destination.Workout ->
            WorkoutScreen(appStore, workoutStore, navigation, routineId = destination.routineId)

        is Destination.WorkoutSummary ->
            WorkoutSummaryScreen(appStore, workoutStore, navigation)

        is Destination.Login -> LoginScreen(authStore, navigation)
        is Destination.Register -> RegisterScreen(authStore, navigation)
    }
}

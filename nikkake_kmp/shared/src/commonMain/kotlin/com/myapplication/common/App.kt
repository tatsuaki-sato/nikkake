package com.myapplication.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import cafe.adriel.voyager.navigator.Navigator
import cafe.adriel.voyager.transitions.SlideTransition
import com.myapplication.common.ui.auth.LoginScreen
import com.myapplication.common.ui.MainScreen
import com.myapplication.common.ui.theme.NikkakeTheme

@Composable
fun App() {
    NikkakeTheme {
        // Simple logic for starting point
        // If auth state needs to be checked, it can happen inside or before Navigator
        Navigator(LoginScreen()) { navigator ->
            SlideTransition(navigator)
        }
    }
}

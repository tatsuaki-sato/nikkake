package com.myapplication.common.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material.MaterialTheme
import androidx.compose.material.darkColors
import androidx.compose.material.lightColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf

val LocalColors = staticCompositionLocalOf { Colors.Light }

@Composable
fun NikkakeTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (darkTheme) Colors.Dark else Colors.Light
    val materialColors = if (darkTheme) {
        darkColors(
            primary = colors.primary,
            primaryVariant = colors.primaryLight,
            secondary = colors.secondary,
            background = colors.background,
            surface = colors.surface,
            error = colors.error,
            onPrimary = colors.textPrimary,
            onSecondary = colors.textPrimary,
            onBackground = colors.textPrimary,
            onSurface = colors.textPrimary,
            onError = colors.textPrimary
        )
    } else {
        lightColors(
            primary = colors.primary,
            primaryVariant = colors.primaryLight,
            secondary = colors.secondary,
            background = colors.background,
            surface = colors.surface,
            error = colors.error,
            onPrimary = colors.background, // or white
            onSecondary = colors.textPrimary,
            onBackground = colors.textPrimary,
            onSurface = colors.textPrimary,
            onError = colors.textPrimary
        )
    }

    CompositionLocalProvider(LocalColors provides colors) {
        MaterialTheme(
            colors = materialColors,
            content = content
        )
    }
}

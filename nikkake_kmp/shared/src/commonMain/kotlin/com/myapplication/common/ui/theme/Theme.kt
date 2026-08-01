package com.myapplication.common.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material.MaterialTheme
import androidx.compose.material.darkColors
import androidx.compose.material.lightColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * 3実装(RN/Flutter/KMP)で同じ見た目にするため、色と余白はここに集約する。
 * 画面側で個別に色を決めない。
 */
data class ColorsPalette(
    val background: Color,
    val surface: Color,
    val surfaceElevated: Color,
    val primary: Color,
    val primaryLight: Color,
    val secondary: Color,
    val secondaryLight: Color,
    val accent: Color,
    val accentLight: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val success: Color,
    val warning: Color,
    val error: Color,
    val border: Color,
)

object Palettes {
    val Dark = ColorsPalette(
        background = Color(0xFF0F0F14),
        surface = Color(0xFF1A1A24),
        surfaceElevated = Color(0xFF24243A),
        primary = Color(0xFF6C5CE7),
        primaryLight = Color(0xFFA29BFE),
        secondary = Color(0xFF00B894),
        secondaryLight = Color(0xFF55EFC4),
        accent = Color(0xFFFDCB6E),
        accentLight = Color(0xFFFFEAA7),
        textPrimary = Color(0xFFF0F0F0),
        textSecondary = Color(0xFFA0A0B0),
        success = Color(0xFF55EFC4),
        warning = Color(0xFFFFEAA7),
        error = Color(0xFFFF8A8A),
        border = Color(0x1AFFFFFF),
    )

    val Light = ColorsPalette(
        background = Color(0xFFFAFAFA),
        surface = Color(0xFFFFFFFF),
        surfaceElevated = Color(0xFFF5F5F5),
        primary = Color(0xFF6C5CE7),
        primaryLight = Color(0xFFA29BFE),
        secondary = Color(0xFF00B894),
        secondaryLight = Color(0xFF55EFC4),
        accent = Color(0xFFFDCB6E),
        accentLight = Color(0xFFFFEAA7),
        textPrimary = Color(0xFF2D3436),
        textSecondary = Color(0xFF636E72),
        success = Color(0xFF00B894),
        warning = Color(0xFFFDCB6E),
        error = Color(0xFFD63031),
        border = Color(0x1A000000),
    )
}

val LocalPalette = staticCompositionLocalOf { Palettes.Dark }

object Spacing {
    val xs = 4.dp
    val sm = 8.dp
    val md = 16.dp
    val lg = 24.dp
    val xl = 32.dp
}

object Radii {
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val pill = 999.dp
}

/** '#RRGGBB' 形式の文字列をColorへ。DBに色をhexで保存しているため */
fun hexToColor(hex: String, fallback: Color = Palettes.Dark.primary): Color {
    val cleaned = hex.removePrefix("#")
    if (cleaned.length != 6) return fallback
    val value = cleaned.toLongOrNull(16) ?: return fallback
    return Color(0xFF000000 or value)
}

@Composable
fun NikkakeTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val palette = if (darkTheme) Palettes.Dark else Palettes.Light

    val materialColors = if (darkTheme) {
        darkColors(
            primary = palette.primary,
            primaryVariant = palette.primaryLight,
            secondary = palette.secondary,
            background = palette.background,
            surface = palette.surface,
            error = palette.error,
            onPrimary = Color.White,
            onBackground = palette.textPrimary,
            onSurface = palette.textPrimary,
        )
    } else {
        lightColors(
            primary = palette.primary,
            primaryVariant = palette.primaryLight,
            secondary = palette.secondary,
            background = palette.background,
            surface = palette.surface,
            error = palette.error,
            onPrimary = Color.White,
            onBackground = palette.textPrimary,
            onSurface = palette.textPrimary,
        )
    }

    CompositionLocalProvider(LocalPalette provides palette) {
        MaterialTheme(colors = materialColors, content = content)
    }
}

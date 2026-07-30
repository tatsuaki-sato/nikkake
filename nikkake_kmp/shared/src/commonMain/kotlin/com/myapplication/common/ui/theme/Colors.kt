package com.myapplication.common.ui.theme

import androidx.compose.ui.graphics.Color

object Colors {
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
        border = Color(0x1AFFFFFF)
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
        border = Color(0x1A000000)
    )
}

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
    val border: Color
)

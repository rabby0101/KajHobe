package com.kajhobe.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Brand/semantic colors that have no direct Material 3 role
 * (mirrors iOS DesignSystem.swift semantic colors + accents).
 */
data class KajHobeExtraColors(
    val success: Color,
    val warning: Color,
    val info: Color,
    val accentOrange: Color,
    val online: Color,
    val offline: Color,
    val cardBackground: Color,
    val subtleBackground: Color,
    val divider: Color,
    val textSecondary: Color,
    val textTertiary: Color,
)

private val LightExtraColors = KajHobeExtraColors(
    success = EmeraldGreen,
    warning = WarmOrange,
    info = PrimaryBlue,
    accentOrange = WarmOrange,
    online = EmeraldGreen,
    offline = NeutralGray400,
    cardBackground = PureWhite,
    subtleBackground = NeutralGray100,
    divider = NeutralGray300,
    textSecondary = NeutralGray600,
    textTertiary = NeutralGray500,
)

private val DarkExtraColors = KajHobeExtraColors(
    success = EmeraldGreen,
    warning = WarmOrange,
    info = PrimaryBlueLight,
    accentOrange = WarmOrange,
    online = EmeraldGreen,
    offline = NeutralGray600,
    cardBackground = NeutralGray900,
    subtleBackground = Color(0xFF161616),
    divider = NeutralGray800,
    textSecondary = NeutralGray400,
    textTertiary = NeutralGray500,
)

val LocalKajHobeColors = staticCompositionLocalOf { LightExtraColors }

private val LightColors = lightColorScheme(
    primary = PrimaryBlue,
    onPrimary = PureWhite,
    primaryContainer = PrimaryBlueLight,
    onPrimaryContainer = PrimaryBlueDark,
    secondary = EmeraldGreen,
    onSecondary = PureWhite,
    tertiary = WarmOrange,
    onTertiary = PureWhite,
    error = CrimsonRed,
    onError = PureWhite,
    background = PureWhite,
    onBackground = NeutralGray900,
    surface = PureWhite,
    onSurface = NeutralGray900,
    surfaceVariant = NeutralGray200,
    onSurfaceVariant = NeutralGray600,
    outline = NeutralGray300,
    outlineVariant = NeutralGray200,
)

private val DarkColors = darkColorScheme(
    primary = PrimaryBlueLight,
    onPrimary = NearBlack,
    primaryContainer = PrimaryBlueDark,
    onPrimaryContainer = PrimaryBlueLight,
    secondary = EmeraldGreen,
    onSecondary = NearBlack,
    tertiary = WarmOrange,
    onTertiary = NearBlack,
    error = CrimsonRed,
    onError = PureWhite,
    background = NearBlack,
    onBackground = NeutralGray100,
    surface = NeutralGray900,
    onSurface = NeutralGray100,
    surfaceVariant = NeutralGray800,
    onSurfaceVariant = NeutralGray400,
    outline = NeutralGray700,
    outlineVariant = NeutralGray800,
)

@Composable
fun KajHobeTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) DarkColors else LightColors
    val extraColors = if (darkTheme) DarkExtraColors else LightExtraColors

    CompositionLocalProvider(
        LocalKajHobeColors provides extraColors,
        LocalSpacing provides Spacing(),
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = kajHobeTypography(LocalAppFontFamily.current),
            shapes = KajHobeShapes,
            content = content,
        )
    }
}

/** Ergonomic accessors: `KajHobeTheme.spacing.md`, `KajHobeTheme.colors.success`. */
object KajHobeTheme {
    val spacing: Spacing
        @Composable @ReadOnlyComposable get() = LocalSpacing.current
    val colors: KajHobeExtraColors
        @Composable @ReadOnlyComposable get() = LocalKajHobeColors.current
}

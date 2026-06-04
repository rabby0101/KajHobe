package com.kajhobe.app.ui.theme

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Spacing scale mirroring iOS DesignSystem.swift Spacing.
 * Material 3 has no spacing scale, so we expose our own via a CompositionLocal.
 */
data class Spacing(
    val xs: Dp = 4.dp,
    val sm: Dp = 8.dp,
    val md: Dp = 16.dp,
    val lg: Dp = 24.dp,
    val xl: Dp = 32.dp,
    val xxl: Dp = 48.dp,
    val xxxl: Dp = 64.dp,
)

val LocalSpacing = staticCompositionLocalOf { Spacing() }

/**
 * Shadow elevation tiers approximating iOS shadow opacities
 * (small 0.1 / medium 0.15 / large 0.2 / extraLarge 0.25).
 * Compose derives blur + opacity from elevation, so we map to dp tiers.
 */
object Elevations {
    val small: Dp = 2.dp
    val medium: Dp = 4.dp
    val large: Dp = 8.dp
    val extraLarge: Dp = 16.dp
}

/** Corner radii mirroring iOS DesignSystem.swift Radius. */
object Radii {
    val xs: Dp = 4.dp
    val sm: Dp = 8.dp
    val md: Dp = 12.dp
    val lg: Dp = 16.dp
    val xl: Dp = 24.dp
    // "pill" is represented by a 50% RoundedCornerShape (see Shape.kt PillShape)
}

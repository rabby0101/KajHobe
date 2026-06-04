package com.kajhobe.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * Active font family. Defaults to the system family; the Bengali ("Kalpurush")
 * family is swapped in via [LocalAppFontFamily] when the active locale is `bn`
 * (wired in the localization phase). Mirrors iOS Typography.bengaliFont fallback.
 */
val LocalAppFontFamily = staticCompositionLocalOf { FontFamily.Default }

/**
 * Builds a Material 3 [Typography] from the iOS DesignSystem.swift type scale.
 *  - display 32 bold / 28 bold / 24 semibold
 *  - headings 22 bold / 20 bold / 18 semibold / 16 semibold
 *  - body 16 / 14 / 12 regular
 *  - labels 14 / 12 / 10 medium
 */
fun kajHobeTypography(fontFamily: FontFamily = FontFamily.Default): Typography {
    fun style(size: Int, weight: FontWeight, lineHeight: Int = (size * 1.3).toInt()) = TextStyle(
        fontFamily = fontFamily,
        fontWeight = weight,
        fontSize = size.sp,
        lineHeight = lineHeight.sp,
    )
    return Typography(
        // Display
        displayLarge = style(32, FontWeight.Bold),
        displayMedium = style(28, FontWeight.Bold),
        displaySmall = style(24, FontWeight.SemiBold),
        // Headings
        headlineLarge = style(22, FontWeight.Bold),
        headlineMedium = style(20, FontWeight.Bold),
        headlineSmall = style(18, FontWeight.SemiBold),
        titleLarge = style(18, FontWeight.SemiBold),
        titleMedium = style(16, FontWeight.SemiBold),
        titleSmall = style(14, FontWeight.SemiBold),
        // Body
        bodyLarge = style(16, FontWeight.Normal),
        bodyMedium = style(14, FontWeight.Normal),
        bodySmall = style(12, FontWeight.Normal),
        // Labels
        labelLarge = style(14, FontWeight.Medium),
        labelMedium = style(12, FontWeight.Medium),
        labelSmall = style(10, FontWeight.Medium),
    )
}

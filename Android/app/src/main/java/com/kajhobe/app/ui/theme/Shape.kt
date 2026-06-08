package com.kajhobe.app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

/** Corner radii mirroring iOS DesignSystem.swift Radius (xs 4 / sm 8 / md 12 / lg 16 / xl 24). */
val KajHobeShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(24.dp),
)

/** iOS Radius.pill (9999) → fully rounded ends. */
val PillShape = RoundedCornerShape(percent = 50)

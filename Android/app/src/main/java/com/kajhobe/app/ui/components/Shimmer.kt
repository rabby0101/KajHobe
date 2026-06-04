package com.kajhobe.app.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape

/**
 * A horizontally-sweeping shimmer brush for skeleton placeholders. Create one per skeleton and
 * share it across all [ShimmerBox]es so they animate in sync. Theme-aware (light/dark) via
 * `surfaceVariant`.
 */
@Composable
fun rememberShimmerBrush(): Brush {
    val base = MaterialTheme.colorScheme.surfaceVariant
    val colors = listOf(base.copy(alpha = 0.7f), base.copy(alpha = 0.25f), base.copy(alpha = 0.7f))

    val transition = rememberInfiniteTransition(label = "shimmer")
    val x by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1400f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1300, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "shimmer-x",
    )
    return Brush.linearGradient(
        colors = colors,
        start = Offset(x - 400f, 0f),
        end = Offset(x, 0f),
    )
}

/** A single shimmering placeholder shape. */
@Composable
fun ShimmerBox(
    modifier: Modifier = Modifier,
    shape: Shape = RectangleShape,
    brush: Brush = rememberShimmerBrush(),
) {
    Box(modifier.clip(shape).background(brush))
}

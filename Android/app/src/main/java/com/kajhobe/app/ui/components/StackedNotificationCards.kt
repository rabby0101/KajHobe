package com.kajhobe.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import com.kajhobe.app.ui.theme.KajHobeTheme

/**
 * 3D stacked-card effect — iOS StackedNotificationCard.
 * Renders [stackCount] subtly offset + scaled background layers behind [content]
 * to convey a deck of notifications. When [stackCount] <= 0, only [content] shows.
 */
@Composable
fun StackedNotificationCards(
    modifier: Modifier = Modifier,
    stackCount: Int = 2,
    content: @Composable () -> Unit,
) {
    Box(modifier = modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        // Background layers, furthest first (larger offset, smaller scale, lighter).
        for (index in stackCount downTo 1) {
            val scale = 1f - index * 0.04f
            val yOffset = (index * 8).dp
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = (index * 6).dp)
                    .height(72.dp)
                    .graphicsLayer {
                        scaleX = scale
                        translationY = yOffset.toPx()
                    }
                    .shadow(2.dp, RoundedCornerShape(16.dp), clip = false)
                    .background(KajHobeTheme.colors.subtleBackground, RoundedCornerShape(16.dp)),
            )
        }
        // Foreground (real) card.
        content()
    }
}

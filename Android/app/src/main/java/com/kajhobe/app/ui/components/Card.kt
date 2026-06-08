package com.kajhobe.app.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.kajhobe.app.ui.theme.Elevations
import com.kajhobe.app.ui.theme.KajHobeTheme

/**
 * Premium elevated card — iOS PremiumCardStyle (16dp radius == Radius.lg, layered shadow).
 * [elevation] maps to the iOS shadow tiers via [Elevations].
 */
@Composable
fun PremiumCard(
    modifier: Modifier = Modifier,
    elevation: Dp = Elevations.medium,
    contentPadding: Dp = KajHobeTheme.spacing.md,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    Surface(
        modifier = modifier.shadow(elevation = elevation, shape = shape, clip = false),
        shape = shape,
        color = KajHobeTheme.colors.cardBackground,
        contentColor = MaterialTheme.colorScheme.onSurface,
    ) {
        Column(modifier = Modifier.padding(contentPadding), content = content)
    }
}

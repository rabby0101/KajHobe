package com.kajhobe.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kajhobe.app.ui.theme.PillShape
import com.kajhobe.app.ui.theme.PureWhite

/**
 * Pill-shaped badge — iOS BadgeStyle (pill radius, semibold caption).
 */
@Composable
fun KajHobeBadge(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary,
    textColor: Color = PureWhite,
) {
    Text(
        text = text,
        color = textColor,
        fontWeight = FontWeight.SemiBold,
        style = MaterialTheme.typography.labelSmall,
        modifier = modifier
            .background(color = color, shape = PillShape)
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

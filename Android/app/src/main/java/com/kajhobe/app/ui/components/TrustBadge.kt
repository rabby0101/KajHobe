package com.kajhobe.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MilitaryTech
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.TrustLevel
import com.kajhobe.app.ui.theme.KajHobeTheme

/**
 * Trust level badge — mirrors iOS `PublicProfileComponents.swift::TrustBadge`.
 *  - unverified (gray), newcomer (blue), established (green),
 *    experienced (orange), expert (purple).
 * [compact] hides the label so the badge fits inline in a card header.
 */
@Composable
fun TrustBadge(
    trustLevel: TrustLevel,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
) {
    val color = colorFor(trustLevel)
    Row(
        modifier = modifier
            .background(color.copy(alpha = 0.1f), RoundedCornerShape(if (compact) 4.dp else 6.dp))
            .padding(horizontal = if (compact) 4.dp else 6.dp, vertical = if (compact) 2.dp else 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Icon(
            imageVector = iconFor(trustLevel),
            contentDescription = null,
            tint = color,
        )
        if (!compact) {
            Text(
                text = trustLevel.displayName,
                style = MaterialTheme.typography.labelSmall,
                color = color,
            )
        }
    }
}

@Composable
private fun colorFor(level: TrustLevel): Color = when (level) {
    TrustLevel.UNVERIFIED -> KajHobeTheme.colors.textSecondary
    TrustLevel.NEWCOMER -> MaterialTheme.colorScheme.primary
    TrustLevel.ESTABLISHED -> KajHobeTheme.colors.success
    TrustLevel.EXPERIENCED -> KajHobeTheme.colors.accentOrange
    TrustLevel.EXPERT -> MaterialTheme.colorScheme.tertiary
}

@Composable
private fun iconFor(level: TrustLevel): ImageVector = when (level) {
    TrustLevel.UNVERIFIED -> Icons.Filled.Star
    TrustLevel.NEWCOMER -> Icons.Filled.Star
    TrustLevel.ESTABLISHED -> Icons.Filled.Verified
    TrustLevel.EXPERIENCED -> Icons.Filled.MilitaryTech
    TrustLevel.EXPERT -> Icons.Filled.WorkspacePremium
}

/**
 * "Verified" badge — granted by manual admin approval (profiles.is_verified_provider).
 * Distinct from the auto-computed [TrustBadge]; shown only for approved providers.
 */
@Composable
fun VerifiedBadge(
    modifier: Modifier = Modifier,
    compact: Boolean = false,
) {
    val color = MaterialTheme.colorScheme.primary
    Row(
        modifier = modifier
            .background(color, RoundedCornerShape(if (compact) 4.dp else 6.dp))
            .padding(horizontal = if (compact) 4.dp else 7.dp, vertical = if (compact) 2.dp else 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Verified,
            contentDescription = null,
            tint = Color.White,
        )
        if (!compact) {
            Text(
                text = "Verified",
                style = MaterialTheme.typography.labelSmall,
                color = Color.White,
            )
        }
    }
}

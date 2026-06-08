package com.kajhobe.app.ui.feature.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.kajhobe.app.ui.components.ShimmerBox
import com.kajhobe.app.ui.components.rememberShimmerBrush
import com.kajhobe.app.ui.theme.KajHobeTheme

/** Shimmer placeholder mirroring the home layout; shown until the first data arrives. */
@Composable
fun HomeSkeleton(modifier: Modifier = Modifier) {
    val brush = rememberShimmerBrush()
    val pill = RoundedCornerShape(50)
    val card = RoundedCornerShape(16.dp)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = KajHobeTheme.spacing.sm),
        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.lg),
    ) {
        // Category chip row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = KajHobeTheme.spacing.md),
            horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
        ) {
            ShimmerBox(Modifier.size(width = 56.dp, height = 40.dp), pill, brush)
            repeat(3) { ShimmerBox(Modifier.size(width = 150.dp, height = 40.dp), pill, brush) }
        }

        // Favorite categories: header + 2x2 grid
        SkeletonHeader(brush, pill)
        Column(
            modifier = Modifier.padding(horizontal = KajHobeTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
        ) {
            repeat(2) {
                Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm)) {
                    ShimmerBox(Modifier.weight(1f).height(104.dp), card, brush)
                    ShimmerBox(Modifier.weight(1f).height(104.dp), card, brush)
                }
            }
        }

        // A carousel section: header + a row of wide cards
        SkeletonHeader(brush, pill)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = KajHobeTheme.spacing.lg),
            horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
        ) {
            repeat(3) { SkeletonJobCard(brush, card) }
        }
    }
}

@Composable
private fun SkeletonHeader(brush: Brush, pill: androidx.compose.ui.graphics.Shape) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = KajHobeTheme.spacing.lg),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.xs)) {
            ShimmerBox(Modifier.size(width = 200.dp, height = 18.dp), pill, brush)
            ShimmerBox(Modifier.size(width = 150.dp, height = 12.dp), pill, brush)
        }
        ShimmerBox(Modifier.size(width = 64.dp, height = 24.dp), pill, brush)
    }
}

@Composable
private fun SkeletonJobCard(brush: Brush, card: androidx.compose.ui.graphics.Shape) {
    Column(
        modifier = Modifier
            .width(280.dp)
            .padding(KajHobeTheme.spacing.md),
        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
    ) {
        ShimmerBox(Modifier.size(width = 180.dp, height = 16.dp), card, brush)
        ShimmerBox(Modifier.fillMaxWidth().height(12.dp), card, brush)
        ShimmerBox(Modifier.fillMaxWidth().height(12.dp), card, brush)
        Spacer(Modifier.height(KajHobeTheme.spacing.xs))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ShimmerBox(Modifier.size(width = 100.dp, height = 12.dp), card, brush)
            ShimmerBox(Modifier.size(width = 60.dp, height = 16.dp), card, brush)
        }
    }
}

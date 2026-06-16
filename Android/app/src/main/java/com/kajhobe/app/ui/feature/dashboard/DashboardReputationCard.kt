package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.components.ProviderReviewCard
import com.kajhobe.app.ui.components.TrustBadge
import com.kajhobe.app.ui.theme.KajHobeTheme

@Composable
fun DashboardReputationCard(
    reviews: List<ProviderReview>,
    averageRating: Double,
    completedJobs: Int,
    onViewAll: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val trustLevel = DashboardAnalytics.trustLevel(completedJobs, averageRating)
    val distribution = DashboardAnalytics.ratingDistribution(reviews)
    val maxCount = (distribution.maxOfOrNull { it.second } ?: 1).coerceAtLeast(1)

    PremiumCard(modifier = modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = Icons.Filled.Star,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.tertiary,
            )
            Spacer(Modifier.width(8.dp))
            Text("Reputation", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            TrustBadge(trustLevel = trustLevel, compact = true)
        }
        Spacer(Modifier.height(12.dp))
        TrustProgressRow(completedJobs = completedJobs, averageRating = averageRating)
        Spacer(Modifier.height(12.dp))
        if (reviews.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Filled.Star,
                        contentDescription = null,
                        tint = KajHobeTheme.colors.textSecondary,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "No reviews yet",
                        style = MaterialTheme.typography.bodySmall,
                        color = KajHobeTheme.colors.textSecondary,
                    )
                }
            }
        } else {
            DistributionBars(distribution = distribution, maxCount = maxCount)
            Spacer(Modifier.height(12.dp))
            Text("Latest reviews", style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.height(8.dp))
            reviews.take(3).forEach { review ->
                ProviderReviewCard(review = review)
                Spacer(Modifier.height(8.dp))
            }
            if (reviews.size > 3 && onViewAll != null) {
                TextButton(onClick = onViewAll, modifier = Modifier.fillMaxWidth()) {
                    Text("View all ${reviews.size} reviews")
                }
            }
        }
    }
}

@Composable
private fun TrustProgressRow(completedJobs: Int, averageRating: Double) {
    val target = DashboardAnalytics.nextTrustLevelTarget(completedJobs, averageRating)
    if (target == null) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Star, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
            Spacer(Modifier.width(4.dp))
            Text(
                "Top tier reached",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.tertiary,
            )
        }
    } else {
        Column {
            LinearProgressIndicator(
                progress = { target.progress.toFloat() },
                modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                color = MaterialTheme.colorScheme.tertiary,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = "${target.jobsNeeded} completed jobs and ${"%.1f".format(target.ratingNeeded)}★ away from ${target.next.displayName}",
                style = MaterialTheme.typography.bodySmall,
                color = KajHobeTheme.colors.textSecondary,
            )
        }
    }
}

@Composable
private fun DistributionBars(distribution: List<Pair<Int, Int>>, maxCount: Int) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        distribution.forEach { (stars, count) ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stars.toString(),
                    style = MaterialTheme.typography.bodySmall,
                    color = KajHobeTheme.colors.textSecondary,
                    modifier = Modifier.width(20.dp),
                )
                Icon(
                    Icons.Filled.Star,
                    contentDescription = null,
                    tint = KajHobeTheme.colors.accentOrange,
                    modifier = Modifier.size(12.dp),
                )
                Spacer(Modifier.width(6.dp))
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(KajHobeTheme.colors.subtleBackground),
                ) {
                    val frac = count.toFloat() / maxCount
                    if (frac > 0f) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(frac)
                                .height(8.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(KajHobeTheme.colors.accentOrange),
                        )
                    }
                }
                Spacer(Modifier.width(6.dp))
                Text(
                    count.toString(),
                    style = MaterialTheme.typography.bodySmall,
                    color = KajHobeTheme.colors.textSecondary,
                    modifier = Modifier.width(20.dp),
                )
            }
        }
    }
}

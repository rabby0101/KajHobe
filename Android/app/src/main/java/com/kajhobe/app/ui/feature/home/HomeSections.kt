package com.kajhobe.app.ui.feature.home

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.HardcodedServiceCategory
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.feature.jobs.JobCard
import com.kajhobe.app.ui.theme.KajHobeTheme

/** Section header: title + subtitle on the left, an optional action (e.g. "View All"/"Edit") right. */
@Composable
fun SectionHeader(
    title: String,
    subtitle: String? = null,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = KajHobeTheme.spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            if (subtitle != null) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.labelMedium,
                    color = KajHobeTheme.colors.textSecondary,
                )
            }
        }
        if (actionLabel != null && onAction != null) {
            Text(
                actionLabel,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable(onClick = onAction),
            )
        }
    }
}

/** "Your Favorite Categories" — 2-column grid of up to 4 tiles with an Edit action. */
@Composable
fun FavoriteCategoriesSection(
    categories: List<HardcodedServiceCategory>,
    jobCountFor: (String) -> Int,
    onEdit: () -> Unit,
    onCategoryClick: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
        SectionHeader(
            title = "Your Favorite Categories",
            subtitle = "Quick access to your preferred services",
            actionLabel = "Edit",
            onAction = onEdit,
        )
        // Fixed 2-column grid (max 4) rendered as rows so it nests inside a vertical scroll.
        Column(
            modifier = Modifier.padding(horizontal = KajHobeTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
        ) {
            categories.chunked(2).forEach { rowCats ->
                Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm)) {
                    rowCats.forEach { category ->
                        CategoryTile(
                            category = category,
                            jobCount = jobCountFor(category.name),
                            onClick = { onCategoryClick(category.name) },
                            modifier = Modifier.weight(1f),
                        )
                    }
                    if (rowCats.size == 1) Spacer(Modifier.weight(1f)) // keep alignment for odd counts
                }
            }
        }
    }
}

@Composable
private fun CategoryTile(
    category: HardcodedServiceCategory,
    jobCount: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    PremiumCard(modifier = modifier.heightIn(min = 104.dp).clickable(onClick = onClick)) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.xs),
        ) {
            Text(category.icon, style = MaterialTheme.typography.headlineSmall)
            Text(
                category.name,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                "$jobCount jobs",
                style = MaterialTheme.typography.labelSmall,
                color = KajHobeTheme.colors.textSecondary,
            )
        }
    }
}

/** Horizontal carousel of job cards under a section header — iOS jobsNearYou/featured/recent. */
@Composable
fun JobCarousel(
    title: String,
    subtitle: String?,
    jobs: List<Job>,
    cardWidth: Dp,
    isNew: (Job) -> Boolean,
    onViewAll: () -> Unit,
    onJobClick: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
        SectionHeader(title = title, subtitle = subtitle, actionLabel = "View All", onAction = onViewAll)
        LazyRow(
            contentPadding = PaddingValues(horizontal = KajHobeTheme.spacing.lg),
            horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
        ) {
            items(jobs, key = { it.id }) { job ->
                JobCard(
                    job = job,
                    onClick = { onJobClick(job.id) },
                    isNew = isNew(job),
                    modifier = Modifier.width(cardWidth),
                )
            }
        }
    }
}

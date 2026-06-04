package com.kajhobe.app.ui.feature.jobs

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.HardcodedServiceCategory
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.ui.components.KajHobeBadge
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.theme.KajHobeTheme

/** Job summary card — iOS JobCardView. */
@Composable
fun JobCard(
    job: Job,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isNew: Boolean = false,
) {
    val categoryIcon = HardcodedServiceCategory.byName(job.category)?.icon ?: "🔧"

    PremiumCard(modifier = modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(categoryIcon, style = MaterialTheme.typography.headlineSmall)
            Spacer(Modifier.width(KajHobeTheme.spacing.sm))
            Text(
                text = job.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            if (isNew) {
                KajHobeBadge(text = "New", color = MaterialTheme.colorScheme.primary)
                if (job.urgent == true) Spacer(Modifier.width(KajHobeTheme.spacing.xs))
            }
            if (job.urgent == true) {
                KajHobeBadge(text = "Urgent", color = MaterialTheme.colorScheme.error)
            }
        }

        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
        Text(
            text = job.description,
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )

        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.LocationOn,
                    contentDescription = null,
                    tint = KajHobeTheme.colors.textTertiary,
                    modifier = Modifier.height(16.dp),
                )
                Text(
                    text = job.location,
                    style = MaterialTheme.typography.labelMedium,
                    color = KajHobeTheme.colors.textTertiary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = "৳${job.budget}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

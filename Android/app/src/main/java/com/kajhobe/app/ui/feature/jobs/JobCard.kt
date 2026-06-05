package com.kajhobe.app.ui.feature.jobs

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.data.model.timeAgo
import com.kajhobe.app.ui.components.CompactMediaPreview
import com.kajhobe.app.ui.components.KajHobeBadge
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.theme.KajHobeTheme
import com.kajhobe.app.ui.theme.PillShape

/** Status pill shown in the card footer — mirrors iOS JobCardView.JobStatus + "Your Job". */
enum class JobCardStatus(val label: String) {
    NEW("New"),
    VIEWED("Viewed"),
    INTERESTED("Interested"),
    OWN("Your Job"),
}

@Composable
private fun JobCardStatus.color(): Color = when (this) {
    JobCardStatus.NEW -> MaterialTheme.colorScheme.primary
    JobCardStatus.VIEWED -> KajHobeTheme.colors.warning
    JobCardStatus.INTERESTED -> KajHobeTheme.colors.success
    JobCardStatus.OWN -> MaterialTheme.colorScheme.primary
}

/** Accent color per category — mirrors iOS JobCardView.accentColor. */
private fun categoryAccent(category: String): Color {
    val c = category.lowercase()
    return when {
        c.contains("technology") || c.contains("it") -> Color(0xFFAF52DE) // purple
        c.contains("home") || c.contains("repair") -> Color(0xFF007AFF) // blue
        c.contains("education") || c.contains("tutoring") -> Color(0xFF34C759) // green
        c.contains("design") || c.contains("creative") -> Color(0xFFFF9F0A) // orange
        else -> Color(0xFF32ADE6) // cyan
    }
}

/** Job summary card — iOS JobCardView (category, attachment, title, desc, amount/location, posted, status). */
@Composable
fun JobCard(
    job: Job,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    status: JobCardStatus = JobCardStatus.NEW,
) {
    val accent = categoryAccent(job.category)

    PremiumCard(modifier = modifier.fillMaxWidth().clickable(onClick = onClick)) {
        // 1. Header: category pill (left) + urgent badge (right)
        Row(verticalAlignment = Alignment.CenterVertically) {
            KajHobeBadge(
                text = job.category,
                color = accent.copy(alpha = 0.15f),
                textColor = accent,
            )
            Spacer(Modifier.weight(1f))
            if (job.urgent == true) {
                KajHobeBadge(text = "Urgent", color = MaterialTheme.colorScheme.error)
            }
        }

        // 2. Attachment thumbnails (if any)
        if (!job.media_urls.isNullOrEmpty()) {
            Spacer(Modifier.height(KajHobeTheme.spacing.md))
            CompactMediaPreview(job.media_urls!!)
        }

        // 3. Title
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Text(
            text = job.title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )

        // 4. Description
        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
        Text(
            text = job.description,
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
        )

        // 5. Amount (left) + Location (right)
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.Payments,
                    contentDescription = null,
                    tint = accent,
                    modifier = Modifier.height(16.dp),
                )
                Spacer(Modifier.width(KajHobeTheme.spacing.xs))
                Text(
                    text = "৳${job.budget}",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
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
        }

        // 6. Divider
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        HorizontalDivider(color = KajHobeTheme.colors.divider)

        // 7. Footer: posted time (left) + status pill (right)
        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Posted ${timeAgo(job.created_at)}",
                style = MaterialTheme.typography.labelMedium,
                color = KajHobeTheme.colors.textTertiary,
            )
            StatusPill(status)
        }
    }
}

/** Tinted status pill with a leading dot — mirrors iOS JobCardView.footerSection. */
@Composable
private fun StatusPill(status: JobCardStatus) {
    val color = status.color()
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.xs),
        modifier = Modifier
            .background(color = color.copy(alpha = 0.12f), shape = PillShape)
            .padding(horizontal = 10.dp, vertical = 5.dp),
    ) {
        Box(modifier = Modifier.size(6.dp).background(color, CircleShape))
        Text(
            text = status.label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = color,
        )
    }
}

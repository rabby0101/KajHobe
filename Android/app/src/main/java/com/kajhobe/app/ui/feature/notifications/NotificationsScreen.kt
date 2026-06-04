package com.kajhobe.app.ui.feature.notifications

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.EnrichedJobInterest
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.components.PrimaryButton
import com.kajhobe.app.ui.components.SecondaryButton
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel

@Composable
fun NotificationsScreen(viewModel: NotificationsViewModel = koinViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // Silently refresh whenever this tab becomes visible again, so navigating away and back
    // picks up new interest requests / notifications without a loading flash.
    LifecycleResumeEffect(Unit) {
        viewModel.load(silent = true)
        onPauseOrDispose { }
    }

    if (state.isLoading) {
        PremiumLoadingView(message = "Loading notifications…")
        return
    }

    if (state.interests.isEmpty() && state.notifications.isEmpty()) {
        Column(
            modifier = Modifier.fillMaxSize().padding(KajHobeTheme.spacing.xl),
            horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text("🔔", style = MaterialTheme.typography.displaySmall)
            Text(
                "You're all caught up",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(top = KajHobeTheme.spacing.sm),
            )
            Text(
                "Interest requests on your jobs will appear here.",
                style = MaterialTheme.typography.bodyMedium,
                color = KajHobeTheme.colors.textSecondary,
            )
        }
        return
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(KajHobeTheme.spacing.md),
        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
    ) {
        item {
            Text(
                "Notifications",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(vertical = KajHobeTheme.spacing.sm),
            )
        }

        if (state.interests.isNotEmpty()) {
            item {
                Text(
                    "Interest requests",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            items(state.interests, key = { it.id }) { interest ->
                InterestCard(
                    interest = interest,
                    isProcessing = interest.id in state.processingIds,
                    onAccept = { viewModel.respond(interest, accept = true) },
                    onReject = { viewModel.respond(interest, accept = false) },
                )
            }
        }

        if (state.notifications.isNotEmpty()) {
            item {
                Text(
                    "Activity",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = KajHobeTheme.spacing.sm),
                )
            }
            items(state.notifications, key = { it.id }) { n ->
                PremiumCard(modifier = Modifier.fillMaxWidth()) {
                    Text(n.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                    if (n.message.isNotBlank()) {
                        Text(
                            n.message,
                            style = MaterialTheme.typography.bodyMedium,
                            color = KajHobeTheme.colors.textSecondary,
                        )
                    }
                    Text(
                        n.timeAgoText,
                        style = MaterialTheme.typography.labelSmall,
                        color = KajHobeTheme.colors.textTertiary,
                    )
                }
            }
        }
    }
}

@Composable
private fun InterestCard(
    interest: EnrichedJobInterest,
    isProcessing: Boolean,
    onAccept: () -> Unit,
    onReject: () -> Unit,
) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Text(
            interest.provider_name ?: "A provider",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            "is interested in: ${interest.job_title}",
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
        )
        interest.job_budget?.let {
            Text(
                "Budget: ৳$it",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(top = KajHobeTheme.spacing.xs),
            )
        }
        if (!interest.message.isNullOrBlank()) {
            Text(
                "\"${interest.message}\"",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = KajHobeTheme.spacing.xs),
            )
        }

        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm)) {
            PrimaryButton(
                text = if (isProcessing) "…" else "Accept",
                onClick = onAccept,
                enabled = !isProcessing,
                fillWidth = false,
                modifier = Modifier.weight(1f),
            )
            SecondaryButton(
                text = "Decline",
                onClick = onReject,
                enabled = !isProcessing,
                fillWidth = false,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

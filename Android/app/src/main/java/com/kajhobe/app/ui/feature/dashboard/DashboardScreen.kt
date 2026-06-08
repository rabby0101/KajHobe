package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.components.TertiaryButton
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel

@Composable
fun DashboardScreen(
    onSignOut: () -> Unit,
    onDealClick: (String) -> Unit,
    viewModel: DashboardViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // Silently refresh whenever this tab becomes visible again, so stats/deals stay current
    // after navigating away and back — without a loading flash.
    LifecycleResumeEffect(Unit) {
        viewModel.load(silent = true)
        onPauseOrDispose { }
    }

    if (state.isLoading) {
        PremiumLoadingView(message = "Loading dashboard…")
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(KajHobeTheme.spacing.lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Dashboard", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            TertiaryButton(text = "Sign out", onClick = onSignOut)
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.md))

        val data = state.data
        if (data != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
                StatCard("Active deals", data.active_deals_count.toString(), Modifier.weight(1f))
                StatCard("Completed", data.completed_deals_count.toString(), Modifier.weight(1f))
            }
            Spacer(Modifier.height(KajHobeTheme.spacing.md))
            Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
                StatCard("Earned", "৳${data.total_earnings.toInt()}", Modifier.weight(1f))
                StatCard("Spent", "৳${data.total_spent.toInt()}", Modifier.weight(1f))
            }
            // Note: completion-approval moved to Notifications → Deal Details; the
            // pending_completion_requests count is no longer surfaced on the dashboard
            // (iOS parity — see iOS commit f649a808). The field is kept on DashboardData
            // for JSON compatibility.
        }

        Spacer(Modifier.height(KajHobeTheme.spacing.lg))
        Text("Active deals", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(KajHobeTheme.spacing.sm))

        if (state.activeDeals.isEmpty()) {
            Text(
                "No active deals yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = KajHobeTheme.colors.textSecondary,
            )
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
                state.activeDeals.forEach { deal -> DealRow(deal, onClick = { onDealClick(deal.id) }) }
            }
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.xl))
    }
}

@Composable
private fun StatCard(label: String, value: String, modifier: Modifier = Modifier) {
    PremiumCard(modifier = modifier) {
        Text(value, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
        Text(label, style = MaterialTheme.typography.labelMedium, color = KajHobeTheme.colors.textSecondary)
    }
}

@Composable
private fun DealRow(deal: Deal, onClick: () -> Unit) {
    PremiumCard(modifier = Modifier.fillMaxWidth().clickable { onClick() }) {
        Text(
            deal.job?.title ?: "Deal",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.xs))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(
                deal.completion_status ?: deal.status,
                style = MaterialTheme.typography.labelMedium,
                color = KajHobeTheme.colors.textSecondary,
            )
            Text(
                "৳${deal.agreed_amount}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

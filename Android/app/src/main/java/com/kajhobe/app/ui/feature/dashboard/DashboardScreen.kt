package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Note
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.DashboardDeal
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.components.PrimaryButton
import com.kajhobe.app.ui.components.SecondaryButton
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    onMyProfile: () -> Unit,
    onNotificationSettings: () -> Unit,
    onOpenJobs: () -> Unit,
    onPostJob: () -> Unit,
    onDealClick: (String) -> Unit,
    viewModel: DashboardViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }

    LifecycleResumeEffect(Unit) {
        viewModel.loadFromCacheThenNetwork()
        onPauseOrDispose { }
    }

    LaunchedEffect(Unit) { viewModel.subscribeRealtime() }
    LaunchedEffect(Unit) { viewModel.startAutoRefresh() }
    DisposableEffect(Unit) {
        onDispose {
            viewModel.unsubscribeRealtime()
            viewModel.stopAutoRefresh()
        }
    }

    LaunchedEffect(state.errorMessage) {
        state.errorMessage?.let { snackbarHost.showSnackbar(it) }
    }

    var dealsFilter by remember { mutableStateOf<DealsFilter?>(null) }
    var showingReviews by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Dashboard") },
                navigationIcon = {
                    IconButton(onClick = onNotificationSettings) {
                        Icon(
                            Icons.Filled.Notifications,
                            contentDescription = "Notification settings",
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onMyProfile) {
                        Icon(
                            Icons.Filled.AccountCircle,
                            contentDescription = "My profile",
                        )
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        },
        snackbarHost = { SnackbarHost(snackbarHost) },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            if (state.isLoading) {
                PremiumLoadingView(message = "Loading dashboard…")
            } else {
                DashboardContent(
                    state = state,
                    onStatCardTap = { filter -> dealsFilter = filter },
                    onRatingCardTap = { showingReviews = true },
                    onDealClick = onDealClick,
                    onOpenJobs = onOpenJobs,
                    onPostJob = onPostJob,
                )
            }
        }
    }

    dealsFilter?.let { filter ->
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { dealsFilter = null },
            sheetState = sheetState,
        ) {
            DealsListView(
                deals = state.myDeals,
                initialFilter = filter,
                onClose = { dealsFilter = null },
                onDealClick = { deal ->
                    dealsFilter = null
                    onDealClick(deal.id)
                },
            )
        }
    }
    if (showingReviews) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { showingReviews = false },
            sheetState = sheetState,
        ) {
            ReviewsListView(
                reviews = state.myReviews,
                onClose = { showingReviews = false },
            )
        }
    }
}

@Composable
private fun DashboardContent(
    state: DashboardUiState,
    onStatCardTap: (DealsFilter) -> Unit,
    onRatingCardTap: () -> Unit,
    onDealClick: (String) -> Unit,
    onOpenJobs: () -> Unit,
    onPostJob: () -> Unit,
) {
    val data = state.data
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = KajHobeTheme.spacing.lg),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(vertical = KajHobeTheme.spacing.md),
    ) {
        item {
            if (state.hasRealtimeUpdate) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            } else {
                Spacer(Modifier.height(2.dp))
            }
        }
        item {
            if (data != null) {
                StatsSection(
                    data = data,
                    onStatCardTap = onStatCardTap,
                    onRatingCardTap = onRatingCardTap,
                )
            } else {
                EmptyStatsSection(
                    onOpenJobs = onOpenJobs,
                    onPostJob = onPostJob,
                )
            }
        }
        if (data != null && (state.myDeals.isNotEmpty() || state.myReviews.isNotEmpty())) {
            item {
                DashboardChartsSection(
                    deals = state.myDeals,
                    reviews = state.myReviews,
                    userId = state.currentUserId,
                )
            }
            item {
                DashboardReputationCard(
                    reviews = state.myReviews,
                    averageRating = data.average_rating,
                    completedJobs = data.completed_deals_count,
                    onViewAll = onRatingCardTap,
                )
            }
        }
        if (state.activeDeals.isNotEmpty()) {
            item {
                ActiveDealsSection(deals = state.activeDeals, onDealClick = onDealClick)
            }
        }
        if (data?.recent_deals?.isNotEmpty() == true) {
            item {
                RecentActivitySection(
                    recent = data.recent_deals,
                    allDeals = state.myDeals,
                    onDealClick = onDealClick,
                )
            }
        }
    }
}

@Composable
private fun StatsSection(
    data: DashboardData,
    onStatCardTap: (DealsFilter) -> Unit,
    onRatingCardTap: () -> Unit,
) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.BarChart, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(8.dp))
            Text("Overview", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            StatCard(
                title = "Active deals",
                value = data.active_deals_count.toString(),
                icon = Icons.Filled.Work,
                color = MaterialTheme.colorScheme.primary,
                onTap = { onStatCardTap(DealsFilter.Active) },
                modifier = Modifier.weight(1f),
            )
            StatCard(
                title = "Completed",
                value = data.completed_deals_count.toString(),
                icon = Icons.Filled.CheckCircle,
                color = KajHobeTheme.colors.success,
                onTap = { onStatCardTap(DealsFilter.Completed) },
                modifier = Modifier.weight(1f),
            )
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            val isProvider = data.user_type == "provider"
            val amount = if (isProvider) data.total_earnings else data.total_spent
            StatCard(
                title = if (isProvider) "Total Earned" else "Total Spent",
                value = "৳${amount.toInt()}",
                icon = Icons.AutoMirrored.Filled.Note,
                color = KajHobeTheme.colors.accentOrange,
                onTap = { onStatCardTap(DealsFilter.Completed) },
                modifier = Modifier.weight(1f),
            )
            StatCard(
                title = "Rating",
                value = "%.1f".format(data.average_rating),
                icon = Icons.Filled.Star,
                color = KajHobeTheme.colors.accentOrange,
                onTap = onRatingCardTap,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun EmptyStatsSection(onOpenJobs: () -> Unit, onPostJob: () -> Unit) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.BarChart, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(8.dp))
            Text("Overview", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            StatCard("Active deals", "0", Icons.Filled.Work, MaterialTheme.colorScheme.primary, modifier = Modifier.weight(1f))
            StatCard("Completed", "0", Icons.Filled.CheckCircle, KajHobeTheme.colors.success, modifier = Modifier.weight(1f))
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            StatCard("Total Earned", "৳0", Icons.AutoMirrored.Filled.Note, KajHobeTheme.colors.accentOrange, modifier = Modifier.weight(1f))
            StatCard("Rating", "4.5", Icons.Filled.Star, KajHobeTheme.colors.accentOrange, modifier = Modifier.weight(1f))
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Text(
            "Get started with your first job",
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
        )
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            PrimaryButton(text = "Browse Available Jobs", onClick = onOpenJobs, modifier = Modifier.weight(1f))
            SecondaryButton(text = "Post a Job", onClick = onPostJob, modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun StatCard(
    title: String,
    value: String,
    icon: ImageVector,
    color: Color,
    onTap: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val baseModifier = if (onTap != null) modifier.clickable { onTap() } else modifier
    Box(
        modifier = baseModifier
            .clip(RoundedCornerShape(8.dp))
            .background(KajHobeTheme.colors.subtleBackground)
            .padding(10.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
                Spacer(Modifier.weight(1f))
            }
            Spacer(Modifier.height(4.dp))
            Text(value, style = MaterialTheme.typography.titleLarge)
            Text(
                title,
                style = MaterialTheme.typography.labelSmall,
                color = KajHobeTheme.colors.textSecondary,
            )
        }
    }
}

@Composable
private fun ActiveDealsSection(deals: List<Deal>, onDealClick: (String) -> Unit) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Work, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(8.dp))
            Text("Active deals", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(12.dp))
        deals.forEach { deal ->
            ActiveDealRow(deal = deal, onTap = { onDealClick(deal.id) })
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun ActiveDealRow(deal: Deal, onTap: () -> Unit) {
    val status = deal.completion_status ?: "in_progress"
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(KajHobeTheme.colors.subtleBackground)
            .clickable { onTap() }
            .padding(12.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    deal.job?.title ?: "Unknown Job",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "৳${deal.agreed_amount}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = KajHobeTheme.colors.success,
                )
            }
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                val otherName = deal.client_profile?.full_name
                    ?: deal.provider_profile?.full_name
                    ?: "Unknown"
                Text(
                    "with $otherName",
                    style = MaterialTheme.typography.labelSmall,
                    color = KajHobeTheme.colors.textSecondary,
                    modifier = Modifier.weight(1f),
                )
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(statusColor(status)),
                )
                Spacer(Modifier.size(4.dp))
                Text(
                    status.replace("_", " ").replaceFirstChar { it.titlecase(Locale.US) },
                    style = MaterialTheme.typography.labelSmall,
                    color = KajHobeTheme.colors.textSecondary,
                )
                Spacer(Modifier.size(4.dp))
                Icon(
                    Icons.Filled.ChevronRight,
                    contentDescription = null,
                    tint = KajHobeTheme.colors.textSecondary,
                    modifier = Modifier.size(14.dp),
                )
            }
            Spacer(Modifier.height(8.dp))
            HairlineDivider()
        }
    }
}

@Composable
private fun RecentActivitySection(
    recent: List<DashboardDeal>,
    @Suppress("UNUSED_PARAMETER") allDeals: List<Deal>,
    onDealClick: (String) -> Unit,
) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.BarChart, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
            Spacer(Modifier.width(8.dp))
            Text("Recent activity", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(12.dp))
        recent.forEach { r ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(KajHobeTheme.colors.subtleBackground)
                    .clickable { onDealClick(r.id) }
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(r.job_title, style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "with ${r.other_party_name ?: "Unknown"}",
                        style = MaterialTheme.typography.labelSmall,
                        color = KajHobeTheme.colors.textSecondary,
                    )
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        "৳${r.agreed_amount}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = KajHobeTheme.colors.success,
                    )
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .clip(CircleShape)
                                .background(statusColor(r.completion_status)),
                        )
                        Spacer(Modifier.size(4.dp))
                        Text(
                            r.completion_status.replace("_", " ")
                                .replaceFirstChar { it.titlecase(Locale.US) },
                            style = MaterialTheme.typography.labelSmall,
                            color = KajHobeTheme.colors.textSecondary,
                        )
                    }
                }
            }
            HairlineDivider()
        }
    }
}

@Composable
private fun HairlineDivider() {
    androidx.compose.material3.HorizontalDivider(
        modifier = Modifier.padding(vertical = 8.dp),
        color = KajHobeTheme.colors.divider,
    )
}

@Composable
private fun statusColor(status: String): Color = when (status.lowercase()) {
    "completed" -> KajHobeTheme.colors.success
    "in_progress" -> MaterialTheme.colorScheme.primary
    "pending_approval" -> KajHobeTheme.colors.accentOrange
    "disputed" -> MaterialTheme.colorScheme.error
    else -> KajHobeTheme.colors.textSecondary
}

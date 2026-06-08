package com.kajhobe.app.ui.feature.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Work
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.PublicProfile
import com.kajhobe.app.data.model.ServiceHighlight
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PublicProfileScreen(
    userId: String,
    onBack: () -> Unit,
    viewModel: PublicProfileViewModel = koinViewModel(parameters = { parametersOf(userId) }),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    LaunchedEffect(userId) { viewModel.load(userId) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Profile",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                        )
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            state.isLoading -> LoadingView(modifier = Modifier.padding(innerPadding))
            state.profile != null -> ProfileDetail(
                profile = state.profile!!,
                highlights = state.serviceHighlights,
                reviews = state.reviews,
                modifier = Modifier.padding(innerPadding),
            )
            else -> ErrorView(
                message = state.errorMessage ?: "Profile not available",
                onRetry = viewModel::retry,
                modifier = Modifier.padding(innerPadding),
            )
        }
    }
}

@Composable
private fun ProfileDetail(
    profile: PublicProfile,
    highlights: List<ServiceHighlight>,
    reviews: List<ProviderReview>,
    modifier: Modifier = Modifier,
) {
    var selectedTab by rememberSaveable { mutableStateOf(ProviderProfileTab.ABOUT) }
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        item { ProfileHero(profile = profile) }
        item { StatCardsRow(profile = profile) }
        item {
            ProfileTabStrip(
                selected = selectedTab,
                onSelected = { selectedTab = it },
            )
        }
        item {
            when (selectedTab) {
                ProviderProfileTab.ABOUT -> AboutTab(profile = profile)
                ProviderProfileTab.AVAILABILITY -> AvailabilityTab(profile = profile)
                ProviderProfileTab.EXPERIENCE -> ExperienceTab(
                    profile = profile,
                    highlights = highlights,
                )
                ProviderProfileTab.REVIEWS -> ReviewsTab(reviews = reviews)
            }
        }
        val hourly = profile.formattedHourlyRate
        val team = profile.formattedTeamRate
        if (hourly != null || team != null) {
            item {
                androidx.compose.foundation.layout.Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    if (hourly != null) {
                        PricingCard(
                            icon = Icons.Outlined.Payments,
                            title = "Hourly Fee",
                            value = hourly,
                            caption = null,
                            modifier = Modifier.weight(1f),
                        )
                    }
                    if (team != null) {
                        PricingCard(
                            icon = Icons.Filled.Group,
                            title = "Team Work",
                            value = team,
                            caption = profile.team_hours_label,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
        item { Spacer(Modifier.height(40.dp)) }
    }
}

@Composable
private fun LoadingView(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator()
        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
        Text(
            text = "Loading profile\u2026",
            color = KajHobeTheme.colors.textSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun ErrorView(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(KajHobeTheme.spacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Filled.Work,
            contentDescription = null,
            tint = KajHobeTheme.colors.textSecondary,
            modifier = Modifier.size(56.dp),
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Text(
            text = "Profile not available",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.xs))
        Text(
            text = message,
            color = KajHobeTheme.colors.textSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        OutlinedButton(onClick = onRetry) { Text(text = "Try again") }
    }
}

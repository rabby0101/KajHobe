package com.kajhobe.app.ui.feature.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.kajhobe.app.data.model.PublicProfile
import com.kajhobe.app.data.model.TrustLevel
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/**
 * Tap-to-profile destination for the in-app interest notification flow.
 * Mirrors iOS `PublicProfileView.swift`.
 */
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
                title = { Text("Profile", maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(),
            )
        },
    ) { innerPadding ->
        when {
            state.isLoading -> LoadingView(modifier = Modifier.padding(innerPadding))
            state.profile != null -> ProfileBody(
                profile = state.profile!!,
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
private fun LoadingView(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator()
        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
        Text(
            "Loading profile…",
            color = KajHobeTheme.colors.textSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun ErrorView(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(KajHobeTheme.spacing.lg),
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
            "Profile not available",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.xs))
        Text(
            message,
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        OutlinedButton(onClick = onRetry) { Text("Try again") }
    }
}

@Composable
private fun ProfileBody(profile: PublicProfile, modifier: Modifier = Modifier) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            horizontal = KajHobeTheme.spacing.md,
            vertical = KajHobeTheme.spacing.md,
        ),
        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
    ) {
        item { ProfileHeader(profile = profile) }
        item { StatsRow(profile = profile) }
        if (profile.service_categories.isNotEmpty()) {
            item { CategoriesRow(profile = profile) }
        }
        if (!profile.bio.isNullOrBlank()) {
            item { BioCard(profile = profile) }
        }
        item { DetailsCard(profile = profile) }
        item { Spacer(Modifier.height(KajHobeTheme.spacing.lg)) }
    }
}

@Composable
private fun ProfileHeader(profile: PublicProfile) {
    val context = LocalContext.current
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(112.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            val avatarUrl = profile.avatar_url
            if (!avatarUrl.isNullOrBlank()) {
                AsyncImage(
                    model = avatarUrl,
                    contentDescription = profile.full_name,
                    modifier = Modifier.fillMaxSize().clip(CircleShape),
                )
            } else {
                Text(
                    (profile.full_name ?: "?").take(1).uppercase(),
                    style = MaterialTheme.typography.displaySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Text(
            profile.full_name ?: "User",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.xs))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
        ) {
            if (profile.is_service_provider == true) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = KajHobeTheme.colors.success,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        "Service provider",
                        style = MaterialTheme.typography.labelMedium,
                        color = KajHobeTheme.colors.success,
                    )
                }
            }
            if (profile.isOnline) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier.size(8.dp).clip(CircleShape)
                            .background(KajHobeTheme.colors.online),
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        "Online",
                        style = MaterialTheme.typography.labelMedium,
                        color = KajHobeTheme.colors.online,
                    )
                }
            } else if (!profile.last_seen_at.isNullOrBlank()) {
                Text(
                    "Last seen ${profile.formattedLastSeen}",
                    style = MaterialTheme.typography.labelMedium,
                    color = KajHobeTheme.colors.textSecondary,
                )
            }
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
        TrustBadge(profile.trustLevelEnum)
    }
}

@Composable
private fun TrustBadge(level: TrustLevel) {
    val (bg, fg) = when (level) {
        TrustLevel.UNVERIFIED -> KajHobeTheme.colors.textTertiary.copy(alpha = 0.15f) to KajHobeTheme.colors.textSecondary
        TrustLevel.NEWCOMER -> Color(0xFF1E88E5).copy(alpha = 0.15f) to Color(0xFF1E88E5)
        TrustLevel.ESTABLISHED -> KajHobeTheme.colors.success.copy(alpha = 0.15f) to KajHobeTheme.colors.success
        TrustLevel.EXPERIENCED -> KajHobeTheme.colors.warning.copy(alpha = 0.15f) to KajHobeTheme.colors.warning
        TrustLevel.EXPERT -> Color(0xFF8E24AA).copy(alpha = 0.15f) to Color(0xFF8E24AA)
    }
    Text(
        level.displayName,
        color = fg,
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(CircleShape)
            .background(bg)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
private fun StatsRow(profile: PublicProfile) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(vertical = KajHobeTheme.spacing.md),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        StatCell(
            icon = { Icon(Icons.Filled.Work, contentDescription = null, tint = KajHobeTheme.colors.info) },
            value = profile.completed_jobs.toString(),
            label = if (profile.completed_jobs == 1) "Job done" else "Jobs done",
        )
        StatCell(
            icon = { Icon(Icons.Filled.Star, contentDescription = null, tint = KajHobeTheme.colors.warning) },
            value = if (profile.avg_rating > 0) String.format("%.1f", profile.avg_rating) else "—",
            label = if (profile.review_count == 1) "1 review" else "${profile.review_count} reviews",
        )
        StatCell(
            icon = { Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = KajHobeTheme.colors.success) },
            value = profile.formattedEarnings,
            label = "Total earned",
        )
    }
}

@Composable
private fun StatCell(icon: @Composable () -> Unit, value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        icon()
        Spacer(Modifier.height(4.dp))
        Text(
            value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = KajHobeTheme.colors.textSecondary,
        )
    }
}

@Composable
private fun CategoriesRow(profile: PublicProfile) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            "Service categories",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm)) {
            items(profile.service_categories) { category ->
                CategoryChip(label = category)
            }
        }
    }
}

@Composable
private fun CategoryChip(label: String) {
    Text(
        label,
        color = MaterialTheme.colorScheme.onPrimaryContainer,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primaryContainer)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

@Composable
private fun BioCard(profile: PublicProfile) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(KajHobeTheme.spacing.md),
    ) {
        Text(
            "About",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.xs))
        Text(
            profile.bio.orEmpty(),
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun DetailsCard(profile: PublicProfile) {
    val hasAny = !profile.location.isNullOrBlank() ||
        !profile.website.isNullOrBlank() ||
        profile.average_response_time_minutes != null
    if (!hasAny) return
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(KajHobeTheme.spacing.md),
        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
    ) {
        if (!profile.location.isNullOrBlank()) {
            DetailRow(icon = Icons.Filled.LocationOn, text = profile.location!!)
        }
        if (!profile.website.isNullOrBlank()) {
            DetailRow(icon = Icons.Filled.Language, text = profile.website!!)
        }
        val respMin = profile.average_response_time_minutes
        if (respMin != null) {
            DetailRow(icon = Icons.Filled.Work, text = profile.responseTimeTextValue)
        }
    }
}

@Composable
private fun DetailRow(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            icon,
            contentDescription = null,
            tint = KajHobeTheme.colors.textSecondary,
            modifier = Modifier.size(18.dp),
        )
        Spacer(Modifier.width(KajHobeTheme.spacing.sm))
        Text(
            text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

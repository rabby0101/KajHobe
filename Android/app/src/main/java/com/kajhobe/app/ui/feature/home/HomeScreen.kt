package com.kajhobe.app.ui.feature.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.kajhobe.app.R
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.HardcodedServiceCategory
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel

/** Kinds of "View All" / vertical job lists reachable from the home sections. */
enum class JobListKind(val slug: String) {
    NEAR_YOU("near_you"),
    FEATURED("featured"),
    RECENT("recent");

    companion object {
        fun fromSlug(slug: String?): JobListKind? = entries.firstOrNull { it.slug == slug }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onJobClick: (String) -> Unit,
    onViewAll: (JobListKind) -> Unit,
    onCategoryClick: (String) -> Unit,
    onOpenSearch: () -> Unit,
    viewModel: HomeViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showFavoritesSheet by remember { mutableStateOf(false) }

    // Silent refresh on every tab-resume (no skeleton/spinner once we have data).
    LifecycleResumeEffect(Unit) {
        viewModel.load(com.kajhobe.app.ui.feature.jobs.LoadMode.SILENT)
        onPauseOrDispose { }
    }

    if (showFavoritesSheet) {
        FavoriteCategoriesSheet(
            currentFavorites = state.favoriteCategoryNames,
            onDismiss = { showFavoritesSheet = false },
            onSave = {
                viewModel.saveFavoriteCategories(it)
                showFavoritesSheet = false
            },
        )
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // Top bar: wordmark + search
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = KajHobeTheme.spacing.lg, vertical = KajHobeTheme.spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Image(
                painter = painterResource(R.drawable.app_logo),
                contentDescription = "KajHobe",
                modifier = Modifier.height(34.dp),
            )
            Spacer(modifier = Modifier.weight(1f))
            IconButton(onClick = onOpenSearch) {
                Icon(Icons.Filled.Search, contentDescription = "Search")
            }
        }

        // Sticky category chips row
        CategoryChipsRow(onCategoryClick = onCategoryClick)

        when {
            state.isLoading && !state.hasData -> HomeSkeleton()
            else -> PullToRefreshBox(
                isRefreshing = state.isRefreshing,
                onRefresh = { viewModel.load(com.kajhobe.app.ui.feature.jobs.LoadMode.PULL) },
                modifier = Modifier.fillMaxSize(),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = KajHobeTheme.spacing.md),
                    verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.xl),
                ) {
                    FavoriteCategoriesSection(
                        categories = state.favoriteCategories,
                        jobCountFor = state::jobCount,
                        onEdit = { showFavoritesSheet = true },
                        onCategoryClick = onCategoryClick,
                    )

                    if (state.jobsNearYou.isNotEmpty()) {
                        JobCarousel(
                            title = "Jobs Near You",
                            subtitle = "Opportunities in your area",
                            jobs = state.jobsNearYou,
                            cardWidth = 280.dp,
                            status = state::statusOf,
                            onViewAll = { onViewAll(JobListKind.NEAR_YOU) },
                            onJobClick = onJobClick,
                        )
                    }

                    if (state.featuredJobs.isNotEmpty()) {
                        JobCarousel(
                            title = "Featured Jobs",
                            subtitle = "High-value and urgent opportunities",
                            jobs = state.featuredJobs,
                            cardWidth = 320.dp,
                            status = state::statusOf,
                            onViewAll = { onViewAll(JobListKind.FEATURED) },
                            onJobClick = onJobClick,
                        )
                    }

                    if (state.recentJobs.isNotEmpty()) {
                        JobCarousel(
                            title = "Recently Posted Jobs",
                            subtitle = "Latest opportunities",
                            jobs = state.recentJobs,
                            cardWidth = 300.dp,
                            status = state::statusOf,
                            onViewAll = { onViewAll(JobListKind.RECENT) },
                            onJobClick = onJobClick,
                        )
                    }

                    if (state.jobsNearYou.isEmpty() && state.featuredJobs.isEmpty() && state.recentJobs.isEmpty()) {
                        Text(
                            "No jobs available right now.",
                            style = MaterialTheme.typography.bodyLarge,
                            color = KajHobeTheme.colors.textSecondary,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth().padding(KajHobeTheme.spacing.xl),
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CategoryChipsRow(onCategoryClick: (String) -> Unit) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = KajHobeTheme.spacing.md),
        horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
    ) {
        item {
            FilterChip(
                selected = true,
                onClick = { },
                label = { Icon(Icons.Filled.Home, contentDescription = "Home", modifier = Modifier.padding(2.dp)) },
                colors = FilterChipDefaults.filterChipColors(),
            )
        }
        items(HardcodedServiceCategory.categories) { category ->
            FilterChip(
                selected = false,
                onClick = { onCategoryClick(category.name) },
                label = { Text("${category.icon} ${category.name}") },
            )
        }
    }
}

package com.kajhobe.app.ui.feature.jobs

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.HardcodedServiceCategory
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JobsListScreen(
    onJobClick: (String) -> Unit,
    viewModel: JobsViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // Silently reconcile whenever the Jobs tab becomes visible again (returning from another
    // tab or a job detail) — no spinner. Realtime keeps the list live in between; this is a
    // throttled safety net (skipped if fetched within the last 30s).
    LifecycleResumeEffect(Unit) {
        viewModel.load(LoadMode.SILENT)
        onPauseOrDispose { }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // Search
        OutlinedTextField(
            value = state.searchQuery,
            onValueChange = viewModel::onSearchChange,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = KajHobeTheme.spacing.md, vertical = KajHobeTheme.spacing.sm),
            placeholder = { Text("Search jobs") },
            leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
        )

        // Category chips
        LazyRow(
            contentPadding = PaddingValues(horizontal = KajHobeTheme.spacing.md),
            horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
        ) {
            items(HardcodedServiceCategory.categories) { cat ->
                FilterChip(
                    selected = state.selectedCategory == cat.name,
                    onClick = { viewModel.onCategorySelected(cat.name) },
                    label = { Text("${cat.icon} ${cat.name}") },
                )
            }
        }

        when {
            state.isLoading -> PremiumLoadingView(message = "Loading jobs…")
            state.errorMessage != null -> CenteredMessage(state.errorMessage!!, isError = true)
            else -> PullToRefreshBox(
                isRefreshing = state.isRefreshing,
                onRefresh = { viewModel.load(LoadMode.PULL) },
                modifier = Modifier.fillMaxSize(),
            ) {
                if (state.visibleJobs.isEmpty()) {
                    CenteredMessage("No jobs available right now.")
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(KajHobeTheme.spacing.md),
                        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
                    ) {
                        items(state.visibleJobs, key = { it.id }) { job ->
                            JobCard(
                                job = job,
                                onClick = { onJobClick(job.id) },
                                status = state.statusOf(job),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CenteredMessage(message: String, isError: Boolean = false) {
    Column(
        modifier = Modifier.fillMaxSize().padding(KajHobeTheme.spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodyLarge,
            color = if (isError) MaterialTheme.colorScheme.error else KajHobeTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

package com.kajhobe.app.ui.feature.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.feature.jobs.JobCard
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AllJobsScreen(
    kind: JobListKind?,
    categoryName: String?,
    isSearch: Boolean,
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    viewModel: AllJobsViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    val title = when {
        isSearch -> "Search Jobs"
        categoryName != null -> categoryName
        kind == JobListKind.NEAR_YOU -> "Jobs Near You"
        kind == JobListKind.FEATURED -> "Featured Jobs"
        kind == JobListKind.RECENT -> "Recently Posted Jobs"
        else -> "Jobs"
    }

    val visible = filterJobs(state, kind, categoryName, isSearch)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            if (isSearch) {
                OutlinedTextField(
                    value = state.query,
                    onValueChange = viewModel::setQuery,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = KajHobeTheme.spacing.md, vertical = KajHobeTheme.spacing.sm),
                    placeholder = { Text("Search jobs") },
                    leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                )
            }

            when {
                state.isLoading && state.jobs.isEmpty() -> PremiumLoadingView(message = "Loading…")
                visible.isEmpty() -> Text(
                    if (isSearch && state.query.isBlank()) "Type to search jobs." else "No jobs found.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = KajHobeTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(KajHobeTheme.spacing.xl),
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(KajHobeTheme.spacing.md),
                    verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
                ) {
                    items(visible, key = { it.id }) { job ->
                        JobCard(job = job, onClick = { onJobClick(job.id) }, status = state.statusOf(job))
                    }
                }
            }
        }
    }
}

/** Apply the same filters as the home sections (uncapped) for the chosen kind/category/search. */
private fun filterJobs(
    state: AllJobsUiState,
    kind: JobListKind?,
    categoryName: String?,
    isSearch: Boolean,
): List<Job> {
    val open = state.jobs.filter { it.status == "open" }
    return when {
        isSearch -> if (state.query.isBlank()) emptyList() else state.jobs.filter {
            it.title.contains(state.query, ignoreCase = true) ||
                it.description.contains(state.query, ignoreCase = true) ||
                it.category.contains(state.query, ignoreCase = true)
        }
        categoryName != null -> state.jobs.filter { it.category.contains(categoryName, ignoreCase = true) }
        kind == JobListKind.NEAR_YOU -> open.filter {
            it.location.contains(state.userLocation, ignoreCase = true) ||
                it.location.contains(HomeUiState.DEFAULT_LOCATION, ignoreCase = true)
        }
        kind == JobListKind.FEATURED -> open
            .filter { it.urgent == true || it.budget >= HomeUiState.FEATURED_BUDGET }
            .sortedWith(compareByDescending<Job> { it.urgent == true }.thenByDescending { it.budget })
        kind == JobListKind.RECENT -> open.sortedByDescending { it.created_at ?: "" }
        else -> state.jobs
    }
}

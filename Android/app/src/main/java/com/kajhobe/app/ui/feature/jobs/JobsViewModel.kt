package com.kajhobe.app.ui.feature.jobs

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.cache.CachedJobs
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.data.repository.JobsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** How a refresh should present: full loading view, pull spinner, or invisible. */
enum class LoadMode { INITIAL, PULL, SILENT }

data class JobsUiState(
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val jobs: List<Job> = emptyList(),
    val viewedJobIds: Set<String> = emptySet(),
    val currentUserId: String? = null,
    val selectedCategory: String? = null,
    val searchQuery: String = "",
    val errorMessage: String? = null,
) {
    /** Jobs after applying the active category + search filters. */
    val visibleJobs: List<Job>
        get() = jobs.filter { job ->
            (selectedCategory == null || job.category == selectedCategory) &&
                (searchQuery.isBlank() ||
                    job.title.contains(searchQuery, ignoreCase = true) ||
                    job.description.contains(searchQuery, ignoreCase = true) ||
                    job.location.contains(searchQuery, ignoreCase = true))
        }

    /** A job is "New" if the user hasn't opened it yet and didn't post it. */
    fun isNew(job: Job): Boolean =
        job.id !in viewedJobIds && job.client_id != currentUserId
}

class JobsViewModel(
    private val jobsRepository: JobsRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(JobsUiState())
    val uiState: StateFlow<JobsUiState> = _uiState.asStateFlow()

    init { seedFromCacheThenLoad() }

    private fun seedFromCacheThenLoad() {
        val memory = jobsRepository.cachedSnapshot()
        if (memory != null) {
            applySnapshot(memory)
            load(LoadMode.SILENT)
        } else {
            viewModelScope.launch {
                val disk = jobsRepository.warmCache()
                if (disk != null) {
                    applySnapshot(disk)
                    load(LoadMode.SILENT)
                } else {
                    load(LoadMode.INITIAL)
                }
            }
        }
    }

    private fun applySnapshot(snapshot: CachedJobs) {
        _uiState.update {
            it.copy(
                isLoading = false,
                jobs = snapshot.jobs,
                viewedJobIds = snapshot.viewedIds,
                currentUserId = jobsRepository.currentUserIdOrNull(),
            )
        }
    }

    /**
     * Refresh the list. [LoadMode.INITIAL] shows the loading view, [LoadMode.PULL] shows the
     * pull-to-refresh spinner, [LoadMode.SILENT] updates invisibly (cached list stays on screen).
     * Called silently on every tab-resume so the list is always current after navigation.
     */
    fun load(mode: LoadMode = LoadMode.INITIAL) {
        _uiState.update {
            when (mode) {
                LoadMode.INITIAL -> it.copy(isLoading = true, errorMessage = null)
                LoadMode.PULL -> it.copy(isRefreshing = true, errorMessage = null)
                LoadMode.SILENT -> it.copy(errorMessage = null)
            }
        }
        viewModelScope.launch {
            runCatching { jobsRepository.loadJobsAndViews() }
                .onSuccess { snapshot ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            isRefreshing = false,
                            jobs = snapshot.jobs,
                            viewedJobIds = snapshot.viewedIds,
                            currentUserId = jobsRepository.currentUserIdOrNull(),
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            isRefreshing = false,
                            // Keep showing cached jobs on a background failure; only surface an
                            // error when there's nothing to show.
                            errorMessage = if (it.jobs.isEmpty()) (e.message ?: "Failed to load jobs") else null,
                        )
                    }
                }
        }
    }

    fun onSearchChange(query: String) = _uiState.update { it.copy(searchQuery = query) }

    fun onCategorySelected(category: String?) = _uiState.update {
        it.copy(selectedCategory = if (it.selectedCategory == category) null else category)
    }
}

package com.kajhobe.app.ui.feature.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.data.repository.JobsRepository
import com.kajhobe.app.data.repository.ProfileRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AllJobsUiState(
    val isLoading: Boolean = true,
    val jobs: List<Job> = emptyList(),
    val viewedJobIds: Set<String> = emptySet(),
    val currentUserId: String? = null,
    val userLocation: String = HomeUiState.DEFAULT_LOCATION,
    val query: String = "",
) {
    fun isNew(job: Job): Boolean = job.id !in viewedJobIds && job.client_id != currentUserId
}

/**
 * Backs the vertical "View All" / category / search lists. Loads the same job set as the home
 * (cache-seeded) and exposes raw jobs + the user's location; the screen applies the matching
 * filter for its [JobListKind]/category/query.
 */
class AllJobsViewModel(
    private val jobsRepository: JobsRepository,
    private val profileRepository: ProfileRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AllJobsUiState())
    val uiState: StateFlow<AllJobsUiState> = _uiState.asStateFlow()

    init {
        jobsRepository.cachedSnapshot()?.let {
            _uiState.update { s ->
                s.copy(isLoading = false, jobs = it.jobs, viewedJobIds = it.viewedIds, currentUserId = jobsRepository.currentUserIdOrNull())
            }
        }
        load()
        viewModelScope.launch {
            runCatching { profileRepository.getCurrentUserProfile() }.getOrNull()?.let { p ->
                _uiState.update {
                    it.copy(userLocation = p.location?.ifBlank { HomeUiState.DEFAULT_LOCATION } ?: HomeUiState.DEFAULT_LOCATION)
                }
            }
        }
    }

    private fun load() {
        viewModelScope.launch {
            runCatching { jobsRepository.loadJobsAndViews() }
                .onSuccess { snap ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            jobs = snap.jobs,
                            viewedJobIds = snap.viewedIds,
                            currentUserId = jobsRepository.currentUserIdOrNull(),
                        )
                    }
                }
                .onFailure { _uiState.update { it.copy(isLoading = false) } }
        }
    }

    fun setQuery(query: String) = _uiState.update { it.copy(query = query) }
}

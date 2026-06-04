package com.kajhobe.app.ui.feature.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.cache.CachedJobs
import com.kajhobe.app.data.model.HardcodedServiceCategory
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.data.repository.JobsRepository
import com.kajhobe.app.data.repository.ProfileRepository
import com.kajhobe.app.ui.feature.jobs.LoadMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class HomeUiState(
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val hasData: Boolean = false,
    val jobs: List<Job> = emptyList(),
    val viewedJobIds: Set<String> = emptySet(),
    val currentUserId: String? = null,
    val favoriteCategoryNames: List<String> = emptyList(),
    val userLocation: String = DEFAULT_LOCATION,
    val errorMessage: String? = null,
) {
    private val openJobs: List<Job> get() = jobs.filter { it.status == "open" }

    /** Up to 4 favorite categories (profile choice, else the first 4) — iOS favoriteCategories. */
    val favoriteCategories: List<HardcodedServiceCategory>
        get() = if (favoriteCategoryNames.isEmpty()) {
            HardcodedServiceCategory.categories.take(4)
        } else {
            favoriteCategoryNames.mapNotNull { name -> HardcodedServiceCategory.byName(name) }.take(4)
        }

    /** Open jobs in the user's area (or Khulna), first 6 — iOS jobsNearYou. */
    val jobsNearYou: List<Job>
        get() = openJobs.filter {
            it.location.contains(userLocation, ignoreCase = true) ||
                it.location.contains(DEFAULT_LOCATION, ignoreCase = true)
        }.take(6)

    /** Urgent or high-value open jobs, urgent-first then budget desc, first 6 — iOS featuredJobs. */
    val featuredJobs: List<Job>
        get() = openJobs.filter { it.urgent == true || it.budget >= FEATURED_BUDGET }
            .sortedWith(compareByDescending<Job> { it.urgent == true }.thenByDescending { it.budget })
            .take(6)

    /** Newest open jobs first, first 6 — iOS recentJobs. */
    val recentJobs: List<Job>
        get() = openJobs.sortedByDescending { it.created_at ?: "" }.take(6)

    fun jobCount(categoryName: String): Int =
        jobs.count { it.category.contains(categoryName, ignoreCase = true) }

    fun isNew(job: Job): Boolean = job.id !in viewedJobIds && job.client_id != currentUserId

    companion object {
        const val DEFAULT_LOCATION = "Khulna"
        const val FEATURED_BUDGET = 5000
    }
}

class HomeViewModel(
    private val jobsRepository: JobsRepository,
    private val profileRepository: ProfileRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
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
                    load(LoadMode.INITIAL) // no data yet → skeleton
                }
            }
        }
        refreshProfile()
    }

    private fun applySnapshot(snapshot: CachedJobs) {
        _uiState.update {
            it.copy(
                isLoading = false,
                hasData = true,
                jobs = snapshot.jobs,
                viewedJobIds = snapshot.viewedIds,
                currentUserId = jobsRepository.currentUserIdOrNull(),
            )
        }
    }

    /** [LoadMode.INITIAL] → skeleton; PULL → spinner; SILENT → invisible (tab-resume). */
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
                            hasData = true,
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
                            errorMessage = if (!it.hasData) (e.message ?: "Failed to load") else null,
                        )
                    }
                }
        }
    }

    private fun refreshProfile() {
        viewModelScope.launch {
            runCatching { profileRepository.getCurrentUserProfile() }.getOrNull()?.let { profile ->
                _uiState.update {
                    it.copy(
                        favoriteCategoryNames = profile.favorite_categories ?: emptyList(),
                        userLocation = profile.location?.ifBlank { HomeUiState.DEFAULT_LOCATION }
                            ?: HomeUiState.DEFAULT_LOCATION,
                    )
                }
            }
        }
    }

    /** Save favorite categories (capped at 4) and persist to the profile. */
    fun saveFavoriteCategories(names: List<String>) {
        val limited = names.take(4)
        _uiState.update { it.copy(favoriteCategoryNames = limited) } // optimistic
        viewModelScope.launch {
            runCatching { profileRepository.updateProfile(favoriteCategories = limited) }
        }
    }
}

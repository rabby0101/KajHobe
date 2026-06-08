package com.kajhobe.app.ui.feature.jobs

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.data.model.Profile
import com.kajhobe.app.data.repository.JobsRepository
import com.kajhobe.app.data.repository.ProfileRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class JobDetailUiState(
    val isLoading: Boolean = true,
    val job: Job? = null,
    val client: Profile? = null,
    val hasShownInterest: Boolean = false,
    val isOwnJob: Boolean = false,
    val isSubmitting: Boolean = false,
    val errorMessage: String? = null,
    val message: String? = null,
)

class JobDetailViewModel(
    private val jobsRepository: JobsRepository,
    private val profileRepository: ProfileRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(JobDetailUiState())
    val uiState: StateFlow<JobDetailUiState> = _uiState.asStateFlow()

    private var loadedJobId: String? = null

    fun load(jobId: String) {
        if (loadedJobId == jobId) return
        loadedJobId = jobId
        _uiState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                val job = jobsRepository.fetchJob(jobId)
                val client = job?.client_id?.let { profileRepository.fetchProfile(it) }
                val interested = jobsRepository.hasShownInterest(jobId)
                Triple(job, client, interested)
            }.onSuccess { (job, client, interested) ->
                val isOwn = job?.client_id == profileRepository.currentUserIdOrNull()
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        job = job,
                        client = client,
                        hasShownInterest = interested,
                        isOwnJob = isOwn,
                    )
                }
                // Mark this job as viewed so the "New" badge clears in the list (iOS markJobAsViewed).
                if (job != null && !isOwn) {
                    viewModelScope.launch { runCatching { jobsRepository.recordJobView(jobId) } }
                }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, errorMessage = e.message ?: "Failed to load job") }
            }
        }
    }

    fun showInterest(message: String) {
        val jobId = loadedJobId ?: return
        if (_uiState.value.hasShownInterest || _uiState.value.isSubmitting) return
        _uiState.update { it.copy(isSubmitting = true) }
        viewModelScope.launch {
            runCatching { jobsRepository.showInterest(jobId, message) }
                .onSuccess {
                    _uiState.update { it.copy(isSubmitting = false, hasShownInterest = true, message = "Interest sent!") }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isSubmitting = false, errorMessage = e.message ?: "Could not send interest") }
                }
        }
    }
}

package com.kajhobe.app.ui.feature.jobs

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.CooldownStatus
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
    /** Current job_interests status for this provider: pending/accepted/rejected/null. */
    val interestStatus: String? = null,
    val cooldown: CooldownStatus = CooldownStatus(),
    val isOwnJob: Boolean = false,
    val isSubmitting: Boolean = false,
    val isDeleting: Boolean = false,
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
                val interestState = jobsRepository.fetchInterestState(jobId)
                Triple(job, client, interestState)
            }.onSuccess { (job, client, interestState) ->
                val isOwn = job?.client_id == profileRepository.currentUserIdOrNull()
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        job = job,
                        client = client,
                        interestStatus = interestState.currentStatus,
                        cooldown = interestState.cooldown,
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
        val state = _uiState.value
        if (state.isSubmitting) return
        // Respect the cooldown (rate limit / 2-min wait / 2-attempt cap). The RPC
        // also enforces this server-side; this just avoids a doomed round-trip.
        if (!state.cooldown.canShowInterest) {
            _uiState.update { it.copy(errorMessage = it.cooldown.statusDescription) }
            return
        }
        _uiState.update { it.copy(isSubmitting = true, errorMessage = null) }
        viewModelScope.launch {
            runCatching { jobsRepository.showInterest(jobId, message) }
                .onSuccess {
                    val refreshed = runCatching { jobsRepository.fetchInterestState(jobId) }.getOrNull()
                    _uiState.update {
                        it.copy(
                            isSubmitting = false,
                            message = "Interest sent!",
                            interestStatus = refreshed?.currentStatus ?: "pending",
                            cooldown = refreshed?.cooldown ?: it.cooldown,
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isSubmitting = false, errorMessage = e.message ?: "Could not send interest") }
                }
        }
    }

    /** Delete the current (own) job. Calls [onDeleted] on success so the screen can pop. */
    fun deleteJob(onDeleted: () -> Unit) {
        val jobId = loadedJobId ?: return
        if (_uiState.value.isDeleting) return
        _uiState.update { it.copy(isDeleting = true, errorMessage = null) }
        viewModelScope.launch {
            runCatching { jobsRepository.deleteJob(jobId) }
                .onSuccess { onDeleted() }
                .onFailure { e ->
                    _uiState.update { it.copy(isDeleting = false, errorMessage = e.message ?: "Could not delete job") }
                }
        }
    }

    /** Re-read interest status + cooldown (e.g. when a countdown reaches zero). */
    fun refreshCooldown() {
        val jobId = loadedJobId ?: return
        viewModelScope.launch {
            runCatching { jobsRepository.fetchInterestState(jobId) }
                .onSuccess { st ->
                    _uiState.update { it.copy(interestStatus = st.currentStatus, cooldown = st.cooldown) }
                }
        }
    }
}

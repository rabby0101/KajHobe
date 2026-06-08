package com.kajhobe.app.ui.feature.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.PublicProfile
import com.kajhobe.app.data.repository.ProfilePublicRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class PublicProfileUiState(
    val isLoading: Boolean = true,
    val profile: PublicProfile? = null,
    val errorMessage: String? = null,
)

/**
 * Loads a [PublicProfile] by id for the destination of the
 * "interest notification → sender's profile" flow. Mirrors iOS
 * `PublicProfileView.loadProfile()`.
 */
class PublicProfileViewModel(
    private val repository: ProfilePublicRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(PublicProfileUiState())
    val uiState: StateFlow<PublicProfileUiState> = _uiState.asStateFlow()

    private var loadedUserId: String? = null

    fun load(userId: String) {
        if (userId.isBlank()) {
            _uiState.update { it.copy(isLoading = false, errorMessage = "Invalid user id") }
            return
        }
        loadedUserId = userId
        _uiState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            val profile = runCatching { repository.fetchPublicProfile(userId) }
                .getOrNull()
            if (profile != null) {
                _uiState.update { it.copy(isLoading = false, profile = profile, errorMessage = null) }
            } else {
                _uiState.update {
                    it.copy(isLoading = false, profile = null, errorMessage = "Profile not found")
                }
            }
        }
    }

    fun retry() {
        loadedUserId?.let { load(it) }
    }
}

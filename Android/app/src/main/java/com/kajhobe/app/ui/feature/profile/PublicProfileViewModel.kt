package com.kajhobe.app.ui.feature.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.PublicProfile
import com.kajhobe.app.data.model.ServiceHighlight
import com.kajhobe.app.data.repository.ProfilePublicRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class PublicProfileUiState(
    val isLoading: Boolean = true,
    val profile: PublicProfile? = null,
    val serviceHighlights: List<ServiceHighlight> = emptyList(),
    val reviews: List<ProviderReview> = emptyList(),
    val errorMessage: String? = null,
)

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
            coroutineScope {
                val profileD = async { repository.fetchPublicProfile(userId) }
                val highlightsD = async {
                    runCatching { repository.fetchServiceHighlights(userId) }
                        .getOrDefault(emptyList())
                }
                val reviewsD = async {
                    runCatching { repository.fetchReviews(userId) }
                        .getOrDefault(emptyList())
                }
                val profile = profileD.await()
                if (profile == null) {
                    _uiState.update {
                        it.copy(isLoading = false, profile = null, errorMessage = "Profile not found")
                    }
                } else {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            profile = profile,
                            serviceHighlights = highlightsD.await(),
                            reviews = reviewsD.await(),
                            errorMessage = null,
                        )
                    }
                }
            }
        }
    }

    fun retry() {
        loadedUserId?.let { load(it) }
    }
}

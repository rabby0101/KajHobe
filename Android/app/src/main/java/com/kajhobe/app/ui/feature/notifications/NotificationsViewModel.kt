package com.kajhobe.app.ui.feature.notifications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.EnhancedNotification
import com.kajhobe.app.data.model.EnrichedJobInterest
import com.kajhobe.app.data.repository.NotificationsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class NotificationsUiState(
    val isLoading: Boolean = true,
    val interests: List<EnrichedJobInterest> = emptyList(),
    val notifications: List<EnhancedNotification> = emptyList(),
    val processingIds: Set<String> = emptySet(),
    val errorMessage: String? = null,
)

class NotificationsViewModel(
    private val repository: NotificationsRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(NotificationsUiState())
    val uiState: StateFlow<NotificationsUiState> = _uiState.asStateFlow()

    init { load() }

    /**
     * Load notifications. [silent] = true keeps the current list on screen with no loading view
     * (used on tab-resume so navigation refreshes seamlessly); false shows the full loader.
     */
    fun load(silent: Boolean = false) {
        _uiState.update { it.copy(isLoading = if (silent) it.isLoading else true, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                val interests = repository.fetchEnrichedJobInterests()
                val notifications = repository.fetchEnhancedNotifications()
                interests to notifications
            }.onSuccess { (interests, notifications) ->
                _uiState.update { it.copy(isLoading = false, interests = interests, notifications = notifications) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, errorMessage = e.message ?: "Failed to load notifications") }
            }
        }
    }

    fun respond(interest: EnrichedJobInterest, accept: Boolean) {
        if (interest.id in _uiState.value.processingIds) return
        _uiState.update { it.copy(processingIds = it.processingIds + interest.id) }
        viewModelScope.launch {
            runCatching { repository.respondToInterest(interest, accept) }
                .onSuccess {
                    // Remove the handled interest from the list.
                    _uiState.update {
                        it.copy(
                            interests = it.interests.filterNot { i -> i.id == interest.id },
                            processingIds = it.processingIds - interest.id,
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update {
                        it.copy(processingIds = it.processingIds - interest.id, errorMessage = e.message ?: "Action failed")
                    }
                }
        }
    }
}

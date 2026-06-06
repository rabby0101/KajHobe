package com.kajhobe.app.ui.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.repository.DealsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class DealDetailUiState(
    val isLoading: Boolean = true,
    val deal: Deal? = null,
    val isUserClient: Boolean = false,
    val isProcessing: Boolean = false,
    val errorMessage: String? = null,
)

/**
 * Deal Details — Android port of iOS `DealDetailView`. Loads a single deal (with job + both
 * profiles), resolves the viewer's role, and drives the completion-request workflow.
 */
class DealDetailViewModel(
    private val dealsRepository: DealsRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DealDetailUiState())
    val uiState: StateFlow<DealDetailUiState> = _uiState.asStateFlow()

    private var dealId: String = ""

    fun load(id: String) {
        dealId = id
        _uiState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch { refresh(showLoading = true) }
    }

    /** Request completion of the deal (iOS "Request Completion"). */
    fun requestCompletion(message: String) {
        val deal = _uiState.value.deal ?: return
        val requesterType = if (_uiState.value.isUserClient) "client" else "provider"
        _uiState.update { it.copy(isProcessing = true) }
        viewModelScope.launch {
            runCatching {
                dealsRepository.requestTaskCompletion(deal.id, requesterType, message.ifBlank { null })
            }.onFailure { e -> _uiState.update { it.copy(errorMessage = e.message ?: "Failed to request completion") } }
            refresh(showLoading = false)
        }
    }

    /** Approve / request changes on a pending completion request (iOS "Approve"/"Request Changes"). */
    fun respondToCompletion(approve: Boolean) {
        val deal = _uiState.value.deal ?: return
        _uiState.update { it.copy(isProcessing = true) }
        viewModelScope.launch {
            runCatching {
                val request = dealsRepository.fetchPendingCompletionRequests()
                    .firstOrNull { it.deal_id == deal.id }
                    ?: error("No pending completion request found")
                dealsRepository.respondToCompletionRequest(
                    requestId = request.id,
                    approve = approve,
                    message = if (approve) "Approved" else "Please make the requested changes",
                )
            }.onFailure { e -> _uiState.update { it.copy(errorMessage = e.message ?: "Failed to respond") } }
            refresh(showLoading = false)
        }
    }

    fun clearError() = _uiState.update { it.copy(errorMessage = null) }

    private suspend fun refresh(showLoading: Boolean) {
        val uid = dealsRepository.currentUid()
        val deal = runCatching { dealsRepository.fetchMyDeals() }
            .getOrDefault(emptyList())
            .firstOrNull { it.id == dealId }
        _uiState.update {
            it.copy(
                isLoading = if (showLoading) false else it.isLoading,
                isProcessing = false,
                deal = deal ?: it.deal,
                isUserClient = (deal ?: it.deal)?.client_id == uid,
            )
        }
    }
}

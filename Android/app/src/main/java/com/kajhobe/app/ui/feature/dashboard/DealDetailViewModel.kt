package com.kajhobe.app.ui.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.CompletionRequest
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.EscrowTransaction
import com.kajhobe.app.data.repository.DealsRepository
import com.kajhobe.app.data.repository.CompletionRequestAlreadyPendingException
import com.kajhobe.app.data.repository.PaymentRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class DealDetailUiState(
    val isLoading: Boolean = true,
    val deal: Deal? = null,
    val isUserClient: Boolean = false,
    val isProcessing: Boolean = false,
    val errorMessage: String? = null,
    // Escrow & admin
    val escrow: EscrowTransaction? = null,
    val escrowLoading: Boolean = false,
    val isAdmin: Boolean = false,
)

/**
 * One-shot events from the deal-detail workflow. The screen collects these and reacts
 * (e.g. open the response sheet when the other party already filed a request).
 */
sealed interface DealDetailEvent {
    /** The other party already filed a pending completion request — re-route to the response sheet. */
    data class OpenResponseSheet(val request: CompletionRequest) : DealDetailEvent
}

/**
 * Deal Details — Android port of iOS `DealDetailView`. Loads a single deal (with job + both
 * profiles), resolves the viewer's role, and drives the completion-request workflow.
 */
class DealDetailViewModel(
    private val dealsRepository: DealsRepository,
    private val paymentRepository: PaymentRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DealDetailUiState())
    val uiState: StateFlow<DealDetailUiState> = _uiState.asStateFlow()

    private val _events = Channel<DealDetailEvent>(Channel.BUFFERED)
    val events: Flow<DealDetailEvent> = _events.receiveAsFlow()

    private var dealId: String = ""

    fun load(id: String) {
        dealId = id
        _uiState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch { refresh(showLoading = true) }
        viewModelScope.launch { refreshEscrow() }
        viewModelScope.launch { refreshAdmin() }
    }

    /** Request completion of the deal (iOS "Request Completion"). */
    fun requestCompletion(message: String?) {
        val deal = _uiState.value.deal ?: return
        val requesterType = if (_uiState.value.isUserClient) "client" else "provider"
        _uiState.update { it.copy(isProcessing = true) }
        viewModelScope.launch {
            val outcome = runCatching {
                dealsRepository.requestTaskCompletion(deal.id, requesterType, message)
            }
            outcome.onFailure { e ->
                when (e) {
                    is CompletionRequestAlreadyPendingException -> {
                        // The other party already filed a request. Refresh the deal
                        // (so flags reflect reality) and route the user to the response sheet.
                        refresh(showLoading = false)
                        val existing = fetchPendingRequestForCurrentDeal()
                        if (existing != null) {
                            _events.send(DealDetailEvent.OpenResponseSheet(existing))
                        } else {
                            _uiState.update {
                                it.copy(errorMessage = "A completion request is already pending for this deal.")
                            }
                        }
                    }
                    else -> _uiState.update {
                        it.copy(errorMessage = e.message ?: "Failed to request completion")
                    }
                }
                return@launch
            }
            refresh(showLoading = false)
        }
    }

    /** Approve / request changes on a pending completion request (iOS "Approve"/"Request Changes"). */
    fun respondToCompletion(approve: Boolean, message: String? = null) {
        val deal = _uiState.value.deal ?: return
        _uiState.update { it.copy(isProcessing = true) }
        viewModelScope.launch {
            runCatching {
                val request = dealsRepository.fetchPendingCompletionRequests()
                    .firstOrNull { it.deal_id == deal.id }
                    ?: return@runCatching
                dealsRepository.respondToCompletionRequest(
                    requestId = request.id,
                    approve = approve,
                    message = message,
                )
            }.onFailure { e ->
                _uiState.update { it.copy(errorMessage = e.message ?: "Failed to respond") }
            }
            refresh(showLoading = false)
            refreshEscrow()
        }
    }

    /** Returns the pending completion request (with requester profile) for the currently loaded deal, if any. */
    suspend fun fetchPendingRequestForCurrentDeal(): CompletionRequest? {
        val deal = _uiState.value.deal ?: return null
        return runCatching {
            dealsRepository.fetchPendingCompletionRequests().firstOrNull { it.deal_id == deal.id }
        }.getOrNull()
    }

    // MARK: - Escrow admin actions (iOS EscrowSectionView)

    fun markEscrowPaidOut() {
        val escrow = _uiState.value.escrow ?: return
        _uiState.update { it.copy(isProcessing = true) }
        viewModelScope.launch {
            runCatching { paymentRepository.markPaidOut(escrow.id) }
                .onFailure { e -> _uiState.update { it.copy(errorMessage = e.message ?: "Failed to mark paid out") } }
            refreshEscrow()
            _uiState.update { it.copy(isProcessing = false) }
        }
    }

    fun markEscrowRefunded() {
        val escrow = _uiState.value.escrow ?: return
        _uiState.update { it.copy(isProcessing = true) }
        viewModelScope.launch {
            runCatching { paymentRepository.markRefunded(escrow.id) }
                .onFailure { e -> _uiState.update { it.copy(errorMessage = e.message ?: "Failed to refund") } }
            refreshEscrow()
            _uiState.update { it.copy(isProcessing = false) }
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

    private suspend fun refreshEscrow() {
        if (dealId.isEmpty()) return
        _uiState.update { it.copy(escrowLoading = true) }
        val escrow = paymentRepository.fetchEscrow(dealId)
        _uiState.update { it.copy(escrow = escrow, escrowLoading = false) }
    }

    private suspend fun refreshAdmin() {
        val isAdmin = paymentRepository.isCurrentUserAdmin()
        _uiState.update { it.copy(isAdmin = isAdmin) }
    }
}

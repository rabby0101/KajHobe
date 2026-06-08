package com.kajhobe.app.ui.feature.messages

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.media.MediaUploadManager
import com.kajhobe.app.data.model.ChatMessage
import com.kajhobe.app.data.notifications.MessageBadgeManager
import com.kajhobe.app.data.payment.PaymentDeepLinkBus
import com.kajhobe.app.data.repository.MessagesRepository
import com.kajhobe.app.data.repository.PaymentRepository
import io.github.jan.supabase.realtime.RealtimeChannel
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

data class ChatUiState(
    val isLoading: Boolean = true,
    val title: String = "Chat",
    val subtitle: String? = null,
    val messages: List<ChatMessage> = emptyList(),
    val draft: String = "",
    val isSending: Boolean = false,
    val currentUserId: String? = null,
    val errorMessage: String? = null,
    // Deal + photo state
    val clientId: String? = null,
    val providerId: String? = null,
    val jobId: String? = null,
    val offerCount: Int = 0,
    val hasUnansweredOffer: Boolean = false,
    val existingDealExists: Boolean = false,
    val isSendingDealOffer: Boolean = false,
    val isUploadingImage: Boolean = false,
    // bKash payment state (mirrors iOS `isPaying` / `payError`)
    val isPaying: Boolean = false,
    val payError: String? = null,
    // URL the UI should launch in Chrome Custom Tabs (one-shot — cleared on consume).
    val pendingBkashUrl: String? = null,
    // offerId → "pending" | "accepted" | "rejected" (DB-truth wins; derived
    // from `deal_offers.status` first, falls back to chat `deal_response` msgs).
    val dealStatuses: Map<String, String> = emptyMap(),
) {
    /** Only the service provider may send deal offers (iOS rule). */
    val isProvider: Boolean get() = currentUserId != null && currentUserId == providerId

    /** iOS canSendOffer: no existing deal, < 2 offers, no unanswered offer. */
    val canSendOffer: Boolean get() = !existingDealExists && offerCount < 2 && !hasUnansweredOffer
}

class ChatViewModel(
    private val repository: MessagesRepository,
    private val paymentRepository: PaymentRepository,
    private val mediaUploadManager: MediaUploadManager,
    private val messageBadgeManager: MessageBadgeManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    private var conversationId: String? = null
    private var channel: RealtimeChannel? = null
    private var collectJob: Job? = null
    private var loaded = false
    private var deepLinkJob: Job? = null

    fun start(conversationId: String) {
        if (loaded) return
        loaded = true
        this.conversationId = conversationId
        _uiState.update { it.copy(currentUserId = repository.currentUserId()) }

        viewModelScope.launch {
            // Header (title) — best effort.
            runCatching { repository.fetchConversationHeader(conversationId) }.getOrNull()?.let { h ->
                _uiState.update { it.copy(title = h.otherPartyName ?: "Chat", subtitle = h.jobTitle) }
            }
            // Conversation meta (role + ids for the deal flow).
            runCatching { repository.fetchConversation(conversationId) }.getOrNull()?.let { c ->
                _uiState.update { it.copy(clientId = c.client_id, providerId = c.provider_id, jobId = c.job_id) }
            }
            // Initial messages.
            runCatching { repository.fetchMessages(conversationId) }
                .onSuccess { msgs ->
                    _uiState.update { it.copy(isLoading = false, messages = msgs, dealStatuses = dealStatusesFrom(msgs)) }
                    // DB truth wins: re-read deal_offers.status for every offer
                    // referenced in this conversation.
                    refreshDealOfferStatuses()
                }
                .onFailure { e -> _uiState.update { it.copy(isLoading = false, errorMessage = e.message) } }
            // Mark received messages read so the conversation-list unread badge clears.
            runCatching { repository.markConversationRead(conversationId) }
            // Offer status (gates the deal button).
            refreshOfferStatus()
        }

        subscribe(conversationId)
        subscribeToDeepLinks()
    }

    private fun subscribe(conversationId: String) {
        val ch = repository.conversationChannel(conversationId)
        channel = ch
        // Set up the flow BEFORE joining (supabase-kt requirement).
        val flow = repository.incomingMessages(ch, conversationId)
        collectJob = viewModelScope.launch {
            flow.collect { msg -> appendIfNew(msg) }
        }
        viewModelScope.launch { runCatching { repository.joinChannel(ch) } }
    }

    /**
     * Listen for bKash deep-link callbacks. When the user returns from the
     * bKash-hosted page, refetch the offer status — the webhook has had
     * time to fire and flip `deal_offers.status`.
     */
    private fun subscribeToDeepLinks() {
        deepLinkJob?.cancel()
        deepLinkJob = viewModelScope.launch {
            PaymentDeepLinkBus.events.collect { event ->
                val offerId = event.dealOfferId ?: return@collect
                val status = event.status
                _uiState.update { current ->
                    val updated = current.dealStatuses.toMutableMap()
                    if (status == "success") updated[offerId] = "accepted"
                    current.copy(
                        dealStatuses = updated,
                        isPaying = false,
                        payError = if (status == "success") null
                            else "Payment not completed (${status ?: "cancelled"}).",
                    )
                }
                // Refetch from the server to pick up the new deal + escrow rows.
                refreshDealOfferStatuses()
                refreshOfferStatus()
            }
        }
    }

    private fun appendIfNew(msg: ChatMessage) {
        var wasNew = false
        _uiState.update { state ->
            if (state.messages.any { it.id == msg.id }) state
            else {
                wasNew = true
                val merged = state.messages + msg
                state.copy(messages = merged, dealStatuses = dealStatusesFrom(merged))
            }
        }
        // A deal response changes whether the provider can send another offer.
        if (msg.message_type == "deal_response") {
            viewModelScope.launch { refreshOfferStatus() }
        }
        // Chat is open: a new incoming message from the other party is now visible.
        if (wasNew) {
            val uid = _uiState.value.currentUserId
            if (msg.sender_id != uid && msg.read_at.isNullOrEmpty()) {
                viewModelScope.launch {
                    runCatching { repository.markConversationRead(msg.conversation_id) }
                }
            }
        }
    }

    /**
     * Build offerId → status map from the conversation's deal_response messages.
     * The DB-truth map (built by [refreshDealOfferStatuses]) overrides this.
     */
    private fun dealStatusesFrom(messages: List<ChatMessage>): Map<String, String> {
        val map = mutableMapOf<String, String>()
        for (m in messages) {
            if (m.message_type != "deal_response") continue
            val obj = m.negotiation_data?.jsonObject ?: continue
            val offerId = obj["original_deal_offer_id"]?.jsonPrimitive?.contentOrNull ?: continue
            val response = obj["response"]?.jsonPrimitive?.contentOrNull ?: continue
            map[offerId] = response
        }
        return map
    }

    /**
     * Read every `deal_offers` row referenced in the loaded messages directly
     * and merge its `status` into `state.dealStatuses`. DB wins over the
     * message-derived map. Mirrors iOS `loadDealStatus()` in
     * `ChatView.swift:998-1025`.
     */
    private suspend fun refreshDealOfferStatuses() {
        val state = _uiState.value
        val offerIds = state.messages
            .filter { it.message_type == "deal_offer" }
            .mapNotNull { it.negotiation_data?.jsonObject?.get("deal_offer_id")?.jsonPrimitive?.contentOrNull }
            .distinct()
        if (offerIds.isEmpty()) return
        runCatching {
            val rows = repository.fetchDealOfferStatuses(offerIds)
            val dbMap = rows.associate { it.id to it.status }
            _uiState.update { current ->
                val merged = current.dealStatuses.toMutableMap().apply { putAll(dbMap) }
                current.copy(dealStatuses = merged)
            }
        }
    }

    private suspend fun refreshOfferStatus() {
        val convId = conversationId ?: return
        val state = _uiState.value
        val providerId = state.providerId ?: return
        val jobId = state.jobId
        val status = runCatching { repository.getOfferStatus(convId, providerId) }.getOrNull()
        val dealExists = jobId?.let { runCatching { repository.dealExistsForJob(it) }.getOrDefault(false) } ?: false
        _uiState.update {
            it.copy(
                offerCount = status?.totalOffers ?: it.offerCount,
                hasUnansweredOffer = status?.hasUnansweredOffer ?: it.hasUnansweredOffer,
                existingDealExists = dealExists,
            )
        }
    }

    fun onDraftChange(value: String) = _uiState.update { it.copy(draft = value) }

    fun send() {
        val convId = conversationId ?: return
        val text = _uiState.value.draft.trim()
        if (text.isEmpty() || _uiState.value.isSending) return
        _uiState.update { it.copy(isSending = true, draft = "") }
        viewModelScope.launch {
            runCatching { repository.sendMessage(convId, text) }
                .onSuccess { sent ->
                    appendIfNew(sent) // optimistic; realtime echo is de-duped by id
                    _uiState.update { it.copy(isSending = false) }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isSending = false, draft = text, errorMessage = e.message ?: "Send failed") }
                }
        }
    }

    fun sendDealOffer(amount: Int, terms: String?, timeline: String?, additionalMessage: String?) {
        val convId = conversationId ?: return
        val s = _uiState.value
        val providerId = s.providerId ?: return
        val clientId = s.clientId ?: return
        val jobId = s.jobId ?: return
        if (s.isSendingDealOffer || !s.canSendOffer) return
        _uiState.update { it.copy(isSendingDealOffer = true, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                repository.sendDealOffer(convId, providerId, clientId, jobId, amount, terms, timeline, additionalMessage)
            }
                .onSuccess {
                    refreshOfferStatus()
                    _uiState.update { it.copy(isSendingDealOffer = false) }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isSendingDealOffer = false, errorMessage = e.message ?: "Failed to send deal offer") }
                }
        }
    }

    fun respondToDeal(message: ChatMessage, accept: Boolean) {
        val convId = conversationId ?: return
        val offerId = message.negotiation_data?.jsonObject?.get("deal_offer_id")?.jsonPrimitive?.contentOrNull ?: return
        if (!accept) {
            // Reject path is direct (mirrors iOS).
            viewModelScope.launch {
                runCatching { repository.respondToDealOffer(offerId, convId, accept = false) }
                    .onSuccess { refreshOfferStatus() }
                    .onFailure { e -> _uiState.update { it.copy(errorMessage = e.message ?: "Failed to reject offer") } }
            }
        } else {
            // Accept path goes through bKash.
            acceptAndPay(offerId)
        }
    }

    /**
     * Open the bKash sandbox checkout for a deal OFFER (the iOS "Accept & Pay"
     * path). The bKash webhook handles acceptance + deal creation server-side.
     * The actual Chrome Custom Tabs launch is done by the UI layer (which has
     * an Activity context). When the user returns to the app via the
     * `kajhobe://escrow-callback` deep link, [subscribeToDeepLinks] clears
     * `isPaying`.
     */
    fun acceptAndPay(dealOfferId: String) {
        _uiState.update { it.copy(isPaying = true, payError = null) }
        viewModelScope.launch {
            runCatching { paymentRepository.startCollection(dealOfferId) }
                .onSuccess { url ->
                    _uiState.update { it.copy(pendingBkashUrl = url) }
                }
                .onFailure { e ->
                    _uiState.update {
                        it.copy(
                            isPaying = false,
                            payError = e.message ?: "Could not start bKash checkout.",
                        )
                    }
                }
        }
    }

    /** Called by the UI after it has launched Chrome Custom Tabs for the URL. */
    fun onBkashCheckoutLaunched() {
        // Leave isPaying=true; the deep-link callback clears it.
    }

    fun sendImage(uri: String) {
        val convId = conversationId ?: return
        if (_uiState.value.isUploadingImage) return
        _uiState.update { it.copy(isUploadingImage = true, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                val url = mediaUploadManager.uploadChatImage(uri, convId)
                    ?: error("Image upload failed")
                repository.sendImageMessage(convId, url)
            }
                .onSuccess { sent ->
                    appendIfNew(sent)
                    _uiState.update { it.copy(isUploadingImage = false) }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isUploadingImage = false, errorMessage = e.message ?: "Failed to send photo") }
                }
        }
    }

    fun clearPayError() = _uiState.update { it.copy(payError = null) }

    fun clearPendingBkashUrl() = _uiState.update { it.copy(pendingBkashUrl = null) }

    @OptIn(DelicateCoroutinesApi::class)
    override fun onCleared() {
        super.onCleared()
        collectJob?.cancel()
        deepLinkJob?.cancel()
        val ch = channel ?: return
        channel = null
        // viewModelScope is cancelled here, so tear the channel down on a detached scope.
        GlobalScope.launch { runCatching { repository.leaveChannel(ch) } }
    }
}

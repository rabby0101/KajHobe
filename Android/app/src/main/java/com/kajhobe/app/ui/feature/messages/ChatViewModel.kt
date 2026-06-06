package com.kajhobe.app.ui.feature.messages

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.media.MediaUploadManager
import com.kajhobe.app.data.model.ChatMessage
import com.kajhobe.app.data.notifications.MessageBadgeManager
import com.kajhobe.app.data.repository.MessagesRepository
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
    // offerId → "pending" | "accepted" | "rejected", derived from deal_response messages.
    val dealStatuses: Map<String, String> = emptyMap(),
) {
    /** Only the service provider may send deal offers (iOS rule). */
    val isProvider: Boolean get() = currentUserId != null && currentUserId == providerId

    /** iOS canSendOffer: no existing deal, < 2 offers, no unanswered offer. */
    val canSendOffer: Boolean get() = !existingDealExists && offerCount < 2 && !hasUnansweredOffer
}

class ChatViewModel(
    private val repository: MessagesRepository,
    private val mediaUploadManager: MediaUploadManager,
    private val messageBadgeManager: MessageBadgeManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    private var conversationId: String? = null
    private var channel: RealtimeChannel? = null
    private var collectJob: Job? = null
    private var loaded = false

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
                }
                .onFailure { e -> _uiState.update { it.copy(isLoading = false, errorMessage = e.message) } }
            // Mark received messages read so the conversation-list unread badge clears.
            // The realtime UPDATE on the messages table fires MessageBadgeManager.handleUpdate()
            // and decrements the badge by one for each row updated. We deliberately do NOT
            // decrement locally here to avoid double-counting.
            runCatching { repository.markConversationRead(conversationId) }
            // Offer status (gates the deal button).
            refreshOfferStatus()
        }

        subscribe(conversationId)
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
        // Mark it read — the realtime UPDATE on the messages table will fire
        // MessageBadgeManager.handleUpdate() and decrement the badge. We deliberately
        // do NOT decrement locally here to avoid double-counting.
        if (wasNew) {
            val uid = _uiState.value.currentUserId
            if (msg.sender_id != uid && msg.read_at.isNullOrEmpty()) {
                viewModelScope.launch {
                    runCatching { repository.markConversationRead(msg.conversation_id) }
                }
            }
        }
    }

    /** Build offerId → status map from the conversation's deal_response messages. */
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
        viewModelScope.launch {
            runCatching { repository.respondToDealOffer(offerId, convId, accept) }
                .onSuccess { refreshOfferStatus() }
                .onFailure { e -> _uiState.update { it.copy(errorMessage = e.message ?: "Failed to respond to deal") } }
        }
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

    @OptIn(DelicateCoroutinesApi::class)
    override fun onCleared() {
        super.onCleared()
        collectJob?.cancel()
        val ch = channel ?: return
        channel = null
        // viewModelScope is cancelled here, so tear the channel down on a detached scope.
        GlobalScope.launch { runCatching { repository.leaveChannel(ch) } }
    }
}

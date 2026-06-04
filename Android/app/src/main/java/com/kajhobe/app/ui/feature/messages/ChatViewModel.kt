package com.kajhobe.app.ui.feature.messages

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.ChatMessage
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

data class ChatUiState(
    val isLoading: Boolean = true,
    val title: String = "Chat",
    val subtitle: String? = null,
    val messages: List<ChatMessage> = emptyList(),
    val draft: String = "",
    val isSending: Boolean = false,
    val currentUserId: String? = null,
    val errorMessage: String? = null,
)

class ChatViewModel(
    private val repository: MessagesRepository,
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
            // Initial messages.
            runCatching { repository.fetchMessages(conversationId) }
                .onSuccess { msgs -> _uiState.update { it.copy(isLoading = false, messages = msgs) } }
                .onFailure { e -> _uiState.update { it.copy(isLoading = false, errorMessage = e.message) } }
            // Mark received messages read so the conversation-list unread badge clears.
            runCatching { repository.markConversationRead(conversationId) }
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
        _uiState.update { state ->
            if (state.messages.any { it.id == msg.id }) state
            else state.copy(messages = state.messages + msg)
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

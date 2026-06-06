package com.kajhobe.app.ui.feature.messages

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.ConversationWithDetails
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

data class ConversationsUiState(
    val isLoading: Boolean = true,
    val conversations: List<ConversationWithDetails> = emptyList(),
    val currentUserId: String? = null,
    val errorMessage: String? = null,
)

class ConversationsViewModel(
    private val repository: MessagesRepository,
    private val messageBadgeManager: MessageBadgeManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ConversationsUiState())
    val uiState: StateFlow<ConversationsUiState> = _uiState.asStateFlow()

    private var channel: RealtimeChannel? = null
    private var collectJob: Job? = null

    init {
        load()
        subscribeRealtime()
        // Ensure the messages tab badge is in sync whenever the conversations list loads.
        messageBadgeManager.refreshCounts()
    }

    fun load() {
        _uiState.update { it.copy(isLoading = it.conversations.isEmpty(), errorMessage = null) }
        viewModelScope.launch {
            runCatching { repository.fetchConversations() }
                .onSuccess { list ->
                    _uiState.update {
                        it.copy(isLoading = false, conversations = list, currentUserId = repository.currentUserId())
                    }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isLoading = false, errorMessage = e.message ?: "Failed to load chats") }
                }
        }
    }

    /** Live updates: any new message in one of my conversations refreshes the list. */
    private fun subscribeRealtime() {
        val ch = repository.allMessagesChannel()
        channel = ch
        // Set up the flow BEFORE joining (supabase-kt requirement). The
        // `incomingAllMessages` call synchronously registers the listener via
        // `postgresChangeFlow`, so it must happen before any code calls
        // `channel.subscribe()`.
        val flow = repository.incomingAllMessages(ch)
        collectJob = viewModelScope.launch {
            // Any inserted message may change a preview/unread/order or add a new conversation.
            flow.collect { load() }
        }
        viewModelScope.launch { runCatching { repository.joinChannel(ch) } }
    }

    fun unreadFor(conversation: ConversationWithDetails): Int = repository.unreadFor(conversation)

    @OptIn(DelicateCoroutinesApi::class)
    override fun onCleared() {
        super.onCleared()
        collectJob?.cancel()
        val ch = channel ?: return
        channel = null
        GlobalScope.launch { runCatching { repository.leaveChannel(ch) } }
    }
}

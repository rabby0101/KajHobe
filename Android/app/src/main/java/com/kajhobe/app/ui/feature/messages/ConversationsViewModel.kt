package com.kajhobe.app.ui.feature.messages

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.ConversationWithDetails
import com.kajhobe.app.data.model.isArchivedFor
import com.kajhobe.app.data.model.isClient
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

/** Mirrors iOS ConversationFilter. */
enum class ConversationFilter { ALL, UNREAD }

data class ConversationsUiState(
    val isLoading: Boolean = true,
    val conversations: List<ConversationWithDetails> = emptyList(),
    val currentUserId: String? = null,
    val errorMessage: String? = null,
    // Redesign state — search text, active All/Unread pill, and the Archived sheet flag.
    val searchText: String = "",
    val selectedFilter: ConversationFilter = ConversationFilter.ALL,
    val showArchivedSheet: Boolean = false,
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
                        it.copy(
                            isLoading = false,
                            conversations = list,
                            currentUserId = repository.currentUserId(),
                        )
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

    // MARK: - Redesign actions

    fun onSearchTextChange(value: String) {
        _uiState.update { it.copy(searchText = value) }
    }

    fun onFilterChange(filter: ConversationFilter) {
        _uiState.update { it.copy(selectedFilter = filter) }
    }

    fun onShowArchivedSheetChange(open: Boolean) {
        _uiState.update { it.copy(showArchivedSheet = open) }
    }

    /**
     * Optimistically flip the current user's archive flag, then persist. On failure
     * we silently reload from the server to undo the optimistic change (matches
     * iOS MessagesView.setArchived).
     */
    fun setArchived(conversation: ConversationWithDetails, archived: Boolean) {
        val uid = _uiState.value.currentUserId ?: return
        val isClient = conversation.isClient(uid)
        val targetId = conversation.id

        _uiState.update { state ->
            state.copy(
                conversations = state.conversations.map { c ->
                    if (c.id != targetId) c
                    else c.copy(
                        client_archived = if (isClient) archived else c.client_archived,
                        provider_archived = if (!isClient) archived else c.provider_archived,
                    )
                },
            )
        }

        viewModelScope.launch {
            runCatching {
                repository.setConversationArchived(
                    conversationId = targetId,
                    userId = uid,
                    isClient = isClient,
                    archived = archived,
                )
            }.onFailure {
                // Silent revert — match iOS behavior.
                load()
            }
        }
    }

    // MARK: - Derived lists (iOS ConversationsView.split helpers)

    /** Active = not archived for the current user. Powers the main list. */
    val activeConversations: List<ConversationWithDetails>
        get() {
            val state = _uiState.value
            return state.conversations.filterNot { it.isArchivedFor(state.currentUserId) }
        }

    /** Archived = archived for the current user. Powers the Archived sheet. */
    val archivedConversations: List<ConversationWithDetails>
        get() {
            val state = _uiState.value
            return state.conversations.filter { it.isArchivedFor(state.currentUserId) }
        }

    /** Final list shown in the main list: active → filter pill → search. */
    val visibleConversations: List<ConversationWithDetails>
        get() {
            val state = _uiState.value
            var result = activeConversations
            if (state.selectedFilter == ConversationFilter.UNREAD) {
                result = result.filter { it.unread > 0 }
            }
            val query = state.searchText.trim().lowercase()
            if (query.isNotEmpty()) {
                result = result.filter { c ->
                    val title = c.job?.title.orEmpty().lowercase()
                    val otherName = otherNameFor(c, state.currentUserId).lowercase()
                    val preview = c.last_message?.content.orEmpty().lowercase()
                    title.contains(query) || otherName.contains(query) || preview.contains(query)
                }
            }
            return result
        }

    /** Unread-conversation count (for the Unread pill badge). */
    val unreadConversationCount: Int
        get() = activeConversations.count { it.unread > 0 }

    /** Other party name for a conversation (current user perspective). */
    fun otherNameFor(c: ConversationWithDetails, currentUserId: String?): String {
        val other = if (c.isClient(currentUserId)) c.provider_profile else c.client_profile
        return other?.full_name?.takeIf { it.isNotBlank() } ?: "KajHobe user"
    }

    @OptIn(DelicateCoroutinesApi::class)
    override fun onCleared() {
        super.onCleared()
        collectJob?.cancel()
        val ch = channel ?: return
        channel = null
        GlobalScope.launch { runCatching { repository.leaveChannel(ch) } }
    }
}

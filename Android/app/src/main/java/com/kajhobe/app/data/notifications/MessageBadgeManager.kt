package com.kajhobe.app.data.notifications

import com.kajhobe.app.data.model.ChatMessage
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.decodeRecord
import io.github.jan.supabase.realtime.postgresChangeFlow
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/**
 * Messages tab badge — total unread message count across all conversations for
 * the current user, kept fresh in real-time via the same `public:messages` channel
 * the conversation list uses. Android port of iOS `MessageBadgeManager`.
 */
class MessageBadgeManager(
    private val client: SupabaseClient,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val postgrest get() = client.postgrest
    private val auth get() = client.auth

    private val _totalUnreadCount = MutableStateFlow(0)
    val totalUnreadCount: StateFlow<Int> = _totalUnreadCount.asStateFlow()

    private var channel: RealtimeChannel? = null
    private var insertJob: Job? = null
    private var updateJob: Job? = null
    private var currentUserId: String? = null

    init {
        // Boot the realtime subscription as soon as the manager is created.
        // start() re-checks the user each time so the subscription is rebound on login.
        scope.launch { start() }
    }

    /**
     * (Re)bind the subscription to the current user. Safe to call on login.
     *
     * IMPORTANT ordering rule (supabase-kt): `postgresChangeFlow` MUST be called
     * before the channel is joined (`channel.subscribe()`). Calling it after a
     * channel with the same name has already been subscribed elsewhere will
     * throw `IllegalStateException: You cannot call postgresChangeFlow after
     * joining the channel`. Because `client.channel("public:messages")` is
     * de-duped by RealtimeImpl, the conversations view and this manager SHARE
     * the same channel — so we must register listeners BEFORE anyone else
     * subscribes.
     *
     * Strategy: this manager runs at app startup (Koin singleton), well before
     * the user opens the Messages tab. We register our listeners here and DO
     * NOT call `subscribe()` — that is the conversations view's job. As long
     * as our `postgresChangeFlow` calls run before the conversations view's
     * listener registration, the shared channel will join with all listeners
     * attached and the messages will flow to us.
     */
    suspend fun start() {
        val uid = auth.currentUserOrNull()?.id
        if (uid == null) {
            _totalUnreadCount.value = 0
            return
        }
        if (uid == currentUserId && channel != null) return // already bound
        currentUserId = uid

        // Tear down any prior subscription before rebuilding.
        stopInternal()

        // Initial count (one SELECT) — fire and forget.
        scope.launch { refreshCount() }

        val ch = client.channel("public:messages")
        channel = ch

        // Register BOTH listeners synchronously. `postgresChangeFlow` calls
        // `addPostgresChange` immediately at call time, so as long as we invoke
        // these BEFORE the channel is in SUBSCRIBED state, we're safe. The
        // conversations view will eventually call subscribe() — at that point
        // we'll already be wired up.
        val insertFlow = ch.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "messages"
        }
        val updateFlow = ch.postgresChangeFlow<PostgresAction.Update>(schema = "public") {
            table = "messages"
        }

        // Collect the two flows. Listeners are already attached at this point.
        insertJob = scope.launch {
            insertFlow.collect { action ->
                val msg = runCatching { action.decodeRecord<ChatMessage>() }.getOrNull() ?: return@collect
                handleInsert(msg)
            }
        }
        updateJob = scope.launch {
            updateFlow.collect { action ->
                val msg = runCatching { action.decodeRecord<ChatMessage>() }.getOrNull() ?: return@collect
                handleUpdate(msg)
            }
        }

        // NOTE: We do NOT call ch.subscribe() here. The ConversationsViewModel
        // owns the channel lifecycle for "public:messages" — calling subscribe
        // twice is a no-op, but it would also mean our listeners get registered
        // only AFTER someone else subscribes (a race). Leaving it to the
        // conversations view guarantees the order: register-listener → subscribe.
    }

    /** Stop the realtime subscription (e.g., on sign-out). */
    suspend fun stop() {
        currentUserId = null
        stopInternal()
        _totalUnreadCount.value = 0
    }

    /** Optimistic local decrement (used by the chat screen after marking messages read). */
    fun decrement(by: Int) {
        if (by <= 0) return
        _totalUnreadCount.update { (it - by).coerceAtLeast(0) }
    }

    /** Force a full re-fetch from the server. */
    fun refreshCounts() {
        scope.launch { refreshCount() }
    }

    private suspend fun refreshCount() {
        val uid = currentUserId ?: return
        runCatching {
            // Just selecting `id` is enough — we only care about the list size.
            postgrest.from("messages")
                .select(Columns.list("id")) {
                    filter { exact("read_at", null); neq("sender_id", uid) }
                }
                .decodeList<UnreadIdRow>()
                .size
        }.onSuccess { count ->
            _totalUnreadCount.value = count
        }
    }

    private fun handleInsert(msg: ChatMessage) {
        val uid = currentUserId ?: return
        // Only count messages from OTHER users; skip if it was already read.
        if (msg.sender_id == uid) return
        if (!msg.read_at.isNullOrEmpty()) return
        _totalUnreadCount.update { it + 1 }
    }

    private fun handleUpdate(msg: ChatMessage) {
        val uid = currentUserId ?: return
        // A previously-unread message from the other party just got a read_at → -1.
        // (We don't have the prior state here, so we only decrement when read_at is now set
        // and the sender is the other party — this matches the "marked as read" signal.)
        if (msg.sender_id == uid) return // we sent it; the recipient reading it has no badge effect
        if (msg.read_at.isNullOrEmpty()) return
        _totalUnreadCount.update { (it - 1).coerceAtLeast(0) }
    }

    private suspend fun stopInternal() {
        insertJob?.cancel(); insertJob = null
        updateJob?.cancel(); updateJob = null
        // We never subscribe the channel (the conversations view owns the
        // subscription lifecycle for "public:messages"), so there's nothing to
        // unsubscribe. We just drop our reference to the channel so the next
        // start() can re-register its listeners cleanly.
        channel = null
    }

    @Serializable
    private data class UnreadIdRow(val id: String? = null)
}

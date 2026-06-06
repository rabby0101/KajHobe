package com.kajhobe.app.data.notifications

import com.kajhobe.app.data.local.NotificationLocalState
import com.kajhobe.app.data.repository.NotificationsRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/**
 * Bell badge count — the Android port of iOS `NotificationBadgeManager`.
 *
 * Candidate rows (id + created_at only) are fetched from the server and cached; "unread" is
 * then derived purely from device-local read/cleared state ([NotificationLocalState]), so the
 * badge can recompute instantly (no network) when the user reads or clears items.
 *
 * unread = (pending interests on the user's own jobs) + (business notifications, excluding chat
 * / interest / superseded-offer types) that are locally unread.
 *
 * A real-time Supabase subscription on the user-specific notifications channel keeps the
 * candidates in sync without waiting for the next manual refresh.
 */
class NotificationBadgeManager(
    private val client: SupabaseClient,
    private val localState: NotificationLocalState,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val postgrest get() = client.postgrest
    private val auth get() = client.auth

    private val _unreadCount = MutableStateFlow(0)
    val unreadCount: StateFlow<Int> = _unreadCount.asStateFlow()

    @Serializable
    private data class Candidate(val id: String, val created_at: String? = null, val type: String? = null)

    @Volatile private var interestCandidates: List<Candidate> = emptyList()
    @Volatile private var businessCandidates: List<Candidate> = emptyList()

    private var channel: RealtimeChannel? = null
    private var realtimeJob: Job? = null
    private var currentUserId: String? = null

    init {
        // Recompute whenever local read/cleared state changes (a read/clear is cheap + instant).
        scope.launch { localState.revision.collect { recomputeFromLocal() } }
        // Boot real-time subscription. Rebinds on login.
        scope.launch { startRealtime() }
    }

    /** Re-fetch candidate rows from the server, then derive the count from local state. */
    fun refreshCounts() {
        scope.launch { refreshCountsInternal() }
    }

    private suspend fun refreshCountsInternal() {
        val uid = auth.currentUserOrNull()?.id ?: return
        currentUserId = uid
        localState.configure(uid)

        // Interest candidates: pending interests on the user's OWN jobs.
        interestCandidates = runCatching {
            postgrest.from("job_interests")
                .select(Columns.raw("id, created_at, jobs!inner(client_id)")) {
                    filter {
                        eq("jobs.client_id", uid)
                        eq("status", "pending")
                    }
                }
                .decodeList<Candidate>()
        }.getOrDefault(emptyList())

        // Business candidates: notifications addressed to the user, excluding chat, interest
        // (already counted via job_interests) and superseded offer types. The exclusion is
        // applied client-side (see NotificationsRepository.EXCLUDED_BUSINESS_TYPES) because
        // supabase-kt does not reliably AND the `neq` filters with the `or(...)` group.
        businessCandidates = runCatching {
            postgrest.from("notifications")
                .select(Columns.raw("id, created_at, type")) {
                    filter { or { eq("to_user_id", uid); eq("user_id", uid) } }
                }
                .decodeList<Candidate>()
                .filterNot { it.type in NotificationsRepository.EXCLUDED_BUSINESS_TYPES }
        }.getOrDefault(emptyList())

        recomputeFromLocal()
    }

    /** Recompute the badge from cached candidates + local read/cleared state. Cheap. */
    fun recomputeFromLocal() {
        val unreadInterests = interestCandidates.count { localState.isUnread(it.id, it.created_at) }
        val unreadBusiness = businessCandidates.count { localState.isUnread(it.id, it.created_at) }
        _unreadCount.value = unreadInterests + unreadBusiness
    }

    /**
     * Subscribe to a per-user notifications channel so the badge updates the moment
     * the server inserts a new row for this user. iOS does the same thing on
     * `notifications_{userId}`. We re-fetch on every change — the candidate cache
     * is small and the recompute is purely local, so this is cheap.
     *
     * IMPORTANT: `postgresChangeFlow` MUST be called before the channel is joined
     * (supabase-kt throws if you try to add a listener after `subscribe()`).
     */
    private suspend fun startRealtime() {
        val uid = auth.currentUserOrNull()?.id ?: return
        if (uid == currentUserId && channel != null) return
        currentUserId = uid

        stopRealtime()

        val ch = client.channel("notifications_$uid")
        channel = ch

        // Register the listener SYNCHRONOUSLY (before subscribe).
        val changeFlow = ch.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "notifications"
        }
        realtimeJob = scope.launch {
            changeFlow.collect { refreshCounts() }
        }

        // Join the channel LAST, after the listener is attached.
        runCatching { ch.subscribe() }
    }

    /** Tear down the real-time subscription (e.g., on sign-out). */
    fun stop() {
        currentUserId = null
        stopRealtime()
    }

    private fun stopRealtime() {
        realtimeJob?.cancel(); realtimeJob = null
        val ch = channel ?: return
        channel = null
        scope.launch {
            runCatching { ch.unsubscribe() }
            runCatching { client.realtime.removeChannel(ch) }
        }
    }
}

package com.kajhobe.app.data.dashboard

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.launch
import kotlinx.coroutines.plus

/**
 * Wraps a single Supabase realtime V2 channel for the dashboard, listening to
 * `deals`, `deal_completion_requests`, `deal_offers`, and `jobs`. Any change
 * emits on [events] so the screen can refresh.
 *
 * Mirrors iOS `setupRealtimeSubscription` (DashboardView.swift:461-561).
 * The channel id includes uid + epoch ms so two concurrent subscriptions don't
 * collide on the Supabase backend.
 */
class DashboardRealtime(private val client: SupabaseClient) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var channel: RealtimeChannel? = null
    private var collectorJob: Job? = null

    private val _events = MutableSharedFlow<Unit>(replay = 0, extraBufferCapacity = 16)
    val events: SharedFlow<Unit> = _events.asSharedFlow()

    /**
     * Subscribe to all four tables. If a previous subscription is active it's
     * unsubscribed first. [onEvent] is invoked once per change.
     */
    fun subscribe(userId: String) {
        unsubscribe()
        val channelId = "dashboard:$userId:${System.currentTimeMillis()}"
        val ch = client.channel(channelId)
        channel = ch

        // Register ALL four listeners synchronously. `postgresChangeFlow` MUST
        // be called before the channel is joined (supabase-kt ordering rule).
        val dealsFlow = ch.postgresChangeFlow<PostgresAction>(schema = "public") { table = "deals" }
        val completionFlow = ch.postgresChangeFlow<PostgresAction>(schema = "public") { table = "deal_completion_requests" }
        val offersFlow = ch.postgresChangeFlow<PostgresAction>(schema = "public") { table = "deal_offers" }
        val jobsFlow = ch.postgresChangeFlow<PostgresAction>(schema = "public") { table = "jobs" }

        collectorJob = scope.launch {
            merge(dealsFlow, completionFlow, offersFlow, jobsFlow).collect {
                _events.tryEmit(Unit)
            }
        }

        scope.launch { runCatching { ch.subscribe() } }
    }

    /** Cancel the coroutine and remove the channel. Idempotent. */
    fun unsubscribe() {
        collectorJob?.cancel()
        collectorJob = null
        channel?.let { ch ->
            scope.launch { runCatching { client.realtime.removeChannel(ch) } }
        }
        channel = null
    }
}

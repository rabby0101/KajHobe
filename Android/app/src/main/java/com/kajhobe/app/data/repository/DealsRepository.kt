package com.kajhobe.app.data.repository

import com.kajhobe.app.data.model.CompletionRequest
import com.kajhobe.app.data.model.CompletionRequestInsert
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.Deal
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.exception.PostgrestRestException
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.rpc
import java.time.Instant
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Deals, dashboard, and completion flow — mirrors iOS DealsNetworking. */
class DealsRepository(client: SupabaseClient) : BaseRepository(client) {

    private val dealJoins = Columns.raw(
        "*, job:jobs!job_id(*), " +
            "client_profile:profiles!deals_client_id_fkey(*), " +
            "provider_profile:profiles!deals_provider_id_fkey(*)",
    )

    /**
     * Dashboard summary (iOS fetchDashboardData): tries the get_user_dashboard_data RPC,
     * falls back to manual counts. Always returns data (never throws) to protect the UI.
     */
    suspend fun fetchDashboardData(): DashboardData {
        val uid = currentUserId ?: return emptyDashboard()
        return runCatching {
            postgrest.rpc("get_user_dashboard_data", buildJsonObject { put("user_id", uid) })
                .decodeList<DashboardData>()
                .firstOrNull()
        }.getOrNull() ?: runCatching { manualDashboard(uid) }.getOrDefault(emptyDashboard())
    }

    private suspend fun manualDashboard(uid: String): DashboardData {
        val active = countDeals(uid, "active")
        val completed = countDeals(uid, "completed")
        return DashboardData(
            user_type = "client",
            active_deals_count = active,
            completed_deals_count = completed,
            pending_completion_requests = 0,
            total_earnings = 0.0,
            total_spent = 0.0,
            average_rating = 0.0,
            recent_deals = null,
        )
    }

    private suspend fun countDeals(uid: String, status: String): Int =
        runCatching {
            postgrest.from("deals")
                .select {
                    filter {
                        or { eq("client_id", uid); eq("provider_id", uid) }
                        eq("status", status)
                    }
                }
                .decodeList<Deal>()
                .size
        }.getOrDefault(0)

    private fun emptyDashboard() = DashboardData(
        user_type = "client",
        active_deals_count = 0,
        completed_deals_count = 0,
        pending_completion_requests = 0,
        total_earnings = 0.0,
        total_spent = 0.0,
        average_rating = 0.0,
        recent_deals = null,
    )

    /** Current authenticated user id (exposes the protected base accessor to view models). */
    fun currentUid(): String? = currentUserId

    /** Active/in-progress deals for the user, with job + both profiles joined. */
    suspend fun fetchActiveDeals(): List<Deal> {
        val uid = currentUserId ?: return emptyList()
        return postgrest.from("deals")
            .select(dealJoins) {
                filter {
                    or { eq("client_id", uid); eq("provider_id", uid) }
                    isIn("status", listOf("active", "in_progress"))
                }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Deal>()
    }

    suspend fun fetchMyDeals(): List<Deal> {
        val uid = currentUserId ?: return emptyList()
        return postgrest.from("deals")
            .select(dealJoins) {
                filter { or { eq("client_id", uid); eq("provider_id", uid) } }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Deal>()
    }

    /** Completion requests awaiting the current user's response. */
    suspend fun fetchPendingCompletionRequests(): List<CompletionRequest> {
        val uid = currentUserId ?: return emptyList()
        return runCatching {
            postgrest.from("completion_requests")
                .select(
                    Columns.raw("*, deals(*, job:jobs(*)), requester_profile:profiles!completion_requests_requester_id_fkey(*)"),
                ) {
                    filter { eq("status", "pending") }
                    order("created_at", Order.DESCENDING)
                }
                .decodeList<CompletionRequest>()
                // Only requests where the current user is the counterparty (not the requester).
                .filter { it.requester_id != uid }
        }.getOrDefault(emptyList())
    }

    /** Request completion of a deal (iOS requestTaskCompletion). */
    suspend fun requestTaskCompletion(dealId: String, requesterType: String, message: String?): CompletionRequest {
        return try {
            postgrest.from("completion_requests")
                .insert(
                    CompletionRequestInsert(
                        deal_id = dealId,
                        requester_id = currentUserId ?: "",
                        requester_type = requesterType,
                        request_message = message,
                    ),
                ) { select() }
                .decodeSingle<CompletionRequest>()
        } catch (e: PostgrestRestException) {
            // Postgres unique_violation (23505) on completion_requests_one_pending_per_deal
            // means the other party already filed a pending request for this deal.
            if (e.message?.contains("completion_requests_one_pending_per_deal") == true ||
                e.message?.contains("duplicate key value") == true
            ) {
                throw CompletionRequestAlreadyPendingException(dealId, e)
            }
            throw e
        }
    }

    /** Approve/reject a completion request (iOS respondToCompletionRequest).
     *
     * Mirrors `iOS/KajHobe/DealsNetworking.swift:497-501` and `:527-540`:
     *  * On approve, also UPDATE `deals` directly to `status='completed'`,
     *    `completed_at=now()` (iOS writes the deal row directly; Android used
     *    to rely on the DB trigger, but doing both ensures parity and protects
     *    against drift if the trigger is missing in some env).
     *  * On reject, also UPDATE `deals` back to `status='active'`,
     *    `completion_status='in_progress'`, clearing the per-party completion
     *    flags and their timestamps.
     */
    suspend fun respondToCompletionRequest(requestId: String, approve: Boolean, message: String?) {
        val uid = currentUserId ?: return
        val status = if (approve) "approved" else "rejected"
        val now = Instant.now().toString()
        postgrest.from("completion_requests").update({
            set("status", status)
            set("responded_by", uid)
            set("responded_at", now)
            message?.let { set("response_message", it) }
        }) { filter { eq("id", requestId) } }

        // Find the deal_id from the just-responded request, then write the
        // deal row directly so both clients converge on the same state without
        // waiting for the trigger.
        val dealId = runCatching {
            postgrest.from("completion_requests")
                .select { filter { eq("id", requestId) } }
                .decodeSingle<CompletionRequest>()
                .deal_id
        }.getOrNull() ?: return

        if (approve) {
            runCatching {
                postgrest.from("deals").update({
                    set("status", "completed")
                    set("completed_at", now)
                }) { filter { eq("id", dealId) } }
            }
        } else {
            runCatching {
                // The DB trigger `update_deal_completion_status` already resets
                // deal status on a `rejected` completion_request. We additionally
                // write the flags here so the UI re-renders immediately on both
                // clients without waiting for the realtime echo. Mirrors
                // iOS `DealsNetworking.swift:527-540`.
                postgrest.from("deals").update({
                    set("status", "active")
                    set("completion_status", "in_progress")
                    set("client_completion_requested", false)
                    set("provider_completion_requested", false)
                }) { filter { eq("id", dealId) } }
                // Cleared timestamps go through a raw update via raw value
                // (the Kotlin DSL's set() doesn't accept nullable directly).
                postgrest.from("deals").update(
                    mapOf(
                        "client_completion_requested_at" to null as Any?,
                        "provider_completion_requested_at" to null as Any?,
                    ),
                ) { filter { eq("id", dealId) } }
            }
        }
    }
}

/**
 * Thrown when the user tries to file a completion request for a deal that
 * already has a pending request (from the other party). Mapped from the
 * `completion_requests_one_pending_per_deal` unique-index violation (SQLSTATE 23505).
 */
class CompletionRequestAlreadyPendingException(
    val dealId: String,
    cause: Throwable,
) : Exception("A completion request is already pending for this deal", cause)

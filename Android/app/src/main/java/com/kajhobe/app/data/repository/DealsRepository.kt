package com.kajhobe.app.data.repository

import com.kajhobe.app.data.model.CompletionRequest
import com.kajhobe.app.data.model.CompletionRequestInsert
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.Deal
import io.github.jan.supabase.SupabaseClient
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
    suspend fun requestTaskCompletion(dealId: String, requesterType: String, message: String?): CompletionRequest =
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

    /** Approve/reject a completion request (iOS respondToCompletionRequest). */
    suspend fun respondToCompletionRequest(requestId: String, approve: Boolean, message: String?) {
        val uid = currentUserId ?: return
        postgrest.from("completion_requests").update({
            set("status", if (approve) "approved" else "rejected")
            set("responded_by", uid)
            set("responded_at", Instant.now().toString())
            message?.let { set("response_message", it) }
        }) { filter { eq("id", requestId) } }
    }
}

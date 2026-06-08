package com.kajhobe.app.data.repository

import com.kajhobe.app.data.model.EnhancedNotification
import com.kajhobe.app.data.model.EnrichedJobInterest
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.data.model.JobInterest
import com.kajhobe.app.data.model.Profile
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import java.time.Instant
import kotlinx.serialization.Serializable

/** Notifications + interest requests — mirrors iOS NotificationsNetworking. */
class NotificationsRepository(client: SupabaseClient) : BaseRepository(client) {

    companion object {
        /**
         * Notification types kept OUT of the business feed (iOS `fetchBusinessNotifications`):
         * chat lives in Messages; `interest_request`/`show_interest` duplicate the `job_interests`
         * row already shown as an Interest card; the offer types are superseded by `deal_created`.
         * Applied client-side because supabase-kt does not reliably AND these `neq` filters with
         * the `or(to_user_id,user_id)` group.
         */
        val EXCLUDED_BUSINESS_TYPES = setOf(
            "message_received",
            "show_interest",
            "interest_request",
            "deal_offer_received",
            "deal_offer_responded",
        )
    }

    @Serializable
    private data class ConversationInsert(
        val job_id: String,
        val client_id: String,
        val provider_id: String,
        val status: String,
    )

    @Serializable
    private data class ConvIdRow(val id: String)

    /**
     * Pending interest requests on the current user's jobs (iOS fetchEnrichedJobInterests),
     * done in 3 batched queries instead of the iOS N+1 loop.
     */
    suspend fun fetchEnrichedJobInterests(): List<EnrichedJobInterest> {
        val uid = currentUserId ?: return emptyList()

        val pending = postgrest.from("job_interests")
            .select {
                filter { eq("status", "pending") }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<JobInterest>()
        if (pending.isEmpty()) return emptyList()

        // Only interests on jobs owned by the current user.
        val myJobs = postgrest.from("jobs")
            .select { filter { eq("client_id", uid) } }
            .decodeList<Job>()
            .associateBy { it.id }

        val relevant = pending.filter { it.job_id in myJobs }
        if (relevant.isEmpty()) return emptyList()

        val providerIds = relevant.map { it.provider_id }.distinct()
        val providers = postgrest.from("profiles")
            .select { filter { isIn("id", providerIds) } }
            .decodeList<Profile>()
            .associateBy { it.id }

        return relevant.map { interest ->
            val job = myJobs[interest.job_id]
            val provider = providers[interest.provider_id]
            EnrichedJobInterest(
                id = interest.id,
                job_id = interest.job_id,
                provider_id = interest.provider_id,
                status = interest.status,
                message = interest.message,
                created_at = interest.created_at,
                actioned_at = interest.actioned_at,
                job_title = job?.title ?: "Your job",
                job_client_id = job?.client_id ?: uid,
                job_budget = job?.budget,
                job_location = job?.location,
                provider_name = provider?.full_name,
                provider_avatar_url = provider?.avatar_url,
                provider_rating = provider?.average_rating,
            )
        }
    }

    /**
     * All interest requests on the current user's jobs — **every** status, newest first — so
     * the unified feed can show accepted/rejected ones as dulled rows with a status pill (the
     * badge still counts only pending, via [fetchEnrichedJobInterests]). Mirrors the iOS
     * interest-feed fetch (`jobs!inner(...)`, `eq jobs.client_id = uid`).
     */
    suspend fun fetchInterestsForFeed(): List<EnrichedJobInterest> {
        val uid = currentUserId ?: return emptyList()

        val interests = runCatching {
            postgrest.from("job_interests")
                .select(Columns.raw("*, jobs!inner(client_id)")) {
                    filter { eq("jobs.client_id", uid) }
                    order("created_at", Order.DESCENDING)
                }
                .decodeList<JobInterest>()
        }.getOrDefault(emptyList())
        if (interests.isEmpty()) return emptyList()

        val jobs = runCatching {
            postgrest.from("jobs")
                .select { filter { isIn("id", interests.map { it.job_id }.distinct()) } }
                .decodeList<Job>()
                .associateBy { it.id }
        }.getOrDefault(emptyMap())

        val providers = runCatching {
            postgrest.from("profiles")
                .select { filter { isIn("id", interests.map { it.provider_id }.distinct()) } }
                .decodeList<Profile>()
                .associateBy { it.id }
        }.getOrDefault(emptyMap())

        return interests.map { interest ->
            val job = jobs[interest.job_id]
            val provider = providers[interest.provider_id]
            EnrichedJobInterest(
                id = interest.id,
                job_id = interest.job_id,
                provider_id = interest.provider_id,
                status = interest.status,
                message = interest.message,
                created_at = interest.created_at,
                actioned_at = interest.actioned_at,
                job_title = job?.title ?: "Your job",
                job_client_id = job?.client_id ?: uid,
                job_budget = job?.budget,
                job_location = job?.location,
                provider_name = provider?.full_name,
                provider_avatar_url = provider?.avatar_url,
                provider_rating = provider?.average_rating,
            )
        }
    }

    /** Current authenticated user id (exposes the protected base accessor to view models). */
    fun currentUid(): String? = currentUserId

    /**
     * Enhanced notifications addressed to the current user (informational feed).
     * Excludes the same types as iOS `fetchBusinessNotifications`: chat lives in Messages,
     * interest requests come from `job_interests`, and the offer types are superseded by
     * `deal_created` — so a single event is never shown twice.
     */
    suspend fun fetchEnhancedNotifications(): List<EnhancedNotification> {
        val uid = currentUserId ?: return emptyList()
        return runCatching {
            postgrest.from("notifications")
                .select {
                    filter { or { eq("to_user_id", uid); eq("user_id", uid) } }
                    order("created_at", Order.DESCENDING)
                    limit(80)
                }
                .decodeList<EnhancedNotification>()
                .filterNot { it.type in EXCLUDED_BUSINESS_TYPES }
        }.getOrDefault(emptyList())
    }

    /**
     * Accept/reject an interest (iOS respondToInterest). Updates the interest status and,
     * on accept, creates a conversation between client and provider if none exists.
     * Returns the conversation id on accept (or null).
     */
    suspend fun respondToInterest(interest: EnrichedJobInterest, accept: Boolean): String? {
        val uid = currentUserId ?: return null
        val status = if (accept) "accepted" else "rejected"

        postgrest.from("job_interests").update({
            set("status", status)
            set("actioned_at", Instant.now().toString())
        }) { filter { eq("id", interest.id) } }

        if (!accept) return null

        // Re-use an existing conversation if present.
        val existing = postgrest.from("conversations")
            .select(Columns.list("id")) {
                filter {
                    eq("job_id", interest.job_id)
                    eq("client_id", uid)
                    eq("provider_id", interest.provider_id)
                }
                limit(1)
            }
            .decodeList<ConvIdRow>()
            .firstOrNull()
        if (existing != null) return existing.id

        return postgrest.from("conversations")
            .insert(
                ConversationInsert(
                    job_id = interest.job_id,
                    client_id = uid,
                    provider_id = interest.provider_id,
                    status = "active",
                ),
            ) { select(Columns.list("id")) }
            .decodeSingle<ConvIdRow>()
            .id
    }

    /** Count of pending interest requests — drives the tab badge. */
    suspend fun pendingInterestCount(): Int =
        runCatching { fetchEnrichedJobInterests().size }.getOrDefault(0)
}

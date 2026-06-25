package com.kajhobe.app.data.repository

import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.PublicProfile
import com.kajhobe.app.data.model.PublicProfileSummary
import com.kajhobe.app.data.model.ServiceHighlight
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.exception.PostgrestRestException
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.Serializable

/**
 * Public-profile lookup. Backed by the `public_profiles` SQL view (the same source
 * the iOS in-app bell's `loadProviderProfile(providerId:)` reads from) so the
 * destination screen shows pre-computed stats: completed_jobs, avg_rating, total
 * earnings, trust level, service categories.
 *
 * Mirrors iOS `KajHobe/NotificationsView.swift:1581-1675` and `PublicProfileView.swift:181-209`.
 */
open class ProfilePublicRepository(client: SupabaseClient) : BaseRepository(client) {

    /**
     * Fetch a single public profile by user id. Returns null if the row is missing
     * (mirrors the iOS "Profile not found" branch).
     */
    open suspend fun fetchPublicProfile(userId: String): PublicProfile? {
        if (userId.isBlank()) return null
        return runCatching {
            postgrest.from("public_profiles")
                .select { filter { eq("id", userId.lowercase()) } }
                .decodeSingleOrNull<PublicProfile>()
        }.getOrNull()
    }

    open suspend fun fetchPublicProfileSummaries(
        providerIds: List<String>,
    ): Map<String, PublicProfileSummary> {
        if (providerIds.isEmpty()) return emptyMap()
        return runCatching {
            postgrest.from("public_profiles")
                .select(
                    columns = Columns.list(
                        "id", "full_name", "avatar_url", "trust_level",
                        "completed_jobs", "avg_rating", "is_online",
                    ),
                ) {
                    filter { isIn("id", providerIds) }
                }
                .decodeList<PublicProfileSummary>()
                .associateBy { it.id }
        }.getOrDefault(emptyMap())
    }

    open suspend fun fetchServiceHighlights(
        providerId: String,
    ): List<ServiceHighlight> {
        if (providerId.isBlank()) return emptyList()
        val profile = runCatching { fetchPublicProfile(providerId) }.getOrNull() ?: return emptyList()
        val categories = profile.topServiceCategories
        if (categories.isEmpty()) return emptyList()
        return categories.map { category ->
            ServiceHighlight(
                category = category,
                job_count = profile.completed_jobs,
                avg_rating = profile.avg_rating.takeIf { it > 0 },
                recent_completion = profile.last_updated,
                avg_job_value = profile.avg_job_value.takeIf { it > 0 },
            )
        }
    }

    open suspend fun fetchReviews(
        providerId: String,
        limit: Int = 20,
    ): List<ProviderReview> {
        if (providerId.isBlank()) return emptyList()
        val rows = runCatching {
            postgrest.from("reviews")
                .select(columns = Columns.list("id", "rating", "comment", "created_at", "reviewer_id")) {
                    order("created_at", Order.DESCENDING)
                    limit(limit.toLong())
                    filter {
                        eq("reviewed_id", providerId)
                    }
                }
                .decodeList<ReviewRow>()
        }.getOrDefault(emptyList())
        if (rows.isEmpty()) return emptyList()

        val reviewerIds = rows.mapNotNull { it.reviewer_id }.distinct()
        val summaries = fetchPublicProfileSummaries(reviewerIds)
        return rows.map { row ->
            val summary = row.reviewer_id?.let { summaries[it] }
            ProviderReview(
                id = row.id,
                rating = row.rating,
                comment = row.comment,
                created_at = row.created_at,
                reviewer_name = summary?.full_name,
                reviewer_avatar = summary?.avatar_url,
            )
        }
    }

    /**
     * Submit a review for [reviewedId] on [jobId] — iOS `PublicProfileNetworking.submitReview`.
     * The DB enforces UNIQUE(job_id, reviewer_id, reviewed_id) and an RLS policy that only
     * allows inserts while the job's status is 'completed'; both are mapped to typed errors
     * so the sheet can show a friendly message.
     */
    open suspend fun submitReview(jobId: String, reviewedId: String, rating: Int, comment: String?) {
        val uid = currentUserId ?: throw IllegalStateException("Not signed in")
        try {
            postgrest.from("reviews").insert(
                ReviewInsert(
                    job_id = jobId,
                    reviewer_id = uid,
                    reviewed_id = reviewedId.lowercase(),
                    rating = rating.coerceIn(1, 5),
                    comment = comment?.trim()?.takeIf { it.isNotBlank() },
                ),
            )
        } catch (e: PostgrestRestException) {
            val msg = e.message.orEmpty()
            when {
                msg.contains("duplicate key value") -> throw AlreadyReviewedException(e)
                msg.contains("row-level security") -> throw JobNotCompletedException(e)
                else -> throw e
            }
        }
    }

    /** Whether the current user already reviewed [reviewedId] for [jobId]. */
    open suspend fun hasReviewed(jobId: String, reviewedId: String): Boolean {
        val uid = currentUserId ?: return false
        return runCatching {
            postgrest.from("reviews")
                .select(Columns.list("id")) {
                    filter {
                        eq("job_id", jobId)
                        eq("reviewer_id", uid)
                        eq("reviewed_id", reviewedId.lowercase())
                    }
                    limit(1)
                }
                .decodeList<ReviewIdRow>()
                .isNotEmpty()
        }.getOrDefault(false)
    }

    @Serializable
    private data class ReviewRow(
        val id: String,
        val rating: Int,
        val comment: String? = null,
        val created_at: String? = null,
        val reviewer_id: String? = null,
    )

    @Serializable
    private data class ReviewIdRow(val id: String)

    @Serializable
    private data class ReviewInsert(
        val job_id: String,
        val reviewer_id: String,
        val reviewed_id: String,
        val rating: Int,
        val comment: String? = null,
    )
}

/** The (job, reviewer, reviewed) triple already has a review — UNIQUE violation 23505. */
class AlreadyReviewedException(cause: Throwable) :
    Exception("You've already reviewed this person for this job.", cause)

/** RLS refused the insert — the job isn't marked completed (yet). */
class JobNotCompletedException(cause: Throwable) :
    Exception("Reviews can be left once the job is completed.", cause)

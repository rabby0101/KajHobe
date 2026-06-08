package com.kajhobe.app.data.repository

import com.kajhobe.app.data.cache.CachedJobs
import com.kajhobe.app.data.cache.JobsCache
import com.kajhobe.app.data.model.Bid
import com.kajhobe.app.data.model.BidInsert
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.data.model.JobInsert
import com.kajhobe.app.data.model.MediaItem
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.Serializable

/** Jobs + bids + interest — mirrors iOS JobsNetworking. */
class JobsRepository(
    client: SupabaseClient,
    private val cache: JobsCache,
) : BaseRepository(client) {

    @Serializable
    private data class JobIdRow(val job_id: String)

    /** Public accessor for the signed-in user id (UI uses it to hide "New" on own jobs). */
    fun currentUserIdOrNull(): String? = currentUserId

    /**
     * Open jobs not yet tied to a deal (iOS JobsNetworking.fetchJobs).
     * Fetch open jobs + the set of job_ids that already have a deal, then filter client-side.
     */
    suspend fun fetchJobs(): List<Job> {
        val openJobs = postgrest.from("jobs")
            .select {
                filter { eq("status", "open") }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Job>()

        val jobIdsWithDeals = runCatching {
            postgrest.from("deals")
                .select(Columns.list("job_id")) {
                    filter { isIn("status", HIDDEN_DEAL_STATUSES.toList()) }
                }
                .decodeList<JobIdRow>()
                .map { it.job_id }
                .toSet()
        }.getOrDefault(emptySet())

        return openJobs.filter { it.id !in jobIdsWithDeals }
    }

    /** Jobs posted by the signed-in user. */
    suspend fun fetchMyJobs(): List<Job> {
        val uid = currentUserId ?: return emptyList()
        return postgrest.from("jobs")
            .select {
                filter { eq("client_id", uid) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Job>()
    }

    /** Create a new job posting (iOS PostJobView submit). Returns the created job. */
    suspend fun createJob(
        title: String,
        description: String,
        category: String,
        location: String,
        budget: Int,
        urgent: Boolean,
        mediaUrls: List<MediaItem>? = null,
    ): Job {
        val insert = JobInsert(
            title = title.trim(),
            description = description.trim(),
            category = category,
            location = location,
            status = "open",
            urgent = urgent,
            client_id = currentUserId ?: "",
            budget = budget,
            media_urls = mediaUrls,
        )
        return postgrest.from("jobs").insert(insert) { select() }.decodeSingle<Job>()
    }

    suspend fun fetchJob(jobId: String): Job? =
        postgrest.from("jobs")
            .select { filter { eq("id", jobId) } }
            .decodeSingleOrNull<Job>()

    suspend fun deleteJob(jobId: String) {
        val uid = currentUserId ?: return
        postgrest.from("jobs").delete {
            filter {
                eq("id", jobId)
                eq("client_id", uid) // RLS-safe: only own jobs
            }
        }
    }

    suspend fun fetchBids(jobId: String): List<Bid> =
        postgrest.from("bids")
            .select {
                filter { eq("job_id", jobId) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Bid>()

    suspend fun createBid(jobId: String, amount: Int, message: String?): Bid =
        postgrest.from("bids")
            .insert(BidInsert(job_id = jobId, provider_id = currentUserId ?: "", amount = amount, message = message, status = "pending"))
            { select() }
            .decodeSingle<Bid>()

    /** Application/bid status for the current provider on a job. */
    suspend fun applicationStatus(jobId: String): String? {
        val uid = currentUserId ?: return null
        return postgrest.from("bids")
            .select(Columns.list("status")) {
                filter { eq("job_id", jobId); eq("provider_id", uid) }
                limit(1)
            }
            .decodeList<StatusRow>()
            .firstOrNull()?.status
    }

    @Serializable
    private data class StatusRow(val status: String? = null)

    // MARK: - Interest

    /** Whether the current provider has already shown interest in this job. */
    suspend fun hasShownInterest(jobId: String): Boolean {
        val uid = currentUserId ?: return false
        return postgrest.from("job_interests")
            .select(Columns.list("id")) {
                filter { eq("job_id", jobId); eq("provider_id", uid) }
                limit(1)
            }
            .decodeList<IdRow>()
            .isNotEmpty()
    }

    @Serializable
    private data class IdRow(val id: String)

    @Serializable
    private data class JobInterestInsert(
        val job_id: String,
        val provider_id: String,
        val message: String,
        val status: String = "pending",
    )

    /**
     * Show interest in a job with an optional message (iOS showInterestWithMessage →
     * job_interests insert; the message is stored in job_interests.message).
     */
    suspend fun showInterest(jobId: String, message: String = DEFAULT_INTEREST_MESSAGE) {
        val uid = currentUserId ?: return
        val text = message.trim().ifBlank { DEFAULT_INTEREST_MESSAGE }
        postgrest.from("job_interests")
            .insert(JobInterestInsert(job_id = jobId, provider_id = uid, message = text))
    }

    // MARK: - Job views ("New" indicator, mirrors iOS job_views table)

    /** Job ids the current user has already opened. Empty if signed out / on error. */
    suspend fun fetchViewedJobIds(): Set<String> {
        val uid = currentUserId ?: return emptySet()
        return runCatching {
            postgrest.from("job_views")
                .select(Columns.list("job_id")) {
                    filter { eq("user_id", uid) }
                }
                .decodeList<JobIdRow>()
                .map { it.job_id }
                .toSet()
        }.getOrDefault(emptySet())
    }

    /**
     * Job ids the current user has shown interest in (iOS job_interests, provider side).
     * Drives the "Interested" status pill. Empty if signed out / on error.
     */
    suspend fun fetchInterestedJobIds(): Set<String> {
        val uid = currentUserId ?: return emptySet()
        return runCatching {
            postgrest.from("job_interests")
                .select(Columns.list("job_id")) {
                    filter { eq("provider_id", uid) }
                }
                .decodeList<JobIdRow>()
                .map { it.job_id }
                .toSet()
        }.getOrDefault(emptySet())
    }

    @Serializable
    private data class JobViewInsert(
        val job_id: String,
        val user_id: String,
        val viewed_at: String,
    )

    /**
     * Record that the current user opened a job (iOS markJobAsViewed → job_views).
     * Check-then-insert so repeated opens don't create duplicate rows or hit a
     * duplicate-key error regardless of the table's unique constraints.
     */
    suspend fun recordJobView(jobId: String) {
        val uid = currentUserId ?: return
        runCatching {
            val alreadyViewed = postgrest.from("job_views")
                .select(Columns.list("job_id")) {
                    filter { eq("job_id", jobId); eq("user_id", uid) }
                    limit(1)
                }
                .decodeList<JobIdRow>()
                .isNotEmpty()
            if (!alreadyViewed) {
                postgrest.from("job_views").insert(
                    JobViewInsert(
                        job_id = jobId,
                        user_id = uid,
                        viewed_at = java.time.Instant.now().toString(),
                    ),
                )
            }
        }
    }

    // MARK: - Cache (disk + memory, seamless seeding)

    /** Synchronous in-memory cached snapshot for instant first paint (null on cold start). */
    fun cachedSnapshot(): CachedJobs? = cache.peek()

    /** In-memory snapshot, or read from disk (DataStore) — for cold-start seeding. */
    suspend fun warmCache(): CachedJobs? = cache.load()

    /** Fetch jobs + viewed ids + interested ids in one go and persist to cache. */
    suspend fun loadJobsAndViews(): CachedJobs {
        val jobs = fetchJobs()
        val viewed = fetchViewedJobIds()
        val interested = fetchInterestedJobIds()
        cache.save(jobs, viewed, interested)
        return CachedJobs(jobs, viewed, interested)
    }

    companion object {
        const val DEFAULT_INTEREST_MESSAGE = "I'm interested in this job!"
        private val HIDDEN_DEAL_STATUSES = setOf("accepted", "in_progress", "active", "completed")
    }
}

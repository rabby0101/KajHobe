package com.kajhobe.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Media attachment type (image/video). */
@Serializable
enum class MediaType {
    @SerialName("image") IMAGE,
    @SerialName("video") VIDEO,
}

/** Photo/video attachment on a job — iOS Job.MediaItem. */
@Serializable
data class MediaItem(
    val id: String,
    val url: String,
    val type: MediaType,
    val thumbnail_url: String? = null,
)

/** Service request — iOS Job. */
@Serializable
data class Job(
    val id: String,
    val title: String,
    val description: String,
    val category: String,
    val location: String,
    val status: String? = null,
    val urgent: Boolean? = null,
    val created_at: String? = null,
    val updated_at: String? = null,
    val client_id: String,
    val budget: Int,
    val media_urls: List<MediaItem>? = null,
)

/** Insert payload for a new job — iOS JobInsert. */
@Serializable
data class JobInsert(
    val title: String,
    val description: String,
    val category: String,
    val location: String,
    val status: String? = null,
    val urgent: Boolean? = null,
    val client_id: String,
    val budget: Int,
    val media_urls: List<MediaItem>? = null,
)

/** iOS Bid. */
@Serializable
data class Bid(
    val id: String,
    val job_id: String,
    val provider_id: String,
    val amount: Int,
    val message: String? = null,
    val status: String? = null,
    val created_at: String? = null,
)

@Serializable
data class BidInsert(
    val job_id: String,
    val provider_id: String,
    val amount: Int,
    val message: String? = null,
    val status: String? = null,
)

/** iOS BidResponse (application status). */
@Serializable
data class BidResponse(
    val id: String,
    val job_id: String,
    val provider_id: String,
    val amount: Int,
    val message: String? = null,
    val status: String,
    val created_at: String,
)

/** iOS Proposal. */
@Serializable
data class Proposal(
    val id: String,
    val job_id: String,
    val provider_id: String,
    val amount: Int,
    val message: String? = null,
    val status: String,
    val created_at: String? = null,
    val updated_at: String? = null,
)

@Serializable
data class ProposalInsert(
    val job_id: String,
    val provider_id: String,
    val amount: Int,
    val message: String? = null,
    val status: String,
)

/** iOS Review. */
@Serializable
data class Review(
    val id: String,
    val job_id: String,
    val reviewer_id: String,
    val reviewed_id: String,
    val rating: Int,
    val comment: String? = null,
    val created_at: String? = null,
)

@Serializable
data class ReviewInsert(
    val job_id: String,
    val reviewer_id: String,
    val reviewed_id: String,
    val rating: Int,
    val comment: String? = null,
)

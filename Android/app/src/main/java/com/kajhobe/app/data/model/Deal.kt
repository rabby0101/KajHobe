package com.kajhobe.app.data.model

import kotlinx.serialization.Serializable

/** iOS DealOffer. */
@Serializable
data class DealOffer(
    val id: String,
    val conversation_id: String,
    val provider_id: String,
    val client_id: String,
    val job_id: String,
    val amount: Int,
    val terms: String? = null,
    val timeline: String? = null,
    val status: String,
    val created_at: String,
    val responded_at: String? = null,
    // Related data from joins
    val job: Job? = null,
    val provider_profile: SimpleProfile? = null,
    val client_profile: SimpleProfile? = null,
)

@Serializable
data class DealOfferInsert(
    val conversation_id: String,
    val provider_id: String,
    val client_id: String,
    val job_id: String,
    val amount: Int,
    val terms: String? = null,
    val timeline: String? = null,
    val status: String,
)

@Serializable
data class DealResponse(
    val deal_offer_id: String,
    val response: String,
    val message: String? = null,
)

@Serializable
data class DealCount(
    val job_id: String,
    val provider_id: String,
    val deal_count: Int,
)

/** iOS Deal. */
@Serializable
data class Deal(
    val id: String,
    val job_id: String,
    val client_id: String,
    val provider_id: String,
    val proposal_id: String? = null,
    val conversation_id: String? = null,
    val agreed_amount: Int,
    val agreed_terms: String? = null,
    val timeline: String? = null,
    val status: String,
    val completion_status: String? = null,
    val client_completion_requested: Boolean? = null,
    val provider_completion_requested: Boolean? = null,
    val client_completion_requested_at: String? = null,
    val provider_completion_requested_at: String? = null,
    val created_at: String? = null,
    val completed_at: String? = null,
    // Related data from joins
    val job: Job? = null,
    val client_profile: SimpleProfile? = null,
    val provider_profile: SimpleProfile? = null,
)

@Serializable
data class DealInsert(
    val deal_offer_id: String,
    val conversation_id: String,
    val provider_id: String,
    val client_id: String,
    val job_id: String,
    val agreed_amount: Int,
    val agreed_terms: String? = null,
    val timeline: String? = null,
    val status: String,
)

/** iOS OfferData (jsonb in notifications). */
@Serializable
data class OfferData(
    val amount: Int,
    val terms: String? = null,
    val timeline: String? = null,
)

// MARK: - Completion / dashboard

@Serializable
data class CompletionRequest(
    val id: String,
    val deal_id: String,
    val requester_id: String,
    val requester_type: String,
    val request_message: String? = null,
    val status: String,
    val responded_by: String? = null,
    val responded_at: String? = null,
    val response_message: String? = null,
    val created_at: String,
    val updated_at: String,
    // Related data
    val deals: Deal? = null,
    val requester_profile: SimpleProfile? = null,
    val responder_profile: SimpleProfile? = null,
)

@Serializable
data class CompletionRequestInsert(
    val deal_id: String,
    val requester_id: String,
    val requester_type: String,
    val request_message: String? = null,
)

@Serializable
data class CompletionRequestResponse(
    val status: String,
    val response_message: String? = null,
    val responded_by: String,
    val responded_at: String,
)

@Serializable
data class DashboardData(
    val user_type: String,
    val active_deals_count: Int,
    val completed_deals_count: Int,
    val pending_completion_requests: Int,
    val total_earnings: Double,
    val total_spent: Double,
    val average_rating: Double,
    val recent_deals: List<DashboardDeal>? = null,
)

@Serializable
data class DashboardDeal(
    val id: String,
    val job_title: String,
    val agreed_amount: Int,
    val completion_status: String,
    val created_at: String,
    val other_party_name: String? = null,
)

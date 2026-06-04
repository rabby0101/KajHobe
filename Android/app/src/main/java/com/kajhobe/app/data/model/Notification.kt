package com.kajhobe.app.data.model

import kotlinx.serialization.Serializable

/** A button on an interactive notification — iOS NotificationAction. */
@Serializable
data class NotificationAction(
    val id: String = "",
    val type: String,            // "accept", "reject", "view"
    val label: String = "",
    val style: String = "primary", // "primary", "secondary", "destructive"
    val title: String? = null,
    val systemIcon: String? = null,
) {
    val displayTitle: String get() = title ?: label
}

/** Interactive action payload — iOS ActionData. */
@Serializable
data class ActionData(
    val interest_id: String? = null,
    val provider_name: String? = null,
    val job_title: String? = null,
    val interest_message: String? = null,
    val actions: List<NotificationAction>? = null,
)

/**
 * Enhanced notification — iOS EnhancedNotification.
 * Raw fields are decoded tolerantly; typed accessors apply the iOS fallback rules
 * (to_user_id↔user_id, read→state, grouped_date←created_at).
 */
@Serializable
data class EnhancedNotification(
    val id: String,
    val type: String = "unknown",
    val title: String = "",
    val message: String = "",
    val job_id: String? = null,
    val from_user_id: String? = null,
    val to_user_id: String? = null,
    val user_id: String? = null,
    val notification_state: String? = null,
    val read: Boolean? = null,
    val interaction_type: String? = null,
    val action_data: ActionData? = null,
    val priority: String? = null,
    val avatar_url: String? = null,
    val grouped_date: String? = null,
    val read_at: String? = null,
    val archived_at: String? = null,
    val completion_request_id: String? = null,
    val created_at: String,
) {
    val state: NotificationState
        get() = notification_state?.let { NotificationState.fromRaw(it) }
            ?: read?.let { if (it) NotificationState.READ else NotificationState.UNREAD }
            ?: NotificationState.UNREAD

    val toUser: String get() = to_user_id ?: user_id ?: ""
    val interaction: InteractionType get() = InteractionType.fromRaw(interaction_type)
    val priorityEnum: NotificationPriority
        get() = when (priority?.lowercase()) {
            "high" -> NotificationPriority.HIGH
            "low" -> NotificationPriority.LOW
            else -> NotificationPriority.NORMAL
        }
    val groupedDate: String get() = grouped_date ?: created_at.take(10)

    val isUnread: Boolean get() = state == NotificationState.UNREAD
    val isRead: Boolean get() = state == NotificationState.READ
    val isArchived: Boolean get() = state == NotificationState.ARCHIVED
    val isInteractive: Boolean get() = interaction == InteractionType.INTERACTIVE
    val isHighPriority: Boolean get() = priorityEnum == NotificationPriority.HIGH
    val hasActions: Boolean get() = action_data?.actions?.isNotEmpty() == true
    val timeAgoText: String get() = timeAgo(created_at)
}

/** Legacy notification — iOS Notification. */
@Serializable
data class LegacyNotification(
    val id: String,
    val type: String,
    val job_id: String,
    val from_user_id: String? = null,
    val to_user_id: String,
    val status: String,
    val message: String? = null,
    val offer_data: OfferData? = null,
    val completion_request_id: String? = null,
    val actioned_at: String? = null,
    val created_at: String,
    val job: Job? = null,
    val from_profile: Profile? = null,
) {
    val isPending: Boolean get() = status == "pending"
    val isInterestRequest: Boolean get() = type == "interest_request" || type == "show_interest"
    val isOfferReceived: Boolean get() = type == "offer_received"
    val isCompletionRequest: Boolean get() = type == "completion_request"
}

/** iOS NotificationItem (legacy compatibility). */
@Serializable
data class NotificationItem(
    val id: String,
    val user_id: String,
    val title: String,
    val message: String,
    val type: String,
    val read: Boolean,
    val related_job_id: String? = null,
    val created_at: String? = null,
)

/** iOS JobInterest. */
@Serializable
data class JobInterest(
    val id: String,
    val job_id: String,
    val provider_id: String,
    val status: String,
    val message: String? = null,
    val created_at: String,
    val actioned_at: String? = null,
)

/** iOS EnrichedJobInterest (primary realtime notification source). */
@Serializable
data class EnrichedJobInterest(
    val id: String,
    val job_id: String,
    val provider_id: String,
    val status: String,
    val message: String? = null,
    val created_at: String,
    val actioned_at: String? = null,
    val job_title: String,
    val job_client_id: String,
    val job_budget: Int? = null,
    val job_location: String? = null,
    val provider_name: String? = null,
    val provider_avatar_url: String? = null,
    val provider_rating: Double? = null,
)

// MARK: - Insert / update payloads

@Serializable
data class EnhancedNotificationInsert(
    val type: String,
    val title: String,
    val message: String,
    val job_id: String? = null,
    val from_user_id: String? = null,
    val to_user_id: String,
    val notification_state: NotificationState,
    val interaction_type: InteractionType,
    val action_data: ActionData? = null,
    val priority: NotificationPriority,
    val avatar_url: String? = null,
    val grouped_date: String,
)

@Serializable
data class NotificationStateUpdate(
    val notification_state: NotificationState,
    val read_at: String? = null,
    val archived_at: String? = null,
)

@Serializable
data class NotificationUpdate(
    val status: String,
    val actioned_at: String,
)

@Serializable
data class NotificationInsert(
    val type: String,
    val job_id: String,
    val from_user_id: String,
    val to_user_id: String,
    val message: String,
    val offer_data: OfferData? = null,
)

@Serializable
data class InterestData(
    val job_id: String,
    val provider_id: String,
)

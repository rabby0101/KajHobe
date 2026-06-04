package com.kajhobe.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors iOS DatabaseNotificationType. */
@Serializable
enum class DatabaseNotificationType {
    @SerialName("interest_received") INTEREST_RECEIVED,
    @SerialName("interest_accepted") INTEREST_ACCEPTED,
    @SerialName("interest_rejected") INTEREST_REJECTED,
    @SerialName("interest_request") INTEREST_REQUEST,
    @SerialName("deal_offer_received") DEAL_OFFER_RECEIVED,
    @SerialName("deal_offer_accepted") DEAL_OFFER_ACCEPTED,
    @SerialName("deal_offer_rejected") DEAL_OFFER_REJECTED,
    @SerialName("offer_received") OFFER_RECEIVED,
    @SerialName("completion_requested") COMPLETION_REQUESTED,
    @SerialName("completion_approved") COMPLETION_APPROVED,
    @SerialName("completion_rejected") COMPLETION_REJECTED,
    @SerialName("deal_created") DEAL_CREATED,
    @SerialName("deal_completed") DEAL_COMPLETED,
    @SerialName("message_received") MESSAGE_RECEIVED,
    @SerialName("new_message") NEW_MESSAGE,
    @SerialName("profile_view") PROFILE_VIEW,
    @SerialName("job_application") JOB_APPLICATION,
    UNKNOWN;

    companion object {
        fun fromRaw(value: String?): DatabaseNotificationType =
            entries.firstOrNull { it.serialName() == value } ?: UNKNOWN
    }
}

private fun DatabaseNotificationType.serialName(): String = when (this) {
    DatabaseNotificationType.INTEREST_RECEIVED -> "interest_received"
    DatabaseNotificationType.INTEREST_ACCEPTED -> "interest_accepted"
    DatabaseNotificationType.INTEREST_REJECTED -> "interest_rejected"
    DatabaseNotificationType.INTEREST_REQUEST -> "interest_request"
    DatabaseNotificationType.DEAL_OFFER_RECEIVED -> "deal_offer_received"
    DatabaseNotificationType.DEAL_OFFER_ACCEPTED -> "deal_offer_accepted"
    DatabaseNotificationType.DEAL_OFFER_REJECTED -> "deal_offer_rejected"
    DatabaseNotificationType.OFFER_RECEIVED -> "offer_received"
    DatabaseNotificationType.COMPLETION_REQUESTED -> "completion_requested"
    DatabaseNotificationType.COMPLETION_APPROVED -> "completion_approved"
    DatabaseNotificationType.COMPLETION_REJECTED -> "completion_rejected"
    DatabaseNotificationType.DEAL_CREATED -> "deal_created"
    DatabaseNotificationType.DEAL_COMPLETED -> "deal_completed"
    DatabaseNotificationType.MESSAGE_RECEIVED -> "message_received"
    DatabaseNotificationType.NEW_MESSAGE -> "new_message"
    DatabaseNotificationType.PROFILE_VIEW -> "profile_view"
    DatabaseNotificationType.JOB_APPLICATION -> "job_application"
    DatabaseNotificationType.UNKNOWN -> "unknown"
}

/** Mirrors iOS NotificationSource. */
@Serializable
enum class NotificationSource {
    @SerialName("job_interest") JOB_INTEREST,
    @SerialName("deal_offer") DEAL_OFFER,
    @SerialName("completion_request") COMPLETION_REQUEST,
    @SerialName("deal") DEAL,
    @SerialName("message") MESSAGE,
}

/** Mirrors iOS NotificationPriority. */
@Serializable
enum class NotificationPriority {
    @SerialName("high") HIGH,
    @SerialName("normal") NORMAL,
    @SerialName("low") LOW,
}

/** Mirrors iOS NotificationState. */
@Serializable
enum class NotificationState {
    @SerialName("unread") UNREAD,
    @SerialName("read") READ,
    @SerialName("archived") ARCHIVED;

    companion object {
        fun fromRaw(value: String?): NotificationState = when (value?.lowercase()) {
            "read" -> READ
            "archived" -> ARCHIVED
            else -> UNREAD
        }
    }
}

/** Mirrors iOS InteractionType. */
@Serializable
enum class InteractionType {
    @SerialName("interactive") INTERACTIVE,
    @SerialName("informational") INFORMATIONAL;

    companion object {
        fun fromRaw(value: String?): InteractionType =
            if (value?.lowercase() == "interactive") INTERACTIVE else INFORMATIONAL
    }
}

/** Mirrors iOS TrustLevel, including display metadata. */
@Serializable
enum class TrustLevel {
    @SerialName("unverified") UNVERIFIED,
    @SerialName("newcomer") NEWCOMER,
    @SerialName("established") ESTABLISHED,
    @SerialName("experienced") EXPERIENCED,
    @SerialName("expert") EXPERT;

    val displayName: String
        get() = when (this) {
            UNVERIFIED -> "Unverified"
            NEWCOMER -> "Newcomer"
            ESTABLISHED -> "Established"
            EXPERIENCED -> "Experienced"
            EXPERT -> "Expert"
        }

    /** Color name matching iOS TrustLevel.badgeColor. */
    val badgeColorName: String
        get() = when (this) {
            UNVERIFIED -> "gray"
            NEWCOMER -> "blue"
            ESTABLISHED -> "green"
            EXPERIENCED -> "orange"
            EXPERT -> "purple"
        }

    companion object {
        fun fromRaw(value: String?): TrustLevel = when (value?.lowercase()) {
            "newcomer" -> NEWCOMER
            "established" -> ESTABLISHED
            "experienced" -> EXPERIENCED
            "expert" -> EXPERT
            else -> UNVERIFIED
        }
    }
}

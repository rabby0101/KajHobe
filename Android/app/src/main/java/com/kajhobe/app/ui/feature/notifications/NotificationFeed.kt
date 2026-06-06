package com.kajhobe.app.ui.feature.notifications

import androidx.compose.ui.graphics.Color
import com.kajhobe.app.data.model.EnhancedNotification
import com.kajhobe.app.data.model.EnrichedJobInterest
import com.kajhobe.app.data.model.parseIsoMillis
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Canonical color system for the unified feed — the Android port of iOS `NotificationCategory`.
 * Unread cards are tinted in the category color across the whole card; read cards fade to plain
 * gray (the color doubles as the unread signal).
 */
enum class NotificationCategory(val label: String, val color: Color) {
    INTEREST("Interest", Color(0xFF5856D6)),            // Indigo
    DEAL_CREATED("Deal", Color(0xFF30B0C7)),            // Teal
    COMPLETION_REQUEST("Completion", Color(0xFFFFB300)), // Amber rgb(255,179,0)
    DEAL_COMPLETED("Completed", Color(0xFF34C759)),     // Green
    OTHER("Update", Color(0xFF8E8E93));                 // Gray

    companion object {
        /**
         * Resolves a `notifications.type` string to a category (mirrors iOS
         * `NotificationCategory.from(businessType:)`).
         */
        fun fromBusinessType(rawType: String?): NotificationCategory {
            val t = rawType?.lowercase() ?: return OTHER
            return when {
                t.contains("completion") -> if (t.contains("approved")) DEAL_COMPLETED else COMPLETION_REQUEST
                t == "deal_completed" || t.contains("completed") -> DEAL_COMPLETED
                t.contains("deal") || t.contains("offer") -> DEAL_CREATED
                t.contains("interest") -> INTEREST
                else -> OTHER
            }
        }
    }
}

/**
 * One entry in the single notifications feed — either an interest request (from `job_interests`)
 * or a business notification (from `notifications`). Mirrors iOS `NotificationFeedItem`.
 */
sealed interface NotificationFeedItem {
    /** Prefixed id for stable list keys. */
    val id: String

    /** Underlying row id used for local read/cleared state. */
    val rawId: String

    val createdAt: String

    val category: NotificationCategory

    data class Interest(val interest: EnrichedJobInterest) : NotificationFeedItem {
        override val id get() = "interest_${interest.id}"
        override val rawId get() = interest.id
        override val createdAt get() = interest.created_at
        override val category get() = NotificationCategory.INTEREST
    }

    data class Business(val notification: EnhancedNotification) : NotificationFeedItem {
        override val id get() = "business_${notification.id}"
        override val rawId get() = notification.id
        override val createdAt get() = notification.created_at
        override val category get() = NotificationCategory.fromBusinessType(notification.type)
    }
}

/** Sort key (epoch millis), newest first when sorted descending. */
fun NotificationFeedItem.createdMillis(): Long = parseIsoMillis(createdAt) ?: Long.MIN_VALUE

/**
 * Smart timestamp for business rows — mirrors iOS `formattedDate`: time today, "Yesterday",
 * "MMM d" this year, else "MMM d, yyyy".
 */
fun formattedNotificationDate(iso: String): String {
    val millis = parseIsoMillis(iso) ?: return ""
    val zone = ZoneId.systemDefault()
    val date = Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()
    val now = Instant.now().atZone(zone).toLocalDate()
    val instant = Instant.ofEpochMilli(millis).atZone(zone)
    return when {
        date == now -> DateTimeFormatter.ofPattern("h:mm a", Locale.getDefault()).format(instant)
        date == now.minusDays(1) -> "Yesterday"
        date.year == now.year -> DateTimeFormatter.ofPattern("MMM d", Locale.getDefault()).format(instant)
        else -> DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.getDefault()).format(instant)
    }
}

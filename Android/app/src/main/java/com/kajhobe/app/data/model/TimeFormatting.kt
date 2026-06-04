package com.kajhobe.app.data.model

import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import kotlin.math.roundToLong

/** Parses an ISO-8601 timestamp (with or without fractional seconds / offset) to epoch millis. */
internal fun parseIsoMillis(value: String?): Long? {
    if (value.isNullOrBlank()) return null
    return runCatching { Instant.parse(value).toEpochMilli() }
        .recoverCatching { OffsetDateTime.parse(value, DateTimeFormatter.ISO_DATE_TIME).toInstant().toEpochMilli() }
        .recoverCatching {
            // Supabase often returns "2024-01-01T12:00:00" (no zone) — treat as UTC.
            OffsetDateTime.parse(value + "Z").toInstant().toEpochMilli()
        }
        .getOrNull()
}

/** Mirrors iOS SimpleProfile.formattedLastSeen / PublicProfile.formattedLastSeen. */
internal fun relativeLastSeen(lastSeenAt: String?): String {
    val millis = parseIsoMillis(lastSeenAt) ?: return "Never"
    val interval = (System.currentTimeMillis() - millis) / 1000.0
    return when {
        interval < 60 -> "Just now"
        interval < 3600 -> "${(interval / 60).roundToLong()} min ago"
        interval < 86400 -> {
            val hours = (interval / 3600).toLong()
            "$hours hour${if (hours == 1L) "" else "s"} ago"
        }
        else -> {
            val days = (interval / 86400).toLong()
            "$days day${if (days == 1L) "" else "s"} ago"
        }
    }
}

/** Mirrors iOS averageResponseTimeText / responseTimeText. */
internal fun responseTimeText(minutes: Int?): String {
    val responseTime = minutes ?: return "Unknown"
    return when {
        responseTime < 60 -> "$responseTime min"
        responseTime < 1440 -> {
            val hours = responseTime / 60
            val rem = responseTime % 60
            if (rem == 0) "$hours hour${if (hours == 1) "" else "s"}" else "${hours}h ${rem}m"
        }
        else -> {
            val days = responseTime / 1440
            "$days day${if (days == 1) "" else "s"}"
        }
    }
}

/** Relative "time ago" for notifications — mirrors iOS EnhancedNotification.timeAgo. */
internal fun timeAgo(createdAt: String?): String {
    val millis = parseIsoMillis(createdAt) ?: return "Unknown time"
    val interval = (System.currentTimeMillis() - millis) / 1000.0
    return when {
        interval < 60 -> "Just now"
        interval < 3600 -> "${(interval / 60).toLong()}m ago"
        interval < 86400 -> "${(interval / 3600).toLong()}h ago"
        interval < 604800 -> "${(interval / 86400).toLong()}d ago"
        else -> "${(interval / 604800).toLong()}w ago"
    }
}

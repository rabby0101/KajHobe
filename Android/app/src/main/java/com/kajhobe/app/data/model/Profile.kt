package com.kajhobe.app.data.model

import kotlinx.serialization.Serializable

/** iOS Profile. */
@Serializable
data class Profile(
    val id: String,
    val email: String? = null,
    val full_name: String? = null,
    val phone: String? = null,
    val avatar_url: String? = null,
    val user_type: String? = null,
    val location: String? = null,
    val bio: String? = null,
    val website: String? = null,
    val is_service_provider: Boolean? = null,
    val role: String? = null,
    val average_rating: Double? = null,
    val ratings_count: Int? = null,
    val created_at: String? = null,
    val updated_at: String? = null,
    val favorite_categories: List<String>? = null,
    // Presence
    val is_online: Boolean? = null,
    val last_seen_at: String? = null,
    val average_response_time_minutes: Int? = null,
    // Push
    val device_token: String? = null,
    val push_enabled: Boolean? = null,
    val last_push_sent_at: String? = null,
)

@Serializable
data class ProfileInsert(
    val id: String,
    val email: String? = null,
    val full_name: String? = null,
    val phone: String? = null,
    val avatar_url: String? = null,
    val user_type: String? = null,
    val location: String? = null,
    val bio: String? = null,
    val website: String? = null,
    val is_service_provider: Boolean? = null,
    val favorite_categories: List<String>? = null,
    val device_token: String? = null,
    val push_enabled: Boolean? = null,
)

/** Lightweight profile for joins — iOS SimpleProfile. */
@Serializable
data class SimpleProfile(
    val id: String,
    val full_name: String? = null,
    val avatar_url: String? = null,
    val is_online: Boolean? = null,
    val last_seen_at: String? = null,
    val average_response_time_minutes: Int? = null,
) {
    val isOnline: Boolean get() = is_online ?: false
    val formattedLastSeen: String get() = relativeLastSeen(last_seen_at)
    val averageResponseTimeText: String get() = responseTimeText(average_response_time_minutes)
}

/** iOS PublicProfile with pre-computed statistics. */
@Serializable
data class PublicProfile(
    val id: String,
    val full_name: String? = null,
    val avatar_url: String? = null,
    val bio: String? = null,
    val location: String? = null,
    val website: String? = null,
    val is_service_provider: Boolean? = null,
    val created_at: String? = null,
    val completed_jobs: Int = 0,
    val avg_job_value: Double = 0.0,
    val total_earnings: Double = 0.0,
    val avg_rating: Double = 0.0,
    val review_count: Int = 0,
    val is_online: Boolean? = null,
    val last_seen_at: String? = null,
    val average_response_time_minutes: Int? = null,
    val service_categories: List<String> = emptyList(),
    val trust_level: String = "unverified",
    val last_updated: String? = null,
    val profession: String? = null,
    val tagline: String? = null,
    val experience_years: Int? = null,
    val hourly_rate: Double? = null,
    val team_rate: Double? = null,
    val team_hours_label: String? = null,
) {
    val trustLevelEnum: TrustLevel get() = TrustLevel.fromRaw(trust_level)
    val isOnline: Boolean get() = is_online ?: false
    val formattedRating: String get() = if (avg_rating > 0) String.format("%.1f", avg_rating) else "No ratings"
    val formattedJobCount: String
        get() = when (completed_jobs) {
            0 -> "No completed jobs"
            1 -> "1 completed job"
            else -> "$completed_jobs completed jobs"
        }
    val formattedEarnings: String
        get() = when {
            total_earnings == 0.0 -> "৳0"
            total_earnings >= 100000 -> "৳${String.format("%.0f", total_earnings / 1000)}K"
            else -> "৳${String.format("%.0f", total_earnings)}"
        }
    val topServiceCategories: List<String> get() = service_categories.take(3)
    val hasExperience: Boolean get() = completed_jobs > 0 || avg_rating > 0
    val formattedLastSeen: String get() = relativeLastSeen(last_seen_at)
    val responseTimeTextValue: String get() = responseTimeText(average_response_time_minutes)
    val formattedHourlyRate: String?
        get() {
            val rate = hourly_rate ?: return null
            if (rate <= 0) return null
            return "৳${formatAmount(rate)}/hr"
        }

    val formattedTeamRate: String?
        get() {
            val rate = team_rate ?: return null
            if (rate <= 0) return null
            return "৳${formatAmount(rate)}"
        }

    val experienceText: String
        get() {
            val years = experience_years ?: return "New provider"
            if (years <= 0) return "New provider"
            return "$years year${if (years == 1) "" else "s"} of experience"
        }

    val formattedCustomers: String
        get() = when {
            completed_jobs == 0 -> "New"
            completed_jobs < 10 -> "$completed_jobs"
            completed_jobs < 100 -> "${(completed_jobs / 10) * 10}+"
            else -> "${(completed_jobs / 50) * 50}+"
        }

    private fun formatAmount(v: Double): String {
        val isWhole = v % 1.0 == 0.0
        return if (isWhole) "%.0f".format(v) else "%.2f".format(v)
    }
}

/** Minimal profile for list batch loads — iOS PublicProfileSummary. */
@Serializable
data class PublicProfileSummary(
    val id: String,
    val full_name: String? = null,
    val avatar_url: String? = null,
    val trust_level: String = "unverified",
    val completed_jobs: Int = 0,
    val avg_rating: Double = 0.0,
    val is_online: Boolean? = null,
) {
    val trustLevelEnum: TrustLevel get() = TrustLevel.fromRaw(trust_level)
    val shortRating: String get() = if (avg_rating > 0) String.format("%.1f", avg_rating) else "New"
    val isOnline: Boolean get() = is_online ?: false
}

/** iOS ServiceHighlight. */
@Serializable
data class ServiceHighlight(
    val category: String,
    val job_count: Int,
    val avg_rating: Double? = null,
    val recent_completion: String? = null,
    val avg_job_value: Double? = null,
) {
    val formattedJobCount: String get() = if (job_count == 1) "1 job" else "$job_count jobs"
    val formattedRating: String
        get() = avg_rating?.takeIf { it > 0 }?.let { String.format("%.1f ⭐", it) } ?: "No ratings"

    val formattedRecentCompletion: String
        get() {
            val raw = recent_completion?.takeIf { it.isNotBlank() } ?: return "No recent work"
            val parser = java.time.format.DateTimeFormatterBuilder()
                .append(java.time.format.DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                .optionalStart()
                .appendFraction(java.time.temporal.ChronoField.NANO_OF_SECOND, 0, 9, true)
                .optionalEnd()
                .appendOffset("+HH:MM", "Z")
                .toFormatter()
            val odt = runCatching { java.time.OffsetDateTime.parse(raw, parser) }.getOrNull()
                ?: return "Unknown"
            val days = java.time.temporal.ChronoUnit.DAYS.between(odt.toLocalDate(), java.time.LocalDate.now())
            return when {
                days <= 0 -> "Today"
                days == 1L -> "Yesterday"
                days < 30L -> "$days days ago"
                else -> "Over a month ago"
            }
        }
}


@Serializable
data class ProviderReview(
    val id: String,
    val rating: Int,
    val comment: String? = null,
    val created_at: String? = null,
    val reviewer_name: String? = null,
    val reviewer_avatar: String? = null,
) {
    val displayName: String get() = reviewer_name ?: "Anonymous"

    val formattedDate: String
        get() {
            val raw = created_at ?: return ""
            val parser = java.time.format.DateTimeFormatterBuilder()
                .append(java.time.format.DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                .optionalStart()
                .appendFraction(java.time.temporal.ChronoField.NANO_OF_SECOND, 0, 9, true)
                .optionalEnd()
                .appendOffset("+HH:MM", "Z")
                .toFormatter()
            val odt = runCatching { java.time.OffsetDateTime.parse(raw, parser) }.getOrNull()
                ?: return ""
            return odt.toLocalDate().format(java.time.format.DateTimeFormatter.ofPattern("MMM d, yyyy"))
        }
}

package com.kajhobe.app.data.model

import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.max

/**
 * Interest-request cooldown logic — ported 1:1 from the web
 * `src/lib/interestCooldown.ts` and iOS `InterestCooldownManager`, so all three
 * platforms behave identically. Pure functions; the DB fetch lives in
 * JobsRepository.fetchInterestCooldown.
 *
 * Scoped per (job, provider): a cooldown is one provider's personal speed bump on
 * one job, never a job-wide gate. Distinct providers are independent.
 */
object InterestCooldown {
    /** Cooldown after a rejection before the provider may try again (ms). */
    const val COOLDOWN_MS = 120_000L // 2 minutes
    /** Max rejected attempts before a permanent block. */
    const val MAX_ATTEMPTS = 2
    /** Minimum time between attempts (ms). */
    const val RATE_LIMIT_MS = 60_000L // 1 minute
}

/** One job_interests row (only the status matters here). */
data class InterestRow(val status: String)

/**
 * The current provider's relationship to a job's interest: the live
 * job_interests status (pending/accepted/rejected/null) plus the computed
 * cooldown. Drives the JobDetail call-to-action.
 */
data class InterestState(
    val currentStatus: String?,
    val cooldown: CooldownStatus,
)

/** One `show_interest` notification (drives attempt count + timing). */
data class ShowInterestNotif(
    val status: String?,
    val createdAtMs: Long?,
    val actionedAtMs: Long?,
)

data class CooldownStatus(
    val canShowInterest: Boolean = true,
    val attemptCount: Int = 0,
    val isPermanentlyBlocked: Boolean = false,
    val isRateLimited: Boolean = false,
    /** Remaining cooldown after a rejection, ms (null when not in cooldown). */
    val remainingCooldownMs: Long? = null,
    /** Remaining rate-limit window, ms (null when not rate-limited/unknown). */
    val rateLimitRemainingMs: Long? = null,
    /** Epoch ms when the next attempt becomes available (null if unknown/blocked). */
    val nextAttemptTime: Long? = null,
    val statusDescription: String = "",
)

/** "1m 20s" / "20s" formatting (parity with iOS formatTimeRemaining). */
fun formatTimeRemaining(ms: Long): String {
    val total = max(0L, ceil(ms / 1000.0).toLong())
    val minutes = total / 60
    val seconds = total % 60
    return if (minutes > 0) "${minutes}m ${seconds}s" else "${seconds}s"
}

/** 0..1 progress through a cooldown window. */
fun calculateCooldownProgress(remainingMs: Long): Float {
    val progress = 1f - remainingMs.toFloat() / InterestCooldown.COOLDOWN_MS.toFloat()
    return progress.coerceIn(0f, 1f)
}

/**
 * Pure cooldown computation. Mirrors web computeCooldownStatus / iOS
 * checkCooldownStatus:
 * 1. A pending/accepted interest blocks (treated as "already shown interest").
 * 2. >= MAX_ATTEMPTS rejections -> permanent block.
 * 3. Last attempt within RATE_LIMIT_MS -> rate limited.
 * 4. Last rejection within COOLDOWN_MS -> cooldown active.
 */
fun computeCooldownStatus(
    interests: List<InterestRow>,
    notifications: List<ShowInterestNotif>,
    now: Long = System.currentTimeMillis(),
): CooldownStatus {
    // 1. Existing pending/accepted interest blocks further attempts.
    if (interests.any { it.status == "pending" || it.status == "accepted" }) {
        return describe(CooldownStatus(canShowInterest = false, attemptCount = 1, isRateLimited = true))
    }

    val sorted = notifications.sortedByDescending { it.createdAtMs ?: 0L }
    val rejected = sorted.filter { it.status == "rejected" }
    val attemptCount = rejected.size

    // 2. Permanent block.
    if (attemptCount >= InterestCooldown.MAX_ATTEMPTS) {
        return describe(CooldownStatus(canShowInterest = false, attemptCount = attemptCount, isPermanentlyBlocked = true))
    }

    // 3. Rate limit on the most recent attempt.
    val lastCreated = sorted.firstOrNull()?.createdAtMs
    if (lastCreated != null && now - lastCreated < InterestCooldown.RATE_LIMIT_MS) {
        return describe(
            CooldownStatus(
                canShowInterest = false,
                attemptCount = attemptCount,
                isRateLimited = true,
                rateLimitRemainingMs = InterestCooldown.RATE_LIMIT_MS - (now - lastCreated),
                // Absolute target so a UI countdown doesn't drift.
                nextAttemptTime = lastCreated + InterestCooldown.RATE_LIMIT_MS,
            ),
        )
    }

    // 4. Cooldown after the most recent rejection.
    val rejectedAt = rejected.firstOrNull()?.actionedAtMs
    if (rejectedAt != null && now - rejectedAt < InterestCooldown.COOLDOWN_MS) {
        return describe(
            CooldownStatus(
                canShowInterest = false,
                attemptCount = attemptCount,
                remainingCooldownMs = InterestCooldown.COOLDOWN_MS - (now - rejectedAt),
                nextAttemptTime = rejectedAt + InterestCooldown.COOLDOWN_MS,
            ),
        )
    }

    // No restrictions.
    return describe(CooldownStatus(canShowInterest = true, attemptCount = attemptCount))
}

private fun describe(s: CooldownStatus): CooldownStatus {
    val desc = when {
        s.isPermanentlyBlocked -> "You've reached the maximum attempts for this job"
        s.isRateLimited -> s.rateLimitRemainingMs?.let { "Please wait ${formatTimeRemaining(it)} before trying again" }
            ?: "You have already shown interest in this job"
        s.remainingCooldownMs != null -> "Please wait ${formatTimeRemaining(s.remainingCooldownMs)} before showing interest again"
        else -> "You can show interest in this job"
    }
    return s.copy(statusDescription = desc)
}

/** Parse a Postgres/ISO-8601 timestamp to epoch millis (null-safe). */
fun parseTimestampMs(iso: String?): Long? {
    if (iso.isNullOrBlank()) return null
    val normalized = iso.trim().replace("Z$".toRegex(), "+00:00")
    val withFractional = DateTimeFormatter.ofPattern(
        "yyyy-MM-dd'T'HH:mm:ss[.SSSSSSSSS][.SSSSSS][.SSS][.S]xxx",
        Locale.US,
    )
    val plain = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ssxxx", Locale.US)
    val odt = runCatching { OffsetDateTime.parse(normalized, withFractional) }
        .recoverCatching { OffsetDateTime.parse(normalized, plain) }
        .getOrNull()
        ?: runCatching { OffsetDateTime.parse(normalized).withOffsetSameInstant(ZoneOffset.UTC) }.getOrNull()
    return odt?.toInstant()?.toEpochMilli()
}

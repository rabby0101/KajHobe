package com.kajhobe.app.ui.feature.dashboard

import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.TrustLevel
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Pure client-side aggregation for the dashboard charts.
 * 1:1 port of `iOS/KajHobe/Views/Dashboard/DashboardAnalytics.swift`.
 * Deal volumes per user are small, so aggregating locally is cheaper than an RPC.
 */
object DashboardAnalytics {

    data class MoneyPoint(
        val month: OffsetDateTime,
        val role: Role,
        val amount: Double,
    ) {
        enum class Role { earned, spent }
    }

    data class StatusSlice(val status: String, val count: Int)

    data class RatingPoint(val month: OffsetDateTime, val runningAverage: Double)

    fun isCompleted(deal: Deal): Boolean =
        deal.completion_status == "completed" || deal.status == "completed"

    fun monthlyMoneyFlow(deals: List<Deal>, userId: String): List<MoneyPoint> {
        val uid = userId.lowercase()
        val buckets = mutableMapOf<OffsetDateTime, MutableMap<MoneyPoint.Role, Double>>()
        for (deal in deals) {
            if (!isCompleted(deal)) continue
            val date = parseDate(deal.completed_at ?: deal.created_at) ?: continue
            val month = monthStart(date)
            val role =
                if (deal.provider_id.lowercase() == uid) MoneyPoint.Role.earned else MoneyPoint.Role.spent
            buckets.getOrPut(month) { mutableMapOf() }
            buckets[month]!![role] = (buckets[month]!![role] ?: 0.0) + deal.agreed_amount.toDouble()
        }
        return buckets
            .flatMap { (month, roles) -> roles.map { (role, amt) -> MoneyPoint(month, role, amt) } }
            .sortedBy { it.month }
    }

    fun statusBreakdown(deals: List<Deal>): List<StatusSlice> {
        val counts = mutableMapOf<String, Int>()
        for (deal in deals) {
            val raw = deal.completion_status ?: deal.status
            val display = displayStatus(raw)
            counts[display] = (counts[display] ?: 0) + 1
        }
        return counts.map { (k, v) -> StatusSlice(k, v) }.sortedByDescending { it.count }
    }

    fun ratingTrend(reviews: List<ProviderReview>): List<RatingPoint> {
        val dated = reviews
            .mapNotNull { r -> parseDate(r.created_at)?.let { it to r.rating } }
            .sortedBy { it.first }
        if (dated.isEmpty()) return emptyList()
        val points = mutableMapOf<OffsetDateTime, Double>()
        var total = 0
        dated.forEachIndexed { idx, (date, rating) ->
            total += rating
            points[monthStart(date)] = total.toDouble() / (idx + 1)
        }
        return points.map { (k, v) -> RatingPoint(k, v) }.sortedBy { it.month }
    }

    fun ratingDistribution(reviews: List<ProviderReview>): List<Pair<Int, Int>> =
        (5 downTo 1).map { stars -> stars to reviews.count { it.rating == stars } }

    fun trustLevel(completedJobs: Int, avgRating: Double): TrustLevel = when {
        completedJobs >= 20 && avgRating >= 4.5 -> TrustLevel.EXPERT
        completedJobs >= 10 && avgRating >= 4.0 -> TrustLevel.EXPERIENCED
        completedJobs >= 5 && avgRating >= 3.5 -> TrustLevel.ESTABLISHED
        completedJobs >= 1 -> TrustLevel.NEWCOMER
        else -> TrustLevel.UNVERIFIED
    }

    data class TrustTarget(
        val next: TrustLevel,
        val jobsNeeded: Int,
        val ratingNeeded: Double,
        val progress: Double,
    )

    fun nextTrustLevelTarget(completedJobs: Int, avgRating: Double): TrustTarget? {
        val current = trustLevel(completedJobs, avgRating)
        val target = when (current) {
            TrustLevel.UNVERIFIED -> TrustLevel.NEWCOMER to (1 to 0.0)
            TrustLevel.NEWCOMER -> TrustLevel.ESTABLISHED to (5 to 3.5)
            TrustLevel.ESTABLISHED -> TrustLevel.EXPERIENCED to (10 to 4.0)
            TrustLevel.EXPERIENCED -> TrustLevel.EXPERT to (20 to 4.5)
            TrustLevel.EXPERT -> return null
        }
        val (nextLevel, req) = target
        val (jobsReq, ratingReq) = req
        val jobsProgress = (completedJobs.toDouble() / jobsReq).coerceAtMost(1.0)
        val ratingProgress = if (ratingReq > 0.0) (avgRating / ratingReq).coerceAtMost(1.0) else 1.0
        return TrustTarget(nextLevel, jobsReq, ratingReq, minOf(jobsProgress, ratingProgress))
    }

    fun parseDate(iso: String?): OffsetDateTime? {
        if (iso.isNullOrBlank()) return null
        // Postgres timestamps may or may not have fractional seconds; the offset
        // is usually `+00:00` (UTC). Strip trailing `Z` first, then try with and
        // without fractional seconds.
        val normalized = iso.trim().replace("Z$".toRegex(), "+00:00")
        val withFractional = DateTimeFormatter.ofPattern(
            "yyyy-MM-dd'T'HH:mm:ss[.SSSSSSSSS][.SSSSSS][.SSS][.S]xxx",
            Locale.US,
        )
        val plain = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ssxxx", Locale.US)
        return runCatching { OffsetDateTime.parse(normalized, withFractional) }
            .recoverCatching { OffsetDateTime.parse(normalized, plain) }
            .getOrNull()
            ?: runCatching { OffsetDateTime.parse(normalized).withOffsetSameInstant(ZoneOffset.UTC) }
                .getOrNull()
    }

    private fun monthStart(d: OffsetDateTime): OffsetDateTime =
        d.withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0).withNano(0)

    private fun displayStatus(raw: String): String =
        raw.replace("_", " ").replaceFirstChar { it.titlecase(Locale.US) }
}

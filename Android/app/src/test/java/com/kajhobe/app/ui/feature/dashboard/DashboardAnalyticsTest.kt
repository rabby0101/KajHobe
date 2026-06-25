package com.kajhobe.app.ui.feature.dashboard

import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.TrustLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardAnalyticsTest {

    private fun deal(
        id: String = "d1",
        providerId: String = "u1",
        clientId: String = "u2",
        amount: Int = 100,
        status: String = "completed",
        completionStatus: String? = "completed",
        completedAt: String? = "2026-01-15T10:00:00+00:00",
    ) = Deal(
        id = id,
        job_id = "j1",
        client_id = clientId,
        provider_id = providerId,
        agreed_amount = amount,
        status = status,
        completion_status = completionStatus,
        completed_at = completedAt,
    )

    private fun review(rating: Int, whenIso: String = "2026-02-10T10:00:00+00:00") =
        ProviderReview(id = "r1", rating = rating, created_at = whenIso)

    @Test fun `isCompleted uses completion_status when present`() {
        val d = deal(completionStatus = "completed")
        assertTrue(DashboardAnalytics.isCompleted(d))
    }

    @Test fun `isCompleted falls back to status`() {
        val d = deal(completionStatus = null, status = "completed")
        assertTrue(DashboardAnalytics.isCompleted(d))
    }

    @Test fun `monthlyMoneyFlow returns empty for no deals`() {
        assertEquals(0, DashboardAnalytics.monthlyMoneyFlow(emptyList(), "u1").size)
    }

    @Test fun `monthlyMoneyFlow earned when user is provider`() {
        val points = DashboardAnalytics.monthlyMoneyFlow(listOf(deal(providerId = "u1")), "u1")
        assertEquals(1, points.size)
        assertEquals(DashboardAnalytics.MoneyPoint.Role.earned, points[0].role)
        assertEquals(100.0, points[0].amount, 0.0)
    }

    @Test fun `monthlyMoneyFlow spent when user is client`() {
        val points = DashboardAnalytics.monthlyMoneyFlow(listOf(deal(providerId = "u2", clientId = "u1")), "u1")
        assertEquals(1, points.size)
        assertEquals(DashboardAnalytics.MoneyPoint.Role.spent, points[0].role)
    }

    @Test fun `monthlyMoneyFlow ignores non-completed deals`() {
        val d = deal(completionStatus = "in_progress", status = "active")
        assertEquals(0, DashboardAnalytics.monthlyMoneyFlow(listOf(d), "u1").size)
    }

    @Test fun `statusBreakdown counts and sorts desc`() {
        val deals = listOf(
            deal(id = "a", completionStatus = "completed"),
            deal(id = "b", completionStatus = "completed"),
            deal(id = "c", completionStatus = "in_progress"),
        )
        val slices = DashboardAnalytics.statusBreakdown(deals)
        assertEquals(2, slices.size)
        assertEquals("Completed", slices[0].status)
        assertEquals(2, slices[0].count)
    }

    @Test fun `ratingTrend returns empty for no reviews`() {
        assertEquals(0, DashboardAnalytics.ratingTrend(emptyList()).size)
    }

    @Test fun `ratingTrend running average increases then plateaus`() {
        val reviews = listOf(
            review(rating = 4, whenIso = "2026-01-10T10:00:00+00:00"),
            review(rating = 5, whenIso = "2026-02-10T10:00:00+00:00"),
        )
        val points = DashboardAnalytics.ratingTrend(reviews)
        assertEquals(2, points.size)
        // Jan: running avg of [4] = 4.0
        assertEquals(4.0, points[0].runningAverage, 0.001)
        // Feb: running avg of [4,5] = 4.5
        assertEquals(4.5, points[1].runningAverage, 0.001)
    }

    @Test fun `ratingDistribution returns 5 down to 1 always`() {
        val dist = DashboardAnalytics.ratingDistribution(listOf(review(5), review(5), review(3)))
        assertEquals(listOf(5, 4, 3, 2, 1), dist.map { it.first })
        assertEquals(2, dist.first { it.first == 5 }.second)
        assertEquals(1, dist.first { it.first == 3 }.second)
    }

    @Test fun `trustLevel expert requires 20 jobs and 4_5 average rating`() {
        assertEquals(TrustLevel.EXPERT, DashboardAnalytics.trustLevel(20, 4.5))
        assertEquals(TrustLevel.EXPERIENCED, DashboardAnalytics.trustLevel(20, 4.0))
        assertEquals(TrustLevel.EXPERIENCED, DashboardAnalytics.trustLevel(19, 4.5))
    }

    @Test fun `trustLevel all tiers`() {
        assertEquals(TrustLevel.UNVERIFIED, DashboardAnalytics.trustLevel(0, 0.0))
        assertEquals(TrustLevel.NEWCOMER, DashboardAnalytics.trustLevel(1, 0.0))
        assertEquals(TrustLevel.ESTABLISHED, DashboardAnalytics.trustLevel(5, 3.5))
        assertEquals(TrustLevel.EXPERIENCED, DashboardAnalytics.trustLevel(10, 4.0))
    }

    @Test fun `nextTrustLevelTarget nil at expert`() {
        assertNull(DashboardAnalytics.nextTrustLevelTarget(50, 5.0))
    }

    @Test fun `nextTrustLevelTarget correct for unverified`() {
        val t = DashboardAnalytics.nextTrustLevelTarget(0, 0.0)
        assertNotNull(t)
        assertEquals(TrustLevel.NEWCOMER, t!!.next)
        assertEquals(1, t.jobsNeeded)
    }

    @Test fun `parseDate handles with and without fractional seconds`() {
        assertNotNull(DashboardAnalytics.parseDate("2026-01-15T10:00:00+00:00"))
        assertNotNull(DashboardAnalytics.parseDate("2026-01-15T10:00:00.123+00:00"))
        assertNotNull(DashboardAnalytics.parseDate("2026-01-15T10:00:00Z"))
        assertNull(DashboardAnalytics.parseDate(null))
        assertNull(DashboardAnalytics.parseDate("not a date"))
    }
}

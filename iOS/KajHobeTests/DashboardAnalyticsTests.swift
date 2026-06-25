import Testing
import Foundation
@testable import KajHobe

struct DashboardAnalyticsTests {

    private func makeDeal(
        id: String = UUID().uuidString,
        clientId: String,
        providerId: String,
        amount: Int,
        completionStatus: String?,
        completedAt: String?
    ) -> Deal {
        Deal(
            id: id,
            job_id: UUID().uuidString,
            client_id: clientId,
            provider_id: providerId,
            proposal_id: nil,
            conversation_id: nil,
            agreed_amount: amount,
            agreed_terms: nil,
            timeline: nil,
            status: "active",
            completion_status: completionStatus,
            client_completion_requested: nil,
            provider_completion_requested: nil,
            client_completion_requested_at: nil,
            provider_completion_requested_at: nil,
            created_at: "2026-01-10T10:00:00Z",
            completed_at: completedAt,
            job: nil,
            client_profile: nil,
            provider_profile: nil
        )
    }

    private func makeReview(rating: Int, createdAt: String) -> ProviderReview {
        ProviderReview(
            id: UUID().uuidString,
            rating: rating,
            comment: nil,
            created_at: createdAt,
            reviewer_name: nil,
            reviewer_avatar: nil
        )
    }

    @Test func moneyFlowSeparatesEarningsFromSpending() {
        let me = "11111111-1111-1111-1111-111111111111"
        let deals = [
            // I provided this one — earned 500.
            makeDeal(clientId: "other", providerId: me, amount: 500,
                     completionStatus: "completed", completedAt: "2026-02-05T12:00:00Z"),
            // I commissioned this one — spent 300.
            makeDeal(clientId: me, providerId: "other", amount: 300,
                     completionStatus: "completed", completedAt: "2026-02-20T12:00:00Z"),
            // Not completed — money hasn't moved, must not count.
            makeDeal(clientId: me, providerId: "other", amount: 999,
                     completionStatus: "in_progress", completedAt: nil)
        ]

        let points = DashboardAnalytics.monthlyMoneyFlow(deals: deals, userId: me)

        #expect(points.count == 2)
        #expect(points.first(where: { $0.role == .earned })?.amount == 500)
        #expect(points.first(where: { $0.role == .spent })?.amount == 300)
    }

    @Test func moneyFlowMatchesUserIdCaseInsensitively() {
        let me = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let deals = [
            makeDeal(clientId: "other", providerId: me.lowercased(), amount: 100,
                     completionStatus: "completed", completedAt: "2026-03-01T00:00:00Z")
        ]
        let points = DashboardAnalytics.monthlyMoneyFlow(deals: deals, userId: me)
        #expect(points.first?.role == .earned)
    }

    @Test func statusBreakdownGroupsAndSorts() {
        let deals = [
            makeDeal(clientId: "c", providerId: "p", amount: 1, completionStatus: "completed", completedAt: nil),
            makeDeal(clientId: "c", providerId: "p", amount: 1, completionStatus: "completed", completedAt: nil),
            makeDeal(clientId: "c", providerId: "p", amount: 1, completionStatus: "in_progress", completedAt: nil)
        ]
        let slices = DashboardAnalytics.statusBreakdown(deals: deals)
        #expect(slices.first?.status == "Completed")
        #expect(slices.first?.count == 2)
        #expect(slices.contains(where: { $0.status == "In Progress" && $0.count == 1 }))
    }

    @Test func ratingTrendIsCumulativeAverage() {
        let reviews = [
            makeReview(rating: 5, createdAt: "2026-01-15T10:00:00Z"),
            makeReview(rating: 3, createdAt: "2026-02-15T10:00:00Z")
        ]
        let points = DashboardAnalytics.ratingTrend(reviews: reviews)
        #expect(points.count == 2)
        #expect(points.first?.runningAverage == 5.0)
        #expect(points.last?.runningAverage == 4.0)  // (5+3)/2
    }

    @Test func ratingDistributionCoversAllStars() {
        let reviews = [
            makeReview(rating: 5, createdAt: "2026-01-01T00:00:00Z"),
            makeReview(rating: 5, createdAt: "2026-01-02T00:00:00Z"),
            makeReview(rating: 2, createdAt: "2026-01-03T00:00:00Z")
        ]
        let distribution = DashboardAnalytics.ratingDistribution(reviews: reviews)
        #expect(distribution.count == 5)
        #expect(distribution.first?.stars == 5)
        #expect(distribution.first?.count == 2)
        #expect(distribution.first(where: { $0.stars == 2 })?.count == 1)
        #expect(distribution.first(where: { $0.stars == 1 })?.count == 0)
    }

    @Test func trustLevelTiers() {
        #expect(DashboardAnalytics.trustLevel(completedJobs: 0, avgRating: 0) == .unverified)
        #expect(DashboardAnalytics.trustLevel(completedJobs: 1, avgRating: 0) == .newcomer)
        #expect(DashboardAnalytics.trustLevel(completedJobs: 5, avgRating: 3.5) == .established)
        #expect(DashboardAnalytics.trustLevel(completedJobs: 10, avgRating: 4.0) == .experienced)
        #expect(DashboardAnalytics.trustLevel(completedJobs: 20, avgRating: 4.5) == .expert)
        // High volume but poor rating stays below the rating-gated tiers.
        #expect(DashboardAnalytics.trustLevel(completedJobs: 50, avgRating: 2.0) == .newcomer)
    }

    @Test func nextTrustLevelTargetTopsOut() {
        #expect(DashboardAnalytics.nextTrustLevelTarget(completedJobs: 25, avgRating: 4.8) == nil)
        let target = DashboardAnalytics.nextTrustLevelTarget(completedJobs: 1, avgRating: 5.0)
        #expect(target?.next == .established)
    }

    @Test func parsesTimestampsWithAndWithoutFractionalSeconds() {
        #expect(DashboardAnalytics.parseDate("2026-01-10T10:00:00Z") != nil)
        #expect(DashboardAnalytics.parseDate("2026-01-10T10:00:00.123456Z") != nil)
        #expect(DashboardAnalytics.parseDate(nil) == nil)
    }
}

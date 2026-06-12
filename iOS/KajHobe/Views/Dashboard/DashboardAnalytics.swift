import Foundation

/// Pure client-side aggregation for the dashboard charts. Deal volumes are
/// small (a user's own deals), so aggregating locally beats a server RPC; if
/// volume ever grows, these functions are the single swap point.
nonisolated enum DashboardAnalytics {

    // MARK: - Models

    struct MoneyPoint: Identifiable, Equatable {
        let month: Date
        let role: Role
        let amount: Double

        enum Role: String {
            case earned = "Earned"
            case spent = "Spent"
        }

        var id: String { "\(month.timeIntervalSince1970)-\(role.rawValue)" }
    }

    struct StatusSlice: Identifiable, Equatable {
        let status: String   // normalized display label
        let count: Int
        var id: String { status }
    }

    struct RatingPoint: Identifiable, Equatable {
        let month: Date
        let runningAverage: Double
        var id: Date { month }
    }

    // MARK: - Aggregations

    /// Money moved per month from the user's perspective: deals they provided
    /// count as earnings, deals they commissioned count as spending. Only
    /// completed deals count — that's when money actually moves.
    static func monthlyMoneyFlow(deals: [Deal], userId: String) -> [MoneyPoint] {
        let uid = userId.lowercased()
        var buckets: [Date: [MoneyPoint.Role: Double]] = [:]

        for deal in deals where isCompleted(deal) {
            guard let date = parseDate(deal.completed_at ?? deal.created_at),
                  let month = monthStart(of: date) else { continue }
            let role: MoneyPoint.Role = deal.provider_id.lowercased() == uid ? .earned : .spent
            buckets[month, default: [:]][role, default: 0] += Double(deal.agreed_amount)
        }

        return buckets
            .flatMap { month, roles in
                roles.map { MoneyPoint(month: month, role: $0.key, amount: $0.value) }
            }
            .sorted { $0.month < $1.month }
    }

    /// Deals grouped by their lifecycle state, for the status donut.
    static func statusBreakdown(deals: [Deal]) -> [StatusSlice] {
        var counts: [String: Int] = [:]
        for deal in deals {
            let raw = deal.completion_status ?? deal.status
            counts[displayStatus(raw), default: 0] += 1
        }
        return counts
            .map { StatusSlice(status: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    /// Cumulative average rating over time (one point per month with reviews),
    /// showing how the user's reputation has evolved.
    static func ratingTrend(reviews: [ProviderReview]) -> [RatingPoint] {
        let dated = reviews
            .compactMap { review -> (Date, Int)? in
                guard let date = parseDate(review.created_at) else { return nil }
                return (date, review.rating)
            }
            .sorted { $0.0 < $1.0 }
        guard !dated.isEmpty else { return [] }

        var points: [Date: Double] = [:]
        var total = 0
        for (index, item) in dated.enumerated() {
            total += item.1
            guard let month = monthStart(of: item.0) else { continue }
            // Running average as of the last review in each month.
            points[month] = Double(total) / Double(index + 1)
        }
        return points
            .map { RatingPoint(month: $0.key, runningAverage: $0.value) }
            .sorted { $0.month < $1.month }
    }

    /// Count of reviews per star value (5...1), for the distribution bars.
    static func ratingDistribution(reviews: [ProviderReview]) -> [(stars: Int, count: Int)] {
        (1...5).reversed().map { stars in
            (stars, reviews.filter { $0.rating == stars }.count)
        }
    }

    // MARK: - Trust level derivation

    /// Mirrors the server-side tier thresholds (see CLAUDE.md): jobs completed
    /// plus average rating decide the tier.
    static func trustLevel(completedJobs: Int, avgRating: Double) -> TrustLevel {
        if completedJobs >= 20 && avgRating >= 4.5 { return .expert }
        if completedJobs >= 10 && avgRating >= 4.0 { return .experienced }
        if completedJobs >= 5 && avgRating >= 3.5 { return .established }
        if completedJobs >= 1 { return .newcomer }
        return .unverified
    }

    /// What stands between the user and the next tier, for the progress UI.
    /// Returns nil at the top tier.
    static func nextTrustLevelTarget(completedJobs: Int, avgRating: Double)
        -> (next: TrustLevel, jobsNeeded: Int, ratingNeeded: Double, progress: Double)? {
        let current = trustLevel(completedJobs: completedJobs, avgRating: avgRating)
        let target: (TrustLevel, Int, Double)
        switch current {
        case .unverified: target = (.newcomer, 1, 0)
        case .newcomer: target = (.established, 5, 3.5)
        case .established: target = (.experienced, 10, 4.0)
        case .experienced: target = (.expert, 20, 4.5)
        case .expert: return nil
        }
        let jobsProgress = min(Double(completedJobs) / Double(target.1), 1.0)
        let ratingProgress = target.2 > 0 ? min(avgRating / target.2, 1.0) : 1.0
        return (target.0, target.1, target.2, min(jobsProgress, ratingProgress))
    }

    // MARK: - Helpers

    static func isCompleted(_ deal: Deal) -> Bool {
        deal.completion_status == "completed" || deal.status == "completed"
    }

    private static func displayStatus(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Postgres timestamps arrive with and without fractional seconds.
    static func parseDate(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: iso) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: iso)
    }

    private static func monthStart(of date: Date) -> Date? {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))
    }
}

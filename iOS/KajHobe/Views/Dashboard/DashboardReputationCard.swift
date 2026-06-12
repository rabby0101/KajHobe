import SwiftUI

/// Reputation section of the Dashboard: trust-level progress, rating
/// distribution, and the latest reviews received. Reuses TrustBadge and
/// ProviderReviewCard from the public-profile components.
struct DashboardReputationCard: View {
    let reviews: [ProviderReview]
    let averageRating: Double
    let completedJobs: Int
    /// Opens the full reviews list.
    var onViewAll: (() -> Void)? = nil

    private var trustLevel: TrustLevel {
        DashboardAnalytics.trustLevel(completedJobs: completedJobs, avgRating: averageRating)
    }

    private var distribution: [(stars: Int, count: Int)] {
        DashboardAnalytics.ratingDistribution(reviews: reviews)
    }

    private var maxDistributionCount: Int {
        max(distribution.map(\.count).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "rosette")
                    .foregroundColor(.purple)
                Text("dashboard_reputation".localized)
                    .font(.headline)
                Spacer()
                TrustBadge(trustLevel: trustLevel, compact: true)
            }

            trustProgress

            if reviews.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "star.bubble")
                            .foregroundColor(.secondary)
                        Text("dashboard_no_reviews_yet".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                ratingDistributionView

                VStack(alignment: .leading, spacing: 8) {
                    Text("dashboard_latest_reviews".localized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(reviews.prefix(3)) { review in
                        ProviderReviewCard(review: review)
                    }

                    if reviews.count > 3, let onViewAll {
                        Button(action: onViewAll) {
                            Text(String(format: "dashboard_view_all_reviews".localized, reviews.count))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding()
        .background(CardBackground())
        .cornerRadius(12)
    }

    // MARK: - Trust progress toward the next tier

    @ViewBuilder
    private var trustProgress: some View {
        if let target = DashboardAnalytics.nextTrustLevelTarget(
            completedJobs: completedJobs, avgRating: averageRating
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: target.progress)
                    .tint(.purple)
                Text(String(
                    format: "dashboard_trust_progress".localized,
                    target.next.displayName,
                    target.jobsNeeded,
                    target.ratingNeeded
                ))
                .font(.caption)
                .foregroundColor(.secondary)
            }
        } else {
            Label("dashboard_trust_top_tier".localized, systemImage: "crown.fill")
                .font(.caption)
                .foregroundColor(.purple)
        }
    }

    // MARK: - Rating distribution bars

    private var ratingDistributionView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(distribution, id: \.stars) { row in
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Text("\(row.stars)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                    }
                    .frame(width: 32, alignment: .trailing)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.tertiarySystemGroupedBackground))
                            Capsule()
                                .fill(Color.yellow)
                                .frame(width: geometry.size.width
                                       * CGFloat(row.count) / CGFloat(maxDistributionCount))
                        }
                    }
                    .frame(height: 8)

                    Text("\(row.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .leading)
                }
            }
        }
    }
}

/// Full-screen list of all reviews received, opened from the reputation card
/// or the rating stat card.
struct ReviewsListView: View {
    let reviews: [ProviderReview]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if reviews.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "star.bubble")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("dashboard_no_reviews_yet".localized)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(reviews) { review in
                        ProviderReviewCard(review: review)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("dashboard_reviews_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("done".localized) { dismiss() }
                }
            }
        }
    }
}

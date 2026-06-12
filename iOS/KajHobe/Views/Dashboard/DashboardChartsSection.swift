import SwiftUI
import Charts

/// Analytics section of the Dashboard: money flow over time, deal status
/// breakdown, and rating trend. All data is aggregated client-side by
/// DashboardAnalytics from deals/reviews the dashboard already fetches.
struct DashboardChartsSection: View {
    let deals: [Deal]
    let reviews: [ProviderReview]
    let userId: String

    private var moneyFlow: [DashboardAnalytics.MoneyPoint] {
        DashboardAnalytics.monthlyMoneyFlow(deals: deals, userId: userId)
    }

    private var statusSlices: [DashboardAnalytics.StatusSlice] {
        DashboardAnalytics.statusBreakdown(deals: deals)
    }

    private var ratingPoints: [DashboardAnalytics.RatingPoint] {
        DashboardAnalytics.ratingTrend(reviews: reviews)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.indigo)
                Text("dashboard_analytics".localized)
                    .font(.headline)
                Spacer()
            }

            moneyFlowChart
            statusChart
            ratingTrendChart
        }
        .padding()
        .background(CardBackground())
        .cornerRadius(12)
    }

    // MARK: - Money flow over time

    @ViewBuilder
    private var moneyFlowChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("dashboard_money_flow".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            if moneyFlow.count < 2 {
                chartPlaceholder("dashboard_chart_needs_history".localized)
            } else {
                Chart(moneyFlow) { point in
                    BarMark(
                        x: .value("Month", point.month, unit: .month),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(by: .value("Role", point.role.rawValue))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale([
                    DashboardAnalytics.MoneyPoint.Role.earned.rawValue: Color.green,
                    DashboardAnalytics.MoneyPoint.Role.spent.rawValue: Color.orange
                ])
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Deal status breakdown

    @ViewBuilder
    private var statusChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("dashboard_deal_status".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            if statusSlices.isEmpty {
                chartPlaceholder("dashboard_chart_no_deals".localized)
            } else {
                HStack(spacing: 16) {
                    Chart(statusSlices) { slice in
                        SectorMark(
                            angle: .value("Count", slice.count),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(statusColor(slice.status))
                        .cornerRadius(3)
                    }
                    .frame(width: 130, height: 130)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(statusSlices) { slice in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(statusColor(slice.status))
                                    .frame(width: 8, height: 8)
                                Text(slice.status)
                                    .font(.caption)
                                Spacer()
                                Text("\(slice.count)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Rating trend

    @ViewBuilder
    private var ratingTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("dashboard_rating_trend".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            if ratingPoints.count < 2 {
                chartPlaceholder("dashboard_chart_needs_reviews".localized)
            } else {
                Chart(ratingPoints) { point in
                    LineMark(
                        x: .value("Month", point.month, unit: .month),
                        y: .value("Rating", point.runningAverage)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.yellow)

                    PointMark(
                        x: .value("Month", point.month, unit: .month),
                        y: .value("Rating", point.runningAverage)
                    )
                    .foregroundStyle(Color.yellow)
                }
                .chartYScale(domain: 0...5)
                .frame(height: 140)
            }
        }
    }

    // MARK: - Helpers

    private func chartPlaceholder(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "chart.bar")
                    .foregroundColor(.secondary)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.vertical, 24)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed": return .green
        case "in progress": return .blue
        case "pending approval": return .orange
        case "disputed": return .red
        case "resolved": return .indigo
        default: return .gray
        }
    }
}

import SwiftUI

/// Drill-down list opened by tapping a Dashboard stat card: all of the user's
/// deals filtered by lifecycle state. Rows open the same DealDetailView used
/// everywhere else.
struct DealsListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case active
        case completed
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .active: return "deals_filter_active".localized
            case .completed: return "deals_filter_completed".localized
            case .all: return "deals_filter_all".localized
            }
        }

        func matches(_ deal: Deal) -> Bool {
            switch self {
            case .all: return true
            case .completed: return DashboardAnalytics.isCompleted(deal)
            case .active: return !DashboardAnalytics.isCompleted(deal)
            }
        }
    }

    let deals: [Deal]
    @State var filter: Filter
    @State private var selectedDeal: DealWithCompletion?
    @Environment(\.dismiss) private var dismiss

    private var filteredDeals: [Deal] {
        deals.filter { filter.matches($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredDeals.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "briefcase")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("deals_list_empty".localized)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredDeals) { deal in
                        DealListRow(deal: deal) {
                            selectedDeal = DealWithCompletion(from: deal)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("deals_list_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("done".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("", selection: $filter) {
                        ForEach(Filter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .sheet(item: $selectedDeal) { deal in
                DealDetailView(deal: deal)
            }
        }
    }
}

/// One deal row — same visual language as the Dashboard's ActiveDealCard.
private struct DealListRow: View {
    let deal: Deal
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(deal.job?.title ?? "Unknown Job")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
                Text("৳\(deal.agreed_amount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }

            HStack {
                if let date = DashboardAnalytics.parseDate(deal.completed_at ?? deal.created_at) {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text((deal.completion_status ?? deal.status)
                        .replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var statusColor: Color {
        switch deal.completion_status ?? deal.status {
        case "completed": return .green
        case "in_progress", "active": return .blue
        case "pending_approval": return .orange
        case "disputed": return .red
        default: return .gray
        }
    }
}

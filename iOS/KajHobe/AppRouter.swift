import SwiftUI
import Combine
import Supabase

/// Central navigation router. Maps notification taps (in-app and, later, push
/// deep links) to a destination: switching tabs and/or presenting a sheet at
/// the MainTabView level. Presenting at the root level (instead of inside the
/// Notifications tab) means routing works from any tab without sheet-over-sheet
/// issues.
///
/// Destinations are resolved (fetched) *before* presentation, so the sheet
/// always opens with real data; on resolution failure we fall back to just
/// switching to the most relevant tab.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    enum Tab: Int {
        case jobs = 0
        case messages = 1
        case postJob = 2
        case notifications = 3
        case dashboard = 4
    }

    enum Destination: Identifiable {
        case deal(DealWithCompletion)
        case conversation(ConversationWithDetails)
        case publicProfile(userId: String)

        var id: String {
            switch self {
            case .deal(let deal): return "deal-\(deal.id)"
            case .conversation(let conversation): return "conversation-\(conversation.id)"
            case .publicProfile(let userId): return "profile-\(userId)"
            }
        }
    }

    @Published var selectedTab: Tab = .jobs
    @Published var presentedSheet: Destination?
    /// True while a destination is being resolved (network fetch) after a tap.
    @Published var isResolving = false

    private init() {}

    func switchTab(_ tab: Tab) {
        selectedTab = tab
    }

    func present(_ destination: Destination) {
        presentedSheet = destination
    }

    // MARK: - Notification routing

    /// Route a tapped notification to its destination. Every known
    /// DatabaseNotificationType maps somewhere sensible; unknown raw types fall
    /// back to keyword heuristics and never crash.
    func handleNotificationTap(type rawType: String?, jobId: String?, fromUserId: String?) async {
        guard let rawType, !rawType.isEmpty else { return }

        switch DatabaseNotificationType(rawValue: rawType) {
        // Deal lifecycle → Deal Details (works for completed deals too).
        case .dealCreated, .dealCompleted,
             .completionRequested, .completionApproved, .completionRejected,
             .dealOfferAccepted, .dealOfferRejected:
            await openDealOrFallback(jobId: jobId, fallbackTab: .dashboard)

        // An incoming offer → the deal if one exists, else the Dashboard
        // (mirrors the legacy "NavigateToOffers" behavior).
        case .dealOfferReceived, .offerReceived:
            await openDealOrFallback(jobId: jobId, fallbackTab: .dashboard)

        // Messages → Messages tab, opening the job's conversation when resolvable.
        case .messageReceived, .newMessage:
            switchTab(.messages)
            if let jobId { await openConversation(forJobId: jobId) }

        // Someone is interested / viewed you → their public profile.
        case .interestReceived, .interestRequest, .jobApplication, .profileView:
            if let fromUserId { present(.publicProfile(userId: fromUserId)) }

        // Your interest was accepted → a conversation was created for the job.
        case .interestAccepted:
            switchTab(.messages)
            if let jobId { await openConversation(forJobId: jobId) }

        case .interestRejected:
            switchTab(.jobs)

        case .none:
            // Unknown server type — degrade gracefully via keywords.
            if rawType.contains("message") {
                switchTab(.messages)
            } else if rawType.contains("deal") || rawType.contains("completion")
                        || rawType.contains("payment") || rawType.contains("escrow") {
                await openDealOrFallback(jobId: jobId, fallbackTab: .dashboard)
            } else if rawType.contains("interest"), let fromUserId {
                present(.publicProfile(userId: fromUserId))
            } else {
                print("🧭 AppRouter - No route for notification type '\(rawType)'")
            }
        }
    }

    // MARK: - Destination resolution

    /// Resolve the deal for a job and present Deal Details. Checks active deals
    /// first (cheap, cached), then all of the user's deals so completed-deal
    /// notifications still resolve.
    @discardableResult
    func openDeal(forJobId jobId: String) async -> Bool {
        isResolving = true
        defer { isResolving = false }
        do {
            var deal = try await DealsNetworking.shared.fetchActiveDeals()
                .first(where: { $0.job_id == jobId })
            if deal == nil {
                deal = try await DealsNetworking.shared.fetchMyDeals()
                    .first(where: { $0.job_id == jobId })
            }
            guard let deal else {
                print("🧭 AppRouter - No deal found for job \(jobId)")
                return false
            }
            present(.deal(DealWithCompletion(from: deal)))
            return true
        } catch {
            print("🧭 AppRouter - Failed to resolve deal for job \(jobId): \(error)")
            return false
        }
    }

    private func openDealOrFallback(jobId: String?, fallbackTab: Tab) async {
        if let jobId, await openDeal(forJobId: jobId) { return }
        switchTab(fallbackTab)
    }

    /// Find the current user's conversation for a job and open the chat.
    @discardableResult
    func openConversation(forJobId jobId: String) async -> Bool {
        await openConversation { $0.job_id == jobId }
    }

    /// Open a chat by conversation id (used by push-notification deep links).
    @discardableResult
    func openConversation(id conversationId: String) async -> Bool {
        await openConversation { $0.id == conversationId }
    }

    private func openConversation(matching predicate: (ConversationWithDetails) -> Bool) async -> Bool {
        guard let userId = supabase.auth.currentUser?.id.uuidString else { return false }
        isResolving = true
        defer { isResolving = false }
        do {
            let conversations = try await Networking.shared.fetchConversations(userId: userId)
            guard let conversation = conversations.first(where: predicate) else {
                print("🧭 AppRouter - No matching conversation found")
                return false
            }
            present(.conversation(conversation))
            return true
        } catch {
            print("🧭 AppRouter - Failed to resolve conversation: \(error)")
            return false
        }
    }
}

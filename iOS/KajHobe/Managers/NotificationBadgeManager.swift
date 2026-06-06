import SwiftUI
import Combine
import Supabase

/// Manages notification badge counts across the app
class NotificationBadgeManager: ObservableObject {
    static let shared = NotificationBadgeManager()
    
    @Published var unreadCount: Int = 0
    @Published var readCount: Int = 0
    @Published var archivedCount: Int = 0

    private let networking = NotificationsNetworking.shared
    private var cancellables = Set<AnyCancellable>()
    private var realtimeChannel: RealtimeChannelV2?

    // Candidate notifications fetched from the server (id + creation time only).
    // Unread/read/cleared state is applied locally via NotificationLocalState, so the
    // badge can recompute instantly (no network) when the user reads or clears items.
    private struct CandidateRow: Decodable { let id: String; let created_at: String }
    private struct Candidate { let id: String; let created: Date? }
    private var interestCandidates: [Candidate] = []
    private var businessCandidates: [Candidate] = []
    private var currentUserId: String?
    
    // Serialize start()/resubscribe() so a sign-in + foreground burst can't race
    // two subscribes against the same channel.
    private var isStarting = false

    private init() {
        // No auto-subscribe here. The app lifecycle (sign-in + foreground) drives
        // start()/resubscribe(), so the channel is (re)bound after the launch-time
        // removeAllChannels() teardown and after every socket reconnect.
    }

    deinit {
        cleanup()
    }

    // MARK: - Lifecycle (driven by KajHobeApp auth + foreground events)

    /// (Re)bind the realtime subscription to the current user and re-sync the count.
    /// Safe to call repeatedly. Call on sign-in and on app foreground.
    func start() async {
        await setupRealtimeSubscriptionAsync()
    }

    /// Alias used by the foreground hook for readability.
    func resubscribe() async {
        await setupRealtimeSubscriptionAsync()
    }

    /// Tear down the subscription and reset counts. Call on sign-out.
    func stop() async {
        await networking.unsubscribeFromNotifications(realtimeChannel)
        realtimeChannel = nil
        currentUserId = nil
        await MainActor.run {
            self.unreadCount = 0
            self.readCount = 0
            self.archivedCount = 0
        }
    }
    
    // MARK: - Public Methods
    
    /// Re-fetch the candidate notifications from the server, then derive the unread
    /// count from device-local read/cleared state.
    func refreshCounts() async {
        do {
            let user = try await supabase.auth.user()
            let userId = user.id.uuidString
            await MainActor.run { NotificationLocalState.shared.configure(userId: userId) }

            // Interest candidates: pending interests on the user's OWN jobs.
            var interests: [Candidate] = []
            do {
                let resp = try await supabase
                    .from("job_interests")
                    .select("id, created_at, jobs!inner(client_id)")
                    .eq("jobs.client_id", value: userId)
                    .eq("status", value: "pending")
                    .execute()
                let rows = try JSONDecoder().decode([CandidateRow].self, from: resp.data)
                interests = rows.map { Candidate(id: $0.id, created: NotificationLocalState.date(from: $0.created_at)) }
            } catch {
                print("⚠️ Could not fetch interest candidates: \(error)")
            }

            // Business candidates: notifications addressed to the user (excluding chat).
            var business: [Candidate] = []
            do {
                let resp = try await supabase
                    .from("notifications")
                    .select("id, created_at")
                    .or("user_id.eq.\(userId),to_user_id.eq.\(userId)")
                    // Interest notifications are already counted via job_interests; exclude
                    // them (and chat) here so a single interest isn't counted twice.
                    // deal_offer_received / deal_offer_responded are superseded by deal_created.
                    .neq("type", value: "message_received")
                    .neq("type", value: "show_interest")
                    .neq("type", value: "interest_request")
                    .neq("type", value: "deal_offer_received")
                    .neq("type", value: "deal_offer_responded")
                    .execute()
                let rows = try JSONDecoder().decode([CandidateRow].self, from: resp.data)
                business = rows.map { Candidate(id: $0.id, created: NotificationLocalState.date(from: $0.created_at)) }
            } catch {
                print("⚠️ Could not fetch business candidates: \(error)")
            }

            await MainActor.run {
                self.interestCandidates = interests
                self.businessCandidates = business
                self.recomputeFromLocal()
            }
        } catch {
            print("❌ Error refreshing notification counts: \(error)")
        }
    }

    /// Recompute the badge from cached candidates + local read/cleared state.
    /// Synchronous and cheap — call on the main thread after the user reads or clears.
    func recomputeFromLocal() {
        let state = NotificationLocalState.shared
        let unreadInterests = interestCandidates.filter { state.isUnread(id: $0.id, createdAt: $0.created) }.count
        let unreadBusiness = businessCandidates.filter { state.isUnread(id: $0.id, createdAt: $0.created) }.count
        unreadCount = unreadInterests + unreadBusiness
        print("🔢 Bell unread: \(unreadCount) (interests \(unreadInterests) + business \(unreadBusiness))")
    }
    
    /// Update counts when a notification state changes
    func updateCounts(oldState: NotificationState, newState: NotificationState) {
        DispatchQueue.main.async {
            // Decrease count from old state
            switch oldState {
            case .unread:
                self.unreadCount = max(0, self.unreadCount - 1)
            case .read:
                self.readCount = max(0, self.readCount - 1)
            case .archived:
                self.archivedCount = max(0, self.archivedCount - 1)
            }
            
            // Increase count for new state
            switch newState {
            case .unread:
                self.unreadCount += 1
            case .read:
                self.readCount += 1
            case .archived:
                self.archivedCount += 1
            }
        }
    }
    
    /// Add a new notification (always unread initially)
    func addNewNotification() {
        DispatchQueue.main.async {
            self.unreadCount += 1
        }
    }
    
    /// Mark multiple notifications as read
    func markNotificationsAsRead(_ count: Int) {
        DispatchQueue.main.async {
            let actualCount = min(count, self.unreadCount)
            self.unreadCount = max(0, self.unreadCount - actualCount)
            self.readCount += actualCount
        }
    }
    
    // MARK: - Private Methods
    
    /// (Re)establish the realtime subscription on `notifications_{uid}`. Tears down any
    /// prior channel first so it's safe to call again on every sign-in / foreground.
    private func setupRealtimeSubscriptionAsync() async {
        // Guard against overlapping starts (sign-in + foreground firing together).
        if isStarting { return }
        isStarting = true
        defer { isStarting = false }

        do {
            let user = try await supabase.auth.user()
            currentUserId = user.id.uuidString

            // Drop the old channel before re-subscribing (idempotent re-bind).
            if let existing = realtimeChannel {
                await networking.unsubscribeFromNotifications(existing)
                realtimeChannel = nil
            }

            realtimeChannel = await networking.subscribeToNotifications(
                userId: user.id.uuidString,
                onChange: { [weak self] in
                    // A notification row arrived — re-fetch candidates and recompute
                    // against local read/cleared state (a brand-new notification is unread).
                    Task { await self?.refreshCounts() }

                    // Piggyback the Messages-tab badge on this channel. Every new message
                    // inserts a `message_received` notification (DB trigger handle_new_message),
                    // and the notifications realtime channel is reliable on iOS — whereas a
                    // second postgres_changes channel on the `messages` table is NOT delivered.
                    // So refresh the unread-message count here to keep it live in real time.
                    Task { await MessageBadgeManager.shared.refreshCounts() }
                }
            )

            // Initial count refresh once the channel is live.
            await refreshCounts()
            print("🔔 NotificationBadgeManager subscribed for user: \(user.id.uuidString)")
        } catch {
            print("❌ Error setting up NotificationBadgeManager subscription: \(error)")
        }
    }
    
    private func cleanup() {
        Task {
            await networking.unsubscribeFromNotifications(realtimeChannel)
        }
        realtimeChannel = nil
        cancellables.removeAll()
    }
}

// MARK: - SwiftUI Environment Key
struct NotificationBadgeManagerKey: EnvironmentKey {
    static let defaultValue = NotificationBadgeManager.shared
}

extension EnvironmentValues {
    var notificationBadgeManager: NotificationBadgeManager {
        get { self[NotificationBadgeManagerKey.self] }
        set { self[NotificationBadgeManagerKey.self] = newValue }
    }
}
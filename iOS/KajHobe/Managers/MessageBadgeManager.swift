import SwiftUI
import Combine
import Supabase

/// Manages the unread message badge count on the Messages tab.
/// Tracks the total count of unread messages across ALL conversations
/// for the current user, updated in real-time via Supabase subscriptions.
class MessageBadgeManager: ObservableObject {
    static let shared = MessageBadgeManager()

    @Published var totalUnreadCount: Int = 0

    private var realtimeChannel: RealtimeChannelV2?
    private var currentUserId: String?

    private init() {
        setupRealtimeSubscription()
    }

    deinit {
        Task { [weak realtimeChannel] in
            await realtimeChannel?.unsubscribe()
        }
    }

    // MARK: - Public Methods

    /// Initial fetch of unread count. Called on login/launch.
    func refreshCounts() async {
        do {
            let user = try await supabase.auth.user()
            currentUserId = user.id.uuidString
            await fetchUnreadCount(userId: user.id.uuidString)
        } catch {
            print("❌ Error refreshing message counts: \(error)")
        }
    }

    /// Decrement the badge by the number of messages just marked as read in a conversation.
    /// Called from ChatView after marking messages as read.
    func decrement(by count: Int) {
        guard count > 0 else { return }
        DispatchQueue.main.async {
            self.totalUnreadCount = max(0, self.totalUnreadCount - count)
        }
    }

    /// Reset count to a known value (e.g., after conversation opened). Clamps to 0.
    func setCount(_ count: Int) {
        DispatchQueue.main.async {
            self.totalUnreadCount = max(0, count)
        }
    }

    // MARK: - Private Methods

    private func fetchUnreadCount(userId: String) async {
        do {
            let response = try await supabase
                .from("messages")
                .select("id", count: .exact)
                .is("read_at", value: nil)
                .neq("sender_id", value: userId)
                .execute()
            let count = response.count ?? 0
            await MainActor.run {
                self.totalUnreadCount = count
            }
            print("💬 Message badge: \(count) unread")
        } catch {
            print("⚠️ Could not fetch unread message count: \(error)")
        }
    }

    private func setupRealtimeSubscription() {
        Task {
            do {
                let user = try await supabase.auth.user()
                let userId = user.id.uuidString
                currentUserId = userId

                // Subscribe to public:messages — same channel the rest of the messaging
                // code uses, so a single subscription serves both list and badge updates.
                let channel = supabase.realtimeV2.channel("public:messages")

                // Listen for INSERTs: new message from another user → +1 to badge.
                let insertions = await channel.postgresChange(InsertAction.self, table: "messages")

                // Listen for UPDATEs: read_at changed from NULL to a value → -1 to badge
                // (only when the message wasn't from us and was previously unread).
                let updates = await channel.postgresChange(UpdateAction.self, table: "messages")

                realtimeChannel = channel
                await channel.subscribe()

                // Initial count.
                await fetchUnreadCount(userId: userId)

                // Spawn collectors.
                Task { [weak self] in
                    for await insertion in insertions {
                        await self?.handleInsertion(insertion)
                    }
                }
                Task { [weak self] in
                    for await update in updates {
                        await self?.handleUpdate(update)
                    }
                }

                print("💬 MessageBadgeManager subscribed for user: \(userId)")
            } catch {
                print("❌ Error setting up MessageBadgeManager subscription: \(error)")
            }
        }
    }

    private func handleInsertion(_ action: HasRecord) async {
        let record = action.record
        guard let senderId = record["sender_id"]?.stringValue,
              let readAt = record["read_at"] else {
            return
        }
        guard let uid = currentUserId else { return }
        // Only count messages from OTHER users; only count if currently unread.
        guard senderId != uid else { return }
        if let readAtStr = readAt.stringValue, !readAtStr.isEmpty {
            return // already read, no badge increment
        }
        await MainActor.run {
            self.totalUnreadCount += 1
            print("💬 Message badge +1 → \(self.totalUnreadCount)")
        }
    }

    private func handleUpdate(_ action: HasRecord) async {
        let record = action.record
        guard let readAt = record["read_at"]?.stringValue,
              let senderId = record["sender_id"]?.stringValue else {
            return
        }
        guard let uid = currentUserId else { return }
        // Only decrement when one of OUR messages was just marked read by the recipient.
        guard senderId == uid, !readAt.isEmpty else { return }
        await MainActor.run {
            self.totalUnreadCount = max(0, self.totalUnreadCount - 1)
            print("💬 Message badge -1 → \(self.totalUnreadCount)")
        }
    }
}

// MARK: - SwiftUI Environment Key
struct MessageBadgeManagerKey: EnvironmentKey {
    static let defaultValue = MessageBadgeManager.shared
}

extension EnvironmentValues {
    var messageBadgeManager: MessageBadgeManager {
        get { self[MessageBadgeManagerKey.self] }
        set { self[MessageBadgeManagerKey.self] = newValue }
    }
}

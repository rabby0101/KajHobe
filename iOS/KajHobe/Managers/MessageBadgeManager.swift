import SwiftUI
import Combine
import Supabase

/// Manages the unread message badge count on the Messages tab.
/// Tracks the total count of unread messages across ALL conversations
/// for the current user, updated in real-time via a dedicated Supabase
/// realtime channel (`public:messages:badge`). We use a separate channel
/// name from the conversation list because the iOS SDK de-duplicates
/// channels by topic and silently drops `postgresChange` calls if the
/// channel is already subscribed — and the conversation list view
/// subscribes/unsubscribes its own shared channel as the user navigates,
/// which would otherwise break the badge's real-time stream.
class MessageBadgeManager: ObservableObject {
    static let shared = MessageBadgeManager()

    @Published var totalUnreadCount: Int = 0

    private var realtimeChannel: RealtimeChannelV2?
    private var insertTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
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

                // Cancel any prior collectors (idempotent re-init safety).
                insertTask?.cancel()
                updateTask?.cancel()
                if let existing = realtimeChannel {
                    await existing.unsubscribe()
                }

                // Dedicated channel for the badge — separate from the conversation
                // list's "public:messages" channel so the iOS SDK treats it as an
                // independent subscription that is never unsubscribed by the view.
                let channel = supabase.realtimeV2.channel("public:messages:badge")

                // Order matters: register BOTH listeners BEFORE subscribe(). The
                // iOS SDK drops new listeners on a subscribed channel (line 488
                // of RealtimeChannelV2.swift — `reportIssue` + empty subscription).
                let insertions = channel.postgresChange(InsertAction.self, table: "messages")
                let updates = channel.postgresChange(UpdateAction.self, table: "messages")

                realtimeChannel = channel
                await channel.subscribe()

                // Initial count.
                await fetchUnreadCount(userId: userId)

                // Spawn collectors. Each holds a reference to the channel's async
                // stream and runs independently until the task is cancelled.
                insertTask = Task { [weak self] in
                    for await insertion in insertions {
                        await self?.handleInsertion(insertion)
                    }
                }
                updateTask = Task { [weak self] in
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
        guard let senderId = record["sender_id"]?.stringValue else {
            return
        }
        // read_at is optional — `.null` (AnyJSON) means "not yet read".
        // stringValue on a JSON null is nil, so the if-let correctly skips
        // only when read_at is a non-empty string.
        if let readAt = record["read_at"]?.stringValue, !readAt.isEmpty {
            return // already read, no badge increment
        }
        guard let uid = currentUserId else { return }
        // Only count messages from OTHER users.
        guard senderId != uid else { return }
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
        // Only decrement when one of OUR messages was just marked read by the
        // recipient. (The other party marking their own messages read has no
        // effect on our unread count.)
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

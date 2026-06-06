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
    private var currentUserId: String?

    // Serialize start()/stop() so a foreground burst can't race two subscribes.
    private var isStarting = false

    private init() {
        // No auto-subscribe here. The app lifecycle (sign-in + foreground) drives
        // start()/resubscribe() so the channel is (re)bound after the launch-time
        // removeAllChannels() teardown and after every socket reconnect.
    }

    deinit {
        Task { [weak realtimeChannel] in
            await realtimeChannel?.unsubscribe()
        }
    }

    // MARK: - Lifecycle (driven by KajHobeApp auth + foreground events)

    /// (Re)bind the realtime subscription to the current user and re-sync the count.
    /// Safe to call repeatedly — it tears down any prior channel first. Call on sign-in
    /// and on app foreground.
    func start() async {
        await setupRealtimeSubscription()
    }

    /// Alias used by the foreground hook for readability.
    func resubscribe() async {
        await setupRealtimeSubscription()
    }

    /// Tear down the subscription and reset the badge. Call on sign-out.
    func stop() async {
        insertTask?.cancel(); insertTask = nil
        if let existing = realtimeChannel {
            await existing.unsubscribe()
        }
        realtimeChannel = nil
        currentUserId = nil
        await MainActor.run { self.totalUnreadCount = 0 }
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

    private func setupRealtimeSubscription() async {
        // Guard against overlapping starts (e.g. sign-in + foreground firing together).
        if isStarting { return }
        isStarting = true
        defer { isStarting = false }

        do {
            let user = try await supabase.auth.user()
            let userId = user.id.uuidString
            currentUserId = userId

            // Cancel any prior collector + drop the old channel (idempotent re-bind).
            insertTask?.cancel(); insertTask = nil
            if let existing = realtimeChannel {
                await existing.unsubscribe()
                realtimeChannel = nil
            }

            // Dedicated channel for the badge — separate from the conversation
            // list's "public:messages" channel so the iOS SDK treats it as an
            // independent subscription that is never unsubscribed by the view.
            //
            // IMPORTANT: mirror the WORKING pattern used by ChatView / MessagesView
            // *exactly* — a SINGLE `postgresChange(Insert)` binding, with `subscribe()`
            // and the `for await` loop inside one Task. Registering two bindings
            // (Insert + Update) on one channel was preventing realtime delivery, which
            // is why the badge only updated after the Messages tab forced a manual
            // refresh. We only need INSERT here: a new message → re-count. Read
            // decrements are handled by ChatView.decrement(by:) + the tab refresh.
            let channel = supabase.realtimeV2.channel("public:messages:badge")
            let insertions = channel.postgresChange(InsertAction.self, table: "messages")
            realtimeChannel = channel

            insertTask = Task { [weak self] in
                await channel.subscribe()
                print("💬 MessageBadgeManager subscribed (public:messages:badge) for user: \(userId)")
                // Initial count, after the channel is live.
                await self?.fetchUnreadCount(userId: userId)
                // Any new message anywhere → re-fetch the authoritative unread count.
                // RLS scopes the stream to rows the user can see, and the SELECT count
                // is the single source of truth, so the badge can never drift.
                for await _ in insertions {
                    print("💬 MessageBadgeManager: realtime insert → recount")
                    await self?.fetchUnreadCount(userId: userId)
                }
            }
        } catch {
            print("❌ Error setting up MessageBadgeManager subscription: \(error)")
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

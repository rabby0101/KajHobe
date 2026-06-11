import Foundation

// Thin, named cache instances built on UserScopedDiskCache so each screen can seed
// instantly on appear and refresh from the network in the background. All of these
// hold user-private data and are cleared on sign-out in KajHobeApp.

// MARK: - Dashboard

/// Pairs the dashboard stats with the already-converted active deals, so the
/// Dashboard tab repaints exactly what it last showed.
struct DashboardSnapshot: Codable {
    let dashboard: DashboardData
    let activeDeals: [DealWithCompletion]
}

enum DashboardCache {
    static let shared = UserScopedDiskCache<DashboardSnapshot>(filename: "dashboard_cache.json")
}

// MARK: - Notifications

/// Raw fetch results for the notifications feed. The display models are rebuilt by
/// the existing view logic, so the cache stays dumb and the UI can evolve freely.
struct NotificationsSnapshot: Codable {
    let jobInterests: [JobInterestNotification]
    let businessNotifications: [BusinessNotification]
}

enum NotificationsCache {
    static let shared = UserScopedDiskCache<NotificationsSnapshot>(filename: "notifications_cache.json")
}

// MARK: - Profile

struct ProfileSnapshot: Codable {
    let profile: Profile
    let payoutNumber: String
}

enum ProfileCache {
    static let shared = UserScopedDiskCache<ProfileSnapshot>(filename: "profile_cache.json")
}

// MARK: - Chat messages (one cache file per conversation)

/// Per-conversation message caches (`chat_messages_<conversationId>.json`), capped to
/// the most recent `maxCachedMessages` at save time. `clearAll()` wipes the in-memory
/// instances and sweeps every chat cache file on disk (sign-out).
enum ChatMessagesCache {
    static let maxCachedMessages = 50

    private static let lock = NSLock()
    private static var instances: [String: UserScopedDiskCache<[ChatMessage]>] = [:]

    static func cache(for conversationId: String) -> UserScopedDiskCache<[ChatMessage]> {
        lock.lock(); defer { lock.unlock() }
        if let existing = instances[conversationId] { return existing }
        let fresh = UserScopedDiskCache<[ChatMessage]>(filename: "chat_messages_\(conversationId).json")
        instances[conversationId] = fresh
        return fresh
    }

    static func clearAll() {
        lock.lock()
        let live = Array(instances.values)
        instances.removeAll()
        lock.unlock()
        live.forEach { $0.clear() }

        // Also sweep cache files for conversations not opened this session.
        Task.detached(priority: .utility) {
            let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("chat_messages_") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

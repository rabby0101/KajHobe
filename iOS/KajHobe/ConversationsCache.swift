import Foundation

/// Disk-persisted (JSON file) + in-memory cache for the Messages conversation list, so the tab
/// paints instantly on a cold start and on tab revisits instead of re-fetching everything from
/// scratch each time.
///
/// This is the conversation-list counterpart of `JobsCache` (same in-memory mirror + on-disk JSON
/// design, same `peek()` / `load()` / `save()` shape). `ConversationWithDetails` is already
/// `Codable`, so it round-trips through `JSONEncoder`/`JSONDecoder` with no extra mapping.
///
/// Unlike `JobsCache` (jobs are public), conversations are user-specific, so the cache is **scoped
/// to the owning user id**: `peek`/`load` only return data when the stored owner matches the
/// current user, and `clear()` wipes it on sign-out. This guarantees a re-login on the same device
/// can never flash another account's conversations.
final class ConversationsCache: @unchecked Sendable {
    static let shared = ConversationsCache()

    /// On-disk shape: the conversations plus the id of the user they belong to.
    private struct Payload: Codable {
        let userId: String
        let conversations: [ConversationWithDetails]
    }

    private let lock = NSLock()
    private var memory: Payload?

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("conversations_cache.json")
    }()

    private init() {}

    // MARK: - Read

    /// Synchronous in-memory snapshot for `userId` — `nil` on a cold start or if the cached data
    /// belongs to a different user (use `load()` to read disk).
    func peek(userId: String) -> [ConversationWithDetails]? {
        lock.lock(); defer { lock.unlock() }
        guard let mem = memory, mem.userId == userId else { return nil }
        return mem.conversations
    }

    /// Return the in-memory snapshot, or read + decode from disk and cache it in memory. Only
    /// returns data owned by `userId`.
    func load(userId: String) async -> [ConversationWithDetails]? {
        if let mem = peek(userId: userId) { return mem }

        let url = fileURL
        let decoded: Payload? = await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Payload.self, from: data)
        }.value

        guard let decoded, decoded.userId == userId else { return nil }
        writeMemory(decoded)
        return decoded.conversations
    }

    // MARK: - Write

    /// Update the in-memory mirror immediately and persist to disk (best-effort, off-main),
    /// tagged with the owning `userId`.
    func save(_ conversations: [ConversationWithDetails], userId: String) {
        let payload = Payload(userId: userId, conversations: conversations)
        writeMemory(payload)

        let url = fileURL
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(payload) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    /// Drop the cache (memory + disk). Call on sign-out.
    func clear() {
        lock.lock(); memory = nil; lock.unlock()
        let url = fileURL
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Synchronous, lock-guarded memory access

    private func writeMemory(_ payload: Payload) {
        lock.lock(); defer { lock.unlock() }
        memory = payload
    }
}

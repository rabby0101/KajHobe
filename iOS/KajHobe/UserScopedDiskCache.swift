import Foundation

/// Generic disk-persisted (JSON file) + in-memory cache scoped to an owning user id —
/// the `ConversationsCache` design extracted so every screen can reuse it.
///
/// The in-memory mirror is the fast path (`peek`); the on-disk JSON file survives a cold
/// start (`load`). `peek`/`load` only return data when the stored owner matches the
/// requesting user, so a re-login on the same device can never flash another account's
/// data. Decode failures behave as a cache miss, never a crash.
final class UserScopedDiskCache<T: Codable>: @unchecked Sendable {

    /// On-disk shape: the value plus the id of the user it belongs to.
    private struct Payload: Codable {
        let userId: String
        let value: T
    }

    private let lock = NSLock()
    private var memory: Payload?
    private let fileURL: URL

    init(filename: String) {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent(filename)
    }

    // MARK: - Read

    /// Synchronous in-memory snapshot — `nil` on a cold start or if the cached data
    /// belongs to a different user (use `load()` to read disk).
    func peek(userId: String) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let mem = memory, mem.userId == userId else { return nil }
        return mem.value
    }

    /// Return the in-memory snapshot, or read + decode from disk and cache it in memory.
    /// Only returns data owned by `userId`.
    func load(userId: String) async -> T? {
        if let mem = peek(userId: userId) { return mem }

        let url = fileURL
        let decoded: Payload? = await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Payload.self, from: data)
        }.value

        guard let decoded, decoded.userId == userId else { return nil }

        // Re-check under the lock: a concurrent save() may have installed fresher
        // data while we were reading disk — never clobber it with the older payload.
        lock.lock()
        if let mem = memory, mem.userId == userId {
            lock.unlock()
            return mem.value
        }
        memory = decoded
        lock.unlock()
        return decoded.value
    }

    // MARK: - Write

    /// Update the in-memory mirror immediately and persist to disk (best-effort,
    /// off-main), tagged with the owning `userId`.
    func save(_ value: T, userId: String) {
        let payload = Payload(userId: userId, value: value)
        lock.lock(); memory = payload; lock.unlock()

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
}

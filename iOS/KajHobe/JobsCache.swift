import Foundation

/// Disk-persisted (JSON file) + in-memory cache for the Jobs list, so the home
/// screen paints instantly on a cold start and tab navigation feels seamless.
///
/// This is the iOS counterpart of the Android `JobsCache` (DataStore + in-memory
/// mirror, `peek()` / `load()` / `save()`). The in-memory mirror is the fast path;
/// the on-disk JSON file survives a cold start. `Job` is `Codable`, so the existing
/// model round-trips through `JSONEncoder`/`JSONDecoder` with no extra mapping.
final class JobsCache: @unchecked Sendable {
    static let shared = JobsCache()

    private let lock = NSLock()
    private var memory: [Job]?

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("jobs_cache.json")
    }()

    // UserDefaults key for the user's favorite category names — a lightweight [String]
    // that loads synchronously so the favorites grid never flickers on cold start.
    private let favoritesKey = "jobs_cache_favorite_categories"

    private init() {}

    // MARK: - Jobs (disk-persisted)

    /// Synchronous in-memory snapshot — `nil` on a cold start (use `load()` to read disk).
    func peek() -> [Job]? {
        readMemory()
    }

    /// Return the in-memory snapshot, or read + decode from disk and cache it in memory.
    func load() async -> [Job]? {
        if let mem = readMemory() { return mem }

        let url = fileURL
        let decoded: [Job]? = await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode([Job].self, from: data)
        }.value

        if let decoded { writeMemory(decoded) }
        return decoded
    }

    /// Update the in-memory mirror immediately and persist to disk (best-effort, off-main).
    func save(_ jobs: [Job]) {
        writeMemory(jobs)

        let url = fileURL
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(jobs) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    // MARK: - Favorite categories (UserDefaults — synchronous, tiny payload)

    /// Cached favorite category names from the last known profile. Returns `nil` if
    /// never saved (truly first launch). Reads synchronously — safe to call at view init.
    func peekFavoriteCategories() -> [String]? {
        UserDefaults.standard.stringArray(forKey: favoritesKey)
    }

    /// Persist the user's favorite category names alongside the jobs cache.
    /// Call this whenever the profile is loaded or the user edits their favorites.
    func saveFavoriteCategories(_ categories: [String]) {
        UserDefaults.standard.set(categories, forKey: favoritesKey)
    }

    // MARK: - Synchronous, lock-guarded memory access (kept out of async contexts)

    private func readMemory() -> [Job]? {
        lock.lock(); defer { lock.unlock() }
        return memory
    }

    private func writeMemory(_ jobs: [Job]) {
        lock.lock(); defer { lock.unlock() }
        memory = jobs
    }
}

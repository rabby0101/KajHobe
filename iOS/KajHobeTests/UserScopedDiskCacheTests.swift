import Testing
import Foundation
@testable import KajHobe

struct UserScopedDiskCacheTests {

    /// save() then peek() returns the value for the owning user.
    @Test func roundTripThroughMemory() {
        let cache = UserScopedDiskCache<[String]>(filename: "test_cache_\(UUID().uuidString).json")
        #expect(cache.peek(userId: "user-a") == nil)
        cache.save(["hello", "world"], userId: "user-a")
        #expect(cache.peek(userId: "user-a") == ["hello", "world"])
    }

    /// A different userId must never see another user's cached data.
    @Test func rejectsOtherUser() async {
        let cache = UserScopedDiskCache<[String]>(filename: "test_cache_\(UUID().uuidString).json")
        cache.save(["secret"], userId: "user-a")
        #expect(cache.peek(userId: "user-b") == nil)
        #expect(await cache.load(userId: "user-b") == nil)
    }

    /// A fresh instance (cold start) reads the value back from disk.
    /// Disk writes are async best-effort, so poll briefly until the write lands.
    @Test func loadsFromDiskWithFreshInstance() async throws {
        let filename = "test_cache_\(UUID().uuidString).json"
        let cache = UserScopedDiskCache<[String]>(filename: filename)
        cache.save(["persisted"], userId: "user-a")

        let fresh = UserScopedDiskCache<[String]>(filename: filename)
        var loaded: [String]? = nil
        for _ in 0..<50 {
            loaded = await fresh.load(userId: "user-a")
            if loaded != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(loaded == ["persisted"])
        cache.clear()
    }

    /// clear() wipes memory immediately and disk shortly after.
    @Test func clearWipesMemoryAndDisk() async throws {
        let filename = "test_cache_\(UUID().uuidString).json"
        let cache = UserScopedDiskCache<[String]>(filename: filename)
        cache.save(["gone"], userId: "user-a")

        // Wait for the disk write to land before clearing.
        let fresh = UserScopedDiskCache<[String]>(filename: filename)
        for _ in 0..<50 {
            if await fresh.load(userId: "user-a") != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        cache.clear()
        #expect(cache.peek(userId: "user-a") == nil)

        // Poll until the file deletion lands, then confirm a cold load misses.
        var diskValue: [String]? = ["sentinel"]
        for _ in 0..<50 {
            diskValue = await UserScopedDiskCache<[String]>(filename: filename).load(userId: "user-a")
            if diskValue == nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(diskValue == nil)
    }
}

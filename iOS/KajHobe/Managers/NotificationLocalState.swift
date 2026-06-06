import Foundation
import Combine

/// Device-local read / cleared state for notifications.
///
/// Notifications are treated as transient: the SERVER is the source of truth for
/// *what* notifications exist (job_interests, notifications) and for real actions
/// (accept / reject), while THIS store — persisted in UserDefaults, scoped per user —
/// owns whether each notification is read or cleared.
///
/// Unread rule: `created_at > baseline && id ∉ readIDs && id ∉ clearedIDs`.
/// The `baseline` is stamped the first time a user is configured on a build that has
/// this store, so the entire pre-existing backlog (e.g. the historical 206) is
/// implicitly "read" and never inflates the badge — without any server migration.
///
/// Trade-off (intentional, per product decision): state lives on-device, so it does
/// not sync across devices and resets on reinstall.
///
/// Access is expected on the main thread (SwiftUI views + main-hopped callers).
final class NotificationLocalState: ObservableObject {
    static let shared = NotificationLocalState()

    /// Bumped on every mutation so SwiftUI views observing this object re-render.
    @Published private(set) var revision: Int = 0

    private var userId: String = ""
    private var readIDs: Set<String> = []
    private var clearedIDs: Set<String> = []
    private var baseline: Date = .distantPast

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Configuration

    /// Scope the store to a user and load their persisted state. Idempotent.
    func configure(userId: String) {
        guard !userId.isEmpty, userId != self.userId else { return }
        self.userId = userId
        load()
        revision += 1
    }

    private func key(_ suffix: String) -> String { "notif.\(suffix).\(userId)" }

    private func load() {
        readIDs = Set(defaults.stringArray(forKey: key("read")) ?? [])
        clearedIDs = Set(defaults.stringArray(forKey: key("cleared")) ?? [])

        let baselineKey = key("baseline")
        if defaults.object(forKey: baselineKey) != nil {
            baseline = Date(timeIntervalSince1970: defaults.double(forKey: baselineKey))
        } else {
            // First launch for this user on a build with local state: everything that
            // already exists is considered read. Only notifications created after now
            // can become "unread".
            baseline = Date()
            defaults.set(baseline.timeIntervalSince1970, forKey: baselineKey)
        }
    }

    private func persistRead() { defaults.set(Array(readIDs), forKey: key("read")) }
    private func persistCleared() { defaults.set(Array(clearedIDs), forKey: key("cleared")) }

    // MARK: - Queries

    func isCleared(_ id: String) -> Bool { clearedIDs.contains(id) }

    func isUnread(id: String, createdAt: Date?) -> Bool {
        if clearedIDs.contains(id) || readIDs.contains(id) { return false }
        guard let createdAt else { return false }
        return createdAt > baseline
    }

    func isUnread(id: String, createdAtISO iso: String) -> Bool {
        isUnread(id: id, createdAt: Self.date(from: iso))
    }

    // MARK: - Mutations

    func markRead(_ id: String) {
        guard !readIDs.contains(id) else { return }
        readIDs.insert(id)
        persistRead()
        revision += 1
    }

    func markRead(_ ids: [String]) {
        let newOnes = ids.filter { !readIDs.contains($0) }
        guard !newOnes.isEmpty else { return }
        readIDs.formUnion(newOnes)
        persistRead()
        revision += 1
    }

    func clear(_ id: String) {
        clearedIDs.insert(id)
        readIDs.remove(id)
        persistCleared()
        persistRead()
        revision += 1
    }

    func clear(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        clearedIDs.formUnion(ids)
        readIDs.subtract(ids)
        persistCleared()
        persistRead()
        revision += 1
    }

    // MARK: - Helpers

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    static func date(from iso: String) -> Date? {
        isoFractional.date(from: iso) ?? isoPlain.date(from: iso)
    }
}

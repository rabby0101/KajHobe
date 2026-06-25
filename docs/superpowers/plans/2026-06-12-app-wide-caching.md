# App-Wide Stale-While-Revalidate Caching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every main iOS screen (Dashboard, Notifications, Profile, Chat) paints instantly from a user-scoped disk cache and refreshes from the network in the background, eliminating per-visit spinners.

**Architecture:** Extract the proven `ConversationsCache` design into a generic `UserScopedDiskCache<T: Codable>` (in-memory mirror + JSON file in Caches, tagged with owning userId). Add four thin cache instances and wire each screen to: seed from cache on appear → fetch from network → save back. Clear all caches on sign-out.

**Tech Stack:** Swift 5 / SwiftUI, Supabase Swift SDK, Swift Testing (`import Testing`), xcodebuild with iPhone 16 simulator.

**Spec:** `docs/superpowers/specs/2026-06-12-app-wide-caching-design.md`

**Working directory:** `/Volumes/Experiment/GitHub/KajHobe/iOS` (all paths below relative to repo root `/Volumes/Experiment/GitHub/KajHobe`). The Xcode project uses `fileSystemSynchronizedGroups` (objectVersion 77), so new `.swift` files dropped into `iOS/KajHobe/` or `iOS/KajHobeTests/` are picked up automatically — no pbxproj editing.

**Key facts for the engineer:**
- Template for the seed-then-refresh view pattern: `iOS/KajHobe/MessagesView.swift:114-143`.
- `ChatMessage` has a custom Codable that round-trips `negotiation_data` as a JSON string — safe to encode/decode through the cache as-is.
- The notifications screen renders `feedItems` = `notifications: [JobInterestNotification]` + `businessNotifications: [BusinessNotification]`; its spinner already guards on `feedItems.isEmpty` (`NotificationsView.swift:808`), so seeding those arrays suppresses it automatically. The `unifiedNotifications` state is a legacy code path — don't touch it.
- Build: `xcodebuild -project KajHobe.xcodeproj -scheme KajHobe -destination 'platform=iOS Simulator,name=iPhone 16' build` (run from `iOS/`). Expected: `** BUILD SUCCEEDED **`.

---

### Task 1: `UserScopedDiskCache<T>` generic (TDD)

**Files:**
- Create: `iOS/KajHobeTests/UserScopedDiskCacheTests.swift`
- Create: `iOS/KajHobe/UserScopedDiskCache.swift`

- [ ] **Step 1: Write the failing tests**

Create `iOS/KajHobeTests/UserScopedDiskCacheTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `iOS/`:
```bash
xcodebuild test -project KajHobe.xcodeproj -scheme KajHobe \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:KajHobeTests/UserScopedDiskCacheTests 2>&1 | tail -20
```
Expected: **compile failure** — `cannot find 'UserScopedDiskCache' in scope`.

- [ ] **Step 3: Write the implementation**

Create `iOS/KajHobe/UserScopedDiskCache.swift`:

```swift
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
        lock.lock(); memory = decoded; lock.unlock()
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
```

- [ ] **Step 4: Run tests to verify they pass**

Same command as Step 2. Expected: `** TEST SUCCEEDED **` with 4 passing tests.

- [ ] **Step 5: Commit**

```bash
git add iOS/KajHobe/UserScopedDiskCache.swift iOS/KajHobeTests/UserScopedDiskCacheTests.swift
git commit -m "feat(ios): add generic UserScopedDiskCache extracted from ConversationsCache design"
```

---

### Task 2: Domain cache declarations

**Files:**
- Create: `iOS/KajHobe/DomainCaches.swift`

- [ ] **Step 1: Create the file**

```swift
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
```

Note: `JobInterestNotification` is declared in `iOS/KajHobe/NotificationsView.swift:6` and `BusinessNotification` in `iOS/KajHobe/BusinessNotificationModels.swift:5` — both internal Codable structs with value-type fields, same module, so this compiles without changes. If the compiler complains about Sendable when these snapshots cross into detached tasks, add `, Sendable` to those two struct declarations — all their stored properties are already Sendable.

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild -project KajHobe.xcodeproj -scheme KajHobe \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add iOS/KajHobe/DomainCaches.swift
git commit -m "feat(ios): add Dashboard/Notifications/Profile/ChatMessages cache instances"
```

---

### Task 3: Dashboard — seed from cache, save after fetch

**Files:**
- Modify: `iOS/KajHobe/DashboardView.swift:87-94` (`.onAppear`)
- Modify: `iOS/KajHobe/DashboardView.swift:313-385` (`loadDashboardData`)

- [ ] **Step 1: Seed from cache in `.onAppear`**

Replace the existing `.onAppear` block (lines 87–94):

```swift
        .onAppear {
            Task {
                await loadDashboardData()
                await setupRealtimeSubscription()
                startAutoRefreshTimer()
            }
            // print("📊 Dashboard appeared - refreshing data")
        }
```

with:

```swift
        .onAppear {
            Task {
                // Seed instantly from cache (memory → disk) so the dashboard paints
                // on the first frame instead of a spinner — the fetch below then
                // refreshes silently in the background.
                if dashboardData == nil,
                   let uid = supabase.auth.currentUser?.id.uuidString {
                    if let cached = DashboardCache.shared.peek(userId: uid) {
                        dashboardData = cached.dashboard
                        activeDeals = cached.activeDeals
                        isLoading = false
                    } else if let disk = await DashboardCache.shared.load(userId: uid) {
                        dashboardData = disk.dashboard
                        activeDeals = disk.activeDeals
                        isLoading = false
                    }
                }
                await loadDashboardData()
                await setupRealtimeSubscription()
                startAutoRefreshTimer()
            }
        }
```

- [ ] **Step 2: Save the snapshot after a successful fetch**

In `loadDashboardData`, replace the success path — from `async let dashboardDataFetch...` through the end of the `await MainActor.run { ... }` success block (currently lines ~330–370) — with:

```swift
            print("📊 Starting dashboard data fetch...")
            async let dashboardDataFetch = Networking.shared.fetchDashboardData(forceRefresh: forceRefresh)
            async let activeDealsDataFetch = Networking.shared.fetchActiveDeals(forceRefresh: forceRefresh)

            let (dashboard, deals) = try await (dashboardDataFetch, activeDealsDataFetch)

            print("📊 Dashboard data received - Active deals: \(dashboard.active_deals_count), Completed: \(dashboard.completed_deals_count)")
            print("📊 Fetched \(deals.count) active deals")

            // Convert Deal to DealWithCompletion and remove duplicates (done outside
            // the MainActor block so the converted array can also be persisted below).
            let convertedDeals = deals.map { deal in
                DealWithCompletion(
                    id: deal.id,
                    job_id: deal.job_id,
                    client_id: deal.client_id,
                    provider_id: deal.provider_id,
                    agreed_amount: deal.agreed_amount,
                    agreed_terms: deal.agreed_terms,
                    timeline: deal.timeline,
                    status: deal.status,
                    completion_status: deal.completion_status ?? "in_progress",
                    client_completion_requested: deal.client_completion_requested ?? false,
                    provider_completion_requested: deal.provider_completion_requested ?? false,
                    client_completion_requested_at: deal.client_completion_requested_at,
                    provider_completion_requested_at: deal.provider_completion_requested_at,
                    created_at: deal.created_at,
                    completed_at: deal.completed_at,
                    job: deal.job,
                    client_profile: deal.client_profile,
                    provider_profile: deal.provider_profile,
                    pending_completion_requests: nil
                )
            }.uniqued(by: \.id)

            await MainActor.run {
                // Add smooth animation for real-time updates
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.dashboardData = dashboard
                    self.activeDeals = convertedDeals
                }
                self.isLoading = false
                self.isRefreshing = false

                // Persist for instant paint on the next visit / cold start.
                if let uid = supabase.auth.currentUser?.id.uuidString {
                    DashboardCache.shared.save(
                        DashboardSnapshot(dashboard: dashboard, activeDeals: convertedDeals),
                        userId: uid
                    )
                }
            }
```

Two behavioral notes baked into this change: (a) the hardcoded `forceRefresh: true` on both fetches becomes the function's `forceRefresh` parameter — the always-force comment `// Always force refresh for now` is removed; (b) the stale `// Cache has been removed from the application` comment near the top of `loadDashboardData` (line ~326) must be deleted.

- [ ] **Step 3: Build**

```bash
xcodebuild -project KajHobe.xcodeproj -scheme KajHobe \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add iOS/KajHobe/DashboardView.swift
git commit -m "feat(dashboard): paint instantly from disk cache, refresh in background"
```

---

### Task 4: Notifications — seed both source arrays, save after each fetch

**Files:**
- Modify: `iOS/KajHobe/NotificationsView.swift:1092-1100` (`.onAppear`)
- Modify: `iOS/KajHobe/NotificationsView.swift:1416-1419` (interests save, inside `loadNotifications`)
- Modify: `iOS/KajHobe/NotificationsView.swift:974-993` (business save, inside `loadBusinessNotifications`)

- [ ] **Step 1: Seed from cache in `.onAppear`**

Replace:

```swift
            .onAppear {
                loadingTask = Task {
                    if let uid = supabase.auth.currentUser?.id.uuidString {
                        await MainActor.run { NotificationLocalState.shared.configure(userId: uid) }
                    }
                    await safeLoadUnifiedNotifications()
                    await loadBusinessNotifications()
                }
            }
```

with:

```swift
            .onAppear {
                loadingTask = Task {
                    if let uid = supabase.auth.currentUser?.id.uuidString {
                        await MainActor.run { NotificationLocalState.shared.configure(userId: uid) }

                        // Seed instantly from cache (memory → disk) so the feed paints
                        // on the first frame; the fetches below refresh silently.
                        if notifications.isEmpty && businessNotifications.isEmpty {
                            var snap = NotificationsCache.shared.peek(userId: uid)
                            if snap == nil { snap = await NotificationsCache.shared.load(userId: uid) }
                            if let snap {
                                await MainActor.run {
                                    notifications = snap.jobInterests
                                    businessNotifications = snap.businessNotifications
                                }
                            }
                        }
                    }
                    await safeLoadUnifiedNotifications()
                    await loadBusinessNotifications()
                }
            }
```

- [ ] **Step 2: Save after the interests fetch succeeds**

In `loadNotifications`, replace:

```swift
                await MainActor.run {
                    self.notifications = parsedNotifications
                    print("✅ Successfully loaded \(parsedNotifications.count) notifications with provider names")
                }
```

with:

```swift
                await MainActor.run {
                    self.notifications = parsedNotifications
                    print("✅ Successfully loaded \(parsedNotifications.count) notifications with provider names")

                    // Persist both feed sources for instant paint on the next visit.
                    NotificationsCache.shared.save(
                        NotificationsSnapshot(
                            jobInterests: parsedNotifications,
                            businessNotifications: self.businessNotifications
                        ),
                        userId: user.id.uuidString
                    )
                }
```

(`user` is already in scope — it's the authenticated user resolved at the top of `loadNotifications`.)

- [ ] **Step 3: Save after the business fetch succeeds**

In `loadBusinessNotifications` (line ~974), the success path currently sets `self.businessNotifications = loadedNotifications` inside a `MainActor.run`. Extend that block:

```swift
            await MainActor.run {
                self.businessNotifications = loadedNotifications
                self.isLoadingBusiness = false

                // Persist both feed sources for instant paint on the next visit.
                if let uid = supabase.auth.currentUser?.id.uuidString {
                    NotificationsCache.shared.save(
                        NotificationsSnapshot(
                            jobInterests: self.notifications,
                            businessNotifications: loadedNotifications
                        ),
                        userId: uid
                    )
                }
            }
```

Keep the surrounding code (the `isLoadingBusiness = true` at the start and the catch block) exactly as it is.

- [ ] **Step 4: Build**

Same build command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add iOS/KajHobe/NotificationsView.swift
git commit -m "feat(notifications): paint feed instantly from disk cache, refresh in background"
```

---

### Task 5: Profile — seed from cache, parallel profile+payout fetch, save

**Files:**
- Modify: `iOS/KajHobe/ProfileView.swift:441-466` (`loadProfile`)

- [ ] **Step 1: Replace `loadProfile`**

Replace the whole function with:

```swift
    private func loadProfile() {
        Task {
            // Seed instantly from cache (memory → disk) so the profile paints
            // without a spinner; the fetch below refreshes silently.
            if profile == nil, let uid = supabase.auth.currentUser?.id.uuidString {
                if let cached = ProfileCache.shared.peek(userId: uid) {
                    await applyProfileSnapshot(cached)
                } else if let disk = await ProfileCache.shared.load(userId: uid) {
                    await applyProfileSnapshot(disk)
                }
            }
            if profile == nil {
                await MainActor.run { isLoading = true }
            }

            do {
                let user = try supabase.auth.requireCurrentUser()
                // Fetch profile and payout number in parallel. The payout result is
                // only used for service providers, but starting both up front removes
                // the serial round-trip that used to delay every profile load.
                async let profileFetch = Networking.shared.fetchProfile(userId: user.id.uuidString)
                async let payoutFetch = EscrowNetworking.shared.fetchMyPayoutNumber()

                let fetched = try await profileFetch
                var fetchedPayout = ""
                if fetched.is_service_provider == true {
                    fetchedPayout = ((try? await payoutFetch) ?? nil) ?? ""
                } else {
                    _ = try? await payoutFetch
                }

                await MainActor.run {
                    self.profile = fetched
                    self.payoutNumberLoaded = fetchedPayout
                    self.payoutBkashNumber = fetchedPayout
                    self.isLoading = false

                    // Persist for instant paint on the next visit / cold start.
                    ProfileCache.shared.save(
                        ProfileSnapshot(profile: fetched, payoutNumber: fetchedPayout),
                        userId: user.id.uuidString
                    )
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }

    @MainActor
    private func applyProfileSnapshot(_ snap: ProfileSnapshot) {
        self.profile = snap.profile
        self.payoutNumberLoaded = snap.payoutNumber
        self.payoutBkashNumber = snap.payoutNumber
        self.isLoading = false
    }
```

(The old version did `isLoading = true` unconditionally, then fetched profile and payout **serially**. `applyProfileSnapshot` is a new private helper added right below `loadProfile`.)

- [ ] **Step 2: Build**

Same build command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add iOS/KajHobe/ProfileView.swift
git commit -m "feat(profile): cache profile + payout, fetch both in parallel"
```

---

### Task 6: Chat — instant history paint, cache updated on fetch and realtime insert

**Files:**
- Modify: `iOS/KajHobe/ChatView.swift:275-301` (`loadChatData`)
- Modify: `iOS/KajHobe/ChatView.swift:388-397` (realtime append in `handleNewMessage`)

- [ ] **Step 1: Seed and persist in `loadChatData`**

Replace the function with:

```swift
    private func loadChatData() async {
        print("🔍 CHAT DEBUG: Loading chat data for conversation: \(conversation.id)")

        // Seed instantly from the per-conversation cache (memory → disk) so the chat
        // history paints on the first frame; the fetch below reconciles silently.
        if messages.isEmpty, let uid = currentUserId {
            let cache = ChatMessagesCache.cache(for: conversation.id)
            if let cached = cache.peek(userId: uid) {
                await MainActor.run {
                    self.messages = cached
                    self.isLoading = false
                }
            } else if let disk = await cache.load(userId: uid) {
                await MainActor.run {
                    self.messages = disk
                    self.isLoading = false
                }
            }
        }

        do {
            // The current user id is already resolved synchronously from the session, so we go
            // straight to fetching messages — no profile round-trip blocking the chat load.
            let fetchedMessages = try await MessagesNetworking.shared.fetchMessages(
                conversationId: conversation.id
            )

            await MainActor.run {
                self.messages = fetchedMessages
                self.isLoading = false
                print("🔍 CHAT DEBUG: Chat data loaded with \(self.messages.count) messages")

                persistMessagesToCache(fetchedMessages)

                // Mark unread messages as read for the current user
                Task {
                    await markMessagesAsRead()
                }
            }

        } catch {
            print("❌ CHAT DEBUG: Error loading chat data: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    /// Persist the most recent messages so the next open paints instantly.
    /// Capped to `ChatMessagesCache.maxCachedMessages`; older history still
    /// comes from the network exactly as before.
    private func persistMessagesToCache(_ messages: [ChatMessage]) {
        guard let uid = currentUserId else { return }
        ChatMessagesCache.cache(for: conversation.id)
            .save(Array(messages.suffix(ChatMessagesCache.maxCachedMessages)), userId: uid)
    }
```

- [ ] **Step 2: Persist after a realtime insert**

In `handleNewMessage`, inside the `await MainActor.run { ... }` block, the duplicate-check branch currently looks like:

```swift
                if !messages.contains(where: { $0.id == newMessage.id }) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        messages.append(newMessage)
                    }
                    print("✅ CHAT REALTIME DEBUG: Added new message to chat. Total messages: \(messages.count)")
```

Add one line right after the `withAnimation` block:

```swift
                if !messages.contains(where: { $0.id == newMessage.id }) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        messages.append(newMessage)
                    }
                    persistMessagesToCache(messages)
                    print("✅ CHAT REALTIME DEBUG: Added new message to chat. Total messages: \(messages.count)")
```

(Realtime inserts include the sender's own messages, so sent messages are also captured in the cache through this path.)

- [ ] **Step 3: Build**

Same build command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add iOS/KajHobe/ChatView.swift
git commit -m "feat(chat): paint conversation history instantly from per-conversation cache"
```

---

### Task 7: Clear all caches on sign-out

**Files:**
- Modify: `iOS/KajHobe/KajHobeApp.swift:137-139`

- [ ] **Step 1: Extend the sign-out cleanup**

Replace:

```swift
                        // Drop the cached conversation list so a different account can't
                        // surface the previous user's chats from disk.
                        ConversationsCache.shared.clear()
```

with:

```swift
                        // Drop all user-scoped caches so a different account can't
                        // surface the previous user's data from disk.
                        ConversationsCache.shared.clear()
                        DashboardCache.shared.clear()
                        NotificationsCache.shared.clear()
                        ProfileCache.shared.clear()
                        ChatMessagesCache.clearAll()
```

- [ ] **Step 2: Build**

Same build command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add iOS/KajHobe/KajHobeApp.swift
git commit -m "feat(ios): clear all user-scoped caches on sign-out"
```

---

### Task 8: Hygiene cleanup

**Files:**
- Delete: `iOS/KajHobe/NotificationsView.swift.backup`
- Delete: `iOS/KajHobe/PremiumJobCard.swift.disabled`
- Modify: `iOS/KajHobe/LocalStorageManager.swift` (strip dead code)

- [ ] **Step 1: Verify `ConversationMetadata` has no live references**

```bash
grep -rn "ConversationMetadata" iOS/KajHobe --include="*.swift" | grep -v "LocalStorageManager.swift"
```
Expected: no output. (Its only uses are inside the commented-out block being deleted. If anything shows up, keep the struct and delete only the commented block.)

- [ ] **Step 2: Delete the dead files**

```bash
git rm "iOS/KajHobe/NotificationsView.swift.backup" "iOS/KajHobe/PremiumJobCard.swift.disabled"
```

- [ ] **Step 3: Strip dead code from `LocalStorageManager.swift`**

Delete the entire commented block from `// MARK: - Conversations Storage (Removed with messaging functionality)` (line ~50) through the closing `*/` (line ~240), and delete the `ConversationMetadata` struct at the bottom of the file. Keep everything else (current-user management, sync status, `clearAllData`, directory setup) untouched — `clearAllData` still references the conversations directory.

- [ ] **Step 4: Build**

Same build command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add -A iOS/KajHobe/NotificationsView.swift.backup iOS/KajHobe/PremiumJobCard.swift.disabled iOS/KajHobe/LocalStorageManager.swift
git commit -m "chore(ios): remove dead backup/disabled files and commented-out storage code"
```

---

### Task 9: Final verification

- [ ] **Step 1: Full clean build + complete unit test run**

```bash
xcodebuild -project KajHobe.xcodeproj -scheme KajHobe \
  -destination 'platform=iOS Simulator,name=iPhone 16' clean build 2>&1 | tail -5
xcodebuild test -project KajHobe.xcodeproj -scheme KajHobe \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:KajHobeTests 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`.

- [ ] **Step 2: Manual verification in the simulator (or on device via the deploy-to-iphone skill)**

For each screen — Dashboard, Notifications, Profile, one Chat conversation:
1. Visit the screen once (populates the cache).
2. Kill the app completely.
3. Relaunch and revisit: content must paint immediately with **no spinner**, then silently refresh.
4. Sign out, sign back in as the same user: first visit after sign-in shows the normal spinner (caches were cleared), subsequent visits paint instantly.

- [ ] **Step 3: Report results**

State plainly what passed and what didn't, with test output. Do not claim success without the commands' actual output.

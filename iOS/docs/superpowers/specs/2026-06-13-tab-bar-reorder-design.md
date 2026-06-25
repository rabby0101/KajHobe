# Tab Bar Reorder: Dashboard ↔ Notifications

## Problem

The bottom tab bar currently shows: **Jobs, Messages, Post Job, Notifications, Dashboard**.

The user wants Notifications on the right end, with Dashboard sitting immediately to its left. Final order: **Jobs, Messages, Post Job, Dashboard, Notifications**.

## Scope

Single file change. No database, no API, no model changes. Pure SwiftUI tab order in `KajHobe/MainTabView.swift`.

## Approach Chosen: Visual Reorder Only

Swap the two `tabItem` blocks in `MainTabView.swift` (lines 35–49). Leave `AppRouter.Tab` enum values untouched.

### Why not also renumber `AppRouter.Tab`?

`AppRouter.Tab` raw values are never persisted, never serialized, and never compared by raw value — they're just unique tags SwiftUI uses to match `tabItem` blocks. The `Int` values `(.notifications = 3, .dashboard = 4)` will no longer reflect visual position after the swap, but nothing in the codebase reads them positionally. Keeping them stable avoids touching `AppRouter.swift` and the `onChange(of: router.selectedTab)` switch in `MainTabView.swift` (which switches on enum cases, not raw values).

## File Changes

### `KajHobe/MainTabView.swift`

**Before** (lines 35–49):
```swift
NotificationsView()
    .tabItem {
        Image(systemName: notificationBadgeManager.unreadCount > 0 ? "bell.fill" : "bell")
        Text("notifications".localized)
    }
    .badge(notificationBadgeManager.unreadCount > 0 ? notificationBadgeManager.unreadCount : 0)
    .tag(AppRouter.Tab.notifications)
    .environmentObject(notificationBadgeManager)

DashboardView()
    .tabItem {
        Image(systemName: "chart.bar.fill")
        Text("dashboard".localized)
    }
    .tag(AppRouter.Tab.dashboard)
```

**After:**
```swift
DashboardView()
    .tabItem {
        Image(systemName: "chart.bar.fill")
        Text("dashboard".localized)
    }
    .tag(AppRouter.Tab.dashboard)

NotificationsView()
    .tabItem {
        Image(systemName: notificationBadgeManager.unreadCount > 0 ? "bell.fill" : "bell")
        Text("notifications".localized)
    }
    .badge(notificationBadgeManager.unreadCount > 0 ? notificationBadgeManager.unreadCount : 0)
    .tag(AppRouter.Tab.notifications)
    .environmentObject(notificationBadgeManager)
```

The `NotificationsView` block keeps `.badge(...)` and `.environmentObject(notificationBadgeManager)` modifiers; the `DashboardView` block has no extras. Final order in the `TabView` becomes Jobs, Messages, Post Job, Dashboard, Notifications.

## What Does NOT Change

- `AppRouter.swift` — `Tab` enum cases and raw values stay as-is.
- `onChange(of: router.selectedTab)` switch in `MainTabView.swift` — switches on cases, unaffected.
- `selectedTab = .jobs` default — unchanged.
- Any push-notification handlers that call `router.switchTab(.notifications)` or `.dashboard` — still work, SwiftUI just visually shows them in a different position now.
- All `Tab` references throughout the codebase (search confirmed: only used in `MainTabView.swift` and `AppRouter.swift`).

## Verification

1. Build with `xcodebuild -project KajHobe.xcodeproj -scheme KajHobe -destination 'platform=iOS Simulator,name=iPhone 16' build`.
2. Run in simulator, confirm tab order visually: Jobs, Messages, Post Job, Dashboard, Notifications.
3. Tap Dashboard — opens `DashboardView`. Tap Notifications — opens `EnhancedNotificationsView` (or current `NotificationsView`) with the bell badge.
4. Tap a push notification that routes to `.notifications` or `.dashboard` — should still land on the correct tab.

## Out of Scope

- Renaming tabs, changing icons, changing localized strings.
- Adding/removing tabs.
- Persisting last-selected tab across launches.
- Changing `Tab` enum raw values.

# KajHobe Android Dashboard — iOS Parity Design Spec

**Date:** 2026-06-16
**Author:** Sk Fazla Rabby (with Claude)
**Status:** Approved design — ready for implementation plan

## 1. Goal

Bring the Android app's `DashboardScreen` to **full feature parity** with the iOS
`DashboardView`, including all visual sections, interactions, real-time updates,
and refresh behaviors. The Android side must look and behave the same as iOS for
every dashboard feature currently in production on iOS.

User decisions driving this spec:
- **Full iOS parity, all features** (not a subset).
- **1:1 iOS file mirror** — new Android files are named to match their iOS counterparts.
- **MPAndroidChart** for the three analytics charts.
- **Match iOS real-time + auto-refresh + pull-to-refresh** exactly.

## 2. Current state

### 2.1 iOS dashboard (production)

iOS source of truth:
- `iOS/KajHobe/DashboardView.swift` (782 lines)
- `iOS/KajHobe/Views/Dashboard/DashboardAnalytics.swift` (155 lines)
- `iOS/KajHobe/Views/Dashboard/DashboardChartsSection.swift` (181 lines)
- `iOS/KajHobe/Views/Dashboard/DashboardReputationCard.swift` (184 lines)
- `iOS/KajHobe/Views/Dashboard/DealsListView.swift` (142 lines)
- Reused components: `ProviderReviewCard`, `TrustBadge` (in `PublicProfileComponents.swift`)

iOS dashboard renders, top to bottom on a `ScrollView`:
1. **Toolbar** — left: `bell.badge` → `NotificationSettingsView`; right: `person.circle` → `ProfileView`. Title "Dashboard".
2. **Stats section** (4-card 2×2 `LazyVGrid`) — Active Deals, Completed, Earned/Spent (toggles by `user_type`), Rating. Each card tappable for drill-down except when `dashboardData == nil` (shows empty state with 4 zero cards + "Browse Available Jobs" / "Post a Job" CTAs).
3. **Analytics charts section** (only if `myDeals` or `myReviews` is non-empty):
   - Money flow bar chart (grouped bars: Earned green, Spent orange, per month, last 6 months; placeholder "Needs more history" if <2 points).
   - Status donut chart (130×130, inner radius 0.6, with side legend of status + count).
   - Rating trend line chart (catmull-rom, yellow, 0–5 y-axis, placeholder "Needs more reviews" if <2 points).
4. **Reputation card** — trust badge (compact, top right), trust progress bar toward next tier or "Top tier" crown label, 5-star distribution bars (5→1, proportional capsules), up to 3 latest reviews via `ProviderReviewCard`, "View all N reviews" button.
5. **Active deals section** — header + list of `ActiveDealCard`s (job title, ৳ amount, status dot + label, chevron). Tapping opens `DealDetailView` sheet.
6. **Recent activity section** — header + list of `RecentDealCard`s (summary row). Tapping opens `DealDetailView` for the full deal (resolved via `myDeals` then `activeDeals`).

### 2.2 iOS behaviors

- **Real-time subscriptions** (realtime V2 channel `dashboard:<userId>:<ts>`) on tables: `deals`, `deal_completion_requests`, `deal_offers`, `jobs`. Each handler triggers `loadDashboardData(forceRefresh: true)` with a short haptic (`UIImpactFeedbackGenerator`).
- **Auto-refresh timer** every 5 min via `Timer.scheduledTimer`; also reconnects realtime if dropped.
- **Pull-to-refresh** with `.refreshable`, medium haptic.
- **Foreground/tab notifications** — `willEnterForegroundNotification`, custom `RefreshDashboard` notification, `DealUpdated` notification all trigger refresh.
- **Cache** — `DashboardCache.shared` (memory + disk). `peek(userId:)` for instant paint on cold start, then `load(userId:)` from disk, then network fetch. `save(...)` on every successful load.
- **Drill-downs** — tapping a stat card opens `DealsListView` sheet with `Filter` (active/completed/all) picker.
- **Reviews list** — full screen of all reviews opened from rating card or "View all" button.

### 2.3 What Android currently has

- `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt` (153 lines) — basic stats grid (4 cards, no drill-down), active-deals list (single-line row), sign-out + profile icons. No charts, no reputation card, no drill-downs, no real-time, no pull-to-refresh, no auto-refresh, no reviews list.
- `DashboardViewModel.kt` (54 lines) — fetches `DashboardData` and active deals. No analytics, no reviews, no realtime, no timer.
- `DealsRepository` already has `fetchDashboardData()`, `fetchActiveDeals()`, `fetchMyDeals()`.
- `ProfilePublicRepository` already has `fetchReviews(userId)`.
- Theme + components ready: `PremiumCard`, `PremiumLoadingView`, `KajHobeTheme.spacing/colors`.
- Supabase realtime V2 + auth Koin are wired in.

## 3. Target state

### 3.1 File layout (1:1 mirror with iOS, new files marked ✨)

| iOS file | Android file |
|---|---|
| `DashboardView.swift` | `ui/feature/dashboard/DashboardScreen.kt` (rewrite) + `DashboardViewModel.kt` (rewrite) |
| `Views/Dashboard/DashboardAnalytics.swift` | ✨ `ui/feature/dashboard/DashboardAnalytics.kt` |
| `Views/Dashboard/DashboardChartsSection.swift` | ✨ `ui/feature/dashboard/DashboardChartsSection.kt` |
| `Views/Dashboard/DashboardReputationCard.swift` | ✨ `ui/feature/dashboard/DashboardReputationCard.kt` + ✨ `ReviewsListView.kt` |
| `Views/Dashboard/DealsListView.swift` | ✨ `ui/feature/dashboard/DealsListView.kt` |
| `PublicProfileComponents.swift::TrustBadge` | ✨ `ui/components/TrustBadge.kt` (extracted) |
| `PublicProfileComponents.swift::ProviderReviewCard` | ✨ `ui/components/ProviderReviewCard.kt` (extracted) |
| `DashboardCache.shared` | ✨ `data/dashboard/DashboardCache.kt` |
| `Networking.fetchMyDeals` / `PublicProfileNetworking.fetchReviews` | already exist |
| (no equivalent) | ✨ `data/dashboard/DashboardRealtime.kt` |

### 3.2 Dependencies

Add to `gradle/libs.versions.toml` and `app/build.gradle.kts`:
- `mpandroidchart` — `com.github.PhilJay:MPAndroidChart:v3.1.0`
- Project-level: add `maven { url = uri("https://jitpack.io") }` to `settings.gradle.kts` `dependencyResolutionManagement.repositories` (required by MPAndroidChart).

No other new dependencies (realtime is in `libs.supabase.realtime`, DataStore is in `libs.androidx.datastore.preferences`).

### 3.3 Component model

**`DashboardUiState`** (in `DashboardViewModel.kt`):
```
data class DashboardUiState(
  val isLoading: Boolean = true,
  val isRefreshing: Boolean = false,
  val data: DashboardData? = null,
  val activeDeals: List<Deal> = emptyList(),
  val myDeals: List<Deal> = emptyList(),
  val myReviews: List<ProviderReview> = emptyList(),
  val hasRealtimeUpdate: Boolean = false,
  val errorMessage: String? = null,
)
```

**`DashboardViewModel`**:
- `init { load() }` — initial silent-from-cache load.
- `load(silent: Boolean = false, forceRefresh: Boolean = false)` — fetches `DashboardData` + `activeDeals` in parallel, then `myDeals` + `fetchReviews(uid)` in parallel (analytics). Updates `isLoading` only on first load; otherwise just `isRefreshing`. Saves to cache on success. Best-effort analytics (never fails the dashboard).
- `loadFromCacheThenNetwork()` — called from `onResume` of the screen: reads cache (memory then disk), paints it, then `load(silent = true, forceRefresh = true)`.
- `startAutoRefresh()` / `stopAutoRefresh()` — coroutine `delay(5 * 60_000)` loop, cancelled on dispose.
- `ensureRealtime()` / `subscribeRealtime()` / `unsubscribeRealtime()` — delegates to `DashboardRealtime`.

**`DashboardRealtime`** (`data/dashboard/DashboardRealtime.kt`):
- `subscribe(uid: String, onEvent: () -> Unit): Job` — opens a single channel for the user, registers `onPostgresChange` for `deals`, `deal_completion_requests`, `deal_offers`, `jobs`. Each handler fires `onEvent()`. Channel id includes uid + epoch ms (mirrors iOS).
- `unsubscribe()` — clean teardown.

**`DashboardCache`** (`data/dashboard/DashboardCache.kt`):
- `peek(uid): DashboardSnapshot?` — in-memory (no IO).
- `load(uid): DashboardSnapshot?` — reads from DataStore.
- `save(snapshot, uid)` — writes to DataStore.
- `DashboardSnapshot(dashboard: DashboardData, activeDeals: List<Deal>)` — serialized via kotlinx.serialization, stored as JSON string.

### 3.4 Section rendering (DashboardScreen.kt)

```
Scaffold(
  topBar = CenterAlignedTopAppBar(
    title = { Text("Dashboard") },
    navigationIcon = IconButton(bell.badge) → onNotificationSettings,
    actions = IconButton(person.circle) → onMyProfile,
  ),
  modifier = Modifier.nestedScroll(pullRefresh.nestedScrollConnection),
) {
  PullToRefreshBox(isRefreshing, onRefresh = { vm.refresh() }) {
    LazyColumn {
      item { DashboardStatsSection(...) }      // empty state OR data
      if (state.myDeals.isNotEmpty() || state.myReviews.isNotEmpty()) {
        item { DashboardChartsSection(...) }
        item { DashboardReputationCard(...) }
      }
      if (state.activeDeals.isNotEmpty()) {
        item { ActiveDealsSection(...) }
      }
      if (state.data?.recent_deals?.isNotEmpty() == true) {
        item { RecentActivitySection(...) }
      }
    }
  }
}
```

Bottom sheets (Material3 `ModalBottomSheet`):
- `DealsListSheet` — wraps `DealsListView`, opens on `drillDownFilter` change.
- `ReviewsListSheet` — wraps `ReviewsListView`, opens on `showingReviewsList = true`.
- `DealDetailSheet` — wraps existing `DealDetailScreen` with `onBack = { scope.hide() }`.
- `ProfileSheet` — wraps existing `ProfileScreen` with `onBack = { scope.hide() }`.
- `NotificationSettingsSheet` — wraps a new `NotificationSettingsScreen` (port of iOS `NotificationSettingsView`) with `onBack = { scope.hide() }`.

### 3.5 Charts (MPAndroidChart)

`DashboardChartsSection` renders three `AndroidView { ... }` blocks, each containing a `BarChart` / `PieChart` / `LineChart`:
- **Bar chart** — `BarDataSet` per role (Earned green, Spent orange), `groupBars(...)`, x-axis formatted as month abbreviation. Show placeholder card with `chart.bar` icon + "Needs more history" if <2 points. Height 180.dp.
- **Pie chart** — `PieDataSet` with status colors, `setUsePercentValues(false)`, hole radius 60%. 130×130. Adjacent legend column (status color dot + label + count).
- **Line chart** — `LineDataSet` with cubic interpolation, yellow. y-axis 0..5. Height 140.dp. Placeholder if <2 points.

Status color map (matches iOS):
- `completed` → green, `in progress` → blue, `pending approval` → orange, `disputed` → red, `resolved` → indigo, default → gray.

### 3.6 Reputation card

`DashboardReputationCard(reviews, averageRating, completedJobs, onViewAll)`:
- Header row: rosette icon + "Reputation" + `TrustBadge` (compact, top right).
- Trust progress: `LinearProgressIndicator(purple)` + "X jobs / Y rating away from Z" caption. If at top tier, `Label` with crown icon "Top tier".
- If `reviews.isEmpty()`: centered "No reviews yet" placeholder.
- Else: 5-row distribution bars (5★ down to 1★, proportional `fillMaxWidth` capsule inside a track capsule), then "Latest reviews" subheader + up to 3 `ProviderReviewCard`s, then full-width "View all N reviews" button if `reviews.size > 3` and `onViewAll != null`.

**`TrustBadge`** extracted to `ui/components/TrustBadge.kt`:
- 5 cases: unverified (gray), newcomer (blue), established (green), experienced (orange), expert (purple).
- Icon + display name; `compact` hides name.

**`ProviderReviewCard`** extracted to `ui/components/ProviderReviewCard.kt`:
- AsyncImage (Coil) 36×36 with gray person placeholder, reviewer name + date, 5 star row (yellow, filled vs outlined), comment text. Mirrors iOS layout exactly.

### 3.7 Drill-downs

`DealsListSheet`:
- `Filter` enum: `Active`, `Completed`, `All` — title text via string resources.
- `ModalBottomSheet` hosting a top app bar with a `FilterChip`/`ExposedDropdownMenu` picker on the right.
- List of `DealListRow`s (job title + ৳ amount, abbreviated date, status dot + label + chevron). Empty state with briefcase icon + "No deals to show" message.
- Tapping a row opens the same `DealDetailSheet`.

### 3.8 Real-time + auto-refresh + pull-to-refresh

- `DashboardScreen` calls `LaunchedEffect(uid) { vm.subscribeRealtime(uid) }`, `DisposableEffect { onDispose { vm.unsubscribeRealtime() } }`, `LaunchedEffect(uid) { vm.startAutoRefresh() }`, and `LifecycleResumeEffect(Unit) { vm.loadFromCacheThenNetwork() }`.
- Real-time callbacks set `hasRealtimeUpdate = true` for 1.5s (visual cue) and trigger refresh.
- `PullToRefreshBox` from `androidx.compose.material3:material3` 1.3+ (already on BOM). On refresh, calls `vm.refresh()` which sets `isRefreshing = true` and runs `load(forceRefresh = true)`.
- Light haptic via `LocalHapticFeedback.current` on real-time event (medium for completion requests, heavy for new offers — matches iOS).

### 3.9 Empty state

`emptyDashboardState` rendered when `data == null`:
- "Overview" header.
- 2×2 grid of `StatCard`s with 0 / $0 / 4.5 placeholders.
- "Get started with your first job" subheader.
- Two buttons:
  - Filled blue "Browse Available Jobs" → `onOpenJobs = { nav.navigate(TopLevelDestination.JOBS.route) }`.
  - Tinted blue "Post a Job" → `onPostJob = { nav.navigate(TopLevelDestination.POST.route) }`.

### 3.10 Navigation wiring

Add to `MainScaffold.kt`:
- New route `Routes.NOTIFICATION_SETTINGS = "notification-settings"`.
- New callback `onNotificationSettings` passed to `DashboardScreen`.
- New `composable(Routes.NOTIFICATION_SETTINGS) { NotificationSettingsScreen(onBack = { nav.popBackStack() }) }`.
- Replace `onSignOut = onSignOut` in `DashboardScreen` with a callback `onOpenJobs` / `onPostJob` so the empty-state CTAs navigate via the parent `MainScaffold` (which is the only place that owns the `navController`).
- Add `onOpenProfile` already exists → `Routes.MY_PROFILE`. Reuse it.
- The dashboard does not own sign-out anymore — sign-out lives in `ProfileScreen` on iOS too (the iOS dashboard's `Sign out` button on Android is non-parity; iOS doesn't show it on the dashboard either). Confirm in plan: **remove the "Sign out" button from `DashboardScreen` and route sign-out through the Profile screen only.**

## 4. Data flow

1. **First frame** — `DashboardViewModel` init reads `DashboardCache.peek(uid)`. If hit, `uiState` is seeded with cached data so the screen paints immediately. (iOS does this; Android also.)
2. **On resume / onAppear** — `loadFromCacheThenNetwork()`: paints cached state if not already, then runs `load(silent=true, forceRefresh=true)`.
3. **Network load** — parallel:
   - `dealsRepository.fetchDashboardData()` (RPC or manual fallback).
   - `dealsRepository.fetchActiveDeals()` (runCatching, default empty list).
   - Analytics (best-effort, never throws):
     - `dealsRepository.fetchMyDeals()`.
     - `profilePublicRepository.fetchReviews(currentUid())`.
4. **Real-time event** → `hasRealtimeUpdate = true` (1.5s) + `load(forceRefresh = true)`.
5. **5-min timer** → `load(forceRefresh = true)` + `ensureRealtime()`.
6. **Pull-to-refresh** → same as timer.

## 5. Error handling

- Dashboard data fetch failure: show snackbar/inline error, keep previous state, set `errorMessage`. (iOS surfaces an alert; Android will use a `Snackbar` via the `SnackbarHost` on the scaffold, simpler than an AlertDialog and matches Material 3 idiom.)
- Analytics fetch failure: silently keep previous state (iOS behavior).
- Cache failures: log + ignore (iOS behavior).

## 6. Testing

### 6.1 Unit tests (JVM)

- `DashboardAnalyticsTest`:
  - `monthlyMoneyFlow` — empty, single role, mixed roles, year boundaries.
  - `statusBreakdown` — empty, single status, multiple statuses, sorting.
  - `ratingTrend` — empty, single review, running average correctness.
  - `ratingDistribution` — counts per star (5..1).
  - `trustLevel` — all 5 tiers + boundary cases.
  - `nextTrustLevelTarget` — returns nil at expert; otherwise correct jobsNeeded/ratingNeeded/progress.
  - `isCompleted`, `parseDate` (with/without fractional seconds), `displayStatus`.
- `DashboardViewModelTest`:
  - `init` triggers `load()`.
  - `load(silent=true)` does NOT set `isLoading = true` when state already has data.
  - `load()` failure sets `errorMessage` and clears `isLoading`.
  - `load()` success sets all data and calls cache `save()`.
  - Real-time callbacks set `hasRealtimeUpdate = true`.

### 6.2 Compose UI tests (androidTest)

- `DashboardScreenTest`:
  - Renders empty state when `data == null`.
  - Renders stats with formatted ৳ values matching `user_type`.
  - Tapping a stat card opens the right filter in `DealsListSheet`.
  - Rating card tap opens `ReviewsListSheet`.
  - Active deals / recent activity sections render correct number of cards.
  - Pull-to-refresh triggers a refresh.

### 6.3 Manual QA

Run on emulator:
1. Sign in, observe first-frame paint of cached state from prior session.
2. Wait 5 min — verify auto-refresh.
3. Modify a deal in Supabase dashboard — verify real-time event fires within ~1s, indicator flashes.
4. Pull down — verify refresh.
5. Tap each stat card — verify the right filter is active in the list.
6. Tap rating — verify full reviews list.
7. Switch `user_type` via Supabase — verify Earned ↔ Spent label/icon flip.
8. Empty-state user: tap "Browse Available Jobs" → goes to Jobs; "Post a Job" → goes to Post.

## 7. Out of scope

- New analytics data sources (RPC, materialized views) — we keep client-side aggregation.
- Theming changes to other screens.
- Profile / notification-settings / deal-detail redesigns — those already exist on Android.
- Localization — strings stay English (matches current Android state; iOS has Bengali keys but they're stubs).
- `NotificationSettingsView` port — keep behavior minimal (deep-link to OS settings for now, matches iOS placeholder).

## 8. Risks

- **MPAndroidChart maintenance status**: library is mature but no longer actively maintained. Acceptable risk for a single-screen use; if concerns arise, swap to Vico in a follow-up.
- **DataStore serialization of `Deal` list**: `DashboardSnapshot` contains `List<Deal>` with nested `Job` / `SimpleProfile`. kotlinx.serialization already handles all these models; no new serializers needed.
- **PullToRefreshBox stability**: M3 1.3 introduces a stable API. We pin to the version in the current BOM (verify in plan).
- **Charts re-rendering on theme switch**: MPAndroidChart's `AndroidView` needs explicit `update` block to redraw on data change. Will use `LaunchedEffect(deals, reviews)` to call `chart.invalidate()`.

## 9. Open question resolved

- **Sign-out button on dashboard**: removed (iOS dashboard does not have one). Sign-out stays in the Profile screen only.
- **NotificationSettings screen**: out of scope (just a stub `NotificationSettingsScreen` with a single "Open OS settings" button is acceptable). The dashboard nav button still works and is wired.

## 10. Definition of done

- All 7 new Kotlin files compile and are unit-test covered.
- `DashboardScreen` matches iOS section-for-section, top to bottom.
- Real-time + auto-refresh + pull-to-refresh all trigger refreshes.
- Drill-downs (stat cards → `DealsListView` with filter; rating → `ReviewsListView`) work.
- Cache paints first frame after first session.
- All lint + detekt + ktlint + unit tests + assembleDebug pass.
- `git diff` reviewed; spec updated to `Implemented` status.

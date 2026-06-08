# 2026-06-09 — My Profile screen redesign + Android entrypoint

**Scope:** Add a "view/edit your own profile" entrypoint to the Android Dashboard (iOS already has one), and redesign the **My Profile** screen on both platforms so it visually mirrors the existing **Public Profile** screen (hero, stat cards, soft WarmOrange accent, rounded surfaces) while keeping every editable field that exists today. The redesign is a single scrollable body with an inline edit toggle — not a 4-tab strip — because the owner's profile is primarily an edit surface.

---

## Reference design (already shipped)

- **Public profile (Android):** `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileScreen.kt` + `PublicProfileComponents.kt`
- **Public profile (iOS):** `iOS/KajHobe/Views/PublicProfileComponents.swift` → `struct PublicProfileDetailView` (line 239)
- **Existing own-profile (iOS, to be redesigned):** `iOS/KajHobe/ProfileView.swift`
- **Dashboard top-right (iOS, already correct):** `iOS/KajHobe/DashboardView.swift:70-77` (`person.circle` trailing toolbar button → `ProfileView` sheet)
- **Dashboard top-right (Android, missing):** `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt:55-61` (only has a "Sign out" text button)

---

## Goals & non-goals

**Goals**
1. Android Dashboard has a profile entrypoint in its top-right area that opens the redesigned "My Profile" screen.
2. iOS and Android My Profile screens share the same visual language as the Public Profile screen (hero, 3 stat cards, WarmOrange accent, rounded 20 surfaces, edit-in-place).
3. All currently-editable fields remain editable: name, email (read-only), service-provider toggle, bio, website, location, profession, tagline, experience years, hourly fee, team fee, team hours label, payout bKash number (provider-only), language preference.
4. Payout bKash number is a collapsible card, closed by default, only visible to providers.
5. Both platforms read from the same data sources: `profiles` table + `provider_payout_accounts` table + `/dashboard` RPC for active deal count.

**Non-goals (out of scope for this spec)**
- Implementing `LanguageSelectionScreen` on Android. The language row is rendered but tapping it shows a "Coming soon" snackbar. iOS keeps its existing `LanguageSelectionView` sheet unchanged.
- "View as others see it" affordance on the own-profile screen.
- Real-time subscription to one's own profile changes.
- Any new permissions / RLS changes — the existing `profiles` RLS already permits self-update.
- A separate "Public profile" entrypoint on the dashboard (it's only reachable today via job-detail sender tap and notifications — keep as-is).
- Avatar upload flow (no upload UI exists anywhere in the app today).

---

## Visual structure (single screen, top-to-bottom)

### 1. Hero card
- Rounded 20 corners, 280dp / 280pt tall.
- Background: `AsyncImage` of `avatar_url` (`ContentScale.Crop`) → fallback WarmOrange linear gradient + centered `person.fill` icon (60% white) when no avatar.
- Vertical scrim: `Color.Transparent` → `Color.Black.copy(alpha = 0.65f)` (Android) / `[.clear, .black.opacity(0.65)]` (iOS).
- Bottom-left text stack: **name** (headline, white, bold) and **email** (bodySmall, white 85%, maxLines 1, ellipsized).

### 2. Three stat cards (single row, spaced 12dp)
Reuse the existing `ProviderStatCard` (Android: `PublicProfileComponents.kt:194-223`, iOS: `PublicProfileComponents.swift:544-563`).
- 💼 **Active deals** — `state.activeDealsCount` (default 0; silent failure → 0)
- ⭐ **Rating** — `profile.average_rating ?: 0.0` > 0 → `"%.1f"`, else `"New"`
- 👥 **Completed** — `profile.ratings_count ?: 0` (show `0` when null/0)
- Same three tints as public profile: `#26FF9F0A` / `#268E44AD` / `#26FF4081` (Android constants `ExperienceTint`/`RatingTint`/`CustomersTint` in `PublicProfileComponents.kt:189-191`).

### 3. Body (single scrollable column, no tabs)

**Account section** (header "Account")
- **Full name** — TextField in edit mode, plain text in view mode.
- **Email** — always read-only, muted background (`MaterialTheme.colorScheme.surfaceVariant` / `Color(.systemGray6)`).

**Account Type section** (header "Account Type")
- A single `Surface` row containing:
  - `Switch` (Compose) / `Toggle` (SwiftUI) bound to `isServiceProvider` buffer.
  - Label: "Service Provider"
  - Subtitle: "Enable to apply for jobs and offer services"
- In view mode, the switch is disabled and shows the persisted value.
- Toggling provider ↔ client does **not** auto-clear the provider-detail fields; the user can flip back without losing them. (Mirrors iOS `ProfileView.swift:190-193`.)

**About section** (header "About")
- **Bio** — multi-line. Edit mode: `OutlinedTextField(singleLine = false, minLines = 3)` / `TextEditor(minHeight 100)`. View mode: `Text`.
- **Website** — single-line. View mode: rendered as a `Link` if it parses as a URL, else in red, else "No website". Edit mode: TextField.
- **Location** — single-line. View mode: `Text` or "No location".

**Service Provider Details section** — visible iff `is_service_provider` (effective: `isEditing ? isServiceProvider : profile.is_service_provider`). Otherwise hidden entirely. Header: "Service Provider Details".
- Profession (text)
- Tagline (text)
- Experience years (text, `KeyboardType.NumberPad` / `KeyboardType.Number`)
- Hourly fee (text, decimal pad, prefix `৳` in view mode)
- Team work fee (text, decimal pad, prefix `৳` in view mode)
- Team hours label (text, e.g. "4-7 hrs")

**Payout details** (provider-only, collapsible) — `AnimatedVisibility` / SwiftUI DisclosureGroup-style. Closed by default in both view and edit mode. Header: "Payout details" with a chevron.
- Subtitle (visible when collapsed): "Configure how you get paid" or "Set your bKash number" when blank.
- Payout bKash number (single-line, `KeyboardType.NumberPad` / `KeyboardType.NumberPassword`).
- Helper text (below field, always): "Only used to pay you when a deal completes. Never shown to clients."
- The bKash number itself is **never** displayed in plaintext. In view mode it shows as "•••• •••• 5678" (last 4 digits), or "Not set" when blank. **This is a deliberate behavior change from the current iOS code**, which shows the number in plaintext via `payoutReadonlyRow` (line 387). The plaintext display was leaking the payout number onto a screen that could be screen-shared or recorded; masking is the new behavior on both platforms. In edit mode the field starts empty (so the user types a fresh value) and the "Save" upserts; an empty save keeps the existing number (no delete-on-blank in v1).

**Preferences section**
- Language row — icon (`globe` / `Icons.Filled.Language`) + "Language" + current language display name + trailing chevron. Tap → `LanguageSelectionView` (iOS, unchanged) / snackbar "Coming soon" (Android).

**Account Info section** (view mode only, hidden in edit mode to reduce noise)
- Email row (icon `envelope` / `Icons.Filled.Email`)
- Role row (icon `person.badge.plus` / `Icons.Filled.Person`) — value "Service Provider" or "Client"

**Sign out**
- Full-width red filled button at the bottom of the body, always visible (in both view and edit mode).
- Tap → confirmation alert/dialog ("Are you sure you want to sign out? You'll need to sign in again to access your account."). Destructive button on iOS, red filled button on Android.
- On iOS, heavy haptic on confirm (`UIImpactFeedbackGenerator(style: .heavy)`). On Android, no haptic (none of the existing screens do).
- On confirm, call the existing `supabase.auth.signOut()` (iOS) / injected `AuthRepository.signOut()` (Android), then post `NSNotification.Name("UserLoggedOut")` (iOS) / rely on the existing `AuthGate` flow (Android).

### 4. Toolbar

**iOS** (already exists, kept)
- Trailing: `Edit` (view mode) / `Save` (edit mode). Disabled while `isLoading` or while a save is in flight (shows a small `ProgressView` instead of label).
- Leading: shows `Cancel` in edit mode; in view mode the existing bell-badge leading item stays untouched.

**Android** (new)
- `TopAppBar` with `title = "Profile"`, `navigationIcon` = back arrow (calls `onBack`). In edit mode the navigation icon becomes a `Close` icon that triggers a cancel-confirmation dialog if `unsavedChanges == true` (otherwise pops back directly).
- `actions` = `TextButton` with label `Edit` / `Save` and the same disabled-during-save behavior. While saving, swap the label for a small `CircularProgressIndicator(modifier = Modifier.size(18.dp))`.

---

## Data flow

### iOS (no architectural change)

`ProfileView` is rewritten in body only. State, networking, and save logic stay in the same view (matching the current style). New state:
- `@State private var activeDealsCount: Int = 0` — fetched once on appear from `Networking.shared.fetchDashboardData()`. Decoded via the existing `DashboardData` struct (it has `active_deals_count`). Failure → 0.
- `@State private var isSaving = false` — bound to the Save button.

`loadProfile()` (line 423) is extended to:
1. Fetch `Profile` (existing).
2. If provider, fetch payout bKash (existing).
3. Fetch `DashboardData` (new) → set `activeDealsCount`.

`saveProfile()` (line 474) is extended to:
- Set `isSaving = true` at start, `isSaving = false` at the end (success or failure).
- The actual `ProfileUpdate` struct, the upsert of payout, and the local-mirror assignment are unchanged.

`logout()` is unchanged.

### Android (new)

A new `MyProfileViewModel` + `MyProfileScreen` + `MyProfileComponents.kt`, following the same MVVM + Koin DI pattern as the existing `PublicProfileViewModel`.

```
data class MyProfileUiState(
    val isLoading: Boolean = true,
    val isSaving: Boolean = false,
    val isEditing: Boolean = false,
    val unsavedChanges: Boolean = false,
    val profile: Profile? = null,
    val payoutNumber: String? = null,        // null = not loaded yet; "" = loaded as empty
    val activeDealsCount: Int = 0,
    val errorMessage: String? = null,
    val languageDisplay: String = "English",  // hardcoded for v1
)

class MyProfileViewModel(
    private val profileRepository: ProfileRepository,
    private val payoutRepository: ProviderPayoutRepository,
    private val dashboardRepository: DashboardRepository,   // existing; may need a new public method
    private val authRepository: AuthRepository,
) : ViewModel() {
    fun load()
    fun startEditing()
    fun updateBuffer(transform: (MyProfileEditBuffer) -> MyProfileEditBuffer)
    fun cancelEditing()
    fun save()
    fun signOut()
    fun clearError()
}
```

`MyProfileEditBuffer` is a private data class holding the in-progress field values (strings + booleans for the 11 editable fields). The ViewModel keeps a single instance; `startEditing()` seeds it from `profile`; every keystroke/toggle dispatches `updateBuffer { it.copy(name = newName) }` and sets `unsavedChanges = true` if the new value differs from the persisted one.

`load()` runs three independent network calls (`async { … }`), then merges the results:
- `profile = profileRepository.getCurrentUserProfile()`
- `payoutNumber = if (profile?.is_service_provider == true) payoutRepository.fetchMyPayoutNumber() else null`
- `activeDealsCount = runCatching { dashboardRepository.fetchDashboard().active_deals_count }.getOrDefault(0)`

If `getCurrentUserProfile()` returns null, the screen shows the error state with message "Profile not found" and a Retry button (mirrors `PublicProfileScreen` error view).

`save()` runs in this exact order, with the same validations as the iOS code (lines 477-500):
1. Trim all buffer strings.
2. If the provider flag is on **and** the payout field is non-empty, validate `^01[0-9]{9}$` → if invalid, set `errorMessage` and return.
3. Parse provider numbers (`Int(experienceYears)`, `Double(hourlyRate)`, `Double(teamRate)`). Treat blank as null.
4. Call `profileRepository.updateProfile(fullName, bio, website, location, isServiceProvider, profession, tagline, experienceYears, hourlyRate, teamRate, teamHoursLabel, favoriteCategories = null)`.
5. If a payout number was supplied, call `payoutRepository.upsertMyPayoutNumber(number)`. If blank, do nothing (we don't delete on Android in v1 — matches iOS).
6. On success: update local `profile` and `payoutNumber` from the buffer, set `isEditing = false`, `unsavedChanges = false`, `isSaving = false`.
7. On failure: set `errorMessage`, `isSaving = false`. Do not exit edit mode.

`signOut()` delegates to `authRepository.signOut()` and is fire-and-forget — the `AuthGate` flow in `RootNavHost` handles navigation.

### Data writes (Android)

**`ProfileRepository.updateProfile(...)` — extended signature** (add 6 params, all optional, all default null):
```kotlin
suspend fun updateProfile(
    fullName: String? = null,
    bio: String? = null,
    website: String? = null,
    location: String? = null,
    isServiceProvider: Boolean? = null,
    favoriteCategories: List<String>? = null,
    // new:
    profession: String? = null,
    tagline: String? = null,
    experienceYears: Int? = null,
    hourlyRate: Double? = null,
    teamRate: Double? = null,
    teamHoursLabel: String? = null,
)
```
The implementation does `param?.let { set(column, it) }` for each new field, then sets `updated_at = Instant.now().toString()`. Null params leave existing values untouched (same semantics as the existing 6 params).

**`ProviderPayoutRepository` (new file)** — sibling of the existing `PaymentRepository`, wraps the `provider_payout_accounts` table:
```kotlin
class ProviderPayoutRepository(client: SupabaseClient) : BaseRepository(client) {
    suspend fun fetchMyPayoutNumber(): String? { ... }   // null on RLS deny or no row
    suspend fun upsertMyPayoutNumber(number: String) { ... }   // upsert by user_id = auth.uid()
}
```
The `upsert` uses `postgrest.from("provider_payout_accounts").upsert(...)` with `onConflict = "user_id"`. Read does `eq("user_id", currentUserId)` and returns the first row's `bkash_number`, or null.

**`DashboardRepository` (existing)** — the implementation plan must verify that `DashboardRepository` already exposes a public `fetchDashboard(): DashboardData` (or equivalent) that the new VM can call. If only the existing `DashboardViewModel` wraps the call, add a thin public method on the repository and have the new VM call that. No new SQL.

### Profile data write (iOS) — no change
The existing `ProfileUpdate` struct (lines 5-18) already covers the 11 fields. The iOS save path is unchanged except for the `isSaving` flag plumbing.

---

## Validation rules (mirror iOS exactly)

| Field | Rule | On invalid |
|---|---|---|
| Full name | Non-empty after trim (server also enforces) | Save button disabled + inline error |
| Bio | None | — |
| Website | If non-empty, must parse as `URL` | Inline red text under the field; do **not** block save |
| Location | None | — |
| Service-provider switch | None | — |
| Profession / Tagline / Team hours | None | — |
| Experience years | If non-empty, must parse as `Int >= 0` | Inline error; block save |
| Hourly fee / Team fee | If non-empty, must parse as `Double >= 0` | Inline error; block save |
| Payout bKash | If non-empty and provider is on, must match `^01[0-9]{9}$` (11 digits, starts with 01) | Error alert "Payout bKash number must be 11 digits starting with 01 (e.g. 01712345678)." + block save |

Website is the **only** field that surfaces an error but does not block save (matching iOS `ProfileView.swift:137-150`).

---

## Component inventory

### iOS — no new files
- Rewrite the body of `ProfileView` in `iOS/KajHobe/ProfileView.swift`. The current file mixes state, layout, networking, and validation in one big view — keep that style for consistency with the rest of the iOS codebase (other views like `DashboardView` do the same).
- Extract a small `MyProfileHero`, `MyProfileStatCards`, and `MyProfilePayoutCard` view **inside the same file** (not a new file) to keep the diff reviewable.
- Reuse `ProviderStatCard` from `PublicProfileComponents.swift`.

### Android — new files
- `data/repository/ProviderPayoutRepository.kt` — payout bKash RLS-locked CRUD.
- `ui/feature/profile/MyProfileViewModel.kt` — VM + `MyProfileUiState` + private `MyProfileEditBuffer`.
- `ui/feature/profile/MyProfileScreen.kt` — top-level Composable, default-export. Receives `onBack: () -> Unit` and `onSignOut: () -> Unit` (the sign-out is delegated so the existing `AuthGate` flow handles navigation).
- `ui/feature/profile/MyProfileComponents.kt` — section components listed below.
- `app/src/test/java/com/kajhobe/app/ui/feature/profile/MyProfileViewModelTest.kt` — 7 test cases (see Testing).

### Section components in `MyProfileComponents.kt` (Compose)
- `MyProfileHero(profile: Profile)` — full-width rounded Surface with avatar/scrim/text stack.
- `MyProfileStatCards(activeDeals: Int, rating: Double?, completed: Int)` — three-up row of `ProviderStatCard`.
- `SectionHeader(text: String, badge: String? = null)` — used to introduce each section. Optional badge ("Editing") shown in edit mode.
- `ReadOnlyRow(icon: ImageVector, label: String, value: String?)` — used in Account Info section.
- `AccountSection(buffer, isEditing, onBufferChange)` — name + email.
- `AccountTypeSection(buffer, isEditing, onBufferChange)` — service-provider switch row.
- `AboutSection(buffer, isEditing, websiteError, onBufferChange)` — bio + website + location.
- `ProviderDetailsSection(buffer, isEditing, errors, onBufferChange)` — profession/tagline/experience/pricing/team hours.
- `PayoutDetailsCard(payoutNumber, isEditing, expanded, onExpandedChange, onPayoutChange, error)` — collapsible provider-only card.
- `PreferencesRow(currentLanguage: String, onClick: () -> Unit)` — language row (taps fire the snackbar on Android).
- `SignOutButton(onSignOut: () -> Unit)` — full-width red filled button.
- `MyProfileErrorContent(message: String, onRetry: () -> Unit)` — mirrors `PublicProfileScreen.kt:177-209` error view.

All section components take their `Modifier` as the first optional parameter (Compose convention).

### Reused components
- `ProviderStatCard` from `PublicProfileComponents.kt` (no change).
- `PremiumCard` and `PrimaryButton` from `ui/components/`.
- `WarmOrange` color from `ui/theme/`.
- `KajHobeTheme.spacing.*` and `KajHobeTheme.colors.*`.

### Edit-mode visual cues
- Input field background shifts from `MaterialTheme.colorScheme.surfaceVariant` (view) to `MaterialTheme.colorScheme.surface` (edit) with a 1dp border in `WarmOrange` while focused.
- `SectionHeader` shows a small `Editing` pill (12sp, `WarmOrange` text on `WarmOrange.copy(alpha = 0.12f)`) when `isEditing`.
- Save button label is replaced with an inline 18dp `CircularProgressIndicator` while `isSaving`.

---

## Navigation changes (Android)

`ui/feature/navigation/Destinations.kt`:
```kotlin
object Routes {
    // ... existing
    const val MY_PROFILE = "profile/me"
    fun myProfile() = "profile/me"
}
```

`ui/feature/navigation/MainScaffold.kt`:
- Pass `onProfileClick = { navController.navigate(Routes.myProfile()) }` into `DashboardScreen`.
- Add a new `composable(Routes.MY_PROFILE)` that renders `MyProfileScreen(onBack = { navController.popBackStack() }, onSignOut = onSignOut)`.

`ui/feature/dashboard/DashboardScreen.kt`:
- New parameter `onProfileClick: () -> Unit` (after `onSignOut`).
- Replace the title row's `TertiaryButton("Sign out", …)` with:
  ```
  Row(verticalAlignment = Alignment.CenterVertically) {
      IconButton(onClick = onProfileClick) { Icon(Icons.Filled.Person, contentDescription = "Profile") }
      IconButton(onClick = onSignOut) { Icon(Icons.AutoMirrored.Filled.ExitToApp, contentDescription = "Sign out") }
  }
  ```
- The "Dashboard" `Text` keeps its current size/weight.

`di/AppModule.kt`:
- Add `singleOf(::ProviderPayoutRepository)`.
- Add `viewModelOf(::MyProfileViewModel)`.
- Confirm `DashboardRepository` is registered (existing) and has a public `fetchDashboard()` method; if not, add one.

---

## Testing (Android)

`MyProfileViewModelTest.kt` — 7 cases, all using a hand-rolled fake repository (no MockK) to match `PublicProfileViewModelTest`:

1. **load success** — fake repos return profile + payout + dashboard; final state has `isLoading=false`, profile populated, `payoutNumber` populated, `activeDealsCount=2`.
2. **load profile null** — `profileRepository.getCurrentUserProfile()` returns null; final state has `errorMessage = "Profile not found"`, `isLoading=false`.
3. **load non-provider does not call payout repo** — `profile.is_service_provider = false`; verify `payoutRepository.fetchMyPayoutNumber()` was never invoked.
4. **save happy path no payout** — start editing, change bio, save; verify `profileRepository.updateProfile(...)` called with `bio=newBio` and `payoutRepository.upsertMyPayoutNumber(...)` was never invoked.
5. **save with valid payout** — start editing as provider, set payout = "01712345678"; verify `payoutRepository.upsertMyPayoutNumber("01712345678")` is called and `payoutNumber` is updated locally.
6. **save with invalid payout** — provider with payout = "1234"; verify save returns early, no `updateProfile` call, no `upsertMyPayoutNumber` call, `errorMessage` is set, `isEditing` stays true.
7. **cancel discards buffer** — start editing, change bio, cancel; verify `profile.bio` is unchanged and `isEditing=false, unsavedChanges=false`.

iOS has no test target — skip.

---

## File-by-file change summary

### iOS
| File | Change |
|---|---|
| `iOS/KajHobe/ProfileView.swift` | Rewrite `body` and helpers. Keep `ProfileUpdate`, `loadProfile`, `saveProfile`, `logout`, `SimpleAvatar` as-is (minor additions only: `activeDealsCount` state + dashboard fetch, `isSaving` flag). |

### Android
| File | Change |
|---|---|
| `data/repository/ProfileRepository.kt` | Extend `updateProfile(...)` signature with 6 provider-detail params. |
| `data/repository/ProviderPayoutRepository.kt` *(new)* | `fetchMyPayoutNumber()`, `upsertMyPayoutNumber(number)`. |
| `ui/feature/dashboard/DashboardScreen.kt` | Add `onProfileClick` param. Replace inline "Sign out" with profile + sign-out icon row. |
| `ui/feature/navigation/Destinations.kt` | Add `MY_PROFILE` route + helper. |
| `ui/feature/navigation/MainScaffold.kt` | Wire `onProfileClick` to new route; register new `composable(MY_PROFILE)`. |
| `di/AppModule.kt` | Register `ProviderPayoutRepository`; register `MyProfileViewModel` via `viewModelOf`. |
| `ui/feature/profile/MyProfileViewModel.kt` *(new)* | VM + state + buffer. |
| `ui/feature/profile/MyProfileScreen.kt` *(new)* | Top-level Composable. |
| `ui/feature/profile/MyProfileComponents.kt` *(new)* | Section components. |
| `app/src/test/java/com/kajhobe/app/ui/feature/profile/MyProfileViewModelTest.kt` *(new)* | 7 test cases. |

**Estimated net diff:** ~700 lines added, ~300 lines rewritten.

---

## Rollout

- Single PR, both platforms.
- Feature-flag-free — no migration, no schema change.
- Manual QA checklist:
  - Android: tap profile icon on dashboard → see hero + stat cards + body → edit name → save → see updated name in hero.
  - Android: toggle service-provider on while editing → provider details section appears → save → reload → still a provider, details still there.
  - Android: as provider, open payout details, type a bad number → save → error alert, no DB write. Type a good number → save → reload → still good.
  - iOS: same set of flows, verify hero renders, stat cards show, edit/save round-trips, payout number persists.
  - Cross-platform: changing your name on iOS is reflected when the same user logs in on Android (data is shared, just verifying the integration).

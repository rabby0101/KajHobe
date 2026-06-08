# Android Public Profile — iOS Parity Port

**Date:** 2026-06-08
**Status:** Approved by user (brainstorming)
**Scope:** Replace the existing Android `PublicProfileScreen` with a version that visually and behaviorally matches the iOS `PublicProfileDetailView` (SwiftUI).

## Source of truth

- **iOS reference:** `iOS/KajHobe/Views/PublicProfileComponents.swift` → `struct PublicProfileDetailView` (line 239)
- **iOS data layer:** `iOS/KajHobe/Networking/PublicProfileNetworking.swift`, fields on `PublicProfile` in `iOS/KajHobe/DatabaseModels.swift:655`
- **Database migration that backfills the iOS-only fields:** `Web/supabase/migrations/20260608000000-provider-profile-fields.sql`

## Goal

The screen reached by tapping a sender's profile from the in-app interest-request notification (`com.kajhobe.app.ui.feature.profile.PublicProfileScreen`, route `profile/{userId}`) must look and behave like the iOS detail view: hero with profession/tagline/hourly rate, three colored stat cards, a four-tab strip (About / Availability / Experience / Reviews), and a pricing row.

## Non-goals

- Re-platforming to a different architecture (Compose → WebView, etc.).
- Real per-category service-highlight aggregation (iOS itself doesn't have it — falls back to top categories — so we match that).
- Editing the provider's own profile fields (those screens already exist elsewhere; this is a read-only view).
- Adding `execute_sql` RPC or any other backend change.

## Files

All paths under `Android/app/src/main/java/com/kajhobe/app/`.

| File | Change |
|---|---|
| `data/model/Profile.kt` | Extend `PublicProfile` with 6 optional fields + 3 new computed properties. Add `ProviderReview` data class. |
| `data/repository/ProfilePublicRepository.kt` | Add `fetchPublicProfileSummaries`, `fetchServiceHighlights`, `fetchReviews`. |
| `ui/feature/profile/PublicProfileViewModel.kt` | Extend `PublicProfileUiState` with `serviceHighlights` and `reviews`. Fan out the three fetches. |
| `ui/feature/profile/PublicProfileScreen.kt` | Rewrite body (signature unchanged). |
| `ui/feature/profile/PublicProfileComponents.kt` *(new)* | `ProviderProfileTab` enum, `ProfileHero`, `HourlyRateCapsule`, `ProviderStatCard`, `ProfileTabStrip`, `AvailabilityCard`, `ServiceHighlightCard`, `ProviderReviewCard`, `PricingCard`. |
| `app/build.gradle.kts` | Add `kotlinx-coroutines-test` and `junit` to `testImplementation`. |
| `app/src/test/java/com/kajhobe/app/ui/feature/profile/PublicProfileViewModelTest.kt` *(new)* | ViewModel test for success/error/retry/fan-out. |

## Data model changes

### `PublicProfile` (in `data/model/Profile.kt`)

Add these fields (all optional/defaulted to keep existing call sites compiling):

```kotlin
val profession: String? = null,
val tagline: String? = null,
val experience_years: Int? = null,
val hourly_rate: Double? = null,
val team_rate: Double? = null,
val team_hours_label: String? = null,
```

Add computed properties matching iOS (`DatabaseModels.swift:697-723`):

```kotlin
val formattedHourlyRate: String?
    get() = if ((hourly_rate ?: 0.0) > 0) "৳${formatAmount(hourly_rate!!)}/hr" else null

val formattedTeamRate: String?
    get() = if ((team_rate ?: 0.0) > 0) "৳${formatAmount(team_rate!!)}" else null

val experienceText: String
    get() = experience_years
        ?.takeIf { it > 0 }
        ?.let { "$it year${if (it == 1) "" else "s"} of experience" }
        ?: "New provider"

val formattedCustomers: String
    get() = when {
        completed_jobs == 0 -> "New"
        completed_jobs < 10 -> "$completed_jobs"
        completed_jobs < 100 -> "${(completed_jobs / 10) * 10}+"
        else -> "${(completed_jobs / 50) * 50}+"
    }

private fun formatAmount(v: Double): String {
    val isWhole = v % 1.0 == 0.0
    return if (isWhole) "%.0f".format(v) else "%.2f".format(v)
}
```

The existing `formattedRating`, `formattedJobCount`, `formattedEarnings`, `topServiceCategories`, `hasExperience`, `formattedLastSeen`, `responseTimeTextValue` stay as-is.

### `ProviderReview` (new, in `data/model/Profile.kt`)

Mirrors iOS `ProviderReview` (`DatabaseModels.swift:909`):

```kotlin
@Serializable
data class ProviderReview(
    val id: String,
    val rating: Int,
    val comment: String? = null,
    val created_at: String? = null,
    val reviewer_name: String? = null,
    val reviewer_avatar: String? = null,
) {
    val displayName: String get() = reviewer_name ?: "Anonymous"
    val formattedDate: String get() = /* ISO8601 → "MMM d, yyyy" with the two-format fallback from iOS */
}
```

The repository's `fetchReviews` returns `List<ProviderReview>` (already enriched). The screen never sees the raw `ReviewRow` shape.

## Repository changes

`ProfilePublicRepository` extends with three new methods, all following the existing "swallow exceptions, return safe default" pattern:

```kotlin
suspend fun fetchPublicProfileSummaries(
    providerIds: List<String>
): Map<String, PublicProfileSummary>      // empty map on failure

suspend fun fetchServiceHighlights(
    providerId: String
): List<ServiceHighlight>                  // empty list on failure

suspend fun fetchReviews(
    providerId: String,
    limit: Int = 20
): List<ProviderReview>                    // empty list on failure
```

**Service highlights source** — match iOS fallback. The iOS `execute_sql` RPC does not exist in the migrations, so the iOS code's raw-SQL branch always fails and falls back to deriving highlights from `profile.service_categories` (the placeholder branch in `PublicProfileNetworking.swift:114-126`). The Android implementation calls `fetchPublicProfile` first, then maps the top three service categories into `ServiceHighlight` rows with `job_count = profile.completed_jobs`, `avg_rating = profile.avg_rating`, `recent_completion = profile.last_updated`, `avg_job_value = profile.avg_job_value`. This is byte-for-byte equivalent to what iOS renders today.

**Reviews enrichment** — fetch raw `id, rating, comment, created_at, reviewer_id` rows from `reviews` where `reviewed_id = providerId`, order by `created_at desc`, limit. Then call `fetchPublicProfileSummaries(reviewerIds)` once to batch-resolve reviewer names/avatars, then zip the summary into each row. (Mirrors `PublicProfileNetworking.swift:151-183`.)

## ViewModel changes

Extend `PublicProfileUiState`:

```kotlin
data class PublicProfileUiState(
    val isLoading: Boolean = true,
    val profile: PublicProfile? = null,
    val serviceHighlights: List<ServiceHighlight> = emptyList(),
    val reviews: List<ProviderReview> = emptyList(),
    val errorMessage: String? = null,
)
```

`load(userId)` fans out three coroutines and waits for all:

```kotlin
fun load(userId: String) {
    if (userId.isBlank()) {
        _uiState.update { it.copy(isLoading = false, errorMessage = "Invalid user id") }
        return
    }
    loadedUserId = userId
    _uiState.update { it.copy(isLoading = true, errorMessage = null) }
    viewModelScope.launch {
        coroutineScope {
            val profileD = async { repository.fetchPublicProfile(userId) }
            val highlightsD = async { repository.fetchServiceHighlights(userId) }
            val reviewsD = async { repository.fetchReviews(userId) }
            val profile = profileD.await()
            if (profile == null) {
                _uiState.update {
                    it.copy(isLoading = false, profile = null, errorMessage = "Profile not found")
                }
            } else {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        profile = profile,
                        serviceHighlights = highlightsD.await(),
                        reviews = reviewsD.await(),
                        errorMessage = null,
                    )
                }
            }
        }
    }
}
```

- Highlight / review failures are non-fatal (the await calls don't throw because the repository swallows them).
- `retry()` reloads `loadedUserId` — unchanged.

## Screen changes

`PublicProfileScreen(userId, onBack, viewModel)` keeps its signature. Body becomes:

```kotlin
Scaffold(topBar = TopAppBar(title = "Profile", nav = back)) { padding ->
    when {
        state.isLoading -> LoadingView(padding)
        state.profile != null -> ProfileDetail(
            profile = state.profile!!,
            highlights = state.serviceHighlights,
            reviews = state.reviews,
            modifier = Modifier.padding(padding),
        )
        else -> ErrorView(state.errorMessage ?: "Profile not available", viewModel::retry, padding)
    }
}
```

`ProfileDetail` is a `LazyColumn(contentPadding = (h=16, v=8), verticalArrangement = spacedBy(20.dp))` with items:

1. `ProfileHero(profile)` — fixed 300dp tall.
2. `StatCardsRow(profile)` — 3 `ProviderStatCard`s, each `Modifier.weight(1f)`.
3. `ProfileTabStrip(selected, onSelected)` — pill-style, default `ProviderProfileTab.ABOUT`.
4. `tabContent` — one of `AboutTab`, `AvailabilityTab`, `ExperienceTab`, `ReviewsTab` based on `selected`.
5. `PricingRow(profile)` — rendered only if `formattedHourlyRate != null || formattedTeamRate != null`.
6. `Spacer(40.dp)`.

## UI components (new in `PublicProfileComponents.kt`)

### `ProviderProfileTab` (enum)

```kotlin
enum class ProviderProfileTab(val label: String) {
    ABOUT("About"),
    AVAILABILITY("Availability"),
    EXPERIENCE("Experience"),
    REVIEWS("Reviews"),
}
```

### `ProfileHero`

- Outer `Box(Modifier.fillMaxWidth().height(300.dp).clip(RoundedCornerShape(20.dp)))`.
- Background layer: `AsyncImage` with `ContentScale.Crop`, or `LinearGradient(WarmOrange.copy(0.35) → WarmOrange.copy(0.12))` with centered `Icons.Filled.Person` (60dp, `Color.White.copy(0.8f)`) fallback.
- Scrim layer: `LinearGradient(Color.Transparent → Color.Black.copy(0.65f), center → bottom)` covering the full 300dp.
- Bottom-leading overlay (16dp padding), `Column(Arrangement.spacedBy(6.dp))`:
  - Profession row: `Icons.Filled.Handyman` (caption) + `Text(profession ?: topServiceCategories.firstOrNull() ?: "Service Provider", subheadline, FontWeight.Medium, White.copy(0.9f))`.
  - Name: `Text(fullName, titleLarge, FontWeight.Bold, White)`.
  - Tagline (if non-blank): `Text(tagline, subheadline, White.copy(0.85f))`.
  - Last row: `Text(experienceText, caption, White.copy(0.85f))` + `HourlyRateCapsule` (if `formattedHourlyRate != null`).

### `HourlyRateCapsule`

`Surface(shape = CircleShape, color = WarmOrange)` containing `Text("৳X/hr", caption, FontWeight.SemiBold, White, padding(h=10, v=4))`.

### `ProviderStatCard`

```kotlin
@Composable
fun ProviderStatCard(emoji: String, value: String, label: String, tint: Color) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 16.dp).background(tint, RoundedCornerShape(16.dp)),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(emoji, style = MaterialTheme.typography.titleMedium)
        Text(value, headlineSmall, FontWeight.Bold, maxLines = 1, softWrap = false, overflow = TextOverflow.Visible)
        Text(label, labelSmall, KajHobeTheme.colors.textSecondary)
    }
}
```

(Use `Modifier.weight(1f)` on the caller.)

Stat-card values (note: the Rating card uses `"New"` when `avg_rating == 0`, **not** `profile.formattedRating` which returns "No ratings" — the stat card labels mirror iOS, which uses the shorter "New" form on this card):
- Experience: `experience_years?.takeIf { it > 0 }?.let { "${it} yr${if (it == 1) "" else "s"}" } ?: "New"`
- Rating: `if (profile.avg_rating > 0) "%.1f".format(profile.avg_rating) else "New"`
- Customers: `profile.formattedCustomers`

Tints (constants in this file):
- Experience: `Color(0x26FF9F0A)` (orange @ 0.15)
- Rating: `Color(0x268E44AD)` (purple @ 0.15)
- Customers: `Color(0x26FF4081)` (pink @ 0.15)

### `ProfileTabStrip`

- Outer `Row(Modifier.clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surfaceVariant).padding(4.dp))`.
- 4 children, one per `ProviderProfileTab`:
  ```kotlin
  TextButton(
      onClick = { onSelected(tab) },
      modifier = Modifier.weight(1f),
      contentPadding = PaddingValues(vertical = 10.dp),
      colors = ButtonDefaults.textButtonColors(
          containerColor = if (selected) MaterialTheme.colorScheme.surface else Color.Transparent,
      ),
      shape = RoundedCornerShape(12.dp),
  ) {
      Text(tab.label, subheadline, FontWeight = if (selected) SemiBold else Normal)
  }
  ```
- Active tab gets a shadow on the surface-colored button (`Modifier.shadow(if (selected) 1.dp else 0.dp, RoundedCornerShape(12.dp))`).
- Local state: `var selected by remember { mutableStateOf(ProviderProfileTab.ABOUT) }` — owned by the screen, passed down.

### `AboutTab`

- Local `var isBioExpanded by remember { mutableStateOf(false) }`.
- `Column(Arrangement.spacedBy(8.dp), Modifier.fillMaxWidth())`:
  - `Text("About ${profile.fullName ?: "Provider"}", headlineSmall)`.
  - `Text(bioText, bodyMedium, color = if blank then secondary else primary, maxLines = if (isBioExpanded) Int.MAX_VALUE else 4)`.
  - If `bio != null && bio.length > 160`: `TextButton(onClick = { isBioExpanded = !isBioExpanded }) { Text(if (isBioExpanded) "Read Less" else "Read More", color = WarmOrange, FontWeight.SemiBold) }`.
- Empty bio: `Text("This provider hasn't added a bio yet.", bodyMedium, secondary)`.

### `AvailabilityTab`

`Column(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp)).padding(16.dp), Arrangement.spacedBy(12.dp))`:
- Row 1: 10dp `Box` (green if `isOnline` else neutral gray) + `Text(if (isOnline) "Online now" else "Last seen ${formattedLastSeen}", subheadline, color = if (isOnline) green else secondary)`.
- Row 2: `Icons.Filled.Schedule` (secondary) + `Text("Typically responds in ${responseTimeTextValue}", subheadline, secondary)`.

### `ExperienceTab`

- If `service_categories.isNotEmpty()`:
  - `Text("Service Categories", headlineSmall)`.
  - `FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp))` of small blue chips (reuse the existing `CategoryChip` pattern, or extract a tiny `ServiceCategoryChip(category)` helper).
- If `serviceHighlights.isNotEmpty()`:
  - `Text("Specializations", headlineSmall)`.
  - `Column(Arrangement.spacedBy(8.dp))` of `ServiceHighlightCard`.
- Else: `Text("No experience details yet.", subheadline, secondary)`.

### `ServiceHighlightCard`

`Row(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface, RoundedCornerShape(8.dp)).border(1.dp, Color(0xFFE5E5E5), RoundedCornerShape(8.dp)).padding(12.dp))`:
- Left `Column` (Arrangement.spacedBy(4.dp), `Modifier.weight(1f)`):
  - `Text(highlight.category, subheadline, FontWeight.Medium)`.
  - `Text(highlight.formattedJobCount, labelSmall, secondary)`.
- Right `Column` (horizontal = End):
  - `Text(highlight.formattedRating, labelSmall, FontWeight.Medium)`.
  - `Text(highlight.formattedRecentCompletion, labelSmall, KajHobeTheme.colors.textTertiary)`.

### `ReviewsTab`

- If `isLoading` (the screen-level state covers this; no per-tab loading): the parent `LazyColumn` shows the `LoadingView` branch.
- If `reviews.isEmpty()`: centered `Column(horizontalAlignment = CenterHorizontally, modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp))` with `Icons.Filled.Star` (32dp, secondary) + `Text("No reviews yet", subheadline, secondary)`.
- Else: `Column(Arrangement.spacedBy(12.dp))` of `ProviderReviewCard`.

### `ProviderReviewCard`

`Column(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp)).padding(12.dp), Arrangement.spacedBy(8.dp))`:
- Top `Row(verticalAlignment = CenterVertically, Arrangement.spacedBy(10.dp))`:
  - 36dp circular avatar: `AsyncImage` (Coil, `ContentScale.Crop`) with `Color.Gray.copy(0.3f)` + `Icons.Filled.Person` fallback.
  - `Column(Arrangement.spacedBy(2.dp), Modifier.weight(1f))`:
    - `Text(review.displayName, subheadline, FontWeight.Medium)`.
    - `Text(review.formattedDate, labelSmall, secondary)`.
  - Star row: `Row(spacedBy = 2.dp)` of 5 `Icon`s, `Icons.Filled.Star` (yellow) for indices < `rating`, `Icons.Outlined.StarBorder` (yellow) otherwise; overall `contentDescription = "$rating out of 5 stars"`.
- If `comment` non-blank: `Text(comment, bodyMedium, onSurface)`.

### `PricingRow`

Conditional — only emitted by the screen when `formattedHourlyRate != null || formattedTeamRate != null`.

`Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp))`:
- If `formattedHourlyRate != null`: `PricingCard(Icons.Outlined.Payments, "Hourly Fee", formattedHourlyRate, caption = null)`.
- If `formattedTeamRate != null`: `PricingCard(Icons.Filled.Group, "Team Work", formattedTeamRate, caption = profile.team_hours_label)`.

Each card has `Modifier.weight(1f)`.

### `PricingCard`

`Column(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(14.dp)).padding(16.dp), Arrangement.spacedBy(6.dp))`:
- Top `Row(Arrangement.spacedBy(6.dp), verticalAlignment = CenterVertically)`:
  - `Icon(icon, contentDescription = null, tint = secondary)`.
  - `Text(title, subheadline, secondary)`.
- Bottom `Row(verticalAlignment = Alignment.Bottom)`:
  - `Text(value, titleLarge, FontWeight.Bold)`.
  - If `caption != null && caption.isNotBlank()`: `Text("($caption)", labelSmall, secondary)`.

## Theme

- Accent: `WarmOrange = 0xFFFF9F0A` (from `Color.kt:15`) — exact match for iOS's `Color(red: 1.0, green: 0.58, blue: 0.0)`.
- Surfaces: `MaterialTheme.colorScheme.surfaceVariant` for cards (matches existing Android screen), `surface` for the highlight card background, `surface` for the active-tab button background.
- Text colors: `KajHobeTheme.colors.textSecondary` / `textTertiary` for muted text; `onSurface` for primary.
- Stat-card tints (`#26FF9F0A` / `#268E44AD` / `#26FF4081`) are local constants in `PublicProfileComponents.kt`.

## Edge cases

- **No avatar** → gradient hero with centered person icon.
- **No profession** → first entry of `topServiceCategories`; if empty, "Service Provider".
- **No hourly rate** → `HourlyRateCapsule` omitted; `PricingRow` omitted if team rate is also absent.
- **No service categories** → Experience tab shows "No experience details yet."
- **No reviews** → Reviews tab shows "No reviews yet" empty state.
- **No bio / short bio (≤160 chars)** → no Read More button; empty bio shows "This provider hasn't added a bio yet."
- **`avg_rating == 0`** → Rating card shows "New"; "Customers" shows "New" when `completed_jobs == 0`.
- **Long names** → `Text(maxLines = 2, overflow = Ellipsis)` in hero.
- **Reviewer name/avatar missing** → "Anonymous" and the gray placeholder avatar (matches iOS `displayName`).
- **Repository exceptions** → swallowed; profile null → error state, highlights/reviews empty → fallback UI.
- **Tap-to-profile from a notification or job card** → already wired through `Routes.PUBLIC_PROFILE` in `MainScaffold.kt:199`; no nav changes.

## Accessibility

- Avatar `contentDescription` = `profile.fullName ?: "Provider avatar"`.
- Decorative icons (wrench, schedule, person) get `contentDescription = null`.
- Star row gets a single `contentDescription = "$rating out of 5 stars"` instead of five announcements.
- Hero text on `Color.Black.copy(0.65f)` scrim passes WCAG AA on any background image.
- Tinted stat-card text remains in `onSurface` (high contrast on the 0.15-alpha tint backgrounds).

## Test plan

### Dependencies (added to `app/build.gradle.kts`)

```kotlin
testImplementation(libs.kotlinx.coroutines.test)
testImplementation(libs.junit)
```

Plus version catalog entries in `gradle/libs.versions.toml` if not already present.

### `PublicProfileViewModelTest`

A fake `ProfilePublicRepository` (no mockk needed) with controllable return values for `fetchPublicProfile`, `fetchServiceHighlights`, `fetchReviews`. Test cases:

1. **Success path** — `load(validId)` sets `isLoading = false`, populates `profile` / `highlights` / `reviews`, leaves `errorMessage = null`.
2. **Profile not found** — fake `fetchPublicProfile` returns `null`; final state has `profile = null`, `errorMessage = "Profile not found"`, `isLoading = false`. Highlights and reviews are still awaited but their state isn't observable because the error branch overwrites.
3. **Invalid id** — `load("")` short-circuits to `errorMessage = "Invalid user id"` without calling the repository.
4. **Retry** — after error, `retry()` calls `load(loadedUserId)` and the fake's counters confirm the repository was hit again.
5. **Non-fatal highlight/review failure** — fake throws on `fetchServiceHighlights` and `fetchReviews`; the repository's `runCatching` swallows them, the ViewModel still completes the fan-out and reaches the success branch with empty lists.

### Manual verification (no infra for snapshot tests)

Build the app, open a notification that has an interest request, tap the sender's profile, compare the rendered Android screen side-by-side with the iOS simulator running the same data. Cover at least: provider with full data, provider with minimal data, provider with no avatar, provider with no reviews.

## Out of scope (explicitly)

- Building a real per-category aggregation for "Specializations" (the iOS code itself never succeeds at the raw-SQL path; this PR matches that).
- Adding `execute_sql` RPC to the database.
- Re-skinning the rest of the app to match the new accent color.
- Real-time updates (`subscribeToPublicProfile` on iOS has no Android counterpart in the current codebase; out of scope).
- Animations on tab switch beyond the default Material 3 ripple.
- i18n of any new strings — Bengali / English localizations follow the existing app pattern and are added only when the rest of the codebase does.

# Android Public Profile — iOS Parity Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `PublicProfileScreen` to match the iOS `PublicProfileDetailView` exactly: hero with profession/tagline/hourly rate, three colored stat cards, four-tab strip (About / Availability / Experience / Reviews), and a pricing row.

**Architecture:** Add the iOS-only fields to the data model, add three repository methods, fan out the three fetches in the ViewModel, split the screen into a small set of focused components (one file), and rewrite the screen to assemble them. ViewModel test-only via JUnit + kotlinx-coroutines-test; components are build-checked (no Compose UI test infra in the repo).

**Tech Stack:** Kotlin 2.3.21, Jetpack Compose (BOM 2026.05.01), Supabase Kotlin 3.6.0, Koin 4.1.0, kotlinx-coroutines 1.11.0, JUnit 4.13.2.

**Spec:** `docs/superpowers/specs/2026-06-08-android-public-profile-design.md`

---

## File structure

| File | Responsibility |
|---|---|
| `gradle/libs.versions.toml` | Add `junit` version + `kotlinx-coroutines-test` + `junit` library aliases. |
| `app/build.gradle.kts` | Add `kotlinx-coroutines-test` and `junit` to `testImplementation`. |
| `data/model/Profile.kt` | Extend `PublicProfile` with 6 optional fields and 3 computed properties. Add `ProviderReview` data class. |
| `data/repository/ProfilePublicRepository.kt` | Add `fetchPublicProfileSummaries`, `fetchServiceHighlights`, `fetchReviews`. Open the class for test override. |
| `ui/feature/profile/PublicProfileViewModel.kt` | Extend `PublicProfileUiState` with `serviceHighlights` + `reviews`. Fan out the three fetches via `async`. |
| `ui/feature/profile/PublicProfileComponents.kt` *(new)* | `ProviderProfileTab` enum, `ProfileHero`, `HourlyRateCapsule`, `ProviderStatCard`, `ProfileTabStrip`, `AvailabilityCard`, `ServiceHighlightCard`, `ProviderReviewCard`, `PricingCard`. |
| `ui/feature/profile/PublicProfileScreen.kt` | Rewrite body to assemble the components. Public signature unchanged. |
| `app/src/test/java/com/kajhobe/app/ui/feature/profile/PublicProfileViewModelTest.kt` *(new)* | Six test cases. |

## Conventions

- **No comments** in source files (CLAUDE.md rule). Doc-comments are allowed on the existing public surface (e.g. the new `ProviderReview` data class) but not added gratuitously.
- **No emojis** in code.
- All test files use JUnit 4 (`@Test` from `org.junit.Test`).
- Use `runTest { ... }` from `kotlinx.coroutines.test` for ViewModel tests; the ViewModel's `viewModelScope` is replaced via `Dispatchers.setMain(UnconfinedTestDispatcher())` in `@Before`.
- Frequent commits — one commit per task (or per logical group of 2-3 steps when a task is purely "add code, no test").

---

## Task 1: Add test dependencies

**Files:**
- Modify: `gradle/libs.versions.toml:18` (add `junit` version)
- Modify: `gradle/libs.versions.toml:42` (add `kotlinx-coroutines-test` library alias)
- Modify: `gradle/libs.versions.toml:74` (add `junit` library alias)
- Modify: `app/build.gradle.kts:55-99` (add `testImplementation` lines)

- [ ] **Step 1: Add the `junit` version**

In `gradle/libs.versions.toml`, after the `accompanist = "0.37.3"` line, add:

```toml
junit = "4.13.2"
```

- [ ] **Step 2: Add `kotlinx-coroutines-test` library alias**

In the `[libraries]` block, after the `kotlinx-coroutines-android` line, add:

```toml
kotlinx-coroutines-test = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "coroutines" }
```

- [ ] **Step 3: Add `junit` library alias**

After the `kotlinx-coroutines-test` line, add:

```toml
junit = { module = "junit:junit", version.ref = "junit" }
```

- [ ] **Step 4: Add `testImplementation` lines**

In `app/build.gradle.kts`, after the existing `implementation(libs.coil.network.okhttp)` line (around line 93), add:

```kotlin
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.junit)
```

- [ ] **Step 5: Build to verify Gradle resolves the new deps**

Run: `./gradlew :app:dependencies --configuration testRuntimeClasspath 2>&1 | tail -20`
Expected: build succeeds and prints `kotlinx-coroutines-test` and `junit` in the resolved tree.

- [ ] **Step 6: Commit**

```bash
git add gradle/libs.versions.toml app/build.gradle.kts
git commit -m "build: add junit and kotlinx-coroutines-test for ViewModel testing"
```

---

## Task 2: Extend `PublicProfile` with the iOS-only fields and computed properties

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/data/model/Profile.kt:67-108` (the `PublicProfile` data class)

- [ ] **Step 1: Add the 6 new fields**

In `data/model/Profile.kt`, inside the `PublicProfile` data class, after the existing `last_updated: String? = null,` line, add:

```kotlin
    val profession: String? = null,
    val tagline: String? = null,
    val experience_years: Int? = null,
    val hourly_rate: Double? = null,
    val team_rate: Double? = null,
    val team_hours_label: String? = null,
```

- [ ] **Step 2: Add the 3 new computed properties**

In the same file, after the existing `responseTimeTextValue` getter line, add:

```kotlin
    val formattedHourlyRate: String?
        get() {
            val rate = hourly_rate ?: return null
            if (rate <= 0) return null
            return "৳${formatAmount(rate)}/hr"
        }

    val formattedTeamRate: String?
        get() {
            val rate = team_rate ?: return null
            if (rate <= 0) return null
            return "৳${formatAmount(rate)}"
        }

    val experienceText: String
        get() {
            val years = experience_years ?: return "New provider"
            if (years <= 0) return "New provider"
            return "$years year${if (years == 1) "" else "s"} of experience"
        }

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

- [ ] **Step 3: Build to confirm the model still serializes/deserializes**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -20`
Expected: build succeeds. (The fields are all optional with defaults, so the existing call sites in `ProfilePublicRepository.fetchPublicProfile` and `NotificationsViewModel` keep working without any other changes.)

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/data/model/Profile.kt
git commit -m "feat(profile): extend PublicProfile with iOS provider fields"
```

---

## Task 3: Add the `ProviderReview` data class

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/data/model/Profile.kt` (append after the existing `ServiceHighlight` class around line 138)

- [ ] **Step 1: Add the data class**

At the end of `data/model/Profile.kt`, after the closing brace of the `ServiceHighlight` class, add:

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

    val formattedDate: String
        get() {
            val raw = created_at ?: return ""
            val withFraction = java.time.OffsetDateTime.parse(raw)
                .toLocalDate()
            return withFraction.format(java.time.format.DateTimeFormatter.ofPattern("MMM d, yyyy"))
        }
}
```

- [ ] **Step 2: Build to confirm the new type compiles**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -20`
Expected: build succeeds. (The minSdk is 26; `java.time.OffsetDateTime` and `DateTimeFormatter` are available without desugaring.)

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/data/model/Profile.kt
git commit -m "feat(profile): add ProviderReview model"
```

---

## Task 4: Open `ProfilePublicRepository` for test override

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/data/repository/ProfilePublicRepository.kt:14`

- [ ] **Step 1: Add `open` to the class and methods**

Change the class declaration from:

```kotlin
class ProfilePublicRepository(client: SupabaseClient) : BaseRepository(client) {

    /**
     * Fetch a single public profile by user id. Returns null if the row is missing
     * (mirrors the iOS "Profile not found" branch).
     */
    suspend fun fetchPublicProfile(userId: String): PublicProfile? {
```

to:

```kotlin
open class ProfilePublicRepository(client: SupabaseClient) : BaseRepository(client) {

    /**
     * Fetch a single public profile by user id. Returns null if the row is missing
     * (mirrors the iOS "Profile not found" branch).
     */
    open suspend fun fetchPublicProfile(userId: String): PublicProfile? {
```

- [ ] **Step 2: Build to confirm**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -10`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/data/repository/ProfilePublicRepository.kt
git commit -m "refactor(profile): open ProfilePublicRepository for test override"
```

---

## Task 5: Add `fetchPublicProfileSummaries` to the repository

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/data/repository/ProfilePublicRepository.kt` (append method)

- [ ] **Step 1: Add the method**

At the end of the `ProfilePublicRepository` class (before the closing brace), add:

```kotlin
    open suspend fun fetchPublicProfileSummaries(
        providerIds: List<String>,
    ): Map<String, PublicProfileSummary> {
        if (providerIds.isEmpty()) return emptyMap()
        return runCatching {
            postgrest.from("public_profiles")
                .select(
                    columns = Columns.list(
                        "id", "full_name", "avatar_url", "trust_level",
                        "completed_jobs", "avg_rating", "is_online",
                    ),
                ) {
                    filter { isIn("id", providerIds) }
                }
                .decodeList<PublicProfileSummary>()
                .associateBy { it.id }
        }.getOrDefault(emptyMap())
    }
```

- [ ] **Step 2: Add the missing `Columns` import**

The Supabase Kotlin DSL uses `io.github.jan.supabase.postgrest.query.Columns`. Add to the import block at the top of the file:

```kotlin
import io.github.jan.supabase.postgrest.query.Columns
```

- [ ] **Step 3: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -15`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/data/repository/ProfilePublicRepository.kt
git commit -m "feat(profile): add fetchPublicProfileSummaries to repository"
```

---

## Task 6: Add `fetchServiceHighlights` to the repository

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/data/repository/ProfilePublicRepository.kt` (append method)

- [ ] **Step 1: Add the method**

Right after `fetchPublicProfileSummaries` (still inside the class), add:

```kotlin
    open suspend fun fetchServiceHighlights(
        providerId: String,
    ): List<ServiceHighlight> {
        if (providerId.isBlank()) return emptyList()
        val profile = runCatching { fetchPublicProfile(providerId) }.getOrNull() ?: return emptyList()
        val categories = profile.topServiceCategories
        if (categories.isEmpty()) return emptyList()
        return categories.map { category ->
            ServiceHighlight(
                category = category,
                job_count = profile.completed_jobs,
                avg_rating = profile.avg_rating.takeIf { it > 0 },
                recent_completion = profile.last_updated,
                avg_job_value = profile.avg_job_value.takeIf { it > 0 },
            )
        }
    }
```

This matches the iOS fallback path exactly: derive highlights from `profile.topServiceCategories` (the iOS `execute_sql` RPC does not exist, so the iOS code always falls back to this).

- [ ] **Step 2: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -10`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/data/repository/ProfilePublicRepository.kt
git commit -m "feat(profile): add fetchServiceHighlights to repository"
```

---

## Task 7: Add `fetchReviews` to the repository

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/data/repository/ProfilePublicRepository.kt` (append method + private DTO)

- [ ] **Step 1: Add the private DTO for raw review rows**

At the bottom of the file (still inside `ProfilePublicRepository.kt`, before the closing brace of the class), add a private raw-row model just above the new method:

```kotlin
    @Serializable
    private data class ReviewRow(
        val id: String,
        val rating: Int,
        val comment: String? = null,
        val created_at: String? = null,
        val reviewer_id: String? = null,
    )
```

- [ ] **Step 2: Add the `kotlinx.serialization.Serializable` import**

At the top of the file, add:

```kotlin
import kotlinx.serialization.Serializable
```

- [ ] **Step 3: Add the `fetchReviews` method**

Below the `ReviewRow` data class, add:

```kotlin
    open suspend fun fetchReviews(
        providerId: String,
        limit: Int = 20,
    ): List<ProviderReview> {
        if (providerId.isBlank()) return emptyList()
        val rows = runCatching {
            postgrest.from("reviews")
                .select(columns = Columns.list("id", "rating", "comment", "created_at", "reviewer_id")) {
                    order("created_at", Order.DESCENDING)
                    limit(limit.toLong())
                    filter {
                        eq("reviewed_id", providerId)
                    }
                }
                .decodeList<ReviewRow>()
        }.getOrDefault(emptyList())
        if (rows.isEmpty()) return emptyList()

        val reviewerIds = rows.mapNotNull { it.reviewer_id }.distinct()
        val summaries = fetchPublicProfileSummaries(reviewerIds)
        return rows.map { row ->
            val summary = row.reviewer_id?.let { summaries[it] }
            ProviderReview(
                id = row.id,
                rating = row.rating,
                comment = row.comment,
                created_at = row.created_at,
                reviewer_name = summary?.full_name,
                reviewer_avatar = summary?.avatar_url,
            )
        }
    }
```

- [ ] **Step 4: Add the missing `Order` import**

At the top of the file, add:

```kotlin
import io.github.jan.supabase.postgrest.query.Order
```

- [ ] **Step 5: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -15`
Expected: build succeeds. (The `Order` enum exists in the supabase postgrest 3.6.0 API; if a future version renames it, the build error message will name the replacement.)

- [ ] **Step 6: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/data/repository/ProfilePublicRepository.kt
git commit -m "feat(profile): add fetchReviews to repository with reviewer enrichment"
```

---

## Task 8: Write the failing ViewModel test

**Files:**
- Create: `app/src/test/java/com/kajhobe/app/ui/feature/profile/PublicProfileViewModelTest.kt`

- [ ] **Step 1: Create the test package directory and file**

The directory does not exist yet. Create it and the file `app/src/test/java/com/kajhobe/app/ui/feature/profile/PublicProfileViewModelTest.kt` with this content:

```kotlin
package com.kajhobe.app.ui.feature.profile

import com.kajhobe.app.data.model.PublicProfile
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.ServiceHighlight
import com.kajhobe.app.data.repository.ProfilePublicRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.SupabaseClientConfig
import io.github.jan.supabase.SupabaseSerializer
import io.github.jan.supabase.logging.SupabaseLogger
import io.github.jan.supabase.network.KtorSupabaseHttpClient
import io.github.jan.supabase.plugins.AccessTokenProvider
import io.github.jan.supabase.plugins.PluginManager
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PublicProfileViewModelTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun newVm(repo: ProfilePublicRepository) = PublicProfileViewModel(repo)

    private class FakeRepository(
        var profileResult: PublicProfile? = sampleProfile(),
        var highlightsResult: List<ServiceHighlight> = listOf(sampleHighlight()),
        var reviewsResult: List<ProviderReview> = listOf(sampleReview()),
        val callCounts: MutableMap<String, Int> = mutableMapOf(),
        val perCallDelayMs: Long = 0L,
        val throwOn: Set<String> = emptySet(),
    ) : ProfilePublicRepository(stubSupabaseClient()) {

        private suspend fun <T> gate(name: String, block: suspend () -> T): T {
            callCounts[name] = (callCounts[name] ?: 0) + 1
            if (perCallDelayMs > 0) delay(perCallDelayMs)
            if (name in throwOn) throw RuntimeException("boom: $name")
            return block()
        }

        override suspend fun fetchPublicProfile(userId: String): PublicProfile? =
            gate("fetchPublicProfile") { profileResult }

        override suspend fun fetchServiceHighlights(providerId: String): List<ServiceHighlight> =
            gate("fetchServiceHighlights") { highlightsResult }

        override suspend fun fetchReviews(providerId: String, limit: Int): List<ProviderReview> =
            gate("fetchReviews") { reviewsResult }
    }

    @Test
    fun `load with valid id populates state from all three sources`() = runTest(testDispatcher) {
        val repo = FakeRepository()
        val vm = newVm(repo)

        vm.load("user-1")

        val state = vm.uiState.value
        assertEquals(false, state.isLoading)
        assertNotNull(state.profile)
        assertEquals("user-1", state.profile!!.id)
        assertEquals(1, state.serviceHighlights.size)
        assertEquals(1, state.reviews.size)
        assertNull(state.errorMessage)
    }

    @Test
    fun `load with null profile sets error and skips fatal`() = runTest(testDispatcher) {
        val repo = FakeRepository(profileResult = null)
        val vm = newVm(repo)

        vm.load("user-1")

        val state = vm.uiState.value
        assertEquals(false, state.isLoading)
        assertNull(state.profile)
        assertEquals("Profile not found", state.errorMessage)
        assertEquals(1, repo.callCounts["fetchPublicProfile"])
    }

    @Test
    fun `load with blank id short-circuits without calling repository`() = runTest(testDispatcher) {
        val repo = FakeRepository()
        val vm = newVm(repo)

        vm.load("")

        val state = vm.uiState.value
        assertEquals(false, state.isLoading)
        assertEquals("Invalid user id", state.errorMessage)
        assertTrue(repo.callCounts.isEmpty())
    }

    @Test
    fun `retry reloads the last user id`() = runTest(testDispatcher) {
        val repo = FakeRepository(profileResult = null)
        val vm = newVm(repo)

        vm.load("user-1")
        repo.profileResult = sampleProfile()
        vm.retry()

        assertEquals(2, repo.callCounts["fetchPublicProfile"])
        assertNotNull(vm.uiState.value.profile)
    }

    @Test
    fun `non-fatal highlight and review failures are swallowed`() = runTest(testDispatcher) {
        val repo = FakeRepository(
            throwOn = setOf("fetchServiceHighlights", "fetchReviews"),
        )
        val vm = newVm(repo)

        vm.load("user-1")

        val state = vm.uiState.value
        assertEquals(false, state.isLoading)
        assertNotNull(state.profile)
        assertTrue(state.serviceHighlights.isEmpty())
        assertTrue(state.reviews.isEmpty())
        assertNull(state.errorMessage)
    }

    private fun sampleProfile() = PublicProfile(
        id = "user-1",
        full_name = "Sample Provider",
        trust_level = "experienced",
    )

    private fun sampleHighlight() = ServiceHighlight(
        category = "Home Repair",
        job_count = 5,
    )

    private fun sampleReview() = ProviderReview(
        id = "review-1",
        rating = 5,
        comment = "Great work",
        reviewer_name = "Happy Client",
    )
}

private fun stubSupabaseClient(): SupabaseClient = object : SupabaseClient {
    override val config: SupabaseClientConfig get() = error("not used in test")
    override val supabaseHttpUrl: String get() = ""
    override val supabaseUrl: String get() = ""
    override val supabaseKey: String get() = ""
    override val pluginManager: PluginManager get() = error("not used in test")
    override val httpClient: KtorSupabaseHttpClient get() = error("not used in test")
    override val useHTTPS: Boolean get() = false
    override val defaultSerializer: SupabaseSerializer get() = error("not used in test")
    override val accessToken: AccessTokenProvider? get() = null
    override val coroutineDispatcher: CoroutineDispatcher get() = error("not used in test")
    override val logger: SupabaseLogger get() = error("not used in test")
    override suspend fun close() {}
}
```

- [ ] **Step 2: Run the test to verify it fails (compile-error is also a fail)**

Run: `./gradlew :app:testDebugUnitTest 2>&1 | tail -30`
Expected: build failure or test failure — the `PublicProfileViewModel` constructor and state shape are still the old ones, so the test will not compile.

- [ ] **Step 3: Commit the failing test**

```bash
git add app/src/test/java/com/kajhobe/app/ui/feature/profile/PublicProfileViewModelTest.kt
git commit -m "test(profile): add PublicProfileViewModelTest covering load/retry/fan-out"
```

---

## Task 9: Implement the ViewModel fan-out

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileViewModel.kt`

- [ ] **Step 1: Replace the file contents with the new implementation**

Overwrite `PublicProfileViewModel.kt` with:

```kotlin
package com.kajhobe.app.ui.feature.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.PublicProfile
import com.kajhobe.app.data.model.ServiceHighlight
import com.kajhobe.app.data.repository.ProfilePublicRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class PublicProfileUiState(
    val isLoading: Boolean = true,
    val profile: PublicProfile? = null,
    val serviceHighlights: List<ServiceHighlight> = emptyList(),
    val reviews: List<ProviderReview> = emptyList(),
    val errorMessage: String? = null,
)

class PublicProfileViewModel(
    private val repository: ProfilePublicRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(PublicProfileUiState())
    val uiState: StateFlow<PublicProfileUiState> = _uiState.asStateFlow()

    private var loadedUserId: String? = null

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

    fun retry() {
        loadedUserId?.let { load(it) }
    }
}
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `./gradlew :app:testDebugUnitTest --tests "*PublicProfileViewModelTest*" 2>&1 | tail -30`
Expected: all 6 tests pass.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileViewModel.kt
git commit -m "feat(profile): fan out profile + highlights + reviews in ViewModel"
```

---

## Task 10: Create the new `PublicProfileComponents.kt` file with the tab enum and `HourlyRateCapsule`

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt`

- [ ] **Step 1: Create the file with the enum and capsule**

Create `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt`:

```kotlin
package com.kajhobe.app.ui.feature.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kajhobe.app.ui.theme.WarmOrange

enum class ProviderProfileTab(val label: String) {
    ABOUT("About"),
    AVAILABILITY("Availability"),
    EXPERIENCE("Experience"),
    REVIEWS("Reviews"),
}

@Composable
fun HourlyRateCapsule(rateLabel: String, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier,
        shape = CircleShape,
        color = WarmOrange,
    ) {
        Text(
            text = rateLabel,
            color = Color.White,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
        )
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -10`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt
git commit -m "feat(profile): add ProviderProfileTab enum and HourlyRateCapsule"
```

---

## Task 11: Add `ProfileHero`

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt` (append)

- [ ] **Step 1: Add the `ProfileHero` composable**

Append to `PublicProfileComponents.kt`:

```kotlin
@Composable
fun ProfileHero(profile: PublicProfile, modifier: Modifier = Modifier) {
    val accent = WarmOrange
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(300.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(Color.Black),
    ) {
        val avatarUrl = profile.avatar_url
        if (!avatarUrl.isNullOrBlank()) {
            AsyncImage(
                model = avatarUrl,
                contentDescription = profile.full_name ?: "Provider avatar",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.linearGradient(
                            colors = listOf(accent.copy(alpha = 0.35f), accent.copy(alpha = 0.12f)),
                        ),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.Person,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.8f),
                    modifier = Modifier.size(60.dp),
                )
            }
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.65f)),
                        startY = 0f,
                        endY = Float.POSITIVE_INFINITY,
                    ),
                ),
        )

        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            val profession = profile.profession
                ?: profile.topServiceCategories.firstOrNull()
                ?: "Service Provider"
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.Handyman,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.9f),
                    modifier = Modifier.size(14.dp),
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    text = profession,
                    color = Color.White.copy(alpha = 0.9f),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                )
            }
            Text(
                text = profile.full_name ?: "Unknown Provider",
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            val tagline = profile.tagline
            if (!tagline.isNullOrBlank()) {
                Text(
                    text = tagline,
                    color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.padding(top = 2.dp),
            ) {
                Text(
                    text = profile.experienceText,
                    color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.labelSmall,
                )
                val rate = profile.formattedHourlyRate
                if (rate != null) {
                    HourlyRateCapsule(rateLabel = rate)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add the missing imports**

At the top of `PublicProfileComponents.kt`, expand the import block. After the existing imports, add:

```kotlin
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Handyman
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.kajhobe.app.data.model.PublicProfile
```

- [ ] **Step 3: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -15`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt
git commit -m "feat(profile): add ProfileHero composable"
```

---

## Task 12: Add `ProviderStatCard` and `StatCardsRow`

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt` (append)

- [ ] **Step 1: Add the `ProviderStatCard` and `StatCardsRow`**

Append to `PublicProfileComponents.kt`:

```kotlin
private val ExperienceTint = Color(0x26FF9F0A)
private val RatingTint = Color(0x268E44AD)
private val CustomersTint = Color(0x26FF4081)

@Composable
fun ProviderStatCard(
    emoji: String,
    value: String,
    label: String,
    tint: Color,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .background(tint, RoundedCornerShape(16.dp))
            .padding(vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(text = emoji, style = MaterialTheme.typography.titleMedium)
        Text(
            text = value,
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            softWrap = false,
        )
        Text(
            text = label,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            style = MaterialTheme.typography.labelSmall,
        )
    }
}

@Composable
fun StatCardsRow(profile: PublicProfile, modifier: Modifier = Modifier) {
    val experienceValue = profile.experience_years
        ?.takeIf { it > 0 }
        ?.let { "$it yr${if (it == 1) "" else "s"}" }
        ?: "New"
    val ratingValue = if (profile.avg_rating > 0) "%.1f".format(profile.avg_rating) else "New"
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ProviderStatCard(
            emoji = "\uD83D\uDCBC",
            value = experienceValue,
            label = "Experience",
            tint = ExperienceTint,
            modifier = Modifier.weight(1f),
        )
        ProviderStatCard(
            emoji = "\u2B50",
            value = ratingValue,
            label = "Rating",
            tint = RatingTint,
            modifier = Modifier.weight(1f),
        )
        ProviderStatCard(
            emoji = "\uD83D\uDC65",
            value = profile.formattedCustomers,
            label = "Customers",
            tint = CustomersTint,
            modifier = Modifier.weight(1f),
        )
    }
}
```

The emoji strings are written as `\uD83D\uDCBC` (briefcase) / `\u2B50` (star) / `\uD83D\uDC65` (busts in silhouette) so the source file has no literal emoji glyphs (per CLAUDE.md).

- [ ] **Step 2: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -10`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt
git commit -m "feat(profile): add ProviderStatCard and StatCardsRow"
```

---

## Task 13: Add `ProfileTabStrip`

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt` (append)

- [ ] **Step 1: Add the tab strip composable**

Append to `PublicProfileComponents.kt`:

```kotlin
@Composable
fun ProfileTabStrip(
    selected: ProviderProfileTab,
    onSelected: (ProviderProfileTab) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(4.dp),
    ) {
        ProviderProfileTab.entries.forEach { tab ->
            val isSelected = tab == selected
            val container = if (isSelected) MaterialTheme.colorScheme.surface else Color.Transparent
            TextButton(
                onClick = { onSelected(tab) },
                modifier = Modifier
                    .weight(1f)
                    .shadow(if (isSelected) 1.dp else 0.dp, RoundedCornerShape(12.dp)),
                contentPadding = PaddingValues(vertical = 10.dp),
                colors = ButtonDefaults.textButtonColors(containerColor = container),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text(
                    text = tab.label,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                )
            }
        }
    }
}
```

- [ ] **Step 2: Add the missing imports**

At the top of `PublicProfileComponents.kt`, add:

```kotlin
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.TextButton
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.draw.shadow
```

- [ ] **Step 3: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -10`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt
git commit -m "feat(profile): add ProfileTabStrip"
```

---

## Task 14: Add the four tab content composables

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt` (append)

- [ ] **Step 1: Add `AboutTab`, `AvailabilityTab`, `ExperienceTab`, `ReviewsTab`**

Append to `PublicProfileComponents.kt`:

```kotlin
@Composable
fun AboutTab(profile: PublicProfile, modifier: Modifier = Modifier) {
    var isBioExpanded by remember { mutableStateOf(false) }
    val bio = profile.bio
    val hasBio = !bio.isNullOrBlank()
    val showReadMore = hasBio && bio!!.length > 160
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = "About ${profile.full_name ?: "Provider"}",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        if (hasBio) {
            Text(
                text = bio,
                color = MaterialTheme.colorScheme.onSurface,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = if (isBioExpanded) Int.MAX_VALUE else 4,
            )
        } else {
            Text(
                text = "This provider hasn't added a bio yet.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        if (showReadMore) {
            TextButton(onClick = { isBioExpanded = !isBioExpanded }) {
                Text(
                    text = if (isBioExpanded) "Read Less" else "Read More",
                    color = WarmOrange,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
fun AvailabilityTab(profile: PublicProfile, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .clip(CircleShape)
                    .background(if (profile.isOnline) Color(0xFF34C759) else Color(0xFF999999)),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = if (profile.isOnline) "Online now" else "Last seen ${profile.formattedLastSeen}",
                color = if (profile.isOnline) Color(0xFF34C759) else MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Filled.Schedule,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "Typically responds in ${profile.responseTimeTextValue}",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
fun ExperienceTab(
    profile: PublicProfile,
    highlights: List<ServiceHighlight>,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (profile.service_categories.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Service Categories",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    profile.service_categories.forEach { category ->
                        ServiceCategoryChip(category = category)
                    }
                }
            }
        }
        if (highlights.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = "Specializations",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                highlights.forEach { highlight ->
                    ServiceHighlightCard(highlight = highlight)
                }
            }
        }
        if (profile.service_categories.isEmpty() && highlights.isEmpty()) {
            Text(
                text = "No experience details yet.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
fun ReviewsTab(
    reviews: List<ProviderReview>,
    modifier: Modifier = Modifier,
) {
    if (reviews.isEmpty()) {
        Column(
            modifier = modifier
                .fillMaxWidth()
                .padding(vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                Icons.Filled.Star,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(32.dp),
            )
            Text(
                text = "No reviews yet",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    } else {
        Column(
            modifier = modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            reviews.forEach { review ->
                ProviderReviewCard(review = review)
            }
        }
    }
}
```

- [ ] **Step 2: Add the missing imports**

At the top of `PublicProfileComponents.kt`, add:

```kotlin
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Star
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.FlowRow
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.ServiceHighlight
```

- [ ] **Step 3: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -15`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt
git commit -m "feat(profile): add AboutTab, AvailabilityTab, ExperienceTab, ReviewsTab"
```

---

## Task 15: Add the small building blocks (`ServiceCategoryChip`, `ServiceHighlightCard`, `ProviderReviewCard`)

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt` (append)

- [ ] **Step 1: Add the three small composables**

Append to `PublicProfileComponents.kt`:

```kotlin
@Composable
private fun ServiceCategoryChip(category: String, modifier: Modifier = Modifier) {
    Text(
        text = category,
        color = MaterialTheme.colorScheme.onPrimaryContainer,
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.SemiBold,
        modifier = modifier
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primaryContainer)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

@Composable
fun ServiceHighlightCard(highlight: ServiceHighlight, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(8.dp))
            .border(1.dp, Color(0xFFE5E5E5), RoundedCornerShape(8.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = highlight.category,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
            )
            Text(
                text = highlight.formattedJobCount,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelSmall,
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = highlight.formattedRating,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
            )
            Text(
                text = highlight.formattedRecentCompletion,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelSmall,
            )
        }
    }
}

@Composable
fun ProviderReviewCard(review: ProviderReview, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = Alignment.Center,
            ) {
                val avatar = review.reviewer_avatar
                if (!avatar.isNullOrBlank()) {
                    AsyncImage(
                        model = avatar,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize().clip(CircleShape),
                        contentScale = ContentScale.Crop,
                    )
                } else {
                    Icon(
                        Icons.Filled.Person,
                        contentDescription = null,
                        tint = Color(0xFF999999),
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = review.displayName,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                )
                Text(
                    text = review.formattedDate,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(2.dp),
                modifier = Modifier.semantics { contentDescription = "${review.rating} out of 5 stars" },
            ) {
                for (i in 0 until 5) {
                    val filled = i < review.rating
                    Icon(
                        imageVector = if (filled) Icons.Filled.Star else Icons.Outlined.StarBorder,
                        contentDescription = null,
                        tint = Color(0xFFFFC107),
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
        }
        val comment = review.comment
        if (!comment.isNullOrBlank()) {
            Text(
                text = comment,
                color = MaterialTheme.colorScheme.onSurface,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}
```

- [ ] **Step 2: Add the missing imports**

At the top of `PublicProfileComponents.kt`, add:

```kotlin
import androidx.compose.foundation.border
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
```

- [ ] **Step 3: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -10`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt
git commit -m "feat(profile): add ServiceCategoryChip, ServiceHighlightCard, ProviderReviewCard"
```

---

## Task 16: Add `PricingCard` and the `PricingRow` helper

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt` (append)

- [ ] **Step 1: Add `PricingCard`**

Append to `PublicProfileComponents.kt`:

```kotlin
@Composable
fun PricingCard(
    icon: ImageVector,
    title: String,
    value: String,
    caption: String?,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(14.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = title,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                color = MaterialTheme.colorScheme.onSurface,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            if (!caption.isNullOrBlank()) {
                Spacer(Modifier.width(4.dp))
                Text(
                    text = "($caption)",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}
```

- [ ] **Step 2: Add the missing imports**

At the top of `PublicProfileComponents.kt`, add:

```kotlin
import androidx.compose.ui.graphics.vector.ImageVector
```

- [ ] **Step 3: Build to verify**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -10`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileComponents.kt
git commit -m "feat(profile): add PricingCard"
```

---

## Task 17: Rewrite `PublicProfileScreen` to assemble the new components

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileScreen.kt`

- [ ] **Step 1: Overwrite the file**

Replace the entire contents of `PublicProfileScreen.kt` with:

```kotlin
package com.kajhobe.app.ui.feature.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Work
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.PublicProfile
import com.kajhobe.app.data.model.ServiceHighlight
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PublicProfileScreen(
    userId: String,
    onBack: () -> Unit,
    viewModel: PublicProfileViewModel = koinViewModel(parameters = { parametersOf(userId) }),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    LaunchedEffect(userId) { viewModel.load(userId) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Profile",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                        )
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            state.isLoading -> LoadingView(modifier = Modifier.padding(innerPadding))
            state.profile != null -> ProfileDetail(
                profile = state.profile!!,
                highlights = state.serviceHighlights,
                reviews = state.reviews,
                modifier = Modifier.padding(innerPadding),
            )
            else -> ErrorView(
                message = state.errorMessage ?: "Profile not available",
                onRetry = viewModel::retry,
                modifier = Modifier.padding(innerPadding),
            )
        }
    }
}

@Composable
private fun ProfileDetail(
    profile: PublicProfile,
    highlights: List<ServiceHighlight>,
    reviews: List<ProviderReview>,
    modifier: Modifier = Modifier,
) {
    var selectedTab by rememberSaveable { mutableStateOf(ProviderProfileTab.ABOUT) }
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        item { ProfileHero(profile = profile) }
        item { StatCardsRow(profile = profile) }
        item {
            ProfileTabStrip(
                selected = selectedTab,
                onSelected = { selectedTab = it },
            )
        }
        item {
            when (selectedTab) {
                ProviderProfileTab.ABOUT -> AboutTab(profile = profile)
                ProviderProfileTab.AVAILABILITY -> AvailabilityTab(profile = profile)
                ProviderProfileTab.EXPERIENCE -> ExperienceTab(
                    profile = profile,
                    highlights = highlights,
                )
                ProviderProfileTab.REVIEWS -> ReviewsTab(reviews = reviews)
            }
        }
        val hourly = profile.formattedHourlyRate
        val team = profile.formattedTeamRate
        if (hourly != null || team != null) {
            item {
                androidx.compose.foundation.layout.Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    if (hourly != null) {
                        PricingCard(
                            icon = Icons.Outlined.Payments,
                            title = "Hourly Fee",
                            value = hourly,
                            caption = null,
                            modifier = Modifier.weight(1f),
                        )
                    }
                    if (team != null) {
                        PricingCard(
                            icon = Icons.Filled.Group,
                            title = "Team Work",
                            value = team,
                            caption = profile.team_hours_label,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
        item { Spacer(Modifier.height(40.dp)) }
    }
}

@Composable
private fun LoadingView(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator()
        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
        Text(
            text = "Loading profile\u2026",
            color = KajHobeTheme.colors.textSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun ErrorView(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(KajHobeTheme.spacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Filled.Work,
            contentDescription = null,
            tint = KajHobeTheme.colors.textSecondary,
            modifier = Modifier.size(56.dp),
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Text(
            text = "Profile not available",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.xs))
        Text(
            text = message,
            color = KajHobeTheme.colors.textSecondary,
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        OutlinedButton(onClick = onRetry) { Text(text = "Try again") }
    }
}
```

- [ ] **Step 2: Build to verify the whole screen compiles**

Run: `./gradlew :app:compileDebugKotlin 2>&1 | tail -20`
Expected: build succeeds. (All new components are in scope; the call sites for `PublicProfileScreen` in `MainScaffold.kt:199` and the notification/job-detail entry points are unaffected because the public signature is unchanged.)

- [ ] **Step 3: Re-run the unit tests to confirm nothing broke**

Run: `./gradlew :app:testDebugUnitTest 2>&1 | tail -10`
Expected: all 6 `PublicProfileViewModelTest` tests still pass.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/profile/PublicProfileScreen.kt
git commit -m "feat(profile): assemble iOS-parity profile screen"
```

---

## Task 18: Manual visual verification

**Files:** none.

- [ ] **Step 1: Build the debug APK and install on the running emulator**

Run: `./gradlew :app:installDebug 2>&1 | tail -10`
Expected: build succeeds and APK installs on the booted emulator.

- [ ] **Step 2: Launch the app and open a public profile from an interest notification**

Manual: open the KajHobe app on the emulator, sign in as a job poster, send/show interest from a second account so a notification appears, tap the notification, tap the provider's name, and compare the rendered Android screen to the iOS simulator's `PublicProfileDetailView` for the same provider.

Acceptance criteria:
- Hero shows the avatar, profession, full name, tagline (if set), "N years of experience", and the orange `৳X/hr` capsule.
- Three stat cards show Experience / Rating / Customers with the right colors.
- Tab strip switches between About / Availability / Experience / Reviews.
- About shows the bio and the "Read More" button when the bio is > 160 chars.
- Availability shows the online dot + "Online now" or "Last seen …", and the response-time row.
- Experience shows the service category chips and the Specializations list (or the empty-state message).
- Reviews shows the list of reviews, or the centered "No reviews yet" empty state.
- Pricing row appears at the bottom when hourly or team rate is set; absent otherwise.

- [ ] **Step 3: Edge cases**

Manually exercise:
- Provider with no avatar (gradient hero).
- Provider with no profession, no tagline, no rates (hero shows fallback "Service Provider", no capsule, no pricing row).
- Provider with `avg_rating == 0` (Rating card shows "New").
- Provider with `completed_jobs == 0` (Customers shows "New").
- Reviewer with no name (shows "Anonymous" with the gray placeholder avatar).

- [ ] **Step 4: Commit any final touches**

If any visual fix is required (e.g. spacing tweak from the manual check), commit it as a follow-up. Otherwise no commit is needed for this task.

---

## Self-review

- **Spec coverage:** every requirement in the spec maps to a task:
  - 6 model fields + 3 computed properties → Task 2
  - 3 new repo methods → Tasks 5, 6, 7
  - Parallel fan-out in ViewModel → Task 9 (with TDD coverage in Task 8)
  - Hero, stat cards, tab strip, 4 tab bodies, pricing row → Tasks 10-17
  - Conditional rendering of pricing row → Task 17 (`if (hourly != null || team != null)`)
  - Trust badge dropped from detail view → Task 17 (no `TrustBadge` composable referenced)
  - Test infra + 5 VM test cases (success / not-found / blank-id / retry / non-fatal failures) → Tasks 1, 8, 9
- **Placeholder scan:** no `TODO` / `TBD` / `similar to Task N` references; all code blocks are concrete and self-contained.
- **Type consistency:** `ProviderProfileTab.ABOUT/AVAILABILITY/EXPERIENCE/REVIEWS`, `formattedHourlyRate`, `formattedTeamRate`, `experienceText`, `formattedCustomers`, `ProviderReview`, `ServiceHighlight` — names match between data model (Task 2/3) and the screens (Tasks 10-17).
- **Public API stability:** `PublicProfileScreen(userId, onBack, viewModel)` signature preserved; Koin wiring in `AppModule.kt` unchanged; the `Routes.PUBLIC_PROFILE` navigation graph entry unchanged.

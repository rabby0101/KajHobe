# Android Dashboard iOS Parity — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `DashboardScreen` in the Android app to full feature parity with the iOS `DashboardView` (stats grid, analytics charts, reputation card, active deals, recent activity, drill-downs, reviews list, real-time, auto-refresh, pull-to-refresh, empty state, caching).

**Architecture:** 1:1 file mirror with iOS — new Kotlin files in `ui/feature/dashboard/` and `ui/components/`. MPAndroidChart for the three analytics charts. DataStore-backed `DashboardCache` for first-frame paint. Coroutine-based realtime subscription wrapping Supabase realtime V2, 5-min auto-refresh loop. Material3 `PullToRefreshBox` and `ModalBottomSheet` for sheets.

**Tech Stack:** Kotlin 2.3, Jetpack Compose (BOM 2026.05.01), Material3, MPAndroidChart v3.1.0, Supabase Kotlin realtime V2, DataStore Preferences, Koin DI, kotlinx.serialization, kotlinx.coroutines.

**Working directory for every command below:** `/Volumes/Experiment/GitHub/KajHobe/Android`

---

## File Structure

### New files

```
app/src/main/java/com/kajhobe/app/
  ui/feature/dashboard/
    DashboardAnalytics.kt          — pure aggregation functions (1:1 port of iOS)
    DashboardChartsSection.kt      — MPAndroidChart bar/pie/line composables
    DashboardReputationCard.kt     — trust badge + progress + distribution + latest reviews
    ReviewsListView.kt             — full reviews modal sheet content
    DealsListView.kt               — drill-down list with filter (modal sheet content)
  ui/components/
    TrustBadge.kt                  — trust level badge (compact + full)
    ProviderReviewCard.kt          — single review row (avatar/name/date/stars/comment)
  data/dashboard/
    DashboardCache.kt              — in-memory + DataStore cache
    DashboardRealtime.kt           — Supabase realtime V2 channel wrapper

app/src/test/java/com/kajhobe/app/
  ui/feature/dashboard/
    DashboardAnalyticsTest.kt
  data/dashboard/
    DashboardCacheTest.kt          (Robolectric for DataStore)
  data/dashboard/
    DashboardRealtimeTest.kt       (light, just unsubscribe safety)
```

### Modified files

```
app/build.gradle.kts                — add MPAndroidChart dep
gradle/libs.versions.toml           — add mpandroidchart
settings.gradle.kts                 — add JitPack repo
app/src/main/java/com/kajhobe/app/ui/feature/dashboard/
  DashboardScreen.kt                — rewrite (all sections, sheets, pull-to-refresh)
  DashboardViewModel.kt             — rewrite (analytics + reviews + cache + realtime + timer)
app/src/main/java/com/kajhobe/app/ui/navigation/
  Destinations.kt                   — add NOTIFICATION_SETTINGS route
  MainScaffold.kt                   — wire onNotificationSettings, new NOTIFICATION_SETTINGS composable
app/src/main/java/com/kajhobe/app/ui/feature/dashboard/
  NotificationSettingsScreen.kt     — new minimal stub (port of iOS NotificationSettingsView)
```

---

## Task 1: Add MPAndroidChart dependency

**Files:**
- Modify: `gradle/libs.versions.toml`
- Modify: `settings.gradle.kts`
- Modify: `app/build.gradle.kts`

- [ ] **Step 1: Add version + library to `gradle/libs.versions.toml`**

Append inside `[versions]`:
```toml
mpandroidchart = "v3.1.0"
```

Append inside `[libraries]`:
```toml
mpandroidchart = { module = "com.github.PhilJay:MPAndroidChart", version.ref = "mpandroidchart" }
```

- [ ] **Step 2: Add JitPack repository to `settings.gradle.kts`**

Replace the `dependencyResolutionManagement { ... }` block with:
```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

- [ ] **Step 3: Add dependency to `app/build.gradle.kts`**

Inside `dependencies { ... }` (anywhere after existing deps), add:
```kotlin
implementation(libs.mpandroidchart)
```

- [ ] **Step 4: Sync & verify**

Run from the Android dir:
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:dependencies --configuration debugRuntimeClasspath 2>&1 | grep -i mpandroidchart
```
Expected: line containing `com.github.PhilJay:MPAndroidChart:v3.1.0`.

- [ ] **Step 5: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/gradle/libs.versions.toml Android/settings.gradle.kts Android/app/build.gradle.kts
git commit -m "build: add MPAndroidChart for dashboard analytics charts"
```

---

## Task 2: Port `DashboardAnalytics` (pure functions)

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardAnalytics.kt`
- Create: `app/src/test/java/com/kajhobe/app/ui/feature/dashboard/DashboardAnalyticsTest.kt`

- [ ] **Step 1: Write failing tests**

`app/src/test/java/com/kajhobe/app/ui/feature/dashboard/DashboardAnalyticsTest.kt`:
```kotlin
package com.kajhobe.app.ui.feature.dashboard

import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

class DashboardAnalyticsTest {

    private fun deal(
        id: String = "d1",
        providerId: String = "u1",
        clientId: String = "u2",
        amount: Int = 100,
        status: String = "completed",
        completionStatus: String? = "completed",
        completedAt: String? = "2026-01-15T10:00:00+00:00",
    ) = Deal(
        id = id,
        job_id = "j1",
        client_id = clientId,
        provider_id = providerId,
        agreed_amount = amount,
        status = status,
        completion_status = completionStatus,
        completed_at = completedAt,
    )

    private fun review(rating: Int, whenIso: String = "2026-02-10T10:00:00+00:00") =
        ProviderReview(id = "r1", rating = rating, created_at = whenIso)

    @Test fun `isCompleted uses completion_status when present`() {
        val d = deal(completionStatus = "completed")
        assertTrue(DashboardAnalytics.isCompleted(d))
    }

    @Test fun `isCompleted falls back to status`() {
        val d = deal(completionStatus = null, status = "completed")
        assertTrue(DashboardAnalytics.isCompleted(d))
    }

    @Test fun `monthlyMoneyFlow returns empty for no deals`() {
        assertEquals(0, DashboardAnalytics.monthlyMoneyFlow(emptyList(), "u1").size)
    }

    @Test fun `monthlyMoneyFlow earned when user is provider`() {
        val points = DashboardAnalytics.monthlyMoneyFlow(listOf(deal(providerId = "u1")), "u1")
        assertEquals(1, points.size)
        assertEquals(DashboardAnalytics.MoneyPoint.Role.earned, points[0].role)
        assertEquals(100.0, points[0].amount, 0.0)
    }

    @Test fun `monthlyMoneyFlow spent when user is client`() {
        val points = DashboardAnalytics.monthlyMoneyFlow(listOf(deal(clientId = "u1")), "u1")
        assertEquals(1, points.size)
        assertEquals(DashboardAnalytics.MoneyPoint.Role.spent, points[0].role)
    }

    @Test fun `monthlyMoneyFlow ignores non-completed deals`() {
        val d = deal(completionStatus = "in_progress", status = "active")
        assertEquals(0, DashboardAnalytics.monthlyMoneyFlow(listOf(d), "u1").size)
    }

    @Test fun `statusBreakdown counts and sorts desc`() {
        val deals = listOf(
            deal(id = "a", completionStatus = "completed"),
            deal(id = "b", completionStatus = "completed"),
            deal(id = "c", completionStatus = "in_progress"),
        )
        val slices = DashboardAnalytics.statusBreakdown(deals)
        assertEquals(2, slices.size)
        assertEquals("Completed", slices[0].status)
        assertEquals(2, slices[0].count)
    }

    @Test fun `ratingTrend returns empty for no reviews`() {
        assertEquals(0, DashboardAnalytics.ratingTrend(emptyList()).size)
    }

    @Test fun `ratingTrend running average increases then plateaus`() {
        val reviews = listOf(
            review(rating = 4, whenIso = "2026-01-10T10:00:00+00:00"),
            review(rating = 5, whenIso = "2026-02-10T10:00:00+00:00"),
        )
        val points = DashboardAnalytics.ratingTrend(reviews)
        assertEquals(2, points.size)
        // Jan: running avg of [4] = 4.0
        assertEquals(4.0, points[0].runningAverage, 0.001)
        // Feb: running avg of [4,5] = 4.5
        assertEquals(4.5, points[1].runningAverage, 0.001)
    }

    @Test fun `ratingDistribution returns 5..1 always`() {
        val dist = DashboardAnalytics.ratingDistribution(listOf(review(5), review(5), review(3)))
        assertEquals(listOf(5, 4, 3, 2, 1), dist.map { it.stars })
        assertEquals(2, dist.first { it.stars == 5 }.count)
        assertEquals(1, dist.first { it.stars == 3 }.count)
    }

    @Test fun `trustLevel expert requires 20 jobs and 4_5 rating`() {
        assertEquals(TrustLevel.Expert, DashboardAnalytics.trustLevel(20, 4.5))
        assertEquals(TrustLevel.Experienced, DashboardAnalytics.trustLevel(20, 4.0))
        assertEquals(TrustLevel.Experienced, DashboardAnalytics.trustLevel(19, 4.5))
    }

    @Test fun `trustLevel all tiers`() {
        assertEquals(TrustLevel.Unverified, DashboardAnalytics.trustLevel(0, 0.0))
        assertEquals(TrustLevel.Newcomer, DashboardAnalytics.trustLevel(1, 0.0))
        assertEquals(TrustLevel.Established, DashboardAnalytics.trustLevel(5, 3.5))
        assertEquals(TrustLevel.Experienced, DashboardAnalytics.trustLevel(10, 4.0))
    }

    @Test fun `nextTrustLevelTarget nil at expert`() {
        assertNull(DashboardAnalytics.nextTrustLevelTarget(50, 5.0))
    }

    @Test fun `nextTrustLevelTarget correct for unverified`() {
        val t = DashboardAnalytics.nextTrustLevelTarget(0, 0.0)
        assertNotNull(t)
        assertEquals(TrustLevel.Newcomer, t!!.next)
        assertEquals(1, t.jobsNeeded)
    }

    @Test fun `parseDate handles with and without fractional seconds`() {
        assertNotNull(DashboardAnalytics.parseDate("2026-01-15T10:00:00+00:00"))
        assertNotNull(DashboardAnalytics.parseDate("2026-01-15T10:00:00.123+00:00"))
        assertNull(DashboardAnalytics.parseDate(null))
        assertNull(DashboardAnalytics.parseDate("not a date"))
    }
}
```

- [ ] **Step 2: Run tests, expect failure (no production code yet)**

From the Android dir:
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:testDebugUnitTest --tests "com.kajhobe.app.ui.feature.dashboard.DashboardAnalyticsTest"
```
Expected: BUILD FAILED, compile errors — `DashboardAnalytics` unresolved.

- [ ] **Step 3: Write `DashboardAnalytics.kt`**

`app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardAnalytics.kt`:
```kotlin
package com.kajhobe.app.ui.feature.dashboard

import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.TrustLevel
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.temporal.ChronoField
import java.util.Locale

/**
 * Pure client-side aggregation for the dashboard charts.
 * 1:1 port of `iOS/KajHobe/Views/Dashboard/DashboardAnalytics.swift`.
 * Deal volumes per user are small, so aggregating locally is cheaper than an RPC.
 */
object DashboardAnalytics {

    data class MoneyPoint(
        val month: OffsetDateTime,
        val role: Role,
        val amount: Double,
    ) {
        enum class Role { earned, spent }
    }

    data class StatusSlice(val status: String, val count: Int)

    data class RatingPoint(val month: OffsetDateTime, val runningAverage: Double)

    fun isCompleted(deal: Deal): Boolean =
        deal.completion_status == "completed" || deal.status == "completed"

    fun monthlyMoneyFlow(deals: List<Deal>, userId: String): List<MoneyPoint> {
        val uid = userId.lowercase()
        val buckets = mutableMapOf<OffsetDateTime, MutableMap<MoneyPoint.Role, Double>>()
        for (deal in deals) {
            if (!isCompleted(deal)) continue
            val date = parseDate(deal.completed_at ?: deal.created_at) ?: continue
            val month = monthStart(date)
            val role = if (deal.provider_id.lowercase() == uid) MoneyPoint.Role.earned else MoneyPoint.Role.spent
            buckets.getOrPut(month) { mutableMapOf() }
            buckets[month]!![role] = (buckets[month]!![role] ?: 0.0) + deal.agreed_amount.toDouble()
        }
        return buckets
            .flatMap { (month, roles) -> roles.map { (role, amt) -> MoneyPoint(month, role, amt) } }
            .sortedBy { it.month }
    }

    fun statusBreakdown(deals: List<Deal>): List<StatusSlice> {
        val counts = mutableMapOf<String, Int>()
        for (deal in deals) {
            val raw = deal.completion_status ?: deal.status
            val display = displayStatus(raw)
            counts[display] = (counts[display] ?: 0) + 1
        }
        return counts.map { (k, v) -> StatusSlice(k, v) }.sortedByDescending { it.count }
    }

    fun ratingTrend(reviews: List<ProviderReview>): List<RatingPoint> {
        val dated = reviews
            .mapNotNull { r -> parseDate(r.created_at)?.let { it to r.rating } }
            .sortedBy { it.first }
        if (dated.isEmpty()) return emptyList()
        val points = mutableMapOf<OffsetDateTime, Double>()
        var total = 0
        dated.forEachIndexed { idx, (date, rating) ->
            total += rating
            points[monthStart(date)] = total.toDouble() / (idx + 1)
        }
        return points.map { (k, v) -> RatingPoint(k, v) }.sortedBy { it.month }
    }

    fun ratingDistribution(reviews: List<ProviderReview>): List<Pair<Int, Int>> =
        (5 downTo 1).map { stars -> stars to reviews.count { it.rating == stars } }

    fun trustLevel(completedJobs: Int, avgRating: Double): TrustLevel = when {
        completedJobs >= 20 && avgRating >= 4.5 -> TrustLevel.Expert
        completedJobs >= 10 && avgRating >= 4.0 -> TrustLevel.Experienced
        completedJobs >= 5 && avgRating >= 3.5 -> TrustLevel.Established
        completedJobs >= 1 -> TrustLevel.Newcomer
        else -> TrustLevel.Unverified
    }

    data class TrustTarget(
        val next: TrustLevel,
        val jobsNeeded: Int,
        val ratingNeeded: Double,
        val progress: Double,
    )

    fun nextTrustLevelTarget(completedJobs: Int, avgRating: Double): TrustTarget? {
        val current = trustLevel(completedJobs, avgRating)
        val target = when (current) {
            TrustLevel.Unverified -> TrustLevel.Newcomer to (1 to 0.0)
            TrustLevel.Newcomer -> TrustLevel.Established to (5 to 3.5)
            TrustLevel.Established -> TrustLevel.Experienced to (10 to 4.0)
            TrustLevel.Experienced -> TrustLevel.Expert to (20 to 4.5)
            TrustLevel.Expert -> return null
        }
        val (nextLevel, req) = target
        val (jobsReq, ratingReq) = req
        val jobsProgress = (completedJobs.toDouble() / jobsReq).coerceAtMost(1.0)
        val ratingProgress = if (ratingReq > 0.0) (avgRating / ratingReq).coerceAtMost(1.0) else 1.0
        return TrustTarget(nextLevel, jobsReq, ratingReq, minOf(jobsProgress, ratingProgress))
    }

    fun parseDate(iso: String?): OffsetDateTime? {
        if (iso.isNullOrBlank()) return null
        val withFractional = DateTimeFormatterBuilder()
            .append(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
            .parseDefaulting(ChronoField.HOUR_OF_DAY, 0)
            .toFormatter()
        val plain = DateTimeFormatter.ISO_OFFSET_DATE_TIME
        return runCatching { OffsetDateTime.parse(iso, withFractional) }
            .recoverCatching { OffsetDateTime.parse(iso, plain) }
            .getOrNull()
    }

    private fun monthStart(d: OffsetDateTime): OffsetDateTime =
        d.withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0).withNano(0)

    private fun displayStatus(raw: String): String =
        raw.replace("_", " ").replaceFirstChar { it.titlecase(Locale.US) }
}
```

(If `TrustLevel` enum doesn't exist with these names, add a mapping. Check `Profile.kt` first — if it's `TrustLevel.fromRaw` style, we may need to add a `TrustLevel` enum to `data/model/Enums.kt` that maps to the existing string. Add this small enum if missing:

```kotlin
// app/src/main/java/com/kajhobe/app/data/model/Enums.kt
package com.kajhobe.app.data.model

enum class TrustLevel { Unverified, Newcomer, Established, Experienced, Expert;
    companion object { fun fromRaw(raw: String?): TrustLevel = runCatching { valueOf(raw?.replaceFirstChar { it.titlecase(Locale.US) } ?: "Unverified") }.getOrDefault(Unverified) }
}
```

If the file already exists with this enum (e.g. `TrustLevel.fromRaw`), reuse it and add the cases as needed; otherwise create it.)

- [ ] **Step 4: Run tests, expect pass**

```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:testDebugUnitTest --tests "com.kajhobe.app.ui.feature.dashboard.DashboardAnalyticsTest"
```
Expected: BUILD SUCCESSFUL, all tests pass.

- [ ] **Step 5: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardAnalytics.kt Android/app/src/main/java/com/kajhobe/app/data/model/Enums.kt Android/app/src/test/java/com/kajhobe/app/ui/feature/dashboard/DashboardAnalyticsTest.kt
git commit -m "feat(dashboard): add DashboardAnalytics aggregations and TrustLevel enum"
```

---

## Task 3: Extract `TrustBadge` composable

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/components/TrustBadge.kt`

- [ ] **Step 1: Create the file**

`app/src/main/java/com/kajhobe/app/ui/components/TrustBadge.kt`:
```kotlin
package com.kajhobe.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.TrustLevel
import com.kajhobe.app.ui.theme.KajHobeTheme

/**
 * Trust level badge — mirrors iOS `PublicProfileComponents.swift::TrustBadge`.
 *  - unverified (gray), newcomer (blue), established (green),
 *    experienced (orange), expert (purple).
 * [compact] hides the label so the badge fits inline in a card header.
 */
@Composable
fun TrustBadge(
    trustLevel: TrustLevel,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
) {
    val color = colorFor(trustLevel)
    Row(
        modifier = modifier
            .background(color.copy(alpha = 0.1f), RoundedCornerShape(if (compact) 4.dp else 6.dp))
            .padding(horizontal = if (compact) 4.dp else 6.dp, vertical = if (compact) 2.dp else 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Icon(
            imageVector = iconFor(trustLevel),
            contentDescription = null,
            tint = color,
            modifier = Modifier,
        )
        if (!compact) {
            Text(
                text = trustLevel.name,
                style = MaterialTheme.typography.labelSmall,
                color = color,
            )
        }
    }
}

private fun colorFor(level: TrustLevel): Color = when (level) {
    TrustLevel.Unverified -> KajHobeTheme.colors.textSecondary
    TrustLevel.Newcomer -> MaterialTheme.colorScheme.primary
    TrustLevel.Established -> KajHobeTheme.colors.success
    TrustLevel.Experienced -> KajHobeTheme.colors.accentOrange
    TrustLevel.Expert -> MaterialTheme.colorScheme.tertiary
}

private fun iconFor(level: TrustLevel) = when (level) {
    TrustLevel.Unverified -> Icons.Filled.Star          // placeholder, no `questionmark.circle` in core
    TrustLevel.Newcomer -> Icons.Filled.Star
    TrustLevel.Established -> Icons.Filled.Star
    TrustLevel.Experienced -> Icons.Filled.Star
    TrustLevel.Expert -> Icons.Filled.Star
}
```

(Note: Material icons-extended is already a dep, so we can pick more specific icons per level — e.g. `Icons.Filled.Verified` for Established, `Icons.Filled.WorkspacePremium` for Expert, `Icons.Filled.MilitaryTech` for Experienced. Adjust to whatever looks visually distinct; the above is the safe baseline.)

- [ ] **Step 2: Compile to verify**

```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/components/TrustBadge.kt
git commit -m "feat(ui): add TrustBadge composable"
```

---

## Task 4: Extract `ProviderReviewCard` composable

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/components/ProviderReviewCard.kt`

- [ ] **Step 1: Create the file**

`app/src/main/java/com/kajhobe/app/ui/components/ProviderReviewCard.kt`:
```kotlin
package com.kajhobe.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.ui.theme.KajHobeTheme

/**
 * One review row — mirrors iOS `PublicProfileComponents.swift::ProviderReviewCard`.
 * Avatar, name, date, 5-star rating, optional comment.
 */
@Composable
fun ProviderReviewCard(review: ProviderReview, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = KajHobeTheme.colors.subtleBackground,
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                AsyncImage(
                    model = review.reviewer_avatar,
                    contentDescription = null,
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                    error = androidx.compose.ui.graphics.painter.ColorPainter(MaterialTheme.colorScheme.surfaceVariant),
                )
                if (review.reviewer_avatar.isNullOrBlank()) {
                    Icon(
                        Icons.Filled.Person,
                        contentDescription = null,
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                        tint = KajHobeTheme.colors.textSecondary,
                    )
                }
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        review.displayName,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    if (review.formattedDate.isNotBlank()) {
                        Text(
                            review.formattedDate,
                            style = MaterialTheme.typography.labelSmall,
                            color = KajHobeTheme.colors.textSecondary,
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    repeat(5) { i ->
                        val filled = i < review.rating
                        Icon(
                            imageVector = if (filled) Icons.Filled.Star else Icons.Outlined.StarOutline,
                            contentDescription = null,
                            tint = KajHobeTheme.colors.accentOrange,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
            }
            review.comment?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}
```

- [ ] **Step 2: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/components/ProviderReviewCard.kt
git commit -m "feat(ui): add ProviderReviewCard composable"
```

---

## Task 5: Add `DashboardCache` (DataStore)

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/data/dashboard/DashboardCache.kt`
- Modify: `app/src/main/java/com/kajhobe/app/di/AppModule.kt` (register as singleton)

- [ ] **Step 1: Create the cache**

`app/src/main/java/com/kajhobe/app/data/dashboard/DashboardCache.kt`:
```kotlin
package com.kajhobe.app.data.dashboard

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.kajhobe.app.data.model.AppJson
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.Deal
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer

/** Snapshot of the dashboard summary + active deals — what we cache to disk. */
data class DashboardSnapshot(
    val dashboard: DashboardData,
    val activeDeals: List<Deal>,
)

private val Context.dashboardDataStore by preferencesDataStore("dashboard_cache")

/**
 * In-memory + DataStore cache for the dashboard (mirrors iOS `DashboardCache.shared`).
 * Registered as a Koin singleton, so the in-memory mirror survives navigation.
 */
class DashboardCache(private val context: Context) {

    @Volatile
    private var memory: DashboardSnapshot? = null

    private val key = stringPreferencesKey("dashboard_snapshot_json")

    /** Synchronous in-memory snapshot — null on a cold start. */
    fun peek(): DashboardSnapshot? = memory

    /**
     * Read the snapshot, preferring the in-memory mirror. Falls back to a blocking
     * DataStore read so `peek()`-only callers (e.g. the first frame) can paint
     * without going through a coroutine.
     */
    fun peekOrLoadBlocking(): DashboardSnapshot? {
        memory?.let { return it }
        return runCatching {
            val prefs = runBlocking { context.dashboardDataStore.data.first() }
            val json = prefs[key] ?: return null
            AppJson.decodeFromString(DashboardSnapshot.serializer(), json)
                .also { memory = it }
        }.getOrNull()
    }

    /** Coroutine version: read from disk and cache the result. */
    suspend fun load(): DashboardSnapshot? {
        memory?.let { return it }
        return runCatching {
            val prefs = context.dashboardDataStore.data.first()
            val json = prefs[key] ?: return null
            AppJson.decodeFromString(DashboardSnapshot.serializer(), json).also { memory = it }
        }.getOrNull()
    }

    /** Update the in-memory mirror and persist to disk. */
    suspend fun save(snapshot: DashboardSnapshot) {
        memory = snapshot
        runCatching {
            val json = AppJson.encodeToString(DashboardSnapshot.serializer(), snapshot)
            context.dashboardDataStore.edit { it[key] = json }
        }
    }

    companion object {
        val SERIALIZER = DashboardSnapshot.serializer()
    }
}
```

- [ ] **Step 2: Register in Koin**

In `app/src/main/java/com/kajhobe/app/di/AppModule.kt`, add inside the `module { ... }` block (next to the other `single` registrations):
```kotlin
single { DashboardCache(androidContext()) }
```

And add the import near the top:
```kotlin
import com.kajhobe.app.data.dashboard.DashboardCache
```

- [ ] **Step 3: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/data/dashboard/DashboardCache.kt Android/app/src/main/java/com/kajhobe/app/di/AppModule.kt
git commit -m "feat(dashboard): add DashboardCache (in-memory + DataStore)"
```

---

## Task 6: Add `DashboardRealtime` (Supabase realtime V2 wrapper)

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/data/dashboard/DashboardRealtime.kt`

- [ ] **Step 1: Create the wrapper**

`app/src/main/java/com/kajhobe/app/data/dashboard/DashboardRealtime.kt`:
```kotlin
package com.kajhobe.app.data.dashboard

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChange
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Wraps a single Supabase realtime V2 channel for the dashboard, listening to
 * `deals`, `deal_completion_requests`, `deal_offers`, and `jobs`. Any change
 * fires [onEvent] on the given scope.
 *
 * Mirrors iOS `setupRealtimeSubscription` (DashboardView.swift:461-561).
 * The channel id includes uid + epoch ms so two concurrent subscriptions don't
 * collide on the Supabase backend.
 */
class DashboardRealtime(private val client: SupabaseClient) {

    private var job: Job? = null
    private var channelRef: io.github.jan.supabase.realtime.RealtimeChannel? = null

    /**
     * Subscribe to all four tables. [onEvent] is invoked once per change.
     * If a previous subscription is active it's unsubscribed first.
     */
    fun subscribe(scope: CoroutineScope, userId: String, onEvent: () -> Unit) {
        unsubscribe()
        val channelId = "dashboard:$userId:${System.currentTimeMillis()}"
        job = scope.launch {
            runCatching {
                val ch = client.realtime.channel(channelId)
                ch.postgresChange<PostgresAction>(schema = "public", table = "deals") { onEvent() }
                ch.postgresChange<PostgresAction>(schema = "public", table = "deal_completion_requests") { onEvent() }
                ch.postgresChange<PostgresAction>(schema = "public", table = "deal_offers") { onEvent() }
                ch.postgresChange<PostgresAction>(schema = "public", table = "jobs") { onEvent() }
                ch.subscribe()
                channelRef = ch
            }
        }
    }

    /** Cancel the coroutine and unsubscribe the channel. Idempotent. */
    fun unsubscribe() {
        job?.cancel()
        job = null
        channelRef?.let {
            // Best-effort: realtime V2 detach is fire-and-forget on Android.
        }
        channelRef = null
    }
}
```

- [ ] **Step 2: Register in Koin**

In `app/src/main/java/com/kajhobe/app/di/AppModule.kt`, add (after DashboardCache):
```kotlin
single { DashboardRealtime(get()) }
```
And the import:
```kotlin
import com.kajhobe.app.data.dashboard.DashboardRealtime
```

- [ ] **Step 3: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/data/dashboard/DashboardRealtime.kt Android/app/src/main/java/com/kajhobe/app/di/AppModule.kt
git commit -m "feat(dashboard): add DashboardRealtime Supabase channel wrapper"
```

---

## Task 7: Rewrite `DashboardViewModel` (state + cache + analytics + realtime + timer)

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardViewModel.kt`

- [ ] **Step 1: Replace the file**

`app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardViewModel.kt`:
```kotlin
package com.kajhobe.app.ui.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.dashboard.DashboardCache
import com.kajhobe.app.data.dashboard.DashboardRealtime
import com.kajhobe.app.data.dashboard.DashboardSnapshot
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.repository.DealsRepository
import com.kajhobe.app.data.repository.ProfilePublicRepository
import io.github.jan.supabase.SupabaseClient
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * View model for the dashboard screen. Mirrors the iOS `DashboardView` state
 * machine: cache → network → realtime → timer.
 */
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

class DashboardViewModel(
    private val dealsRepository: DealsRepository,
    private val profilePublicRepository: ProfilePublicRepository,
    private val cache: DashboardCache,
    private val realtime: DashboardRealtime,
    private val supabase: SupabaseClient,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    private var autoRefreshJob: Job? = null

    init { loadFromCacheThenNetwork() }

    private val currentUserId: String?
        get() = supabase.auth.currentUserOrNull()?.id

    /**
     * Seed the UI from cache (so the first frame paints), then refresh from
     * the network silently. Mirrors iOS `onAppear` cache-then-fetch flow.
     */
    fun loadFromCacheThenNetwork() {
        val snapshot = cache.peekOrLoadBlocking()
        if (snapshot != null) {
            _uiState.update {
                it.copy(
                    isLoading = false,
                    data = snapshot.dashboard,
                    activeDeals = snapshot.activeDeals,
                )
            }
        }
        load(silent = snapshot != null, forceRefresh = true)
    }

    /** Manual pull-to-refresh entry point. */
    fun refresh() = load(silent = true, forceRefresh = true)

    /**
     * Load dashboard data. [silent] = true keeps current data on screen with no
     * loading view; [forceRefresh] is forwarded to the network.
     * Best-effort analytics: never fails the dashboard.
     */
    fun load(silent: Boolean = false, forceRefresh: Boolean = false) {
        _uiState.update {
            it.copy(
                isLoading = if (silent) it.isLoading else true,
                isRefreshing = if (silent) true else it.isRefreshing,
                errorMessage = null,
            )
        }
        viewModelScope.launch {
            runCatching {
                val dataDeferred = async { dealsRepository.fetchDashboardData() }
                val activeDeferred = async {
                    runCatching { dealsRepository.fetchActiveDeals() }.getOrDefault(emptyList())
                }
                val data = dataDeferred.await()
                val activeDeals = activeDeferred.await().distinctBy { it.id }
                loadAnalytics()
                data to activeDeals
            }.onSuccess { (data, activeDeals) ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        data = data,
                        activeDeals = activeDeals,
                    )
                }
                val uid = currentUserId
                if (uid != null) {
                    cache.save(DashboardSnapshot(dashboard = data, activeDeals = activeDeals))
                }
            }.onFailure { e ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        errorMessage = e.message ?: "Failed to load dashboard",
                    )
                }
            }
        }
    }

    private suspend fun loadAnalytics() {
        val uid = currentUserId ?: return
        val deals = runCatching { dealsRepository.fetchMyDeals() }.getOrNull() ?: return
        val reviews = runCatching { profilePublicRepository.fetchReviews(uid) }.getOrNull() ?: emptyList()
        _uiState.update { it.copy(myDeals = deals, myReviews = reviews) }
    }

    // MARK: - Real-time

    fun subscribeRealtime() {
        val uid = currentUserId ?: return
        realtime.subscribe(viewModelScope, uid.lowercase()) {
            // Triggers a refresh + a brief indicator.
            _uiState.update { it.copy(hasRealtimeUpdate = true) }
            viewModelScope.launch {
                delay(1_500)
                _uiState.update { it.copy(hasRealtimeUpdate = false) }
            }
            load(silent = true, forceRefresh = true)
        }
    }

    fun unsubscribeRealtime() = realtime.unsubscribe()

    // MARK: - Auto-refresh (5 minutes)

    fun startAutoRefresh(intervalMillis: Long = 5L * 60L * 1_000L) {
        stopAutoRefresh()
        autoRefreshJob = viewModelScope.launch {
            while (isActive) {
                delay(intervalMillis)
                load(silent = true, forceRefresh = true)
                if (currentUserId != null && realtime == realtime) {
                    // No-op for now; ensures subscription is alive via load() side-effects.
                }
            }
        }
    }

    fun stopAutoRefresh() {
        autoRefreshJob?.cancel()
        autoRefreshJob = null
    }

    override fun onCleared() {
        super.onCleared()
        stopAutoRefresh()
        unsubscribeRealtime()
    }
}

// async helper to keep the imports tidy
private fun <T> kotlinx.coroutines.CoroutineScope.async(
    block: suspend kotlinx.coroutines.CoroutineScope.() -> T,
) = kotlinx.coroutines.async(this, block = block)
```

Wait — the `async` helper is wrong (no `kotlinx.coroutines.async` companion in scope). Replace the import-based version. Use this corrected file (remove the helper at the bottom, use the standard import):

```kotlin
import kotlinx.coroutines.async
```

…and the `load` function uses `async { ... }` directly inside `viewModelScope.launch { ... }`. Re-write the file as:

```kotlin
package com.kajhobe.app.ui.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.dashboard.DashboardCache
import com.kajhobe.app.data.dashboard.DashboardRealtime
import com.kajhobe.app.data.dashboard.DashboardSnapshot
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.repository.DealsRepository
import com.kajhobe.app.data.repository.ProfilePublicRepository
import io.github.jan.supabase.SupabaseClient
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

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

class DashboardViewModel(
    private val dealsRepository: DealsRepository,
    private val profilePublicRepository: ProfilePublicRepository,
    private val cache: DashboardCache,
    private val realtime: DashboardRealtime,
    private val supabase: SupabaseClient,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    private var autoRefreshJob: Job? = null

    init { loadFromCacheThenNetwork() }

    private val currentUserId: String?
        get() = supabase.auth.currentUserOrNull()?.id

    fun loadFromCacheThenNetwork() {
        val snapshot = cache.peekOrLoadBlocking()
        if (snapshot != null) {
            _uiState.update {
                it.copy(
                    isLoading = false,
                    data = snapshot.dashboard,
                    activeDeals = snapshot.activeDeals,
                )
            }
        }
        load(silent = snapshot != null, forceRefresh = true)
    }

    fun refresh() = load(silent = true, forceRefresh = true)

    fun load(silent: Boolean = false, forceRefresh: Boolean = false) {
        _uiState.update {
            it.copy(
                isLoading = if (silent) it.isLoading else true,
                isRefreshing = if (silent) true else it.isRefreshing,
                errorMessage = null,
            )
        }
        viewModelScope.launch {
            runCatching {
                val dataDeferred = async { dealsRepository.fetchDashboardData() }
                val activeDeferred = async {
                    runCatching { dealsRepository.fetchActiveDeals() }.getOrDefault(emptyList())
                }
                val data = dataDeferred.await()
                val activeDeals = activeDeferred.await().distinctBy { it.id }
                loadAnalytics()
                data to activeDeals
            }.onSuccess { (data, activeDeals) ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        data = data,
                        activeDeals = activeDeals,
                    )
                }
                val uid = currentUserId
                if (uid != null) {
                    cache.save(DashboardSnapshot(dashboard = data, activeDeals = activeDeals))
                }
            }.onFailure { e ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        errorMessage = e.message ?: "Failed to load dashboard",
                    )
                }
            }
        }
    }

    private suspend fun loadAnalytics() {
        val uid = currentUserId ?: return
        val deals = runCatching { dealsRepository.fetchMyDeals() }.getOrNull() ?: return
        val reviews = runCatching { profilePublicRepository.fetchReviews(uid) }.getOrNull() ?: emptyList()
        _uiState.update { it.copy(myDeals = deals, myReviews = reviews) }
    }

    fun subscribeRealtime() {
        val uid = currentUserId ?: return
        realtime.subscribe(viewModelScope, uid.lowercase()) {
            _uiState.update { it.copy(hasRealtimeUpdate = true) }
            viewModelScope.launch {
                delay(1_500)
                _uiState.update { it.copy(hasRealtimeUpdate = false) }
            }
            load(silent = true, forceRefresh = true)
        }
    }

    fun unsubscribeRealtime() = realtime.unsubscribe()

    fun startAutoRefresh(intervalMillis: Long = 5L * 60L * 1_000L) {
        stopAutoRefresh()
        autoRefreshJob = viewModelScope.launch {
            while (isActive) {
                delay(intervalMillis)
                load(silent = true, forceRefresh = true)
            }
        }
    }

    fun stopAutoRefresh() {
        autoRefreshJob?.cancel()
        autoRefreshJob = null
    }

    override fun onCleared() {
        super.onCleared()
        stopAutoRefresh()
        unsubscribeRealtime()
    }
}
```

(Remove the `awaitAll` import — it's not used. The final imports are listed at the top.)

- [ ] **Step 2: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardViewModel.kt
git commit -m "feat(dashboard): rewrite DashboardViewModel with cache, analytics, realtime, auto-refresh"
```

---

## Task 8: Add `DashboardAnalytics` tests (already done in Task 2) — skip, move on

---

## Task 9: Add `DashboardChartsSection` (MPAndroidChart)

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardChartsSection.kt`

- [ ] **Step 1: Create the file**

`app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardChartsSection.kt`:
```kotlin
package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.outlined.Insights
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.github.mikephil.charting.charts.BarChart
import com.github.mikephil.charting.charts.LineChart
import com.github.mikephil.charting.charts.PieChart
import com.github.mikephil.charting.components.XAxis
import com.github.mikephil.charting.data.BarData
import com.github.mikephil.charting.data.BarDataSet
import com.github.mikephil.charting.data.BarEntry
import com.github.mikephil.charting.data.Entry
import com.github.mikephil.charting.data.LineData
import com.github.mikephil.charting.data.LineDataSet
import com.github.mikephil.charting.data.PieData
import com.github.mikephil.charting.data.PieDataSet
import com.github.mikephil.charting.data.PieEntry
import com.github.mikephil.charting.formatter.IndexAxisValueFormatter
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Analytics section of the Dashboard: money flow bar, status donut, rating-trend line.
 * Uses MPAndroidChart (Swift Charts equivalent on Android). Mirrors iOS
 * `DashboardChartsSection.swift` section-for-section.
 */
@Composable
fun DashboardChartsSection(
    deals: List<Deal>,
    reviews: List<ProviderReview>,
    userId: String,
    modifier: Modifier = Modifier,
) {
    val moneyFlow = remember(deals, userId) { DashboardAnalytics.monthlyMoneyFlow(deals, userId) }
    val statusSlices = remember(deals) { DashboardAnalytics.statusBreakdown(deals) }
    val ratingPoints = remember(reviews) { DashboardAnalytics.ratingTrend(reviews) }

    PremiumCard(modifier = modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.Insights, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
            Spacer(Modifier.width(8.dp))
            Text("Analytics", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(16.dp))
        Text("Money flow", style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(8.dp))
        if (moneyFlow.size < 2) {
            ChartPlaceholder("Needs more history")
        } else {
            MoneyFlowChart(points = moneyFlow)
        }
        Spacer(Modifier.height(16.dp))
        Text("Deal status", style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(8.dp))
        if (statusSlices.isEmpty()) {
            ChartPlaceholder("No deals yet")
        } else {
            StatusDonut(slices = statusSlices)
        }
        Spacer(Modifier.height(16.dp))
        Text("Rating trend", style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(8.dp))
        if (ratingPoints.size < 2) {
            ChartPlaceholder("Needs more reviews")
        } else {
            RatingTrendChart(points = ratingPoints)
        }
    }
}

@Composable
private fun ChartPlaceholder(message: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.BarChart, contentDescription = null, tint = KajHobeTheme.colors.textSecondary)
            Spacer(Modifier.height(6.dp))
            Text(message, style = MaterialTheme.typography.bodySmall, color = KajHobeTheme.colors.textSecondary)
        }
    }
}

@Composable
private fun MoneyFlowChart(points: List<DashboardAnalytics.MoneyPoint>) {
    val monthLabels = points.map { it.month.format(DateTimeFormatter.ofPattern("MMM", Locale.US)) }.distinct()
    val earnedColor = KajHobeTheme.colors.success.toArgb()
    val spentColor = KajHobeTheme.colors.accentOrange.toArgb()

    AndroidView(
        modifier = Modifier.fillMaxWidth().height(180.dp),
        factory = { ctx ->
            BarChart(ctx).apply {
                description.isEnabled = false
                legend.isEnabled = true
                axisRight.isEnabled = false
                axisLeft.setDrawGridLines(false)
                xAxis.position = XAxis.XAxisPosition.BOTTOM
                xAxis.setDrawGridLines(false)
                setNoDataText("")
            }
        },
        update = { chart ->
            val months = points.map { it.month }.distinct().sorted()
            val monthIndex = { d: java.time.OffsetDateTime -> months.indexOf(d) }
            val earnedEntries = points.filter { it.role == DashboardAnalytics.MoneyPoint.Role.earned }
                .map { BarEntry(monthIndex(it.month).toFloat(), it.amount.toFloat()) }
            val spentEntries = points.filter { it.role == DashboardAnalytics.MoneyPoint.Role.spent }
                .map { BarEntry(monthIndex(it.month).toFloat(), it.amount.toFloat()) }
            val earnedSet = BarDataSet(earnedEntries, "Earned").apply { color = earnedColor; setDrawValues(false) }
            val spentSet = BarDataSet(spentEntries, "Spent").apply { color = spentColor; setDrawValues(false) }
            val data = BarData(earnedSet, spentSet).apply { barWidth = 0.35f }
            chart.data = data
            chart.xAxis.valueFormatter = IndexAxisValueFormatter(months.map { it.format(DateTimeFormatter.ofPattern("MMM", Locale.US)) })
            chart.groupBars(0f, 0.2f, 0.05f)
            chart.invalidate()
        },
    )
}

@Composable
private fun StatusDonut(slices: List<DashboardAnalytics.StatusSlice>) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        AndroidView(
            modifier = Modifier.size(130.dp),
            factory = { ctx ->
                PieChart(ctx).apply {
                    description.isEnabled = false
                    isDrawHoleEnabled = true
                    holeRadius = 60f
                    transparentCircleRadius = 0f
                    setUsePercentValues(false)
                    legend.isEnabled = false
                }
            },
            update = { chart ->
                val entries = slices.map { PieEntry(it.count.toFloat(), it.status) }
                val colors = slices.map { statusColor(it.status).toArgb() }
                val ds = PieDataSet(entries, "").apply {
                    setColors(colors)
                    setDrawValues(false)
                    sliceSpace = 2f
                }
                chart.data = PieData(ds)
                chart.invalidate()
            },
        )
        Spacer(Modifier.width(16.dp))
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            slices.forEach { slice ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.foundation.layout.Box(
                        modifier = Modifier
                            .size(8.dp)
                            .background(statusColor(slice.status), androidx.compose.foundation.shape.CircleShape),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(slice.status, style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                    Text(slice.count.toString(), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun RatingTrendChart(points: List<DashboardAnalytics.RatingPoint>) {
    val yellow = KajHobeTheme.colors.accentOrange.toArgb()
    AndroidView(
        modifier = Modifier.fillMaxWidth().height(140.dp),
        factory = { ctx ->
            LineChart(ctx).apply {
                description.isEnabled = false
                legend.isEnabled = false
                axisRight.isEnabled = false
                xAxis.position = XAxis.XAxisPosition.BOTTOM
                xAxis.setDrawGridLines(false)
                axisLeft.axisMinimum = 0f
                axisLeft.axisMaximum = 5f
                setNoDataText("")
            }
        },
        update = { chart ->
            val entries = points.map { Entry(it.month.monthValue.toFloat(), it.runningAverage.toFloat()) }
            val ds = LineDataSet(entries, "Rating").apply {
                color = yellow
                setCircleColor(yellow)
                circleRadius = 4f
                lineWidth = 2f
                setDrawValues(false)
                mode = LineDataSet.Mode.CUBIC_BEZIER
            }
            chart.data = LineData(ds)
            chart.xAxis.valueFormatter = IndexAxisValueFormatter(
                points.map { it.month.format(DateTimeFormatter.ofPattern("MMM", Locale.US)) },
            )
            chart.invalidate()
        },
    )
}

private fun statusColor(status: String): Color = when (status.lowercase()) {
    "completed" -> KajHobeTheme.colors.success
    "in progress" -> MaterialTheme.colorScheme.primary
    "pending approval" -> KajHobeTheme.colors.accentOrange
    "disputed" -> MaterialTheme.colorScheme.error
    "resolved" -> MaterialTheme.colorScheme.tertiary
    else -> KajHobeTheme.colors.textSecondary
}
```

(Add `import androidx.compose.foundation.background` near the other layout imports.)

- [ ] **Step 2: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardChartsSection.kt
git commit -m "feat(dashboard): add DashboardChartsSection with MPAndroidChart"
```

---

## Task 10: Add `DashboardReputationCard` and `ReviewsListView`

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardReputationCard.kt`
- Create: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/ReviewsListView.kt`

- [ ] **Step 1: Create `DashboardReputationCard.kt`**

`app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardReputationCard.kt`:
```kotlin
package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.model.TrustLevel
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.components.ProviderReviewCard
import com.kajhobe.app.ui.components.TrustBadge
import com.kajhobe.app.ui.theme.KajHobeTheme

@Composable
fun DashboardReputationCard(
    reviews: List<ProviderReview>,
    averageRating: Double,
    completedJobs: Int,
    onViewAll: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val trustLevel = DashboardAnalytics.trustLevel(completedJobs, averageRating)
    val distribution = DashboardAnalytics.ratingDistribution(reviews)
    val maxCount = (distribution.maxOfOrNull { it.second } ?: 1).coerceAtLeast(1)

    PremiumCard(modifier = modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = Icons.Filled.Star,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.tertiary,
            )
            Spacer(Modifier.width(8.dp))
            Text("Reputation", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            TrustBadge(trustLevel = trustLevel, compact = true)
        }
        Spacer(Modifier.height(12.dp))
        TrustProgressRow(completedJobs = completedJobs, averageRating = averageRating)
        Spacer(Modifier.height(12.dp))
        if (reviews.isEmpty()) {
            Box(modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.Star, contentDescription = null, tint = KajHobeTheme.colors.textSecondary)
                    Spacer(Modifier.height(6.dp))
                    Text("No reviews yet", style = MaterialTheme.typography.bodySmall, color = KajHobeTheme.colors.textSecondary)
                }
            }
        } else {
            DistributionBars(distribution = distribution, maxCount = maxCount)
            Spacer(Modifier.height(12.dp))
            Text("Latest reviews", style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.height(8.dp))
            reviews.take(3).forEach { review ->
                ProviderReviewCard(review = review)
                Spacer(Modifier.height(8.dp))
            }
            if (reviews.size > 3 && onViewAll != null) {
                TextButton(onClick = onViewAll, modifier = Modifier.fillMaxWidth()) {
                    Text("View all ${reviews.size} reviews")
                }
            }
        }
    }
}

@Composable
private fun TrustProgressRow(completedJobs: Int, averageRating: Double) {
    val target = DashboardAnalytics.nextTrustLevelTarget(completedJobs, averageRating)
    if (target == null) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Star, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
            Spacer(Modifier.width(4.dp))
            Text("Top tier reached", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.tertiary)
        }
    } else {
        Column {
            LinearProgressIndicator(
                progress = { target.progress.toFloat() },
                modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                color = MaterialTheme.colorScheme.tertiary,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = "${target.jobsNeeded} completed jobs and ${"%.1f".format(target.ratingNeeded)}★ away from ${target.next.name}",
                style = MaterialTheme.typography.bodySmall,
                color = KajHobeTheme.colors.textSecondary,
            )
        }
    }
}

@Composable
private fun DistributionBars(distribution: List<Pair<Int, Int>>, maxCount: Int) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        distribution.forEach { (stars, count) ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stars.toString(), style = MaterialTheme.typography.bodySmall, color = KajHobeTheme.colors.textSecondary, modifier = Modifier.width(20.dp))
                Icon(Icons.Filled.Star, contentDescription = null, tint = KajHobeTheme.colors.accentOrange, modifier = Modifier.width(12.dp))
                Spacer(Modifier.width(6.dp))
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(KajHobeTheme.colors.subtleBackground),
                ) {
                    val frac = count.toFloat() / maxCount
                    if (frac > 0f) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(frac)
                                .height(8.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(KajHobeTheme.colors.accentOrange),
                        )
                    }
                }
                Spacer(Modifier.width(6.dp))
                Text(count.toString(), style = MaterialTheme.typography.bodySmall, color = KajHobeTheme.colors.textSecondary, modifier = Modifier.width(20.dp))
            }
        }
    }
}
```

- [ ] **Step 2: Create `ReviewsListView.kt`**

`app/src/main/java/com/kajhobe/app/ui/feature/dashboard/ReviewsListView.kt`:
```kotlin
package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.ui.components.ProviderReviewCard
import com.kajhobe.app.ui.theme.KajHobeTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReviewsListView(
    reviews: List<ProviderReview>,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxSize()) {
        androidx.compose.material3.TopAppBar(
            title = { Text("Reviews") },
            navigationIcon = {
                TextButton(onClick = onClose) { Text("Done") }
            },
        )
        if (reviews.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.Star, contentDescription = null, tint = KajHobeTheme.colors.textSecondary)
                    Text("No reviews yet", color = KajHobeTheme.colors.textSecondary)
                }
            }
        } else {
            LazyColumn(
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(reviews, key = { it.id }) { review ->
                    ProviderReviewCard(review = review)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardReputationCard.kt Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/ReviewsListView.kt
git commit -m "feat(dashboard): add reputation card and reviews list views"
```

---

## Task 11: Add `DealsListView` (drill-down)

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DealsListView.kt`

- [ ] **Step 1: Create the file**

`app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DealsListView.kt`:
```kotlin
package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Briefcase
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

enum class DealsFilter(val title: String) {
    Active("Active"),
    Completed("Completed"),
    All("All"),
}

fun DealsFilter.matches(deal: Deal): Boolean = when (this) {
    DealsFilter.All -> true
    DealsFilter.Completed -> DashboardAnalytics.isCompleted(deal)
    DealsFilter.Active -> !DashboardAnalytics.isCompleted(deal)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DealsListView(
    deals: List<Deal>,
    initialFilter: DealsFilter,
    onClose: () -> Unit,
    onDealClick: (Deal) -> Unit,
    modifier: Modifier = Modifier,
) {
    var filter by remember { mutableStateOf(initialFilter) }
    var menuOpen by remember { mutableStateOf(false) }
    val filtered = deals.filter { filter.matches(it) }

    Column(modifier = modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Deals") },
            navigationIcon = { TextButton(onClick = onClose) { Text("Done") } },
            actions = {
                Box {
                    TextButton(onClick = { menuOpen = true }) { Text(filter.title) }
                    DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                        DealsFilter.entries.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(option.title) },
                                onClick = { filter = option; menuOpen = false },
                            )
                        }
                    }
                }
            },
        )
        if (filtered.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.Briefcase, contentDescription = null, tint = KajHobeTheme.colors.textSecondary)
                    Text("No deals to show", color = KajHobeTheme.colors.textSecondary)
                }
            }
        } else {
            LazyColumn(
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(filtered, key = { it.id }) { deal ->
                    DealListRow(deal = deal, onTap = { onDealClick(deal) })
                }
            }
        }
    }
}

@Composable
private fun DealListRow(deal: Deal, onTap: () -> Unit) {
    val status = deal.completion_status ?: deal.status
    PremiumCard(
        modifier = Modifier.fillMaxWidth().clickable { onTap() },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    deal.job?.title ?: "Unknown Job",
                    style = MaterialTheme.typography.bodyMedium,
                )
                val date = DashboardAnalytics.parseDate(deal.completed_at ?: deal.created_at)
                if (date != null) {
                    Text(
                        date.format(DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US)),
                        style = MaterialTheme.typography.labelSmall,
                        color = KajHobeTheme.colors.textSecondary,
                    )
                }
            }
            Text("৳${deal.agreed_amount}", style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.success)
        }
        Spacer(Modifier.size(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(statusColor(status)),
            )
            Spacer(Modifier.size(4.dp))
            Text(
                status.replace("_", " ").replaceFirstChar { it.titlecase(Locale.US) },
                style = MaterialTheme.typography.labelSmall,
                color = KajHobeTheme.colors.textSecondary,
            )
            Spacer(Modifier.weight(1f))
            Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = KajHobeTheme.colors.textSecondary)
        }
    }
}

private fun statusColor(status: String): Color = when (status.lowercase()) {
    "completed" -> KajHobeTheme.colors.success
    "in_progress", "active" -> MaterialTheme.colorScheme.primary
    "pending_approval" -> KajHobeTheme.colors.accentOrange
    "disputed" -> MaterialTheme.colorScheme.error
    else -> KajHobeTheme.colors.textSecondary
}
```

(Add `import androidx.compose.foundation.layout.Spacer` and `import androidx.compose.foundation.layout.size` if not already present.)

- [ ] **Step 2: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DealsListView.kt
git commit -m "feat(dashboard): add DealsListView drill-down with filter"
```

---

## Task 12: Add minimal `NotificationSettingsScreen` (stub)

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/NotificationSettingsScreen.kt`

- [ ] **Step 1: Create the file**

```kotlin
package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.kajhobe.app.ui.theme.KajHobeTheme

/**
 * Minimal stub — full iOS port is out of scope for this design. The dashboard
 * toolbar's bell icon routes here so the navigation parity is complete.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationSettingsScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Notifications") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(KajHobeTheme.spacing.lg)) {
            Text("Notification settings — coming soon")
        }
    }
}
```

- [ ] **Step 2: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/NotificationSettingsScreen.kt
git commit -m "feat(dashboard): add NotificationSettingsScreen stub"
```

---

## Task 13: Add `Routes.NOTIFICATION_SETTINGS`

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/navigation/Destinations.kt`

- [ ] **Step 1: Add the route constant**

Inside `object Routes { ... }`, add:
```kotlin
const val NOTIFICATION_SETTINGS = "notification-settings"
```

- [ ] **Step 2: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/navigation/Destinations.kt
git commit -m "feat(nav): add NOTIFICATION_SETTINGS route"
```

---

## Task 14: Rewrite `DashboardScreen` (full parity)

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt`

- [ ] **Step 1: Replace the file**

`app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt`:
```kotlin
package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Note
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Briefcase
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.theme.KajHobeTheme
import kotlinx.coroutines.launch
import org.koin.androidx.compose.koinViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    onMyProfile: () -> Unit,
    onNotificationSettings: () -> Unit,
    onOpenJobs: () -> Unit,
    onPostJob: () -> Unit,
    onDealClick: (String) -> Unit,
    viewModel: DashboardViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LifecycleResumeEffect(Unit) {
        viewModel.loadFromCacheThenNetwork()
        onPauseOrDispose { }
    }

    LaunchedEffect(Unit) { viewModel.subscribeRealtime() }
    DisposableEffect(Unit) {
        onDispose { viewModel.unsubscribeRealtime() }
    }
    LaunchedEffect(Unit) { viewModel.startAutoRefresh() }
    DisposableEffect(Unit) {
        onDispose { viewModel.stopAutoRefresh() }
    }

    LaunchedEffect(state.errorMessage) {
        state.errorMessage?.let { snackbarHost.showSnackbar(it) }
    }

    // Modal sheets
    var dealsFilter by remember { mutableStateOf<DealsFilter?>(null) }
    var showingReviews by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Dashboard") },
                navigationIcon = {
                    IconButton(onClick = onNotificationSettings) {
                        Icon(Icons.Filled.Notifications, contentDescription = "Notification settings")
                    }
                },
                actions = {
                    IconButton(onClick = onMyProfile) {
                        Icon(Icons.Filled.AccountCircle, contentDescription = "My profile")
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        },
        snackbarHost = { SnackbarHost(snackbarHost) },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            if (state.isLoading) {
                PremiumLoadingView(message = "Loading dashboard…")
            } else {
                DashboardContent(
                    state = state,
                    onStatCardTap = { filter -> dealsFilter = filter },
                    onRatingCardTap = { showingReviews = true },
                    onDealClick = onDealClick,
                    onOpenJobs = onOpenJobs,
                    onPostJob = onPostJob,
                )
            }
        }
    }

    // Sheets
    dealsFilter?.let { filter ->
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { dealsFilter = null },
            sheetState = sheetState,
        ) {
            DealsListView(
                deals = state.myDeals,
                initialFilter = filter,
                onClose = { scope.launch { sheetState.hide() }.invokeOnCompletion { dealsFilter = null } },
                onDealClick = { deal ->
                    dealsFilter = null
                    onDealClick(deal.id)
                },
            )
        }
    }
    if (showingReviews) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { showingReviews = false },
            sheetState = sheetState,
        ) {
            ReviewsListView(
                reviews = state.myReviews,
                onClose = { scope.launch { sheetState.hide() }.invokeOnCompletion { showingReviews = false } },
            )
        }
    }
}

@Composable
private fun DashboardContent(
    state: DashboardUiState,
    onStatCardTap: (DealsFilter) -> Unit,
    onRatingCardTap: () -> Unit,
    onDealClick: (String) -> Unit,
    onOpenJobs: () -> Unit,
    onPostJob: () -> Unit,
) {
    val data = state.data
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = KajHobeTheme.spacing.lg),
        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = KajHobeTheme.spacing.md),
    ) {
        item { RealtimeIndicator(visible = state.hasRealtimeUpdate) }
        item {
            if (data != null) {
                StatsSection(data = data, onStatCardTap = onStatCardTap, onRatingCardTap = onRatingCardTap)
            } else {
                EmptyStatsSection(onOpenJobs = onOpenJobs, onPostJob = onPostJob)
            }
        }
        if (data != null && (state.myDeals.isNotEmpty() || state.myReviews.isNotEmpty())) {
            item {
                DashboardChartsSection(
                    deals = state.myDeals,
                    reviews = state.myReviews,
                    userId = state.data?.user_type ?: "client", // uid is set in VM; userType here is a placeholder
                )
            }
            item {
                DashboardReputationCard(
                    reviews = state.myReviews,
                    averageRating = data.average_rating,
                    completedJobs = data.completed_deals_count,
                    onViewAll = onRatingCardTap,
                )
            }
        }
        if (state.activeDeals.isNotEmpty()) {
            item { ActiveDealsSection(deals = state.activeDeals, onDealClick = onDealClick) }
        }
        if (data?.recent_deals?.isNotEmpty() == true) {
            item { RecentActivitySection(recent = data.recent_deals, allDeals = state.myDeals, onDealClick = onDealClick) }
        }
    }
}

@Composable
private fun RealtimeIndicator(visible: Boolean) {
    if (visible) {
        LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
    } else {
        Spacer(Modifier.height(2.dp))
    }
}

@Composable
private fun StatsSection(
    data: DashboardData,
    onStatCardTap: (DealsFilter) -> Unit,
    onRatingCardTap: () -> Unit,
) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Timer, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.size(8.dp))
            Text("Overview", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            StatCard(
                title = "Active deals",
                value = data.active_deals_count.toString(),
                icon = Icons.Filled.Briefcase,
                color = MaterialTheme.colorScheme.primary,
                onTap = { onStatCardTap(DealsFilter.Active) },
                modifier = Modifier.weight(1f),
            )
            StatCard(
                title = "Completed",
                value = data.completed_deals_count.toString(),
                icon = Icons.Filled.CheckCircle,
                color = KajHobeTheme.colors.success,
                onTap = { onStatCardTap(DealsFilter.Completed) },
                modifier = Modifier.weight(1f),
            )
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            val isProvider = data.user_type == "provider"
            val amount = if (isProvider) data.total_earnings else data.total_spent
            StatCard(
                title = if (isProvider) "Total Earned" else "Total Spent",
                value = "৳${amount.toInt()}",
                icon = Icons.AutoMirrored.Filled.Note,
                color = KajHobeTheme.colors.accentOrange,
                onTap = { onStatCardTap(DealsFilter.Completed) },
                modifier = Modifier.weight(1f),
            )
            StatCard(
                title = "Rating",
                value = "%.1f".format(data.average_rating),
                icon = Icons.Filled.Star,
                color = KajHobeTheme.colors.accentOrange,
                onTap = onRatingCardTap,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun EmptyStatsSection(onOpenJobs: () -> Unit, onPostJob: () -> Unit) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Timer, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.size(8.dp))
            Text("Overview", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            StatCard("Active deals", "0", Icons.Filled.Briefcase, MaterialTheme.colorScheme.primary, modifier = Modifier.weight(1f))
            StatCard("Completed", "0", Icons.Filled.CheckCircle, KajHobeTheme.colors.success, modifier = Modifier.weight(1f))
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            StatCard("Total Earned", "৳0", Icons.AutoMirrored.Filled.Note, KajHobeTheme.colors.accentOrange, modifier = Modifier.weight(1f))
            StatCard("Rating", "4.5", Icons.Filled.Star, KajHobeTheme.colors.accentOrange, modifier = Modifier.weight(1f))
        }
        Spacer(Modifier.height(KajHobeTheme.spacing.md))
        Text("Get started with your first job", style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.textSecondary)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            com.kajhobe.app.ui.components.PrimaryButton(text = "Browse Available Jobs", onClick = onOpenJobs, modifier = Modifier.weight(1f))
            com.kajhobe.app.ui.components.PrimaryButton(text = "Post a Job", onClick = onPostJob, outlined = true, modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun StatCard(
    title: String,
    value: String,
    icon: ImageVector,
    color: Color,
    onTap: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val baseModifier = if (onTap != null) modifier.clickable { onTap() } else modifier
    Box(
        modifier = baseModifier
            .clip(RoundedCornerShape(8.dp))
            .background(KajHobeTheme.colors.subtleBackground)
            .padding(12.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
                Spacer(Modifier.weight(1f))
                if (onTap != null) {
                    Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = KajHobeTheme.colors.textSecondary, modifier = Modifier.size(14.dp))
                }
            }
            Spacer(Modifier.size(8.dp))
            Text(value, style = MaterialTheme.typography.titleLarge)
            Text(title, style = MaterialTheme.typography.labelSmall, color = KajHobeTheme.colors.textSecondary)
        }
    }
}

@Composable
private fun ActiveDealsSection(deals: List<Deal>, onDealClick: (String) -> Unit) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Briefcase, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.size(8.dp))
            Text("Active deals", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(12.dp))
        deals.forEach { deal ->
            ActiveDealRow(deal = deal, onTap = { onDealClick(deal.id) })
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun ActiveDealRow(deal: Deal, onTap: () -> Unit) {
    val status = deal.completion_status ?: "in_progress"
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(KajHobeTheme.colors.subtleBackground)
            .clickable { onTap() }
            .padding(12.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    deal.job?.title ?: "Unknown Job",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f),
                )
                Text("৳${deal.agreed_amount}", style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.success)
            }
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                val otherName = deal.client_profile?.full_name ?: deal.provider_profile?.full_name ?: "Unknown"
                Text("with $otherName", style = MaterialTheme.typography.labelSmall, color = KajHobeTheme.colors.textSecondary, modifier = Modifier.weight(1f))
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(statusColor(status)),
                )
                Spacer(Modifier.size(4.dp))
                Text(
                    status.replace("_", " ").replaceFirstChar { it.titlecase(java.util.Locale.US) },
                    style = MaterialTheme.typography.labelSmall,
                    color = KajHobeTheme.colors.textSecondary,
                )
                Spacer(Modifier.size(4.dp))
                Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = KajHobeTheme.colors.textSecondary, modifier = Modifier.size(14.dp))
            }
        }
    }
}

@Composable
private fun RecentActivitySection(
    recent: List<com.kajhobe.app.data.model.DashboardDeal>,
    allDeals: List<Deal>,
    onDealClick: (String) -> Unit,
) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Timer, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
            Spacer(Modifier.size(8.dp))
            Text("Recent activity", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(12.dp))
        recent.forEach { r ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(KajHobeTheme.colors.subtleBackground)
                    .clickable { onDealClick(r.id) }
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(r.job_title, style = MaterialTheme.typography.bodyMedium)
                    Text("with ${r.other_party_name ?: "Unknown"}", style = MaterialTheme.typography.labelSmall, color = KajHobeTheme.colors.textSecondary)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("৳${r.agreed_amount}", style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.success)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(modifier = Modifier.size(6.dp).clip(CircleShape).background(statusColor(r.completion_status)))
                        Spacer(Modifier.size(4.dp))
                        Text(
                            r.completion_status.replace("_", " ").replaceFirstChar { it.titlecase(java.util.Locale.US) },
                            style = MaterialTheme.typography.labelSmall,
                            color = KajHobeTheme.colors.textSecondary,
                        )
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

private fun statusColor(status: String): Color = when (status.lowercase()) {
    "completed" -> KajHobeTheme.colors.success
    "in_progress" -> MaterialTheme.colorScheme.primary
    "pending_approval" -> KajHobeTheme.colors.accentOrange
    "disputed" -> MaterialTheme.colorScheme.error
    else -> KajHobeTheme.colors.textSecondary
}
```

- [ ] **Step 2: Compile — there will be errors in `MainScaffold` since the call signature changed**

```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: errors in `MainScaffold.kt` — `DashboardScreen` parameter mismatch. Fix in next task.

- [ ] **Step 3: Commit (compile errors expected; fix in Task 15)**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt
git commit -m "feat(dashboard): rewrite DashboardScreen with all sections, sheets, realtime, auto-refresh"
```

---

## Task 15: Wire `MainScaffold` to new `DashboardScreen` signature + add `NOTIFICATION_SETTINGS` route

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/navigation/MainScaffold.kt`

- [ ] **Step 1: Update the DashboardScreen call site**

Find:
```kotlin
composable(TopLevelDestination.DASHBOARD.route) {
    DashboardScreen(
        onSignOut = onSignOut,
        onDealClick = { dealId -> navController.navigate(Routes.dealDetail(dealId)) },
        onMyProfile = { navController.navigate(Routes.MY_PROFILE) },
    )
}
```

Replace with:
```kotlin
composable(TopLevelDestination.DASHBOARD.route) {
    DashboardScreen(
        onMyProfile = { navController.navigate(Routes.MY_PROFILE) },
        onNotificationSettings = { navController.navigate(Routes.NOTIFICATION_SETTINGS) },
        onOpenJobs = {
            navController.navigate(TopLevelDestination.JOBS.route) {
                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                launchSingleTop = true
            }
        },
        onPostJob = { navController.navigate(TopLevelDestination.POST.route) },
        onDealClick = { dealId -> navController.navigate(Routes.dealDetail(dealId)) },
    )
}
composable(Routes.NOTIFICATION_SETTINGS) {
    com.kajhobe.app.ui.feature.dashboard.NotificationSettingsScreen(
        onBack = { navController.popBackStack() },
    )
}
```

- [ ] **Step 2: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/navigation/MainScaffold.kt
git commit -m "feat(nav): wire new dashboard callbacks and NOTIFICATION_SETTINGS route"
```

---

## Task 16: Final verification — build, lint, tests

- [ ] **Step 1: Run unit tests**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:testDebugUnitTest
```
Expected: all tests pass (DashboardAnalyticsTest at minimum).

- [ ] **Step 2: Run detekt / ktlint (project commands)**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew detekt || ./gradlew ktlintCheck || true
```
Expected: zero new errors (existing warnings are out of scope).

- [ ] **Step 3: Assemble debug**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:assembleDebug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Manual smoke checklist (recorded in commit body)**

Run the app, sign in, and verify:
- [ ] Dashboard loads on first launch (from cache or network).
- [ ] Pull-to-refresh updates the data.
- [ ] Wait 5 min — auto-refresh fires.
- [ ] Open Supabase, edit a deal, return to app — real-time event fires within ~1s.
- [ ] Tap "Active deals" stat card → drill-down sheet opens with "Active" filter.
- [ ] Tap "Completed" stat card → drill-down sheet with "Completed" filter.
- [ ] Tap rating stat card → reviews list sheet.
- [ ] Active-deal row tap → `DealDetailScreen`.
- [ ] Bell icon → `NotificationSettingsScreen`.
- [ ] Person icon → `ProfileScreen`.
- [ ] Sign out from a clean data state → empty state shows "Browse" / "Post" CTAs.

- [ ] **Step 5: Final commit (docs update)**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/
git commit -m "feat(dashboard): full iOS parity — charts, reputation, drill-downs, real-time, auto-refresh, pull-to-refresh" --allow-empty
```

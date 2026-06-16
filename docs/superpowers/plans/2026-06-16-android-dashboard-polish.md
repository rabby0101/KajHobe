# Android Dashboard + Icon Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Android dashboard look premium and consistent with the rest of the app (fix donut overlap, bar chart axis, ghost bars, card padding, bottom nav, icons).

**Architecture:** Visual-only polish pass. No behavior changes. Rewrite `DashboardChartsSection` to use a horizontal segmented status bar instead of a donut, fix the bar chart's Y-axis formatting and zero-data slivers, tighten card padding, swap to M3 default nav indicator, sweep outlined icons to filled.

**Tech Stack:** Kotlin 2.3, Jetpack Compose (BOM 2026.05.01), Material3, MPAndroidChart v3.1.0.

**Working directory for every command below:** `/Volumes/Experiment/GitHub/KajHobe/Android`

---

## File Structure

### Modified files
```
app/src/main/java/com/kajhobe/app/ui/feature/dashboard/
  DashboardChartsSection.kt      — replace donut with status bar; fix bar chart; inline legend
  DashboardReputationCard.kt     — hairline divider, weight bump
  DashboardScreen.kt             — card padding, stat typography, section spacing
  NotificationSettingsScreen.kt  — verify icon (no change expected)
app/src/main/java/com/kajhobe/app/ui/navigation/
  MainScaffold.kt                — single-line labels, M3 default selected indicator
```

### Files created
None — this is a visual polish pass on existing files.

---

## Task 1: Rewrite `DashboardChartsSection` (status bar + bar chart fixes)

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardChartsSection.kt`

- [ ] **Step 1: Replace the file**

`app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardChartsSection.kt`:
```kotlin
package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.github.mikephil.charting.charts.BarChart
import com.github.mikephil.charting.charts.LineChart
import com.github.mikephil.charting.components.XAxis
import com.github.mikephil.charting.data.BarData
import com.github.mikephil.charting.data.BarDataSet
import com.github.mikephil.charting.data.BarEntry
import com.github.mikephil.charting.data.Entry
import com.github.mikephil.charting.data.LineData
import com.github.mikephil.charting.data.LineDataSet
import com.github.mikephil.charting.formatter.IndexAxisValueFormatter
import com.github.mikephil.charting.formatter.ValueFormatter
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.text.DecimalFormat
import java.time.format.DateTimeFormatter
import java.util.Locale

private val TAKA_FORMAT = DecimalFormat("#,##0")

private fun formatTaka(value: Double): String {
    val abs = kotlin.math.abs(value)
    return when {
        abs >= 1_000_000 -> "৳" + TAKA_FORMAT.format(value / 1_000_000) + "M"
        abs >= 1_000 -> "৳" + TAKA_FORMAT.format(value / 1_000) + "K"
        else -> "৳" + TAKA_FORMAT.format(value)
    }
}

private class TakaAxisFormatter : ValueFormatter() {
    override fun getFormattedValue(value: Float): String = formatTaka(value.toDouble())
}

@Composable
fun DashboardChartsSection(
    deals: List<Deal>,
    reviews: List<ProviderReview>,
    userId: String,
    modifier: Modifier = Modifier,
) {
    val moneyFlow = remember(deals, userId) { DashboardAnalytics.monthlyMoneyFlow(deals, userId) }
        // Hide zero-amount months so the bar chart doesn't show empty slivers
        .filter { it.amount > 0.0 }
    val statusSlices = remember(deals) { DashboardAnalytics.statusBreakdown(deals) }
    val ratingPoints = remember(reviews) { DashboardAnalytics.ratingTrend(reviews) }

    PremiumCard(
        modifier = modifier.fillMaxWidth(),
        contentPadding = 0.dp,
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader(
                icon = Icons.Filled.Insights,
                tint = MaterialTheme.colorScheme.tertiary,
                title = "Analytics",
                trailing = {
                    InlineLegend(
                        items = listOf(
                            "Earned" to KajHobeTheme.colors.success,
                            "Spent" to KajHobeTheme.colors.accentOrange,
                        ),
                    )
                },
            )
            Spacer(Modifier.height(12.dp))

            Text("Money flow", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.height(8.dp))
            if (moneyFlow.size < 2) {
                ChartPlaceholder("Needs more history")
            } else {
                MoneyFlowChart(points = moneyFlow)
            }

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 16.dp),
                color = KajHobeTheme.colors.divider,
            )

            Text("Deal status", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.height(8.dp))
            if (statusSlices.isEmpty()) {
                ChartPlaceholder("No deals yet")
            } else {
                StatusBarList(slices = statusSlices)
            }

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 16.dp),
                color = KajHobeTheme.colors.divider,
            )

            Text("Rating trend", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.height(8.dp))
            if (ratingPoints.size < 2) {
                ChartPlaceholder("Needs more reviews")
            } else {
                RatingTrendChart(points = ratingPoints)
            }
        }
    }
}

@Composable
private fun SectionHeader(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    title: String,
    trailing: (@Composable () -> Unit)? = null,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f))
        if (trailing != null) trailing()
    }
}

@Composable
private fun InlineLegend(items: List<Pair<String, Color>>) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        items.forEach { (label, color) ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(color))
                Spacer(Modifier.width(4.dp))
                Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurface)
            }
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
    val earnedColor = KajHobeTheme.colors.success.toArgb()
    val spentColor = KajHobeTheme.colors.accentOrange.toArgb()
    val months = remember(points) { points.map { it.month }.distinct().sorted() }
    val labels = remember(months) {
        months.map { it.format(DateTimeFormatter.ofPattern("MMM", Locale.US)) }
    }

    AndroidView(
        modifier = Modifier.fillMaxWidth().height(160.dp),
        factory = { ctx ->
            BarChart(ctx).apply {
                description.isEnabled = false
                legend.isEnabled = false
                axisRight.isEnabled = false
                axisLeft.setDrawGridLines(true)
                axisLeft.gridColor = KajHobeTheme.colors.divider.toArgb()
                axisLeft.textColor = KajHobeTheme.colors.textSecondary.toArgb()
                axisLeft.valueFormatter = TakaAxisFormatter()
                axisLeft.axisMinimum = 0f
                xAxis.position = XAxis.XAxisPosition.BOTTOM
                xAxis.setDrawGridLines(false)
                xAxis.granularity = 1f
                xAxis.isGranularityEnabled = true
                xAxis.textColor = KajHobeTheme.colors.textSecondary.toArgb()
                setNoDataText("")
            }
        },
        update = { chart ->
            val monthIndex = { d: java.time.OffsetDateTime -> months.indexOf(d) }
            val earnedEntries = points
                .filter { it.role == DashboardAnalytics.MoneyPoint.Role.earned }
                .map { BarEntry(monthIndex(it.month).toFloat(), it.amount.toFloat()) }
            val spentEntries = points
                .filter { it.role == DashboardAnalytics.MoneyPoint.Role.spent }
                .map { BarEntry(monthIndex(it.month).toFloat(), it.amount.toFloat()) }
            val earnedSet = BarDataSet(earnedEntries, "Earned").apply {
                color = earnedColor
                setDrawValues(false)
            }
            val spentSet = BarDataSet(spentEntries, "Spent").apply {
                color = spentColor
                setDrawValues(false)
            }
            val data = BarData(earnedSet, spentSet).apply { barWidth = 0.35f }
            chart.data = data
            chart.xAxis.valueFormatter = IndexAxisValueFormatter(labels)
            chart.groupBars(0f, 0.2f, 0.05f)
            chart.notifyDataSetChanged()
            chart.invalidate()
        },
    )
}

@Composable
private fun StatusBarList(slices: List<DashboardAnalytics.StatusSlice>) {
    val total = slices.sumOf { it.count }.coerceAtLeast(1)
    val colors = slices.map { statusColor(it.status) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        slices.forEachIndexed { idx, slice ->
            StatusBarRow(
                label = slice.status,
                count = slice.count,
                color = colors[idx],
                fraction = slice.count.toFloat() / total,
            )
        }
    }
}

@Composable
private fun StatusBarRow(label: String, count: Int, color: Color, fraction: Float) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(color))
            Spacer(Modifier.width(8.dp))
            Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f))
            Text(count.toString(), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurface)
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(KajHobeTheme.colors.subtleBackground),
        ) {
            if (fraction > 0f) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(color),
                )
            }
        }
    }
}

@Composable
private fun RatingTrendChart(points: List<DashboardAnalytics.RatingPoint>) {
    val yellow = KajHobeTheme.colors.accentOrange.toArgb()
    val labels = remember(points) { points.map { it.month.format(DateTimeFormatter.ofPattern("MMM", Locale.US)) } }

    AndroidView(
        modifier = Modifier.fillMaxWidth().height(140.dp),
        factory = { ctx ->
            LineChart(ctx).apply {
                description.isEnabled = false
                legend.isEnabled = false
                axisRight.isEnabled = false
                xAxis.position = XAxis.XAxisPosition.BOTTOM
                xAxis.setDrawGridLines(false)
                xAxis.granularity = 1f
                xAxis.isGranularityEnabled = true
                xAxis.textColor = KajHobeTheme.colors.textSecondary.toArgb()
                axisLeft.axisMinimum = 0f
                axisLeft.axisMaximum = 5f
                axisLeft.textColor = KajHobeTheme.colors.textSecondary.toArgb()
                axisLeft.gridColor = KajHobeTheme.colors.divider.toArgb()
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
            chart.xAxis.valueFormatter = IndexAxisValueFormatter(labels)
            chart.notifyDataSetChanged()
            chart.invalidate()
        },
    )
}

@Composable
private fun statusColor(status: String): Color = when (status.lowercase()) {
    "completed" -> KajHobeTheme.colors.success
    "in progress" -> MaterialTheme.colorScheme.primary
    "pending approval" -> KajHobeTheme.colors.accentOrange
    "disputed" -> MaterialTheme.colorScheme.error
    "resolved" -> MaterialTheme.colorScheme.tertiary
    else -> KajHobeTheme.colors.textSecondary
}
```

- [ ] **Step 2: Compile**

```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardChartsSection.kt
git commit -m "fix(dashboard): replace donut with status bar, fix bar chart axis and zero-data slivers"
```

---

## Task 2: Update `DashboardReputationCard` (hairline divider, weight bump)

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardReputationCard.kt`

- [ ] **Step 1: Add the divider and bump count text weight**

Find the `TrustProgressRow` end and the distribution bars start. Replace the trust-progress-and-divider area with this adjusted block. Open the file and make these two changes:

Change 1 — in `DistributionBars`, bump count text style from `bodySmall` to `labelMedium` and add `fontWeight = FontWeight.SemiBold`:

```kotlin
                Text(
                    count.toString(),
                    style = MaterialTheme.typography.labelMedium,
                    color = KajHobeTheme.colors.textSecondary,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.width(20.dp),
                )
```

Add the `FontWeight` import near the other imports:
```kotlin
import androidx.compose.ui.text.font.FontWeight
```

Change 2 — in `DashboardReputationCard`, after `TrustProgressRow(...)` and before the empty/review check, add a hairline divider:

```kotlin
        Spacer(Modifier.height(12.dp))
        TrustProgressRow(completedJobs = completedJobs, averageRating = averageRating)
        Spacer(Modifier.height(12.dp))
        HorizontalDivider(color = KajHobeTheme.colors.divider)
        Spacer(Modifier.height(12.dp))
        if (reviews.isEmpty()) {
            ...
```

Add these two imports at the top of the file (with the other imports):
```kotlin
import androidx.compose.material3.HorizontalDivider
```

(They may already be there — check first; if `HorizontalDivider` is already imported, skip the import line.)

- [ ] **Step 2: Compile**

```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardReputationCard.kt
git commit -m "fix(dashboard): add hairline divider in reputation card, bump count weight"
```

---

## Task 3: Polish `DashboardScreen` (card padding, stat typography, section spacing)

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt`

- [ ] **Step 1: Add a helper for hairline row divider**

Insert this small composable just above the existing `private fun ActiveDealsSection(...)` (or anywhere private to the file):

```kotlin
@Composable
private fun HairlineDivider() {
    androidx.compose.material3.HorizontalDivider(
        modifier = Modifier.padding(vertical = 8.dp),
        color = KajHobeTheme.colors.divider,
    )
}
```

- [ ] **Step 2: Bump stat card value typography**

In `StatsSection` and `EmptyStatsSection`, change every `style = MaterialTheme.typography.titleLarge` on the value `Text` to `style = MaterialTheme.typography.headlineSmall`.

Use two `Edit` calls or `replaceAll = true` to replace `style = MaterialTheme.typography.titleLarge` with `style = MaterialTheme.typography.headlineSmall` in this file (the only `titleLarge` references in this file are stat values).

- [ ] **Step 3: Use hairline dividers in active deals and recent activity**

In `ActiveDealRow`, between the title row and the meta row, add:
```kotlin
            Spacer(Modifier.height(8.dp))
            HairlineDivider()
            Spacer(Modifier.height(8.dp))
```

In `RecentActivitySection`, the existing `Spacer(Modifier.height(8.dp))` between rows should be replaced with:
```kotlin
            HairlineDivider()
```

- [ ] **Step 4: Tighten section spacing in the LazyColumn**

In `DashboardContent`, change `verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)` to `verticalArrangement = Arrangement.spacedBy(16.dp)`.

- [ ] **Step 5: Compile**

```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 6: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt
git commit -m "fix(dashboard): tighten section spacing, bump stat typography, hairline dividers"
```

---

## Task 4: Polish `MainScaffold` bottom nav (single-line labels, M3 default selected indicator)

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/navigation/MainScaffold.kt`

- [ ] **Step 1: Add label style imports**

At the top of the file, after the existing `import androidx.compose.material3.NavigationBar` block, add:

```kotlin
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.ui.text.style.TextOverflow
```

If `androidx.compose.foundation.layout.PaddingValues` is not already imported, add it (it is used in some files but may not be in this one yet):
```kotlin
import androidx.compose.foundation.layout.PaddingValues
```

- [ ] **Step 2: Update the NavigationBarItem**

Find the `NavigationBarItem(...)` call and replace it with:

```kotlin
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(dest.route) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = {
                            if (tabBadgeCount != null) {
                                BadgedBox(badge = { Badge { Text(if (tabBadgeCount > 99) "99+" else "$tabBadgeCount") } }) {
                                    Icon(dest.icon, contentDescription = dest.label)
                                }
                            } else {
                                Icon(dest.icon, contentDescription = dest.label)
                            }
                        },
                        label = {
                            Text(
                                dest.label,
                                maxLines = 1,
                                softWrap = false,
                                overflow = TextOverflow.Visible,
                            )
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.onSecondaryContainer,
                            selectedTextColor = MaterialTheme.colorScheme.onSurface,
                            indicatorColor = MaterialTheme.colorScheme.secondaryContainer,
                            unselectedIconColor = KajHobeTheme.colors.textSecondary,
                            unselectedTextColor = KajHobeTheme.colors.textSecondary,
                        ),
                    )
```

- [ ] **Step 3: Compile**

```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/navigation/MainScaffold.kt
git commit -m "fix(nav): single-line labels, M3 default selected indicator on bottom bar"
```

---

## Task 5: App-wide icon sweep (audit + fix any outlined icons)

**Files:**
- Varies (audit + targeted edits)

- [ ] **Step 1: Audit outlined icon usage**

```bash
cd /Volumes/Experiment/GitHub/KajHobe && grep -rln "material.icons.outlined" Android/app/src/main/java/com/kajhobe/app
```
Expected output: a list of files using outlined icons (likely `DashboardChartsSection.kt` and `ProviderReviewCard.kt` from the previous iOS-parity work).

- [ ] **Step 2: Replace `Icons.Outlined.StarOutline` with filled star**

For each file in the audit output that uses `Icons.Outlined.StarOutline`, replace it with the filled star. In `ProviderReviewCard.kt`, the line is:

```kotlin
                        imageVector = if (filled) Icons.Filled.Star else Icons.Outlined.StarOutline,
```

Replace with:
```kotlin
                        imageVector = Icons.Filled.Star,
                        tint = if (filled) KajHobeTheme.colors.accentOrange else KajHobeTheme.colors.divider,
```

This removes the `Icons.Outlined.StarOutline` import (the `else` branch) and gives unfilled stars the divider color so they read as "empty" without a different icon weight.

- [ ] **Step 3: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app
git commit -m "fix(ui): replace outlined star icons with filled (consistency)"
```

---

## Task 6: Build + tests + lint verification

- [ ] **Step 1: Run unit tests**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:testDebugUnitTest
```
Expected: BUILD SUCCESSFUL (15/15 DashboardAnalytics tests still pass).

- [ ] **Step 2: Run lint**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:lintDebug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Build debug APK**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:assembleDebug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Mark spec as implemented**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add docs/superpowers/specs/2026-06-16-android-dashboard-polish-design.md
git commit -m "docs(spec): mark Android dashboard polish design as implemented"
```

Update the spec file's `**Status:**` line from `Approved design — ready for implementation plan` to `Implemented (2026-06-16) — see docs/superpowers/plans/2026-06-16-android-dashboard-polish.md`.

- [ ] **Step 5: Manual visual verification**

Run the app on the emulator and confirm:
- [ ] No chart overlap
- [ ] Status rows look like the rating distribution
- [ ] Bar chart Y axis shows `৳1.2M` / `৳800K` / `৳0`
- [ ] Bottom nav fits all 5 labels on one line
- [ ] All icons consistent weight

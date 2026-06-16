# Android Density + Tab Order + Chat Pin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dashboard denser, reorder Android tabs to match iOS (Notifications last), and pin chat messages to the bottom of the screen.

**Architecture:** Three small visual-only fixes. Density tightening in stat cards, enum reorder, and `reverseLayout = true` on the chat LazyColumn. No data flow changes, no behavior changes.

**Tech Stack:** Kotlin 2.3, Jetpack Compose, Material3.

**Working directory for every command below:** `/Volumes/Experiment/GitHub/KajHobe/Android`

---

## File Structure

### Modified files
```
app/src/main/java/com/kajhobe/app/ui/feature/dashboard/
  DashboardScreen.kt          — stat card density + Overview card cleanup + LazyColumn bottom padding
  DashboardChartsSection.kt   — tighten internal spacers
app/src/main/java/com/kajhobe/app/ui/navigation/
  Destinations.kt             — reorder TopLevelDestination enum
app/src/main/java/com/kajhobe/app/ui/feature/messages/
  ChatScreen.kt               — reverseLayout on LazyColumn
```

### Files created
None.

---

## Task 1: Tighten `StatCard` density in `DashboardScreen.kt`

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt`

- [ ] **Step 1: Replace the `StatCard` composable**

Find the `StatCard` composable (the one with parameters `title`, `value`, `icon`, `color`, `onTap`, `modifier`). Replace its body with:

```kotlin
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
            .padding(10.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
                Spacer(Modifier.weight(1f))
            }
            Spacer(Modifier.height(4.dp))
            Text(value, style = MaterialTheme.typography.titleLarge)
            Text(
                title,
                style = MaterialTheme.typography.labelSmall,
                color = KajHobeTheme.colors.textSecondary,
            )
        }
    }
}
```

Key changes: outer `padding(12.dp)` → `padding(10.dp)`, internal `Spacer(8.dp)` → `Spacer(4.dp)`, value `headlineSmall` → `titleLarge`, removed the chevron icon (the whole card is the tap target now).

- [ ] **Step 2: Compile**

```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt
git commit -m "fix(dashboard): shrink stat card density, drop chevron, make whole card tappable"
```

---

## Task 2: Tighten `StatsSection` and `EmptyStatsSection` in `DashboardScreen.kt`

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt`

- [ ] **Step 1: Update `StatsSection`**

Find the `StatsSection` composable. Replace the trailing `Spacer(Modifier.height(KajHobeTheme.spacing.md))` after the second `Row` with nothing (drop the spacer — the card's bottom `contentPadding` handles it). Also change the `Spacer(Modifier.height(12.dp))` after the header row to `Spacer(Modifier.height(8.dp))`.

The result body:

```kotlin
@Composable
private fun StatsSection(
    data: DashboardData,
    onStatCardTap: (DealsFilter) -> Unit,
    onRatingCardTap: () -> Unit,
) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.BarChart, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(8.dp))
            Text("Overview", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
            StatCard(
                title = "Active deals",
                value = data.active_deals_count.toString(),
                icon = Icons.Filled.Work,
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
```

- [ ] **Step 2: Apply the same drop-trailing-spacer change to `EmptyStatsSection`**

Find `EmptyStatsSection`. Change the `Spacer(Modifier.height(KajHobeTheme.spacing.md))` after the second stat row to nothing (let the card's contentPadding handle it). Also change the `Spacer(Modifier.height(12.dp))` after the header to `Spacer(Modifier.height(8.dp))`.

- [ ] **Step 3: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt
git commit -m "fix(dashboard): tighten Overview card spacing, drop trailing spacer"
```

---

## Task 3: Add 32dp bottom padding to Dashboard LazyColumn

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt`

- [ ] **Step 1: Update the LazyColumn contentPadding**

In `DashboardContent`, find:
```kotlin
        contentPadding = PaddingValues(vertical = KajHobeTheme.spacing.md),
```

Replace with:
```kotlin
        contentPadding = PaddingValues(top = KajHobeTheme.spacing.md, bottom = 32.dp),
```

- [ ] **Step 2: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardScreen.kt
git commit -m "fix(dashboard): add 32dp bottom padding so last card doesn't kiss bottom nav"
```

---

## Task 4: Tighten Analytics card spacers in `DashboardChartsSection.kt`

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardChartsSection.kt`

- [ ] **Step 1: Change all `Spacer(Modifier.height(16.dp))` inside the card to `Spacer(Modifier.height(12.dp))`**

There are 3 such spacers in the `DashboardChartsSection` composable (between the section header and Money flow, between Money flow and the divider, and between the dividers and the next section). Use `Edit` with `replaceAll = true` on the file:

Old: `Spacer(Modifier.height(16.dp))`
New: `Spacer(Modifier.height(12.dp))`

- [ ] **Step 2: Change `HorizontalDivider` `Modifier.padding(vertical = 16.dp)` → `vertical = 12.dp`**

There are 2 `HorizontalDivider` calls in the same composable. Use `replaceAll = true`:

Old: `color = KajHobeTheme.colors.divider,\n            )`
New: `color = KajHobeTheme.colors.divider,\n            modifier = Modifier.padding(vertical = 12.dp),\n            )`

Wait — to avoid accidental replacements, do each `HorizontalDivider` individually. The pattern is:
```
HorizontalDivider(
    modifier = Modifier.padding(vertical = 16.dp),
    color = KajHobeTheme.colors.divider,
)
```
Change to:
```
HorizontalDivider(
    modifier = Modifier.padding(vertical = 12.dp),
    color = KajHobeTheme.colors.divider,
)
```

- [ ] **Step 3: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/dashboard/DashboardChartsSection.kt
git commit -m "fix(dashboard): tighten Analytics card internal spacers (16→12dp)"
```

---

## Task 5: Reorder tabs in `Destinations.kt` to match iOS

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/navigation/Destinations.kt`

- [ ] **Step 1: Audit for ordinal dependencies**

Run:
```bash
cd /Volumes/Experiment/GitHub/KajHobe && grep -rn "TopLevelDestination\.entries\[" Android/app/src/main/java
```
Expected: no output. If anything shows up, note it and re-think — the plan assumes only `MainScaffold` uses `entries.forEach` (which is order-independent).

- [ ] **Step 2: Reorder the enum**

In `app/src/main/java/com/kajhobe/app/ui/navigation/Destinations.kt`, replace the entire `TopLevelDestination` enum with:

```kotlin
enum class TopLevelDestination(
    val route: String,
    val label: String,
    val icon: ImageVector,
) {
    JOBS("jobs", "Jobs", Icons.Filled.Work),
    MESSAGES("messages", "Messages", Icons.AutoMirrored.Filled.Message),
    POST("post", "Post", Icons.Filled.AddCircle),
    DASHBOARD("dashboard", "Dashboard", Icons.Filled.BarChart),
    NOTIFICATIONS("notifications", "Notifications", Icons.Filled.Notifications),
}
```

The change: NOTIFICATIONS and DASHBOARD swapped (DASHBOARD now 4th, NOTIFICATIONS now 5th).

- [ ] **Step 3: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/navigation/Destinations.kt
git commit -m "fix(nav): move Dashboard to 4th, Notifications to 5th (matches iOS)"
```

---

## Task 6: Pin chat to bottom with `reverseLayout`

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/messages/ChatScreen.kt`

- [ ] **Step 1: Audit existing chat scroll behavior**

Run:
```bash
cd /Volumes/Experiment/GitHub/KajHobe && grep -n "scrollToItem\|listState\|LazyColumn" Android/app/src/main/java/com/kajhobe/app/ui/feature/messages/ChatScreen.kt
```
Note the `listState` variable name and any `scrollToItem` calls.

- [ ] **Step 2: Read the LazyColumn block**

Open `ChatScreen.kt` and find the `LazyColumn` (around line 134). The current code looks like:

```kotlin
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f).fillMaxWidth(),
                contentPadding = PaddingValues(KajHobeTheme.spacing.md),
                verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
            ) {
                items(...) { ... }
            }
```

- [ ] **Step 3: Add `reverseLayout = true` and `reverseArrangement = true`**

Replace the LazyColumn with:

```kotlin
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f).fillMaxWidth(),
                contentPadding = PaddingValues(KajHobeTheme.spacing.md),
                verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
                reverseLayout = true,
            ) {
                items(...) { ... }
            }
```

If you also want the items visually ordered top→bottom = oldest→newest, that's the default with `reverseLayout = true` because the LazyColumn renders from the end of the list and the `items` order is oldest→newest. The latest message is at the bottom (visual end), right above the input bar.

- [ ] **Step 4: Update any auto-scroll code**

If there is a `LaunchedEffect` that calls `listState.scrollToItem(...)`, update it to use index 0 (the visually last message) instead of `items.lastIndex`. Example transformation:

Before: `listState.animateScrollToItem(messages.lastIndex)`
After: `listState.animateScrollToItem(0)`

Apply the same change to any equivalent `scrollToItem` call in the file.

- [ ] **Step 5: Compile**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:compileDebugKotlin
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 6: Commit**
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add Android/app/src/main/java/com/kajhobe/app/ui/feature/messages/ChatScreen.kt
git commit -m "fix(chat): reverseLayout LazyColumn so messages anchor to bottom"
```

---

## Task 7: Build + tests + lint verification

- [ ] **Step 1: Run unit tests**
```bash
cd /Volumes/Experiment/GitHub/KajHobe/Android && ./gradlew :app:testDebugUnitTest
```
Expected: BUILD SUCCESSFUL (15/15 tests pass).

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

Update the spec's status line:
```bash
cd /Volumes/Experiment/GitHub/KajHobe && git add docs/superpowers/specs/2026-06-16-android-density-tabs-chat-design.md
git commit -m "docs(spec): mark density + tabs + chat-pin design as implemented"
```

Edit the spec file's `**Status:**` line from `Approved design — ready for implementation plan` to `Implemented (2026-06-16) — see docs/superpowers/plans/2026-06-16-android-density-tabs-chat.md`.

- [ ] **Step 5: Manual visual verification**

Run on emulator and confirm:
- [ ] Stat cards are ~70dp tall
- [ ] Overview card hugs content
- [ ] Analytics card sections are closer together
- [ ] Last card on dashboard has 32dp breathing room above the bottom nav
- [ ] Tab order is Jobs, Messages, Post, Dashboard, Notifications
- [ ] Chat messages anchor to the bottom
- [ ] Chat scroll-up still works
- [ ] New chat messages scroll into view at the bottom

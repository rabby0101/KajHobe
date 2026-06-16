# KajHobe Android Dashboard + Icon System Polish — Design Spec

**Date:** 2026-06-16
**Author:** Sk Fazla Rabby (with Claude)
**Status:** Approved design — ready for implementation plan

## 1. Goal

Polish the Android dashboard and align iconography across the app so the visual
quality matches the iOS app and feels "premium," not "ugly as hell." This is a
**visual-only pass** — no behavior, data flow, or screen logic changes.

User decisions driving this spec:
- **Full premium redesign** scope (charts + nav + icons + card density).
- **Approach B**: dashboard polish + app-wide icon sweep.
- **Replace donut with horizontal segmented status bar** (eliminates overlap risk).
- Keep **1:1 iOS parity** for behavior and screen content.

## 2. Current state (from the screenshot)

Critical issues observed in the live emulator:

1. **Donut chart labels overlap the donut** — "Resolved" / "Disputed" text renders on top of the donut, not beside it.
2. **Bar chart Y-axis shows raw ৳ values** (0 to 2,000,000) instead of abbreviated `৳1.2M` / `৳800K`.
3. **Bar chart has thin "ghost" slivers** in months with no data (Jul, Sep, Dec, Jun).
4. **Bar chart legend is cramped** against the X-axis labels.
5. **An extra "Completed" text artifact** appears inside the donut (rendering bug from a label).
6. **Card padding is wrong** — chart content touches the card edges, and the card itself is too tall.
7. **"Analytics" section header is missing** — the card goes straight to "Money flow".
8. **Bottom nav: "Notifications" wraps to two lines**, and the "Dashboard" tab shows an unusually green pill.
9. **Icon inconsistency** — the new dashboard code uses some `material.icons.outlined.*` (StarOutline) and some `material.icons.filled.*` variants; the rest of the app uses filled.
10. **Stat card values** are visually light compared to the iOS design.

## 3. Target state

### 3.1 Visual rules (apply app-wide)

- **Icons: filled only.** All `Icons.Filled.*` from `material-icons-extended` (already a dep).
- **One-line tab labels:** `maxLines = 1`, `softWrap = false`.
- **Selected nav indicator:** M3 default `NavigationBarItemDefaults.colors()` (soft `SecondaryContainer` pill), not a custom green pill.
- **Card section header pattern** (unified):
  ```
  [icon 18dp tinted accent]  Section Title (titleMedium, 600)   [optional: count or legend]
  ─────────────────────────────────────────────────────────────────────────────
  [content]
  ```
- **Card internal padding:** 16dp top/horizontal, 12dp between sections, 1dp `divider` color hairline between sections.
- **Stat card value typography:** `headlineSmall` (was `titleLarge`).
- **Section spacing:** 16dp between major sections (was `KajHobeTheme.spacing.md` = 12dp).

### 3.2 Dashboard chart card (the biggest offender)

**Replace donut with horizontal segmented status bar:**
- One row per status, sorted by count desc
- Each row: 8dp colored dot + status name (bodyMedium) + count (titleSmall, semibold, right-aligned) + proportional capsule bar
- Reuses the same `DistributionBars` pattern from the reputation card → visual consistency

**Bar chart fixes:**
- `legend.isEnabled = false` (the legend is a visual mess; move swatches to the section header inline)
- Hide months with `amount == 0` from X axis (filter before passing to MPAndroidChart)
- `xAxis.granularity = 1f`, `xAxis.isGranularityEnabled = true`
- `axisLeft.axisMinimum = 0f` and let MPAndroidChart auto-pick a nice round `axisMaximum`
- Custom `ValueFormatter` formats Y values as `৳1.2M`, `৳800K`, `৳0`
- Chart height locked to `160dp` (was `180dp`)
- Card padding `16dp` top so the chart doesn't kiss the card edge
- Inline legend in section header: `● Earned  ● Spent` with the same colors as the bars

**Card layout:**
```
┌────────────────────────────────────────────┐
│ [📊]  Analytics                  ● Earned  │
│                               ● Spent     │
│ ─────────────────────────────────────────  │
│                                            │
│ Money flow                                 │
│ [BarChart 160dp]                           │
│                                            │
│ ─────────────────────────────────────────  │
│                                            │
│ Deal status                                │
│ ● Completed                    58          │
│   ████████████░░░░░░░░                      │
│ ● Resolved                      2          │
│   ██░░░░░░░░░░░░░░░░░░░                    │
│ ● Disputed                      1          │
│   █░░░░░░░░░░░░░░░░░░░░                    │
│                                            │
│ ─────────────────────────────────────────  │
│                                            │
│ Rating trend                               │
│ [LineChart 140dp]                          │
│                                            │
└────────────────────────────────────────────┘
```

### 3.3 Reputation card

Mostly already polished. Tweaks:
- Confirm the trust badge in the header is right-aligned with a `compact` style.
- Add 1dp hairline divider between the trust progress row and the distribution bars (matches the chart card).
- The 5-star distribution bars already look right; bump the count text to `labelMedium` semibold for parity with the new status bar.

### 3.4 Stats grid

- Bump value typography to `headlineSmall` for visual weight.
- Add 1px hairline `divider` color bottom border to each card.
- Section header "Overview" gets the same treatment as the chart card (icon + title).

### 3.5 Active deals / Recent activity

- Tighten internal padding to 12dp.
- Add hairline divider between rows in a list section.

### 3.6 Files I'll touch

**Dashboard feature:**
- `ui/feature/dashboard/DashboardChartsSection.kt` — rewrite (status bar, fixed bar chart, hidden legend, inline legend in header)
- `ui/feature/dashboard/DashboardReputationCard.kt` — minor polish
- `ui/feature/dashboard/DashboardScreen.kt` — apply new card padding, stat typography, section spacing
- `ui/feature/dashboard/NotificationSettingsScreen.kt` — `Icons.AutoMirrored.Filled.ArrowBack` already in use; verify only

**Navigation:**
- `ui/navigation/MainScaffold.kt` — single-line labels, M3 default selected indicator, uniform icon weight

**App-wide icon sweep** (audit + fix any `material.icons.outlined.*` imports in new code; existing app code already uses filled):
- grep `material.icons.outlined` in `app/src/main/java/com/kajhobe/app` — confirm only the new dashboard files
- For each, replace with the filled equivalent

## 4. Out of scope

- Functional behavior (no data flow changes)
- New chart types or aggregations
- Dark mode tweaks (the dark theme is already correct via the existing `KajHobeTheme`)
- Animations beyond the existing `withAnimation` calls
- Localizing the new strings
- Replacing MPAndroidChart with a different chart lib

## 5. Testing

- Build (`./gradlew :app:assembleDebug`) passes
- All 15 unit tests still pass
- Lint (`./gradlew :app:lintDebug`) passes
- Visual check on emulator:
  - Dashboard renders cleanly with no chart overlap
  - All 4 stat cards have consistent typography
  - Status rows look like the iOS rating distribution
  - Bar chart Y axis shows `৳1.2M` style
  - Bottom nav fits all 5 labels on one line
  - All icons consistent weight across screens

## 6. Risks

- **MPAndroidChart layout quirks on different densities** — chart height locked to 160dp, legend hidden, custom Y formatter handles locale.
- **Custom Y-axis formatter** — use `java.text.DecimalFormat` with `RoundingMode.HALF_UP`.
- **iOS parity still holds** — no behavior changes, only visual.

## 7. Definition of done

- All 5 issues from the screenshot are fixed in the next build.
- No new lint errors, no new test failures.
- Debug APK builds, installs, and renders correctly on emulator.
- Visual parity with iOS Dashboard maintained (same data, same sections, same drill-downs).

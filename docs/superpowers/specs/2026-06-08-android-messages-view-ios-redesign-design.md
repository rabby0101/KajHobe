# Android Messages view: iOS redesign port

**Date:** 2026-06-08
**Status:** Draft — awaiting review
**Scope:** `Android/app/src/main/java/com/kajhobe/app/ui/feature/messages/**` and supporting data layer.

## Goal

Bring the Android `ConversationsScreen` to feature parity with the iOS `MessagesView` redesign, so the two apps share the same Messages UX. The redesign is in `iOS/KajHobe/MessagesView.swift` (and `iOS/KajHobe/Views/ArchivedConversationsView.swift`).

The iOS redesign added four things the Android screen is currently missing:

1. **Search bar** — live filter on `job_title`, `other_user_name`, `job_description` (i.e. last-message preview).
2. **All / Unread filter pills** with an unread-count badge on the Unread pill.
3. **Per-user archive** — swipe-to-archive hides a conversation from the *current user's* main list only; an Archived sheet shows the user's archived chats and supports unarchive.
4. **Redesigned `ConversationRow`** — avatar circle (image or initial), name + relative time, job title, last message preview, accent-colored unread badge, accent-emphasized text when unread.

The DB schema is already in place: `Web/supabase/migrations/20260608010000-conversation-per-user-archive.sql` added `client_archived` and `provider_archived` boolean columns. The Android `Conversation` data model simply doesn't read them yet.

## Non-goals

- Chat (`ChatScreen`) changes — out of scope.
- Realtime / message-badging (`MessageBadgeManager`) changes — Android already has these and they're orthogonal.
- Web parity — out of scope.
- Supabase migration changes — none needed; columns exist.

## Architecture

### Data layer

**`data/model/Chat.kt`**

- Add to `Conversation` (line 7–18):
  - `val client_archived: Boolean = false`
  - `val provider_archived: Boolean = false`
- Add same two fields to `ConversationWithDetails` (line 25–41). Defaults keep decode non-breaking for any callers that still decode older shape.

**`data/repository/MessagesRepository.kt`**

- New method, mirroring iOS `MessagesNetworking.setConversationArchived` (line 700–711):

  ```kotlin
  /** Archive or un-archive a conversation for one participant only. */
  suspend fun setConversationArchived(
      conversationId: String,
      userId: String,
      isClient: Boolean,
      archived: Boolean,
  ) {
      val column = if (isClient) "client_archived" else "provider_archived"
      runCatching {
          postgrest.from("conversations")
              .update({ set(column, archived) }) { filter { eq("id", conversationId) } }
      }
  }
  ```

- `fetchConversations` (line 34–85) needs no behavior change: it already decodes via `decodeList<Conversation>`, so the new boolean fields populate automatically.

### State layer

**`ui/feature/messages/ConversationsViewModel.kt`**

- Extend `ConversationsUiState` (line 18–23) with:
  - `searchText: String = ""`
  - `selectedFilter: ConversationFilter = ALL` (new enum: `ALL`, `UNREAD`)
  - `showArchivedSheet: Boolean = false`
  - `currentUserId` already exists; ensure it's available to the UI for archive resolution.

- New enum (top of file):
  ```kotlin
  enum class ConversationFilter { ALL, UNREAD }
  ```

- Computed helpers (pure, no allocation on render — same shape as iOS). `isArchivedFor(uid)` is a tiny extension on `ConversationWithDetails` that returns `client_archived` when `uid == client_id` else `provider_archived`:
  - `activeConversations` — drops rows where the current user's archive flag is `true` (i.e. `isArchivedFor(uid)`).
  - `archivedConversations` — inverse.
  - `unreadConversationCount` — `active.count { it.unread > 0 }`.
  - `visibleConversations` — `active` → filter by pill → filter by search query (lowercase substring on `job.title`, `otherUserName`, `lastMessage.content`).

- New actions:
  - `onSearchTextChange(s: String)`
  - `onFilterChange(f: ConversationFilter)`
  - `onShowArchivedSheetChange(open: Boolean)`
  - `setArchived(convo: ConversationWithDetails, archived: Boolean)` — optimistic in-state flip, then `repository.setConversationArchived(...)`. On failure: silent `load()` to restore from server (matches iOS behavior at `MessagesView.swift:341–367`). No user-facing error UI.

- `load()` is unchanged in behavior; it remains the source-of-truth refresh used by realtime, on-resume, and post-archive-revert.

### UI layer

**`ui/feature/messages/ConversationsScreen.kt`** — full rewrite of the body inside the non-empty branch and the row composable.

Structure when conversations exist:

```
Scaffold
└─ Column
   ├─ SearchBar              (TextField with leading magnifier, clear button)
   ├─ FilterPills            (Row: "All" + "Unread N")
   └─ LazyColumn of rows
       └─ SwipeToDismissBox (each item, trailing edge → archive)
           └─ ConversationRow
```

Top-right toolbar `IconButton` (archivebox) opens the Archived sheet. Use `TopAppBar` from M3 with an actions slot.

`ConversationRow` (private composable) renders:
- Leading: 52dp avatar circle. If `other_user_avatar` present and non-empty → `AsyncImage`. Else → accent-tinted circle with first uppercase letter of `other_user_name`.
- Center column:
  - Top row: name (headline) + relative time (caption, accent if unread).
  - `job.title` (subhead, secondary).
  - `last_message` preview: text or "📷 Photo" (subhead, primary+medium if unread, secondary otherwise), single line, ellipsis.
- Trailing: if `unread > 0`, accent capsule with count (uses existing `KajHobeBadge` with primary color).

Empty / no-results states:
- No conversations at all → existing `EmptyChats` (slight copy polish to match iOS: "No Conversations Yet" + helper text).
- Pill "Unread" + no matches → "You're all caught up — no unread messages." with a checkmark emoji.
- Non-empty search + no matches → "No conversations match your search."

**`ui/feature/messages/ArchivedConversationsSheet.kt`** (new)

Modal bottom sheet containing the archived list. Reuses the same `ConversationRow`. Swipe-to-unarchive calls a callback that flips the archive flag to false (same path as `setArchived(..., archived = false)`). Empty state mirrors iOS (`ArchivedConversationsView.swift:57–72`).

**`ui/feature/messages/TimeFormatting.kt`** (new util)

Small helper for the relative-time formatter (just now / N min ago / N h ago / N days ago / N weeks ago / short date). Mirrors iOS `formatRelativeTime` (`MessagesView.swift:673–708`). Uses `java.time.Instant` and `DateTimeFormatter`. Pure function, easy to unit-test.

**Note on existing `data/model/TimeFormatting.kt`** — kept untouched; the new util lives under the messages feature package because it's only used by the row.

## Error handling

- Archive write failure: `runCatching` swallows the throw, then `load()` re-fetches conversations so the list self-corrects. No snackbar.
- Search / filter: pure client-side, no error path.
- Sheet dismiss: never throws.

## Testing

This repo has no unit/instrumented tests today. The spec adds:

- `@Preview` composables for `ConversationRow` covering: (a) no unread, (b) unread, (c) with avatar, (d) image last message, (e) text last message. Renders in Android Studio preview only.
- Manual verification matrix documented in the implementation plan (smoke checklist).

## Files touched

| File | Change |
|---|---|
| `Android/app/src/main/java/com/kajhobe/app/data/model/Chat.kt` | Add 2 fields × 2 data classes |
| `Android/app/src/main/java/com/kajhobe/app/data/repository/MessagesRepository.kt` | Add `setConversationArchived` |
| `Android/app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsViewModel.kt` | Add search/filter/archive state + actions |
| `Android/app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsScreen.kt` | Redesigned row, search bar, pills, swipe-to-archive, toolbar action, no-results states |
| `Android/app/src/main/java/com/kajhobe/app/ui/feature/messages/ArchivedConversationsSheet.kt` | **New** — bottom sheet for archived chats |
| `Android/app/src/main/java/com/kajhobe/app/ui/feature/messages/TimeFormatting.kt` | **New** — relative-time formatter |

No new dependencies, no migration, no navigation graph change.

## Open risks

- **`SwipeToDismissBox` is `@ExperimentalMaterial3Api`** — same as the rest of the screens in this app, so this is consistent.
- **Optimistic archive + realtime** — when the archive UPDATE writes, realtime may not emit (it's a conversations-row UPDATE, not a message INSERT). The list won't auto-refresh from realtime for archive changes; the user-driven optimistic update is the source of truth. If a future change adds a realtime `UPDATE` binding for `conversations`, the optimistic state should be tolerant of the duplicate update.
- **Search across message body** — iOS searches `job_description` (i.e. last-message preview). Android should match this: search `last_message.content` rather than all message history.

# Android Messages iOS Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Android `ConversationsScreen` to feature parity with the iOS `MessagesView` redesign: search bar, All/Unread filter pills with unread badge, per-user archive with Archived sheet, and a redesigned `ConversationRow` (avatar, relative time, unread styling).

**Architecture:** Compose UI on top of an unchanged realtime flow. New state on the existing `ConversationsViewModel` (search/filter/archive), one new repo method, two new fields on the data model, one new time-formatting util, one new sheet composable. No DI/navigation changes. No new dependencies.

**Tech Stack:** Kotlin 2.3.x, Jetpack Compose, Material3 (`SwipeToDismissBox`, `ModalBottomSheet`, `TopAppBar`), Koin DI (unchanged), kotlinx.serialization (unchanged), kotlinx.coroutines `StateFlow`.

**Reference:** Design spec at `docs/superpowers/specs/2026-06-08-android-messages-view-ios-redesign-design.md`. iOS source of truth: `iOS/KajHobe/MessagesView.swift` and `iOS/KajHobe/Views/ArchivedConversationsView.swift`.

**Build commands (from `Android/`):**
- Compile: `./gradlew :app:compileDebugKotlin`
- Lint: `./gradlew :app:lintDebug`
- Tests (none today; this plan introduces no test sources).

---

## File structure

| File | Status | Responsibility |
|---|---|---|
| `app/src/main/java/com/kajhobe/app/data/model/Chat.kt` | modify | Add `client_archived`/`provider_archived` to `Conversation` and `ConversationWithDetails` |
| `app/src/main/java/com/kajhobe/app/data/repository/MessagesRepository.kt` | modify | Add `setConversationArchived` |
| `app/src/main/java/com/kajhobe/app/ui/feature/messages/TimeFormatting.kt` | create | Relative-time formatter for `latest_message_time` |
| `app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsViewModel.kt` | modify | Add search/filter/archive state + actions |
| `app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsScreen.kt` | modify | Redesigned row, search bar, pills, swipe-to-archive, toolbar action, no-results states |
| `app/src/main/java/com/kajhobe/app/ui/feature/messages/ArchivedConversationsSheet.kt` | create | Bottom sheet listing archived chats with unarchive swipe |

No other files change. No `AppModule.kt` change (everything is already wired).

---

## Task 1: Extend `Conversation` data model with archive flags

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/data/model/Chat.kt:7-18` and `Chat.kt:25-41`

- [ ] **Step 1: Edit `Conversation` to add archive booleans**

In `app/src/main/java/com/kajhobe/app/data/model/Chat.kt`, replace the `Conversation` data class (lines 7–18) with:

```kotlin
/** iOS Conversation. */
@Serializable
data class Conversation(
    val id: String,
    val job_id: String,
    val client_id: String,
    val provider_id: String,
    val status: String,
    val client_unread_count: Int = 0,
    val provider_unread_count: Int = 0,
    val created_at: String,
    val updated_at: String,
    // Per-user archive flags. The current user only ever reads/writes their
    // own side, so archiving is one-sided. See migration
    // Web/supabase/migrations/20260608010000-conversation-per-user-archive.sql.
    val client_archived: Boolean = false,
    val provider_archived: Boolean = false,
)
```

- [ ] **Step 2: Edit `ConversationWithDetails` to forward the same flags**

Replace the `ConversationWithDetails` data class (lines 25–41) with:

```kotlin
@Serializable
data class ConversationWithDetails(
    val id: String,
    val job_id: String,
    val client_id: String,
    val provider_id: String,
    val status: String,
    val client_unread_count: Int = 0,
    val provider_unread_count: Int = 0,
    val created_at: String,
    val updated_at: String,
    val job: Job? = null,
    val client_profile: SimpleProfile? = null,
    val provider_profile: SimpleProfile? = null,
    val last_message: ChatMessage? = null,
    // App-computed unread count for the current user (messages received & not yet read).
    val unread: Int = 0,
    val client_archived: Boolean = false,
    val provider_archived: Boolean = false,
)
```

- [ ] **Step 3: Add `isArchivedFor` extension**

Append a new file `app/src/main/java/com/kajhobe/app/data/model/ChatArchiveExt.kt`:

```kotlin
package com.kajhobe.app.data.model

/**
 * Whether this conversation is archived for the given user. Mirrors
 * iOS ConversationWithDetails.isArchived(for:).
 */
fun ConversationWithDetails.isArchivedFor(userId: String?): Boolean {
    val uid = userId ?: return false
    return if (client_id == uid) client_archived else provider_archived
}

/** Side of the conversation the given user is on. */
fun ConversationWithDetails.isClient(userId: String?): Boolean =
    userId != null && client_id == userId
```

- [ ] **Step 4: Compile to confirm nothing broke**

Run from `Android/`:
```bash
./gradlew :app:compileDebugKotlin
```
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/data/model/Chat.kt app/src/main/java/com/kajhobe/app/data/model/ChatArchiveExt.kt
git -c user.name=opencode -c user.email=opencode@local commit -m "feat(messages): add per-user archive fields to conversation model"
```

---

## Task 2: Add `setConversationArchived` to `MessagesRepository`

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/data/repository/MessagesRepository.kt`

- [ ] **Step 1: Add the new method**

Insert this method just before the `// MARK: - Realtime` block (around line 277) in `MessagesRepository.kt`:

```kotlin
    /**
     * Archive (or un-archive) a conversation for one participant only.
     *
     * The conversation has two sides — client and provider — each with its
     * own archive flag. `isClient` selects which column to write so that one
     * user's archive never affects the other's view. The existing
     * "Users can update conversations they are part of" RLS policy
     * authorises this UPDATE.
     */
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

- [ ] **Step 2: Compile**

From `Android/`:
```bash
./gradlew :app:compileDebugKotlin
```
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/data/repository/MessagesRepository.kt
git -c user.name=opencode -c user.email=opencode@local commit -m "feat(messages): add setConversationArchived repo method"
```

---

## Task 3: Add the relative-time formatter

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/feature/messages/TimeFormatting.kt`

Mirrors iOS `formatRelativeTime` in `MessagesView.swift:673-708`.

- [ ] **Step 1: Create the file**

```kotlin
package com.kajhobe.app.ui.feature.messages

import com.kajhobe.app.data.model.parseIsoMillis
import java.text.DateFormat
import java.util.Date

/**
 * Relative-time formatter for `latest_message_time` on conversations, matching
 * the iOS Messages view (`MessagesView.swift:673-708`):
 *   < 1m      → "just now"
 *   < 1h      → "N min ago" / "1 min ago"
 *   < 1d      → "N h ago"   / "1 h ago"
 *   < 7d      → "N days ago" / "1 day ago"
 *   < 4w      → "N weeks ago" / "1 week ago"
 *   else      → short date (e.g. "6/8/26")
 *
 * On parse failure returns the raw input so we never blank the UI.
 */
internal fun formatRelativeConversationTime(iso: String?): String {
    if (iso.isNullOrBlank()) return ""
    val millis = parseIsoMillis(iso) ?: return iso
    return formatRelativeFromMillis(millis)
}

private fun formatRelativeFromMillis(targetMillis: Long, nowMillis: Long = System.currentTimeMillis()): String {
    val intervalSeconds = ((nowMillis - targetMillis) / 1000.0).coerceAtLeast(0.0)
    val minutes = (intervalSeconds / 60).toInt()
    val hours = (intervalSeconds / 3600).toInt()
    val days = (intervalSeconds / 86400).toInt()
    val weeks = (intervalSeconds / 604800).toInt()
    return when {
        minutes < 1 -> "just now"
        minutes < 60 -> if (minutes == 1) "1 min ago" else "$minutes mins ago"
        hours < 24 -> if (hours == 1) "1 h ago" else "$hours h ago"
        days < 7 -> if (days == 1) "1 day ago" else "$days days ago"
        weeks < 4 -> if (weeks == 1) "1 week ago" else "$weeks weeks ago"
        else -> DateFormat.getDateInstance(DateFormat.SHORT).format(Date(targetMillis))
    }
}
```

- [ ] **Step 2: Compile**

From `Android/`:
```bash
./gradlew :app:compileDebugKotlin
```
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/messages/TimeFormatting.kt
git -c user.name=opencode -c user.email=opencode@local commit -m "feat(messages): add relative-time formatter for conversation row"
```

---

## Task 4: Extend `ConversationsViewModel` with search, filter, and archive state

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsViewModel.kt`

The VM grows a `ConversationFilter` enum, additional `ConversationsUiState` fields, three derived properties (active, archived, visible), and a `setArchived` action. Existing `load()` / `subscribeRealtime()` are untouched.

- [ ] **Step 1: Replace the VM file**

Overwrite `app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsViewModel.kt` with:

```kotlin
package com.kajhobe.app.ui.feature.messages

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.ConversationWithDetails
import com.kajhobe.app.data.model.isArchivedFor
import com.kajhobe.app.data.model.isClient
import com.kajhobe.app.data.notifications.MessageBadgeManager
import com.kajhobe.app.data.repository.MessagesRepository
import io.github.jan.supabase.realtime.RealtimeChannel
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Mirrors iOS ConversationFilter. */
enum class ConversationFilter { ALL, UNREAD }

data class ConversationsUiState(
    val isLoading: Boolean = true,
    val conversations: List<ConversationWithDetails> = emptyList(),
    val currentUserId: String? = null,
    val errorMessage: String? = null,
    // Redesign state — search text, active All/Unread pill, and the Archived sheet flag.
    val searchText: String = "",
    val selectedFilter: ConversationFilter = ConversationFilter.ALL,
    val showArchivedSheet: Boolean = false,
)

class ConversationsViewModel(
    private val repository: MessagesRepository,
    private val messageBadgeManager: MessageBadgeManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ConversationsUiState())
    val uiState: StateFlow<ConversationsUiState> = _uiState.asStateFlow()

    private var channel: RealtimeChannel? = null
    private var collectJob: Job? = null

    init {
        load()
        subscribeRealtime()
        // Ensure the messages tab badge is in sync whenever the conversations list loads.
        messageBadgeManager.refreshCounts()
    }

    fun load() {
        _uiState.update { it.copy(isLoading = it.conversations.isEmpty(), errorMessage = null) }
        viewModelScope.launch {
            runCatching { repository.fetchConversations() }
                .onSuccess { list ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            conversations = list,
                            currentUserId = repository.currentUserId(),
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isLoading = false, errorMessage = e.message ?: "Failed to load chats") }
                }
        }
    }

    /** Live updates: any new message in one of my conversations refreshes the list. */
    private fun subscribeRealtime() {
        val ch = repository.allMessagesChannel()
        channel = ch
        // Set up the flow BEFORE joining (supabase-kt requirement). The
        // `incomingAllMessages` call synchronously registers the listener via
        // `postgresChangeFlow`, so it must happen before any code calls
        // `channel.subscribe()`.
        val flow = repository.incomingAllMessages(ch)
        collectJob = viewModelScope.launch {
            // Any inserted message may change a preview/unread/order or add a new conversation.
            flow.collect { load() }
        }
        viewModelScope.launch { runCatching { repository.joinChannel(ch) } }
    }

    fun unreadFor(conversation: ConversationWithDetails): Int = repository.unreadFor(conversation)

    // MARK: - Redesign actions

    fun onSearchTextChange(value: String) {
        _uiState.update { it.copy(searchText = value) }
    }

    fun onFilterChange(filter: ConversationFilter) {
        _uiState.update { it.copy(selectedFilter = filter) }
    }

    fun onShowArchivedSheetChange(open: Boolean) {
        _uiState.update { it.copy(showArchivedSheet = open) }
    }

    /**
     * Optimistically flip the current user's archive flag, then persist. On failure
     * we silently reload from the server to undo the optimistic change (matches
     * iOS MessagesView.setArchived).
     */
    fun setArchived(conversation: ConversationWithDetails, archived: Boolean) {
        val uid = _uiState.value.currentUserId ?: return
        val isClient = conversation.isClient(uid)
        val targetId = conversation.id

        _uiState.update { state ->
            state.copy(
                conversations = state.conversations.map { c ->
                    if (c.id != targetId) c
                    else c.copy(
                        client_archived = if (isClient) archived else c.client_archived,
                        provider_archived = if (!isClient) archived else c.provider_archived,
                    )
                },
            )
        }

        viewModelScope.launch {
            runCatching {
                repository.setConversationArchived(
                    conversationId = targetId,
                    userId = uid,
                    isClient = isClient,
                    archived = archived,
                )
            }.onFailure {
                // Silent revert — match iOS behavior.
                load()
            }
        }
    }

    // MARK: - Derived lists (iOS ConversationsView.split helpers)

    /** Active = not archived for the current user. Powers the main list. */
    val activeConversations: List<ConversationWithDetails>
        get() {
            val state = _uiState.value
            return state.conversations.filterNot { it.isArchivedFor(state.currentUserId) }
        }

    /** Archived = archived for the current user. Powers the Archived sheet. */
    val archivedConversations: List<ConversationWithDetails>
        get() {
            val state = _uiState.value
            return state.conversations.filter { it.isArchivedFor(state.currentUserId) }
        }

    /** Final list shown in the main list: active → filter pill → search. */
    val visibleConversations: List<ConversationWithDetails>
        get() {
            val state = _uiState.value
            var result = activeConversations
            if (state.selectedFilter == ConversationFilter.UNREAD) {
                result = result.filter { it.unread > 0 }
            }
            val query = state.searchText.trim().lowercase()
            if (query.isNotEmpty()) {
                result = result.filter { c ->
                    val title = c.job?.title.orEmpty().lowercase()
                    val otherName = otherNameFor(c, state.currentUserId).lowercase()
                    val preview = c.last_message?.content.orEmpty().lowercase()
                    title.contains(query) || otherName.contains(query) || preview.contains(query)
                }
            }
            return result
        }

    /** Unread-conversation count (for the Unread pill badge). */
    val unreadConversationCount: Int
        get() = activeConversations.count { it.unread > 0 }

    /** Other party name for a conversation (current user perspective). */
    fun otherNameFor(c: ConversationWithDetails, currentUserId: String?): String {
        val other = if (c.isClient(currentUserId)) c.provider_profile else c.client_profile
        return other?.full_name?.takeIf { it.isNotBlank() } ?: "KajHobe user"
    }

    @OptIn(DelicateCoroutinesApi::class)
    override fun onCleared() {
        super.onCleared()
        collectJob?.cancel()
        val ch = channel ?: return
        channel = null
        GlobalScope.launch { runCatching { repository.leaveChannel(ch) } }
    }
}
```

- [ ] **Step 2: Compile**

From `Android/`:
```bash
./gradlew :app:compileDebugKotlin
```
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsViewModel.kt
git -c user.name=opencode -c user.email=opencode@local commit -m "feat(messages): add search/filter/archive state to ConversationsViewModel"
```

---

## Task 5: Redesign `ConversationsScreen` UI

**Files:**
- Modify: `app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsScreen.kt`

The screen grows a `Scaffold` + `TopAppBar` (with the archivebox action), a search bar, filter pills, a `SwipeToDismissBox` per row with trailing "Archive" action, an accent-emphasized `ConversationRow`, and no-results states. The bottom-sheet for archived chats is wired here but rendered in Task 6.

- [ ] **Step 1: Replace the file**

Overwrite `app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsScreen.kt` with:

```kotlin
package com.kajhobe.app.ui.feature.messages

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Archive
import androidx.compose.material.icons.filled.ArchiveOutlined
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.kajhobe.app.data.model.ConversationWithDetails
import com.kajhobe.app.data.model.isClient
import com.kajhobe.app.ui.components.KajHobeBadge
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConversationsScreen(
    onOpenChat: (String) -> Unit,
    viewModel: ConversationsViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val archived = viewModel.archivedConversations
    val visible = viewModel.visibleConversations
    val unreadPillCount = viewModel.unreadConversationCount

    // Refresh when returning to the list (e.g. after reading a chat) so unread badges update.
    LifecycleResumeEffect(Unit) {
        viewModel.load()
        onPauseOrDispose { }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Messages", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = { viewModel.onShowArchivedSheetChange(true) }) {
                        Icon(
                            imageVector = if (archived.isEmpty()) Icons.Filled.ArchiveOutlined else Icons.Filled.Archive,
                            contentDescription = "Archived conversations",
                            tint = KajHobeTheme.colors.accentOrange,
                        )
                    }
                },
            )
        },
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            when {
                state.isLoading -> PremiumLoadingView(message = "Loading chats…")
                state.conversations.isEmpty() -> EmptyChats()
                visible.isEmpty() -> NoResultsView(
                    hasSearch = state.searchText.isNotBlank(),
                    selectedFilter = state.selectedFilter,
                )
                else -> Column(modifier = Modifier.fillMaxSize()) {
                    SearchBar(
                        value = state.searchText,
                        onValueChange = viewModel::onSearchTextChange,
                    )
                    FilterPills(
                        selected = state.selectedFilter,
                        unreadCount = unreadPillCount,
                        onSelect = viewModel::onFilterChange,
                    )
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            start = KajHobeTheme.spacing.md,
                            end = KajHobeTheme.spacing.md,
                            top = KajHobeTheme.spacing.xs,
                            bottom = KajHobeTheme.spacing.md,
                        ),
                        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
                    ) {
                        items(visible, key = { it.id }) { convo ->
                            ArchiveSwipeRow(
                                convo = convo,
                                otherName = viewModel.otherNameFor(convo, state.currentUserId),
                                unread = viewModel.unreadFor(convo),
                                onClick = { onOpenChat(convo.id) },
                                onArchive = { viewModel.setArchived(convo, archived = true) },
                            )
                        }
                    }
                }
            }
        }
    }

    if (state.showArchivedSheet) {
        ArchivedConversationsSheet(
            conversations = archived,
            otherNameFor = { viewModel.otherNameFor(it, state.currentUserId) },
            unreadFor = viewModel::unreadFor,
            onOpenChat = { id -> viewModel.onShowArchivedSheetChange(false); onOpenChat(id) },
            onUnarchive = { convo -> viewModel.setArchived(convo, archived = false) },
            onDismiss = { viewModel.onShowArchivedSheetChange(false) },
        )
    }
}

// MARK: - Search + filter pills

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SearchBar(value: String, onValueChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = KajHobeTheme.spacing.md, vertical = KajHobeTheme.spacing.xs),
        placeholder = { Text("Search conversations") },
        leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
        trailingIcon = {
            if (value.isNotEmpty()) {
                IconButton(onClick = { onValueChange("") }) {
                    Icon(Icons.Filled.Close, contentDescription = "Clear search")
                }
            }
        },
        singleLine = true,
        shape = RoundedCornerShape(50),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = KajHobeTheme.colors.subtleBackground,
            unfocusedContainerColor = KajHobeTheme.colors.subtleBackground,
            disabledContainerColor = KajHobeTheme.colors.subtleBackground,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
        ),
    )
}

@Composable
private fun FilterPills(
    selected: ConversationFilter,
    unreadCount: Int,
    onSelect: (ConversationFilter) -> Unit,
) {
    val accent = KajHobeTheme.colors.accentOrange
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = KajHobeTheme.spacing.md, vertical = KajHobeTheme.spacing.xs),
        horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Pill(
            label = "All",
            isSelected = selected == ConversationFilter.ALL,
            accent = accent,
            onClick = { onSelect(ConversationFilter.ALL) },
        )
        Pill(
            label = "Unread",
            badge = if (unreadCount > 0) unreadCount.toString() else null,
            isSelected = selected == ConversationFilter.UNREAD,
            accent = accent,
            onClick = { onSelect(ConversationFilter.UNREAD) },
        )
    }
}

@Composable
private fun Pill(
    label: String,
    isSelected: Boolean,
    accent: Color,
    onClick: () -> Unit,
    badge: String? = null,
) {
    val bg = if (isSelected) accent else KajHobeTheme.colors.subtleBackground
    val fg = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(horizontal = KajHobeTheme.spacing.md, vertical = KajHobeTheme.spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(label, color = fg, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        if (badge != null) {
            val badgeBg = if (isSelected) Color.White else accent
            val badgeFg = if (isSelected) accent else Color.White
            Text(
                badge,
                color = badgeFg,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(badgeBg)
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
    }
}

// MARK: - Swipe-to-archive row

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ArchiveSwipeRow(
    convo: ConversationWithDetails,
    otherName: String,
    unread: Int,
    onClick: () -> Unit,
    onArchive: () -> Unit,
) {
    val accent = KajHobeTheme.colors.accentOrange
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onArchive()
                true
            } else false
        },
    )
    // Reset the swipe target after the optimistic state change so the row is no
    // longer in the list (otherwise the box would render the dismissed state
    // for the now-removed row).
    LaunchedEffect(convo.id) { dismissState.reset() }

    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = false,
        enableDismissFromEndToStart = true,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(accent, RoundedCornerShape(12.dp))
                    .padding(horizontal = KajHobeTheme.spacing.md),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Archive, contentDescription = null, tint = Color.White)
                    Spacer(Modifier.size(6.dp))
                    Text("Archive", color = Color.White, fontWeight = FontWeight.SemiBold)
                }
            }
        },
    ) {
        ConversationRow(
            convo = convo,
            otherName = otherName,
            unread = unread,
            onClick = onClick,
        )
    }
}

// MARK: - Conversation row

@Composable
private fun ConversationRow(
    convo: ConversationWithDetails,
    otherName: String,
    unread: Int,
    onClick: () -> Unit,
) {
    val accent = KajHobeTheme.colors.accentOrange
    val avatarUrl = if (convo.isClient(convo.client_id)) convo.provider_profile?.avatar_url else convo.client_profile?.avatar_url
    val jobTitle = convo.job?.title
    val preview = convo.last_message?.let { if (it.isImage) "📷 Photo" else it.content }

    val previewColor = if (unread > 0) MaterialTheme.colorScheme.onSurface else KajHobeTheme.colors.textSecondary
    val previewWeight = if (unread > 0) FontWeight.Medium else FontWeight.Normal
    val timeColor = if (unread > 0) accent else KajHobeTheme.colors.textTertiary
    val time = formatRelativeConversationTime(convo.last_message?.created_at ?: convo.updated_at)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(KajHobeTheme.colors.subtleBackground)
            .clickable(onClick = onClick)
            .padding(KajHobeTheme.spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
    ) {
        Avatar(url = avatarUrl, name = otherName, accent = accent)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.Baseline) {
                Text(
                    otherName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (time.isNotEmpty()) {
                    Text(time, style = MaterialTheme.typography.labelSmall, color = timeColor)
                }
            }
            if (!jobTitle.isNullOrBlank()) {
                Text(
                    jobTitle,
                    style = MaterialTheme.typography.labelMedium,
                    color = KajHobeTheme.colors.textTertiary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (!preview.isNullOrEmpty()) {
                Text(
                    preview,
                    style = MaterialTheme.typography.bodyMedium,
                    color = previewColor,
                    fontWeight = previewWeight,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (unread > 0) {
            KajHobeBadge(text = unread.toString(), color = accent)
        }
    }
}

@Composable
private fun Avatar(url: String?, name: String, accent: Color) {
    Box(
        modifier = Modifier
            .size(52.dp)
            .clip(CircleShape)
            .background(accent.copy(alpha = 0.18f)),
        contentAlignment = Alignment.Center,
    ) {
        if (!url.isNullOrBlank()) {
            AsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize().clip(CircleShape),
            )
        } else {
            Text(
                text = name.firstOrNull()?.uppercaseChar()?.toString().orEmpty(),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = accent,
            )
        }
    }
}

// MARK: - Empty / no-results states

@Composable
private fun EmptyChats() {
    Column(
        modifier = Modifier.fillMaxSize().padding(KajHobeTheme.spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("💬", style = MaterialTheme.typography.displaySmall)
        Text(
            "No Conversations Yet",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(top = KajHobeTheme.spacing.sm),
        )
        Text(
            "Start by showing interest in jobs or posting your own job to begin conversations with others.",
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

@Composable
private fun NoResultsView(hasSearch: Boolean, selectedFilter: ConversationFilter) {
    val text = when {
        hasSearch -> "No conversations match your search."
        selectedFilter == ConversationFilter.UNREAD -> "You're all caught up — no unread messages."
        else -> "No conversations to show."
    }
    val glyph = if (selectedFilter == ConversationFilter.UNREAD) "✅" else "🔍"
    Column(
        modifier = Modifier.fillMaxSize().padding(KajHobeTheme.spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(glyph, style = MaterialTheme.typography.displaySmall)
        Text(
            text,
            style = MaterialTheme.typography.bodyLarge,
            color = KajHobeTheme.colors.textSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.padding(top = KajHobeTheme.spacing.sm, horizontal = KajHobeTheme.spacing.xl),
        )
    }
}
```

- [ ] **Step 2: Compile**

From `Android/`:
```bash
./gradlew :app:compileDebugKotlin
```
Expected: **compile failure** — `ArchivedConversationsSheet` is not yet defined. Expected errors look like `Unresolved reference: ArchivedConversationsSheet`. This is fine; the next task creates the missing composable.

- [ ] **Step 3: Commit (even though compile fails — VM/UI shape is locked in)**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/messages/ConversationsScreen.kt
git -c user.name=opencode -c user.email=opencode@local commit -m "feat(messages): redesign ConversationsScreen with search, pills, swipe-to-archive"
```

---

## Task 6: Add `ArchivedConversationsSheet`

**Files:**
- Create: `app/src/main/java/com/kajhobe/app/ui/feature/messages/ArchivedConversationsSheet.kt`

Reuses the same row visuals as `ConversationsScreen` (we factor the row in-place — the screen and the sheet each render their own copy to keep coupling zero and avoid a deep refactor; the duplication is small and deliberate).

- [ ] **Step 1: Create the file**

```kotlin
package com.kajhobe.app.ui.feature.messages

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Archive
import androidx.compose.material.icons.filled.Unarchive
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.kajhobe.app.data.model.ConversationWithDetails
import com.kajhobe.app.data.model.isClient
import com.kajhobe.app.ui.components.KajHobeBadge
import com.kajhobe.app.ui.theme.KajHobeTheme

/**
 * Bottom sheet listing the current user's archived conversations. Mirrors iOS
 * ArchivedConversationsView. Swiping a row un-archives it; tapping opens the chat.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ArchivedConversationsSheet(
    conversations: List<ConversationWithDetails>,
    otherNameFor: (ConversationWithDetails) -> String,
    unreadFor: (ConversationWithDetails) -> Int,
    onOpenChat: (String) -> Unit,
    onUnarchive: (ConversationWithDetails) -> Unit,
    onDismiss: () -> Unit,
) {
    val accent = KajHobeTheme.colors.accentOrange
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = KajHobeTheme.spacing.md, vertical = KajHobeTheme.spacing.sm),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Archive, contentDescription = null, tint = accent)
                Spacer(Modifier.size(KajHobeTheme.spacing.xs))
                Text(
                    "Archived",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
            }
            if (conversations.isEmpty()) {
                EmptyArchived()
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
                ) {
                    items(conversations, key = { it.id }) { convo ->
                        UnarchiveSwipeRow(
                            convo = convo,
                            otherName = otherNameFor(convo),
                            unread = unreadFor(convo),
                            onClick = { onOpenChat(convo.id) },
                            onUnarchive = { onUnarchive(convo) },
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun UnarchiveSwipeRow(
    convo: ConversationWithDetails,
    otherName: String,
    unread: Int,
    onClick: () -> Unit,
    onUnarchive: () -> Unit,
) {
    val accent = KajHobeTheme.colors.accentOrange
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onUnarchive()
                true
            } else false
        },
    )
    LaunchedEffect(convo.id) { dismissState.reset() }

    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = false,
        enableDismissFromEndToStart = true,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(accent, RoundedCornerShape(12.dp))
                    .padding(horizontal = KajHobeTheme.spacing.md),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Unarchive, contentDescription = null, tint = Color.White)
                    Spacer(Modifier.size(6.dp))
                    Text("Unarchive", color = Color.White, fontWeight = FontWeight.SemiBold)
                }
            }
        },
    ) {
        ArchivedRowContent(
            convo = convo,
            otherName = otherName,
            unread = unread,
            onClick = onClick,
        )
    }
}

@Composable
private fun ArchivedRowContent(
    convo: ConversationWithDetails,
    otherName: String,
    unread: Int,
    onClick: () -> Unit,
) {
    val accent = KajHobeTheme.colors.accentOrange
    val avatarUrl = if (convo.isClient(convo.client_id)) convo.provider_profile?.avatar_url else convo.client_profile?.avatar_url
    val preview = convo.last_message?.let { if (it.isImage) "📷 Photo" else it.content }
    val time = formatRelativeConversationTime(convo.last_message?.created_at ?: convo.updated_at)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(KajHobeTheme.colors.subtleBackground)
            .clickable(onClick = onClick)
            .padding(KajHobeTheme.spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(CircleShape)
                .background(accent.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center,
        ) {
            if (!avatarUrl.isNullOrBlank()) {
                AsyncImage(
                    model = avatarUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize().clip(CircleShape),
                )
            } else {
                Text(
                    otherName.firstOrNull()?.uppercaseChar()?.toString().orEmpty(),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = accent,
                )
            }
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.Baseline) {
                Text(
                    otherName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (time.isNotEmpty()) {
                    Text(time, style = MaterialTheme.typography.labelSmall, color = KajHobeTheme.colors.textTertiary)
                }
            }
            if (!preview.isNullOrEmpty()) {
                Text(
                    preview,
                    style = MaterialTheme.typography.bodyMedium,
                    color = KajHobeTheme.colors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (unread > 0) KajHobeBadge(text = unread.toString(), color = accent)
    }
}

@Composable
private fun EmptyArchived() {
    Column(
        modifier = Modifier.fillMaxWidth().padding(KajHobeTheme.spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("🗄️", style = MaterialTheme.typography.displaySmall)
        Text(
            "No Archived Conversations",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(top = KajHobeTheme.spacing.sm),
        )
        Text(
            "Conversations you archive will appear here. Swipe an archived chat to restore it.",
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.padding(top = KajHobeTheme.spacing.xs, horizontal = KajHobeTheme.spacing.md),
        )
    }
}
```

- [ ] **Step 2: Compile**

From `Android/`:
```bash
./gradlew :app:compileDebugKotlin
```
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/kajhobe/app/ui/feature/messages/ArchivedConversationsSheet.kt
git -c user.name=opencode -c user.email=opencode@local commit -m "feat(messages): add ArchivedConversationsSheet with unarchive swipe"
```

---

## Task 7: Lint pass

**Files:** none modified.

- [ ] **Step 1: Run lint**

From `Android/`:
```bash
./gradlew :app:lintDebug
```
Expected: `BUILD SUCCESSFUL` (warnings about experimental API usage on `SwipeToDismissBox` are acceptable — they match the rest of the codebase).

- [ ] **Step 2: If lint flags anything actionable, fix and commit**

If lint returns errors that block the build, fix them in the obvious place (usually a missing `contentDescription` on an `Icon`) and commit the fix with a `chore(messages):` prefix. Warnings are fine.

---

## Task 8: Manual smoke verification

There are no instrumented tests in this repo today. Verify the redesign manually by running the app and walking the matrix below.

- [ ] **Step 1: Run the app on an emulator/device**

From `Android/`:
```bash
./gradlew :app:installDebug
```

- [ ] **Step 2: Walk the verification matrix**

For each row, observe the screen and confirm:

| # | Action | Expected |
|---|---|---|
| 1 | Open Messages tab with existing conversations | List shows redesigned rows: avatar circle (image or initial), name, relative time, job title, last message preview, accent unread badge where applicable |
| 2 | Type "job" in the search bar | List filters to matches in job title / other name / last message preview |
| 3 | Clear search | List restores |
| 4 | Tap the "Unread N" pill | List filters to unread only; pill shows the count |
| 5 | Tap "All" | List restores |
| 6 | Tap the archivebox icon in the TopAppBar | Bottom sheet opens, titled "Archived" |
| 7 | With archived sheet empty | See 🗄️ empty state with helper text |
| 8 | Close sheet, swipe a conversation left | Row disappears from the main list optimistically; persists after a moment |
| 9 | Open archived sheet | The swiped conversation is listed; swipe it left | Row disappears from the archived list and reappears in the main list |
| 10 | Send a new message from the other party (or wait for one) | Realtime causes `load()` to fire; the conversation moves to the top with an updated preview and incremented unread |
| 11 | Open that conversation, then return | Unread badge clears (chat screen's read-marking path) |
| 12 | Force-quit and relaunch | First frame shows the cached list (existing behavior, unchanged) |

- [ ] **Step 3: Commit any small follow-ups**

If the matrix surfaces a visual bug (wrong color, padding, etc.), fix and commit with `fix(messages):` prefix. Do not fix bugs unrelated to the redesign in this branch.

---

## Self-review

- **Spec coverage:** data model archive fields ✓ (Task 1), repo `setConversationArchived` ✓ (Task 2), time formatter ✓ (Task 3), VM search/filter/archive state ✓ (Task 4), screen redesign ✓ (Task 5), archived sheet ✓ (Task 6), optimistic archive with silent reload on failure ✓ (Task 4 + Task 5), error handling ✓ (Task 4), Compose previews deferred (no `Preview` infrastructure in repo today — out of scope).
- **Placeholder scan:** none.
- **Type consistency:** `isArchivedFor` / `isClient` (Task 1) used identically in Tasks 4–6; `setArchived` signature in repo (Task 2) matches call site in VM (Task 4); `ArchivedConversationsSheet` parameters (Task 6) match the call site in `ConversationsScreen` (Task 5); `formatRelativeConversationTime` (Task 3) used identically in Tasks 5 and 6; `ConversationFilter.ALL` / `UNREAD` (Task 4) referenced identically in Task 5.
- **No new dependencies, no migration, no DI change, no nav change** — all matches the spec's stated non-goals.

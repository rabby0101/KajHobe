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
                            imageVector = Icons.Filled.Archive,
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
            Row(verticalAlignment = Alignment.CenterVertically) {
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
            modifier = Modifier.padding(vertical = KajHobeTheme.spacing.sm, horizontal = KajHobeTheme.spacing.xl),
        )
    }
}

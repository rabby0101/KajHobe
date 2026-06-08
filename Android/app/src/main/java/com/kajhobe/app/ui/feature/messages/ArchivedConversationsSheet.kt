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
    currentUserId: String?,
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
                            currentUserId = currentUserId,
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
    currentUserId: String?,
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
            currentUserId = currentUserId,
            otherName = otherName,
            unread = unread,
            onClick = onClick,
        )
    }
}

@Composable
private fun ArchivedRowContent(
    convo: ConversationWithDetails,
    currentUserId: String?,
    otherName: String,
    unread: Int,
    onClick: () -> Unit,
) {
    val accent = KajHobeTheme.colors.accentOrange
    val avatarUrl = if (convo.isClient(currentUserId)) convo.provider_profile?.avatar_url else convo.client_profile?.avatar_url
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
            modifier = Modifier.padding(top = KajHobeTheme.spacing.xs).padding(horizontal = KajHobeTheme.spacing.md),
        )
    }
}

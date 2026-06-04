package com.kajhobe.app.ui.feature.messages

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.ConversationWithDetails
import com.kajhobe.app.ui.components.KajHobeBadge
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel

@Composable
fun ConversationsScreen(
    onOpenChat: (String) -> Unit,
    viewModel: ConversationsViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // Refresh when returning to the list (e.g. after reading a chat) so unread badges update.
    LifecycleResumeEffect(Unit) {
        viewModel.load()
        onPauseOrDispose { }
    }

    when {
        state.isLoading -> PremiumLoadingView(message = "Loading chats…")
        state.conversations.isEmpty() -> EmptyChats()
        else -> LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(KajHobeTheme.spacing.md),
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
        ) {
            item {
                Text(
                    "Messages",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(vertical = KajHobeTheme.spacing.sm),
                )
            }
            items(state.conversations, key = { it.id }) { convo ->
                ConversationRow(
                    convo = convo,
                    currentUserId = state.currentUserId,
                    unread = viewModel.unreadFor(convo),
                    onClick = { onOpenChat(convo.id) },
                )
            }
        }
    }
}

@Composable
private fun ConversationRow(
    convo: ConversationWithDetails,
    currentUserId: String?,
    unread: Int,
    onClick: () -> Unit,
) {
    val otherName = if (convo.client_id == currentUserId) {
        convo.provider_profile?.full_name
    } else {
        convo.client_profile?.full_name
    } ?: "KajHobe user"

    PremiumCard(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(otherName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                convo.job?.title?.let {
                    Text(
                        it,
                        style = MaterialTheme.typography.labelMedium,
                        color = KajHobeTheme.colors.textTertiary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                convo.last_message?.let { msg ->
                    Text(
                        if (msg.isImage) "📷 Photo" else msg.content,
                        style = MaterialTheme.typography.bodyMedium,
                        color = KajHobeTheme.colors.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            if (unread > 0) {
                Box(modifier = Modifier.padding(start = KajHobeTheme.spacing.sm)) {
                    KajHobeBadge(text = unread.toString(), color = MaterialTheme.colorScheme.primary)
                }
            }
        }
    }
}

@Composable
private fun EmptyChats() {
    Column(
        modifier = Modifier.fillMaxSize().padding(KajHobeTheme.spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("💬", style = MaterialTheme.typography.displaySmall)
        Text("No conversations yet", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = KajHobeTheme.spacing.sm))
        Text(
            "Accept an interest request to start chatting.",
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
        )
    }
}

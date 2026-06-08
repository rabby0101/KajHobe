package com.kajhobe.app.ui.feature.notifications

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Message
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.DoneAll
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.EnhancedNotification
import com.kajhobe.app.data.model.EnrichedJobInterest
import com.kajhobe.app.data.model.timeAgo
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.theme.KajHobeTheme
import kotlinx.coroutines.flow.collectLatest
import androidx.compose.runtime.LaunchedEffect
import org.koin.androidx.compose.koinViewModel

private val AcceptGreen = Color(0xFF34C759)
private val RejectRed = Color(0xFFFF3B30)
private val ReadGray = Color(0xFF8E8E93)

@Composable
fun NotificationsScreen(
    onOpenDeal: (String) -> Unit = {},
    viewModel: NotificationsViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // Silently refresh whenever this tab becomes visible again.
    LifecycleResumeEffect(Unit) {
        viewModel.load(silent = true)
        onPauseOrDispose { }
    }

    LaunchedEffect(Unit) {
        viewModel.navigateToDeal.collectLatest { dealId -> onOpenDeal(dealId) }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        NotificationsHeader(
            onMarkAllRead = viewModel::markAllRead,
            onClearAll = viewModel::clearAll,
        )

        when {
            state.isLoading && state.feedItems.isEmpty() -> {
                PremiumLoadingView(message = "Loading notifications…")
            }

            state.feedItems.isEmpty() -> EmptyNotifications()

            else -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        horizontal = KajHobeTheme.spacing.md,
                        vertical = KajHobeTheme.spacing.sm,
                    ),
                    verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
                ) {
                    items(state.feedItems, key = { it.id }) { item ->
                        // Reading state.localRevision here keeps unread highlighting in sync.
                        val unread = state.localRevision.let { viewModel.isUnread(item) }
                        SwipeToClear(onClear = { viewModel.clear(item) }) {
                            when (item) {
                                is NotificationFeedItem.Interest -> InterestRow(
                                    interest = item.interest,
                                    accent = item.category.color,
                                    categoryLabel = item.category.label,
                                    isUnread = unread,
                                    isProcessing = item.interest.id in state.processingIds,
                                    onTap = { viewModel.onInterestTap(item.interest) },
                                    onAccept = { viewModel.respond(item.interest, accept = true) },
                                    onReject = { viewModel.respond(item.interest, accept = false) },
                                )

                                is NotificationFeedItem.Business -> BusinessRow(
                                    notification = item.notification,
                                    accent = item.category.color,
                                    categoryLabel = item.category.label,
                                    isUnread = unread,
                                    onTap = { viewModel.onBusinessTap(item.notification) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NotificationsHeader(onMarkAllRead: () -> Unit, onClearAll: () -> Unit) {
    var menuOpen by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = KajHobeTheme.spacing.md, end = KajHobeTheme.spacing.sm, top = KajHobeTheme.spacing.sm, bottom = KajHobeTheme.spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            "Notifications",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.weight(1f))
        Box {
            IconButton(onClick = { menuOpen = true }) {
                Icon(Icons.Filled.MoreVert, contentDescription = "More")
            }
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text("Mark all as read") },
                    leadingIcon = { Icon(Icons.Filled.DoneAll, contentDescription = null) },
                    onClick = { menuOpen = false; onMarkAllRead() },
                )
                DropdownMenuItem(
                    text = { Text("Clear all") },
                    leadingIcon = { Icon(Icons.Filled.Delete, contentDescription = null, tint = RejectRed) },
                    onClick = { menuOpen = false; onClearAll() },
                )
            }
        }
    }
}

@Composable
private fun EmptyNotifications() {
    Column(
        modifier = Modifier.fillMaxSize().padding(KajHobeTheme.spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("🔔", style = MaterialTheme.typography.displaySmall)
        Text(
            "You're all caught up",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(top = KajHobeTheme.spacing.sm),
        )
        Text(
            "Interest requests and updates will appear here.",
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
        )
    }
}

@Composable
private fun SwipeToClear(onClear: () -> Unit, content: @Composable () -> Unit) {
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onClear(); true
            } else {
                false
            }
        },
    )
    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(16.dp))
                    .background(RejectRed.copy(alpha = 0.15f))
                    .padding(end = 20.dp),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Icon(Icons.Filled.Delete, contentDescription = "Clear", tint = RejectRed)
            }
        },
    ) {
        content()
    }
}

// MARK: - Rows

@Composable
private fun cardModifier(accent: Color, isUnread: Boolean, onTap: () -> Unit): Modifier {
    // Composite the tint over an opaque surface so the swipe-to-clear background never bleeds
    // through the (otherwise translucent) accent fill.
    val surface = MaterialTheme.colorScheme.surface
    val bg = if (isUnread) {
        accent.copy(alpha = 0.15f).compositeOver(surface)
    } else {
        ReadGray.copy(alpha = 0.10f).compositeOver(surface)
    }
    val borderColor = if (isUnread) accent.copy(alpha = 0.5f) else ReadGray.copy(alpha = 0.3f)
    return Modifier
        .fillMaxWidth()
        .clip(RoundedCornerShape(16.dp))
        .background(bg)
        .border(1.dp, borderColor, RoundedCornerShape(16.dp))
        .clickable { onTap() }
}

@Composable
private fun CategoryChip(label: String, accent: Color) {
    Text(
        label,
        color = accent,
        fontSize = 10.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(CircleShape)
            .background(accent.copy(alpha = 0.15f))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    )
}

@Composable
private fun UnreadDot(accent: Color) {
    Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(accent))
}

@Composable
private fun InterestRow(
    interest: EnrichedJobInterest,
    accent: Color,
    categoryLabel: String,
    isUnread: Boolean,
    isProcessing: Boolean,
    onTap: () -> Unit,
    onAccept: () -> Unit,
    onReject: () -> Unit,
) {
    val effectiveAccent = if (isUnread) accent else ReadGray
    val isPending = interest.status.lowercase() == "pending"

    Column(modifier = cardModifier(accent, isUnread, onTap).padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(40.dp).clip(CircleShape).background(effectiveAccent.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    (interest.provider_name ?: "?").take(1).uppercase(),
                    color = effectiveAccent,
                    fontWeight = FontWeight.SemiBold,
                    style = MaterialTheme.typography.titleSmall,
                )
            }
            Spacer(Modifier.size(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        interest.provider_name ?: "Someone",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = if (isUnread) FontWeight.SemiBold else FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    CategoryChip(categoryLabel, effectiveAccent)
                }
                Text(
                    interest.job_title,
                    style = MaterialTheme.typography.bodyMedium,
                    color = KajHobeTheme.colors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.size(8.dp))
            Column(horizontalAlignment = Alignment.End) {
                Text(timeAgo(interest.created_at), style = MaterialTheme.typography.labelSmall, color = KajHobeTheme.colors.textSecondary)
                Spacer(Modifier.size(6.dp))
                if (isUnread) {
                    UnreadDot(effectiveAccent)
                } else {
                    StatusPill(interest.status)
                }
            }
        }

        if (!interest.message.isNullOrBlank()) {
            Spacer(Modifier.size(10.dp))
            Text(
                interest.message,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(ReadGray.copy(alpha = 0.12f))
                    .padding(10.dp),
            )
        }

        if (isPending) {
            Spacer(Modifier.size(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = onReject,
                    enabled = !isProcessing,
                    colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(contentColor = RejectRed),
                    border = androidx.compose.foundation.BorderStroke(1.dp, RejectRed),
                    modifier = Modifier.weight(1f),
                ) { Text("Reject") }

                androidx.compose.material3.Button(
                    onClick = onAccept,
                    enabled = !isProcessing,
                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                        containerColor = AcceptGreen,
                        contentColor = Color.White,
                    ),
                    modifier = Modifier.weight(1f),
                ) {
                    if (isProcessing) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                    } else {
                        Text("Accept", fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

@Composable
private fun StatusPill(status: String) {
    val (label, color) = when (status.lowercase()) {
        "accepted" -> "Accepted" to AcceptGreen
        "rejected" -> "Rejected" to RejectRed
        else -> return
    }
    Text(
        label,
        color = color,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(CircleShape)
            .background(color.copy(alpha = 0.15f))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

@Composable
private fun BusinessRow(
    notification: EnhancedNotification,
    accent: Color,
    categoryLabel: String,
    isUnread: Boolean,
    onTap: () -> Unit,
) {
    val effectiveAccent = if (isUnread) accent else ReadGray
    Row(
        modifier = cardModifier(accent, isUnread, onTap).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier.size(36.dp).clip(CircleShape).background(effectiveAccent.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(typeIcon(notification.type), contentDescription = null, tint = effectiveAccent, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.size(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    notification.title.ifBlank { "Notification" },
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = if (isUnread) FontWeight.SemiBold else FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                CategoryChip(categoryLabel, effectiveAccent)
                Spacer(Modifier.weight(1f))
                Text(
                    formattedNotificationDate(notification.created_at),
                    style = MaterialTheme.typography.labelSmall,
                    color = KajHobeTheme.colors.textSecondary,
                )
            }
            if (notification.message.isNotBlank()) {
                Text(
                    notification.message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = KajHobeTheme.colors.textSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (isUnread) {
            Spacer(Modifier.size(8.dp))
            UnreadDot(effectiveAccent)
        }
    }
}

private fun typeIcon(type: String?): androidx.compose.ui.graphics.vector.ImageVector {
    val t = type?.lowercase() ?: return Icons.Filled.Notifications
    return when {
        t.contains("deal") -> Icons.Filled.MonetizationOn
        t.contains("message") -> Icons.AutoMirrored.Filled.Message
        t.contains("interest") -> Icons.Filled.Favorite
        t.contains("completion") || t.contains("completed") -> Icons.Filled.CheckCircle
        t.contains("offer") -> Icons.Filled.Description
        else -> Icons.Filled.Notifications
    }
}

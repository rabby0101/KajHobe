package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Message
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Handshake
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Timeline
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.CompletionRequest
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.SimpleProfile
import com.kajhobe.app.data.model.parseIsoMillis
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.launch
import org.koin.androidx.compose.koinViewModel

private val StatusGreen = Color(0xFF34C759)
private val StatusOrange = Color(0xFFFF9500)
private val StatusBlue = Color(0xFF007AFF)
private val StatusRed = Color(0xFFFF3B30)
private val InfoBlue = Color(0xFF007AFF)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DealDetailScreen(
    dealId: String,
    onBack: () -> Unit,
    onOpenChat: (String) -> Unit,
    viewModel: DealDetailViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    LaunchedEffect(dealId) { viewModel.load(dealId) }

    var showCompletionRequestSheet by remember { mutableStateOf(false) }
    var completionRequestMessage by remember { mutableStateOf("") }
    var showCompletionResponseSheet by remember { mutableStateOf(false) }
    var pendingRequest by remember { mutableStateOf<CompletionRequest?>(null) }
    val scope = rememberCoroutineScope()

    // Collect one-shot events from the ViewModel (e.g. "the other party already
    // filed a request, open the response sheet instead").
    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is DealDetailEvent.OpenResponseSheet -> {
                    pendingRequest = event.request
                    completionRequestMessage = ""
                    showCompletionRequestSheet = false
                    showCompletionResponseSheet = true
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Deal Details") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    state.deal?.conversation_id?.let { convId ->
                        IconButton(onClick = { onOpenChat(convId) }) {
                            Icon(Icons.AutoMirrored.Filled.Message, contentDescription = "Message", tint = InfoBlue)
                        }
                    }
                },
            )
        },
    ) { padding ->
        val deal = state.deal
        when {
            state.isLoading -> Box(Modifier.fillMaxSize().padding(padding)) {
                PremiumLoadingView(message = "Loading deal…")
            }

            deal == null -> Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Text("Deal not found", color = KajHobeTheme.colors.textSecondary)
            }

            else -> Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(KajHobeTheme.spacing.md),
                verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
            ) {
                DealHeader(deal)
                JobInfoSection(deal)
                EscrowSectionView(
                    escrow = state.escrow,
                    isLoading = state.escrowLoading,
                    isAdmin = state.isAdmin,
                    isProcessing = state.isProcessing,
                    onMarkPaidOut = { viewModel.markEscrowPaidOut() },
                    onMarkRefunded = { viewModel.markEscrowRefunded() },
                )
                ParticipantsSection(deal, state.isUserClient)
                TermsSection(deal)
                DealProgressTimeline(deal)
                ActionsSection(
                    deal = deal,
                    isUserClient = state.isUserClient,
                    isProcessing = state.isProcessing,
                    onRequestCompletion = { showCompletionRequestSheet = true },
                    onReviewCompletion = {
                        scope.launch {
                            pendingRequest = viewModel.fetchPendingRequestForCurrentDeal()
                            showCompletionResponseSheet = true
                        }
                    },
                    onSendMessage = { deal.conversation_id?.let(onOpenChat) },
                )
            }
        }
    }

    if (showCompletionRequestSheet) {
        CompletionRequestSheet(
            deal = state.deal,
            isProcessing = state.isProcessing,
            errorMessage = state.errorMessage,
            onSend = { msg ->
                viewModel.requestCompletion(msg)
                completionRequestMessage = ""
                showCompletionRequestSheet = false
            },
            onDismiss = {
                completionRequestMessage = ""
                showCompletionRequestSheet = false
            },
            message = completionRequestMessage,
            onMessageChange = { completionRequestMessage = it },
        )
    }

    if (showCompletionResponseSheet) {
        CompletionResponseSheet(
            deal = state.deal,
            pendingRequest = pendingRequest,
            isProcessing = state.isProcessing,
            errorMessage = state.errorMessage,
            onSubmit = { approve, msg ->
                viewModel.respondToCompletion(approve, msg)
                showCompletionResponseSheet = false
                pendingRequest = null
            },
            onDismiss = {
                showCompletionResponseSheet = false
                pendingRequest = null
            },
        )
    }

    state.errorMessage?.let { msg ->
        AlertDialog(
            onDismissRequest = viewModel::clearError,
            title = { Text("Error") },
            text = { Text(msg) },
            confirmButton = { TextButton(onClick = viewModel::clearError) { Text("OK") } },
        )
    }
}

private fun statusColor(status: String): Color = when (status) {
    "completed" -> StatusGreen
    "pending_approval" -> StatusOrange
    "in_progress" -> StatusBlue
    "disputed" -> StatusRed
    else -> Color(0xFF8E8E93)
}

@Composable
private fun DealHeader(deal: Deal) {
    val cs = deal.completion_status ?: "in_progress"
    val color = statusColor(cs)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.10f))
            .border(1.dp, color.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
            .padding(KajHobeTheme.spacing.md),
        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            StatusBadge(cs, color)
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End) {
                Text("৳${deal.agreed_amount}", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Text("Agreed Amount", style = MaterialTheme.typography.labelSmall, color = KajHobeTheme.colors.textSecondary)
            }
        }
        Column {
            Text("Deal #${deal.id.take(8)}", style = MaterialTheme.typography.labelSmall, color = KajHobeTheme.colors.textSecondary)
            deal.created_at?.let {
                Text("Created ${formatDealDate(it)}", style = MaterialTheme.typography.labelSmall, color = KajHobeTheme.colors.textSecondary)
            }
        }
    }
}

@Composable
private fun StatusBadge(status: String, color: Color) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(color.copy(alpha = 0.1f))
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(color))
        Text(
            status.replace("_", " ").replaceFirstChar { it.uppercase() },
            color = color,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun SectionHeader(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun JobInfoSection(deal: Deal) {
    val job = deal.job ?: return
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        SectionHeader("Job Information", Icons.Filled.Work, InfoBlue)
        Spacer(Modifier.size(8.dp))
        Text(job.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        if (job.description.isNotBlank()) {
            Text(job.description, style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.textSecondary)
        }
        Spacer(Modifier.size(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("# ${job.category}", style = MaterialTheme.typography.labelMedium, color = InfoBlue)
            if (job.urgent == true) {
                Spacer(Modifier.weight(1f))
                Text("Urgent", style = MaterialTheme.typography.labelMedium, color = StatusRed)
            }
        }
        if (job.location.isNotBlank()) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Filled.LocationOn, contentDescription = null, tint = KajHobeTheme.colors.textSecondary, modifier = Modifier.size(14.dp))
                Text(job.location, style = MaterialTheme.typography.labelMedium, color = KajHobeTheme.colors.textSecondary)
            }
        }
        if (job.budget > 0) {
            Text("Budget: ৳${job.budget}", style = MaterialTheme.typography.labelMedium, color = StatusGreen)
        }
    }
}

@Composable
private fun ParticipantsSection(deal: Deal, isUserClient: Boolean) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        SectionHeader("Participants", Icons.Filled.People, StatusGreen)
        Spacer(Modifier.size(8.dp))
        deal.client_profile?.let {
            ParticipantCard(it, role = "Client", roleColor = InfoBlue, isCurrentUser = isUserClient)
        }
        deal.provider_profile?.let {
            Spacer(Modifier.size(8.dp))
            ParticipantCard(it, role = "Service Provider", roleColor = StatusGreen, isCurrentUser = !isUserClient)
        }
    }
}

@Composable
private fun ParticipantCard(profile: SimpleProfile, role: String, roleColor: Color, isCurrentUser: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(
            modifier = Modifier.size(40.dp).clip(CircleShape).background(roleColor.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Text((profile.full_name ?: "?").take(1).uppercase(), color = roleColor, fontWeight = FontWeight.SemiBold)
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                (profile.full_name ?: "Unknown") + if (isCurrentUser) " (You)" else "",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
            )
            Text(role, style = MaterialTheme.typography.labelMedium, color = roleColor)
        }
        if (profile.isOnline) {
            Box(Modifier.size(10.dp).clip(CircleShape).background(StatusGreen))
        }
    }
}

@Composable
private fun TermsSection(deal: Deal) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        SectionHeader("Deal Terms", Icons.Filled.Description, StatusOrange)
        Spacer(Modifier.size(8.dp))
        val terms = deal.agreed_terms
        val timeline = deal.timeline
        if (!terms.isNullOrBlank()) {
            Text("Terms & Conditions", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            Text(terms, style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.textSecondary)
        }
        if (!timeline.isNullOrBlank()) {
            Spacer(Modifier.size(6.dp))
            Text("Timeline", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            Text(timeline, style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.textSecondary)
        }
        if (terms.isNullOrBlank() && timeline.isNullOrBlank()) {
            Text(
                "No specific terms or timeline specified",
                style = MaterialTheme.typography.bodyMedium,
                color = KajHobeTheme.colors.textSecondary,
                fontStyle = FontStyle.Italic,
            )
        }
    }
}

@Composable
private fun ActionsSection(
    deal: Deal,
    isUserClient: Boolean,
    isProcessing: Boolean,
    onRequestCompletion: () -> Unit,
    onReviewCompletion: () -> Unit,
    onSendMessage: () -> Unit,
) {
    val cs = deal.completion_status ?: "in_progress"
    val hasUserRequested = (isUserClient && deal.client_completion_requested == true) ||
        (!isUserClient && deal.provider_completion_requested == true)

    Column(verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm)) {
        when (cs) {
            "in_progress" -> {
                if (hasUserRequested) {
                    DisabledActionButton("Completion Requested", StatusOrange)
                } else {
                    FilledActionButton("Request Completion", StatusGreen, enabled = !isProcessing, onClick = onRequestCompletion)
                }
            }

            "pending_approval" -> {
                if (hasUserRequested) {
                    DisabledActionButton("Request Pending", StatusOrange)
                } else {
                    FilledActionButton(
                        "Review Completion Request",
                        StatusBlue,
                        enabled = !isProcessing,
                        onClick = onReviewCompletion,
                    )
                }
            }

            "completed" -> DisabledActionButton("Deal Completed", StatusGreen, icon = Icons.Filled.CheckCircle)
        }

        // Send Message
        Button(
            onClick = onSendMessage,
            enabled = deal.conversation_id != null,
            colors = ButtonDefaults.buttonColors(containerColor = InfoBlue.copy(alpha = 0.12f), contentColor = InfoBlue),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(Icons.AutoMirrored.Filled.Message, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(8.dp))
            Text("Send Message")
        }
    }
}

@Composable
private fun FilledActionButton(text: String, color: Color, enabled: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(containerColor = color, contentColor = Color.White),
        modifier = Modifier.fillMaxWidth(),
    ) { Text(text, fontWeight = FontWeight.SemiBold) }
}

@Composable
private fun DisabledActionButton(text: String, color: Color, icon: androidx.compose.ui.graphics.vector.ImageVector? = null) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(color.copy(alpha = 0.8f))
            .padding(vertical = 14.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(8.dp))
        }
        Text(text, color = Color.White, fontWeight = FontWeight.SemiBold)
    }
}

private fun formatDealDate(iso: String): String {
    val millis = parseIsoMillis(iso) ?: return ""
    return DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.getDefault())
        .format(Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()))
}

private fun formatDealDateTime(iso: String?): String {
    if (iso.isNullOrBlank()) return ""
    val millis = parseIsoMillis(iso) ?: return ""
    return DateTimeFormatter.ofPattern("MMM d, yyyy h:mm a", Locale.getDefault())
        .format(Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()))
}

// MARK: - Progress timeline (iOS DealProgressTimeline port)

@Composable
private fun DealProgressTimeline(deal: Deal) {
    val cs = deal.completion_status ?: "in_progress"
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        SectionHeader("Progress Tracking", Icons.Filled.Timeline, StatusBlue)
        Spacer(Modifier.size(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
            val clientRequested = deal.client_completion_requested == true
            val providerRequested = deal.provider_completion_requested == true
            val isCompleted = cs == "completed"
            val requestItems = buildList {
                if (clientRequested) add(
                    Triple("Client Requested Completion", deal.client_completion_requested_at, Icons.Filled.Person)
                )
                if (providerRequested) add(
                    Triple("Provider Requested Completion", deal.provider_completion_requested_at, Icons.Filled.CheckCircle)
                )
            }
            val totalItems = 3 + requestItems.size
            var index = 0
            TimelineItem(
                title = "Deal Created",
                subtitle = formatDealDateTime(deal.created_at),
                icon = Icons.Filled.Handshake,
                color = StatusGreen,
                isCompleted = true,
                isLast = false,
            )
            index++
            TimelineItem(
                title = "Work in Progress",
                subtitle = "Service being provided",
                icon = Icons.Filled.Build,
                color = StatusBlue,
                isCompleted = cs != "pending_approval",
                isLast = false,
            )
            index++
            requestItems.forEach { (title, date, icon) ->
                index++
                TimelineItem(
                    title = title,
                    subtitle = formatDealDateTime(date),
                    icon = icon,
                    color = StatusOrange,
                    isCompleted = true,
                    isLast = index == totalItems,
                )
            }
            TimelineItem(
                title = "Deal Completed",
                subtitle = if (isCompleted) formatDealDateTime(deal.completed_at) else "Pending completion",
                icon = Icons.Filled.Verified,
                color = StatusGreen,
                isCompleted = isCompleted,
                isLast = true,
            )
        }
    }
}

@Composable
private fun TimelineItem(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    isCompleted: Boolean,
    isLast: Boolean,
) {
    val activeColor = if (isCompleted) color else Color(0xFF8E8E93)
    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Top,
        ) {
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .clip(CircleShape)
                    .background(activeColor.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = activeColor, modifier = Modifier.size(16.dp))
            }
            if (!isLast) {
                Spacer(Modifier.size(2.dp))
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .height(24.dp)
                        .background(activeColor.copy(alpha = 0.3f)),
                )
            }
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(top = 4.dp, bottom = if (isLast) 0.dp else 12.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium,
                color = if (isCompleted) MaterialTheme.colorScheme.onSurface else KajHobeTheme.colors.textSecondary,
            )
            if (subtitle.isNotBlank()) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = KajHobeTheme.colors.textSecondary,
                )
            }
        }
    }
}

// MARK: - Completion request sheet (iOS CompletionRequestView port)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CompletionRequestSheet(
    deal: Deal?,
    isProcessing: Boolean,
    errorMessage: String?,
    message: String,
    onMessageChange: (String) -> Unit,
    onSend: (String?) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    if (deal == null) {
        onDismiss()
        return
    }
    // Defensive guard: if the deal has moved out of in_progress (e.g. the other
    // party already filed a request and the ViewModel re-routes us to the
    // response sheet), do not let the user submit a request.
    if (deal.completion_status != null && deal.completion_status != "in_progress") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(KajHobeTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
        ) {
            Text("This deal is no longer awaiting a new request.", style = MaterialTheme.typography.titleSmall)
            Text(
                "Close this sheet and review the existing completion request.",
                style = MaterialTheme.typography.bodySmall,
                color = KajHobeTheme.colors.textSecondary,
            )
            TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.End)) { Text("Close") }
        }
        return
    }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = KajHobeTheme.spacing.md)
                .padding(bottom = KajHobeTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    deal.job?.title ?: "Deal",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "৳${deal.agreed_amount}",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = StatusGreen,
                )
            }

            // Deal details
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                color = KajHobeTheme.colors.cardBackground,
                tonalElevation = 1.dp,
            ) {
                Column(
                    modifier = Modifier.padding(KajHobeTheme.spacing.md),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    val terms = deal.agreed_terms
                    val timeline = deal.timeline
                    if (!terms.isNullOrBlank()) {
                        KeyValueRow("Terms", terms)
                    }
                    if (!timeline.isNullOrBlank()) {
                        KeyValueRow("Timeline", timeline)
                    }
                    if (terms.isNullOrBlank() && timeline.isNullOrBlank()) {
                        Text(
                            "No specific terms or timeline specified",
                            style = MaterialTheme.typography.bodyMedium,
                            color = KajHobeTheme.colors.textSecondary,
                            fontStyle = FontStyle.Italic,
                        )
                    }
                }
            }

            // Prompt
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    "Are you ready to mark this task as completed?",
                    style = MaterialTheme.typography.titleSmall,
                )
                Text(
                    "The other party will be notified and asked to confirm completion.",
                    style = MaterialTheme.typography.bodySmall,
                    color = KajHobeTheme.colors.textSecondary,
                )
            }

            // Optional message
            OutlinedTextField(
                value = message,
                onValueChange = onMessageChange,
                label = { Text("Optional message") },
                minLines = 3,
                maxLines = 6,
                modifier = Modifier.fillMaxWidth(),
            )

            // Inline error (only show if error came in while sheet is open)
            if (errorMessage != null) {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    color = StatusRed.copy(alpha = 0.1f),
                ) {
                    Text(
                        errorMessage,
                        modifier = Modifier.padding(KajHobeTheme.spacing.sm),
                        color = StatusRed,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }

            // Actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
            ) {
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                Button(
                    onClick = { onSend(message.ifBlank { null }) },
                    enabled = !isProcessing,
                    colors = ButtonDefaults.buttonColors(containerColor = StatusGreen, contentColor = Color.White),
                    modifier = Modifier.weight(1f),
                ) {
                    if (isProcessing) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            color = Color.White,
                            strokeWidth = 2.dp,
                        )
                        Spacer(Modifier.size(8.dp))
                    }
                    Text("Send Request", fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun KeyValueRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
        )
        Spacer(Modifier.size(12.dp))
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = androidx.compose.ui.text.style.TextAlign.End,
            modifier = Modifier.weight(1f),
        )
    }
}

// MARK: - Completion response sheet (iOS CompletionResponseView port)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CompletionResponseSheet(
    deal: Deal?,
    pendingRequest: CompletionRequest?,
    isProcessing: Boolean,
    errorMessage: String?,
    onSubmit: (approve: Boolean, message: String?) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    if (deal == null) {
        onDismiss()
        return
    }
    // Defensive guard: if the deal has already been resolved (completed or moved
    // back to in_progress by a reject) the request the user is looking at is
    // stale. Refuse to submit and tell them to refresh.
    if (deal.completion_status != "pending_approval") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(KajHobeTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
        ) {
            Text("This completion request has already been resolved.", style = MaterialTheme.typography.titleSmall)
            Text(
                "Close this sheet and pull-to-refresh to see the latest state.",
                style = MaterialTheme.typography.bodySmall,
                color = KajHobeTheme.colors.textSecondary,
            )
            TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.End)) { Text("Close") }
        }
        return
    }
    var response by remember { mutableStateOf("approved") }
    var responseMessage by remember { mutableStateOf("") }

    val requesterType = pendingRequest?.requester_type ?: ""
    val isRequesterClient = requesterType == "client"
    val roleColor = if (isRequesterClient) InfoBlue else StatusGreen
    val roleLabel = if (isRequesterClient) "Client" else "Service Provider"
    val submitLabel = if (response == "approved") "Approve" else "Request Changes"
    val submitColor = if (response == "approved") StatusGreen else StatusOrange

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = KajHobeTheme.spacing.md)
                .padding(bottom = KajHobeTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
        ) {
            // Requester card
            RequesterCard(
                profile = pendingRequest?.requester_profile,
                role = roleLabel,
                roleColor = roleColor,
            )

            // Original request message
            if (!pendingRequest?.request_message.isNullOrBlank()) {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    color = KajHobeTheme.colors.cardBackground,
                    tonalElevation = 1.dp,
                ) {
                    Column(
                        modifier = Modifier.padding(KajHobeTheme.spacing.md),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            "${roleLabel} says:",
                            style = MaterialTheme.typography.bodySmall,
                            color = KajHobeTheme.colors.textSecondary,
                        )
                        Text(
                            pendingRequest.request_message.orEmpty(),
                            style = MaterialTheme.typography.bodyMedium,
                            fontStyle = FontStyle.Italic,
                        )
                    }
                }
            }

            Text(
                "Your Response",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
            )

            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                SegmentedButton(
                    selected = response == "approved",
                    onClick = { response = "approved" },
                    shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2),
                ) { Text("Approve") }
                SegmentedButton(
                    selected = response == "rejected",
                    onClick = { response = "rejected" },
                    shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2),
                ) { Text("Request Changes") }
            }

            OutlinedTextField(
                value = responseMessage,
                onValueChange = { responseMessage = it },
                label = { Text("Add a message (optional)") },
                minLines = 3,
                maxLines = 6,
                modifier = Modifier.fillMaxWidth(),
            )

            // Contextual help
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    if (response == "approved") Icons.Filled.CheckCircle else Icons.Filled.Cancel,
                    contentDescription = null,
                    tint = if (response == "approved") StatusGreen else StatusRed,
                    modifier = Modifier.size(18.dp),
                )
                Text(
                    if (response == "approved") {
                        "This will mark the task as completed and close the deal."
                    } else {
                        "This will reject the completion request. The deal will remain active."
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = KajHobeTheme.colors.textSecondary,
                )
            }

            // Inline error
            if (errorMessage != null) {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    color = StatusRed.copy(alpha = 0.1f),
                ) {
                    Text(
                        errorMessage,
                        modifier = Modifier.padding(KajHobeTheme.spacing.sm),
                        color = StatusRed,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }

            // Actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
            ) {
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                Button(
                    onClick = { onSubmit(response == "approved", responseMessage.ifBlank { null }) },
                    enabled = !isProcessing,
                    colors = ButtonDefaults.buttonColors(containerColor = submitColor, contentColor = Color.White),
                    modifier = Modifier.weight(1f),
                ) {
                    if (isProcessing) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            color = Color.White,
                            strokeWidth = 2.dp,
                        )
                        Spacer(Modifier.size(8.dp))
                    }
                    Text(submitLabel, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun RequesterCard(
    profile: SimpleProfile?,
    role: String,
    roleColor: Color,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = KajHobeTheme.colors.cardBackground,
        tonalElevation = 1.dp,
    ) {
        Row(
            modifier = Modifier.padding(KajHobeTheme.spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(roleColor.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    (profile?.full_name ?: "?").take(1).uppercase(),
                    color = roleColor,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    profile?.full_name ?: "Unknown requester",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                )
                Text(
                    role,
                    style = MaterialTheme.typography.labelMedium,
                    color = roleColor,
                )
            }
        }
    }
}

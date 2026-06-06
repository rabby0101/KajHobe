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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Message
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
    androidx.compose.runtime.LaunchedEffect(dealId) { viewModel.load(dealId) }

    var showCompletionDialog by remember { mutableStateOf(false) }
    var completionMessage by remember { mutableStateOf("") }

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
                ParticipantsSection(deal, state.isUserClient)
                TermsSection(deal)
                ActionsSection(
                    deal = deal,
                    isUserClient = state.isUserClient,
                    isProcessing = state.isProcessing,
                    onRequestCompletion = { showCompletionDialog = true },
                    onApprove = { viewModel.respondToCompletion(approve = true) },
                    onRequestChanges = { viewModel.respondToCompletion(approve = false) },
                    onSendMessage = { deal.conversation_id?.let(onOpenChat) },
                )
            }
        }
    }

    if (showCompletionDialog) {
        AlertDialog(
            onDismissRequest = { showCompletionDialog = false },
            title = { Text("Request Completion") },
            text = {
                OutlinedTextField(
                    value = completionMessage,
                    onValueChange = { completionMessage = it },
                    label = { Text("Message (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.requestCompletion(completionMessage)
                    completionMessage = ""
                    showCompletionDialog = false
                }) { Text("Send Request") }
            },
            dismissButton = {
                TextButton(onClick = { showCompletionDialog = false }) { Text("Cancel") }
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
    onApprove: () -> Unit,
    onRequestChanges: () -> Unit,
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
                    Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm)) {
                        Button(
                            onClick = onApprove,
                            enabled = !isProcessing,
                            colors = ButtonDefaults.buttonColors(containerColor = StatusGreen, contentColor = Color.White),
                            modifier = Modifier.weight(1f),
                        ) { Text("Approve") }
                        Button(
                            onClick = onRequestChanges,
                            enabled = !isProcessing,
                            colors = ButtonDefaults.buttonColors(containerColor = StatusOrange, contentColor = Color.White),
                            modifier = Modifier.weight(1f),
                        ) { Text("Request Changes") }
                    }
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

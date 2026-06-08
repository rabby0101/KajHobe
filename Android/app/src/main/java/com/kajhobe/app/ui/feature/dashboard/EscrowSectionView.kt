package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowOutward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.EscrowState
import com.kajhobe.app.data.model.EscrowTransaction
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.text.NumberFormat
import java.util.Locale

/**
 * Read-only "Escrow & Payment" card embedded in the deal detail screen.
 * Mirrors iOS `EscrowSectionView.swift` (the Admin affordances mirror the
 * `markPaidOut` / `markRefunded` buttons in that view).
 */
@Composable
fun EscrowSectionView(
    escrow: EscrowTransaction?,
    isLoading: Boolean,
    isAdmin: Boolean,
    isProcessing: Boolean,
    onMarkPaidOut: () -> Unit,
    onMarkRefunded: () -> Unit,
) {
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        SectionHeader("Escrow & Payment", Icons.Filled.Lock, InfoBlue)
        Spacer(Modifier.size(8.dp))
        when {
            isLoading -> {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.size(8.dp))
                    Text("Loading escrow…", style = MaterialTheme.typography.bodySmall)
                }
            }
            escrow == null -> {
                Text(
                    "No escrow row yet — the deal is awaiting buyer payment.",
                    style = MaterialTheme.typography.bodySmall,
                    color = KajHobeTheme.colors.textSecondary,
                )
            }
            else -> {
                EscrowBody(escrow = escrow, isAdmin = isAdmin, isProcessing = isProcessing, onMarkPaidOut = onMarkPaidOut, onMarkRefunded = onMarkRefunded)
            }
        }
    }
}

@Composable
private fun EscrowBody(
    escrow: EscrowTransaction,
    isAdmin: Boolean,
    isProcessing: Boolean,
    onMarkPaidOut: () -> Unit,
    onMarkRefunded: () -> Unit,
) {
    val (icon, accent) = when (escrow.state) {
        EscrowState.pending -> Icons.Filled.HourglassEmpty to WarmOrange
        EscrowState.held -> Icons.Filled.Lock to InfoBlue
        EscrowState.released -> Icons.Filled.ArrowOutward to InfoBlue
        EscrowState.paid_out -> Icons.Filled.CheckCircle to StatusGreen
        EscrowState.refunded -> Icons.Filled.Refresh to KajHobeTheme.colors.textSecondary
        EscrowState.failed -> Icons.Filled.WarningAmber to StatusRed
    }
    val amountLabel = formatTaka(escrow.amount)
    val roleCopy = when (escrow.state) {
        EscrowState.pending -> "Client pays the seller into escrow before work begins."
        EscrowState.held -> "Funds are held in escrow until the deal is completed."
        EscrowState.released -> "Deal completed. Provider earnings released, awaiting payout."
        EscrowState.paid_out -> "Provider has been paid. Deal closed."
        EscrowState.refunded -> "Money returned to the buyer."
        EscrowState.failed -> "A previous payment attempt failed. Please retry."
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(accent.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = accent, modifier = Modifier.size(20.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(escrow.state.label, color = accent, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyLarge)
                Text(amountLabel, style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.textSecondary)
            }
        }
        Text(
            roleCopy,
            style = MaterialTheme.typography.bodySmall,
            color = KajHobeTheme.colors.textSecondary,
        )
        // Provider amount (only meaningful when funds are held or later)
        if (escrow.state !in listOf(EscrowState.pending, EscrowState.failed)) {
            KeyValueRow("Provider share", formatTaka(escrow.provider_amount))
        }
        if (!escrow.collection_trx_id.isNullOrBlank()) {
            KeyValueRow("bKash trx id", escrow.collection_trx_id)
        }
        if (!escrow.payout_trx_id.isNullOrBlank()) {
            KeyValueRow("Payout trx id", escrow.payout_trx_id)
        }
        if (!escrow.notes.isNullOrBlank()) {
            Text("Notes", style = MaterialTheme.typography.labelMedium, color = KajHobeTheme.colors.textSecondary)
            Text(escrow.notes, style = MaterialTheme.typography.bodySmall)
        }

        if (isAdmin && escrow.state == EscrowState.released) {
            Spacer(Modifier.size(4.dp))
            OutlinedButton(
                onClick = onMarkPaidOut,
                enabled = !isProcessing,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (isProcessing) "Working…" else "Mark as paid out")
            }
        }
        if (isAdmin && escrow.state == EscrowState.held) {
            Spacer(Modifier.size(4.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = onMarkPaidOut,
                    enabled = !isProcessing,
                    modifier = Modifier.weight(1f),
                ) { Text(if (isProcessing) "Working…" else "Mark paid out") }
                OutlinedButton(
                    onClick = onMarkRefunded,
                    enabled = !isProcessing,
                    modifier = Modifier.weight(1f),
                ) { Text("Refund") }
            }
        }
    }
}

private fun formatTaka(amount: Int): String {
    val nf = NumberFormat.getInstance(Locale.US)
    return "৳${nf.format(amount)}"
}

private val StatusGreen = Color(0xFF34C759)
private val StatusRed = Color(0xFFFF3B30)
private val InfoBlue = Color(0xFF007AFF)
private val WarmOrange = Color(0xFFFF9500)

@Composable
private fun SectionHeader(title: String, icon: ImageVector, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun KeyValueRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = KajHobeTheme.colors.textSecondary)
        Text(value, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
    }
}

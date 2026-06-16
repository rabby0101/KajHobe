package com.kajhobe.app.ui.feature.dashboard

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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.time.format.DateTimeFormatter
import java.util.Locale

enum class DealsFilter(val title: String) {
    Active("Active"),
    Completed("Completed"),
    All("All"),
}

fun DealsFilter.matches(deal: Deal): Boolean = when (this) {
    DealsFilter.All -> true
    DealsFilter.Completed -> DashboardAnalytics.isCompleted(deal)
    DealsFilter.Active -> !DashboardAnalytics.isCompleted(deal)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DealsListView(
    deals: List<Deal>,
    initialFilter: DealsFilter,
    onClose: () -> Unit,
    onDealClick: (Deal) -> Unit,
    modifier: Modifier = Modifier,
) {
    var filter by remember { mutableStateOf(initialFilter) }
    var menuOpen by remember { mutableStateOf(false) }
    val filtered = deals.filter { filter.matches(it) }

    Column(modifier = modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Deals") },
            navigationIcon = { TextButton(onClick = onClose) { Text("Done") } },
            actions = {
                Box {
                    TextButton(onClick = { menuOpen = true }) { Text(filter.title) }
                    DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                        DealsFilter.entries.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(option.title) },
                                onClick = {
                                    filter = option
                                    menuOpen = false
                                },
                            )
                        }
                    }
                }
            },
        )
        if (filtered.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.Work, contentDescription = null, tint = KajHobeTheme.colors.textSecondary)
                    Text("No deals to show", color = KajHobeTheme.colors.textSecondary)
                }
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(filtered, key = { it.id }) { deal ->
                    DealListRow(deal = deal, onTap = { onDealClick(deal) })
                }
            }
        }
    }
}

@Composable
private fun DealListRow(deal: Deal, onTap: () -> Unit) {
    val status = deal.completion_status ?: deal.status
    PremiumCard(
        modifier = Modifier.fillMaxWidth().clickable { onTap() },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    deal.job?.title ?: "Unknown Job",
                    style = MaterialTheme.typography.bodyMedium,
                )
                val date = DashboardAnalytics.parseDate(deal.completed_at ?: deal.created_at)
                if (date != null) {
                    Text(
                        date.format(DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US)),
                        style = MaterialTheme.typography.labelSmall,
                        color = KajHobeTheme.colors.textSecondary,
                    )
                }
            }
            Text(
                "৳${deal.agreed_amount}",
                style = MaterialTheme.typography.bodyMedium,
                color = KajHobeTheme.colors.success,
            )
        }
        Spacer(Modifier.size(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(statusColor(status)),
            )
            Spacer(Modifier.size(4.dp))
            Text(
                status.replace("_", " ").replaceFirstChar { it.titlecase(Locale.US) },
                style = MaterialTheme.typography.labelSmall,
                color = KajHobeTheme.colors.textSecondary,
            )
            Spacer(Modifier.weight(1f))
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = KajHobeTheme.colors.textSecondary,
            )
        }
    }
}

@Composable
private fun statusColor(status: String): Color = when (status.lowercase()) {
    "completed" -> KajHobeTheme.colors.success
    "in_progress", "active" -> MaterialTheme.colorScheme.primary
    "pending_approval" -> KajHobeTheme.colors.accentOrange
    "disputed" -> MaterialTheme.colorScheme.error
    else -> KajHobeTheme.colors.textSecondary
}

package com.kajhobe.app.ui.feature.jobs

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.HardcodedServiceCategory
import com.kajhobe.app.data.model.formatTimeRemaining
import com.kajhobe.app.ui.components.MediaCarouselView
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.components.PrimaryButton
import com.kajhobe.app.ui.theme.KajHobeTheme
import kotlinx.coroutines.delay
import org.koin.androidx.compose.koinViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JobDetailScreen(
    jobId: String,
    onBack: () -> Unit,
    onViewProfile: (String) -> Unit,
    viewModel: JobDetailViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    LaunchedEffect(jobId) { viewModel.load(jobId) }

    var showInterestDialog by remember { mutableStateOf(false) }
    var interestMessage by remember { mutableStateOf("I'm interested in this job!") }
    var showDeleteDialog by remember { mutableStateOf(false) }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete Job") },
            text = { Text("Are you sure you want to delete this job? This action cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteDialog = false
                    viewModel.deleteJob(onDeleted = onBack)
                }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel") }
            },
        )
    }

    if (showInterestDialog) {
        AlertDialog(
            onDismissRequest = { showInterestDialog = false },
            title = { Text("Send interest") },
            text = {
                Column {
                    Text(
                        "Add a message to the job poster:",
                        style = MaterialTheme.typography.bodyMedium,
                        color = KajHobeTheme.colors.textSecondary,
                    )
                    Spacer(Modifier.height(KajHobeTheme.spacing.sm))
                    OutlinedTextField(
                        value = interestMessage,
                        onValueChange = { interestMessage = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("Your message") },
                        minLines = 3,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    showInterestDialog = false
                    viewModel.showInterest(interestMessage)
                }) { Text("Send interest") }
            },
            dismissButton = {
                TextButton(onClick = { showInterestDialog = false }) { Text("Cancel") }
            },
        )
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text("Job details") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            state.isLoading -> PremiumLoadingView(modifier = Modifier.padding(innerPadding))
            state.job == null -> Text(
                state.errorMessage ?: "Job not found",
                modifier = Modifier.padding(innerPadding).padding(KajHobeTheme.spacing.lg),
                color = MaterialTheme.colorScheme.error,
            )
            else -> {
                val job = state.job!!
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding)
                        .verticalScroll(rememberScrollState()),
                ) {
                    // Media carousel (full-bleed, if available) — iOS JobDetailView top section.
                    if (!job.media_urls.isNullOrEmpty()) {
                        MediaCarouselView(mediaItems = job.media_urls!!, height = 300.dp)
                    }

                    Column(modifier = Modifier.padding(KajHobeTheme.spacing.lg)) {
                    val icon = HardcodedServiceCategory.byName(job.category)?.icon ?: "🔧"
                    Text("$icon  ${job.category}", style = MaterialTheme.typography.labelLarge, color = KajHobeTheme.colors.textSecondary)
                    Spacer(Modifier.height(KajHobeTheme.spacing.sm))
                    Text(job.title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(KajHobeTheme.spacing.md))

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        LabeledValue("Budget", "৳${job.budget}")
                        LabeledValue("Location", job.location)
                        if (job.urgent == true) LabeledValue("Priority", "Urgent")
                    }

                    Spacer(Modifier.height(KajHobeTheme.spacing.lg))
                    Text("Description", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(KajHobeTheme.spacing.sm))
                    Text(job.description, style = MaterialTheme.typography.bodyLarge)

                    state.client?.let { client ->
                        Spacer(Modifier.height(KajHobeTheme.spacing.lg))
                        PremiumCard(modifier = Modifier.fillMaxWidth()) {
                            Text("Posted by", style = MaterialTheme.typography.labelMedium, color = KajHobeTheme.colors.textSecondary)
                            Spacer(Modifier.height(KajHobeTheme.spacing.xs))
                            Text(
                                client.full_name ?: "KajHobe user",
                                style = MaterialTheme.typography.titleMedium,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            client.location?.let {
                                Text(it, style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.textSecondary)
                            }
                        }
                    }

                    Spacer(Modifier.height(KajHobeTheme.spacing.xl))
                    if (!state.isOwnJob) {
                        InterestCta(
                            state = state,
                            onShowInterest = { showInterestDialog = true },
                            onCountdownEnd = { viewModel.refreshCooldown() },
                        )
                    } else {
                        TextButton(
                            onClick = { showDeleteDialog = true },
                            enabled = !state.isDeleting,
                            colors = ButtonDefaults.textButtonColors(
                                contentColor = MaterialTheme.colorScheme.error,
                            ),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Icon(Icons.Default.Delete, contentDescription = null)
                            Spacer(Modifier.width(KajHobeTheme.spacing.sm))
                            Text(if (state.isDeleting) "Deleting…" else "Delete job")
                        }
                    }
                    state.message?.let {
                        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
                        Text(it, color = KajHobeTheme.colors.success, style = MaterialTheme.typography.bodyMedium)
                    }
                    state.errorMessage?.let {
                        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
                        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
                    }
                    Spacer(Modifier.height(KajHobeTheme.spacing.xl))
                    }
                }
            }
        }
    }
}

@Composable
private fun LabeledValue(label: String, value: String) {
    Column {
        Text(label, style = MaterialTheme.typography.labelMedium, color = KajHobeTheme.colors.textTertiary)
        Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
    }
}

/**
 * Show-interest call-to-action that surfaces the cooldown (parity with web
 * JobCard / iOS): "Interest sent ✓" while pending, a live "Reapply in 1m 20s"
 * countdown during a cooldown/rate-limit, "Maximum attempts reached" at the cap,
 * or the Show interest / Show interest again button.
 */
@Composable
private fun InterestCta(
    state: JobDetailUiState,
    onShowInterest: () -> Unit,
    onCountdownEnd: () -> Unit,
) {
    val cooldown = state.cooldown
    val target = cooldown.nextAttemptTime
    when {
        // A live (pending/accepted) interest already exists.
        state.interestStatus == "pending" || state.interestStatus == "accepted" -> {
            PrimaryButton(text = "Interest sent ✓", onClick = {}, enabled = false)
        }
        // Hit the attempt cap.
        cooldown.isPermanentlyBlocked -> {
            Text(
                "Maximum attempts reached for this job",
                style = MaterialTheme.typography.bodyMedium,
                color = KajHobeTheme.colors.textSecondary,
            )
        }
        // Waiting out a cooldown / rate limit — live countdown.
        !cooldown.canShowInterest && target != null -> {
            var remaining by remember(target) {
                mutableLongStateOf((target - System.currentTimeMillis()).coerceAtLeast(0L))
            }
            LaunchedEffect(target) {
                while (true) {
                    val left = target - System.currentTimeMillis()
                    if (left <= 0L) {
                        remaining = 0L
                        onCountdownEnd()
                        break
                    }
                    remaining = left
                    delay(1000)
                }
            }
            PrimaryButton(
                text = "Reapply in ${formatTimeRemaining(remaining)}",
                onClick = {},
                enabled = false,
            )
        }
        // Allowed — first attempt or a permitted reapply.
        else -> {
            PrimaryButton(
                text = when {
                    state.isSubmitting -> "Sending…"
                    cooldown.attemptCount > 0 -> "Show interest again"
                    else -> "Show interest"
                },
                onClick = onShowInterest,
                enabled = !state.isSubmitting,
            )
        }
    }
}

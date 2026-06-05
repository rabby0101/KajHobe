package com.kajhobe.app.ui.feature.messages

import android.Manifest
import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.kajhobe.app.data.model.ChatMessage
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.io.File
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.koin.androidx.compose.koinViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    conversationId: String,
    onBack: () -> Unit,
    viewModel: ChatViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    LaunchedEffect(conversationId) { viewModel.start(conversationId) }

    val listState = rememberLazyListState()
    LaunchedEffect(state.messages.size) {
        if (state.messages.isNotEmpty()) listState.animateScrollToItem(state.messages.lastIndex)
    }

    var showDealSheet by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(state.title, style = MaterialTheme.typography.titleMedium)
                        state.subtitle?.let {
                            Text(it, style = MaterialTheme.typography.labelSmall, color = KajHobeTheme.colors.textSecondary)
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f).fillMaxWidth(),
                contentPadding = PaddingValues(KajHobeTheme.spacing.md),
                verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
            ) {
                items(state.messages, key = { it.id }) { msg ->
                    val isMine = msg.sender_id == state.currentUserId
                    when (msg.message_type) {
                        "deal_offer" -> DealOfferBubble(
                            msg = msg,
                            isMine = isMine,
                            status = dealOfferId(msg)?.let { state.dealStatuses[it] } ?: "pending",
                            canRespond = !isMine,
                            onAccept = { viewModel.respondToDeal(msg, accept = true) },
                            onReject = { viewModel.respondToDeal(msg, accept = false) },
                        )
                        "image" -> ImageBubble(msg = msg, isMine = isMine)
                        else -> MessageBubble(msg = msg, isMine = isMine)
                    }
                }
            }

            ChatInputBar(
                state = state,
                onDraftChange = viewModel::onDraftChange,
                onSend = viewModel::send,
                onSendImage = viewModel::sendImage,
                onOpenDealSheet = { showDealSheet = true },
            )
        }
    }

    if (showDealSheet) {
        DealOfferSheet(
            offerCount = state.offerCount,
            hasUnansweredOffer = state.hasUnansweredOffer,
            existingDealExists = state.existingDealExists,
            isSending = state.isSendingDealOffer,
            onDismiss = { showDealSheet = false },
            onSend = { amount, terms, timeline, additional ->
                viewModel.sendDealOffer(amount, terms, timeline, additional)
                showDealSheet = false
            },
        )
    }
}

private fun dealOfferId(msg: ChatMessage): String? =
    msg.negotiation_data?.jsonObject?.get("deal_offer_id")?.jsonPrimitive?.contentOrNull

// MARK: - Input bar

@Composable
private fun ChatInputBar(
    state: ChatUiState,
    onDraftChange: (String) -> Unit,
    onSend: () -> Unit,
    onSendImage: (String) -> Unit,
    onOpenDealSheet: () -> Unit,
) {
    val context = LocalContext.current
    var showAttachMenu by remember { mutableStateOf(false) }

    // Photo Library (single image, no runtime permission required).
    val pickImage = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri?.let { onSendImage(it.toString()) }
    }
    // Camera capture → a FileProvider URI created before launch.
    var pendingCameraUri by remember { mutableStateOf<Uri?>(null) }
    val takePicture = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        val uri = pendingCameraUri
        if (success && uri != null) onSendImage(uri.toString())
        pendingCameraUri = null
    }
    val requestCamera = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val uri = createChatCaptureUri(context)
            pendingCameraUri = uri
            takePicture.launch(uri)
        }
    }

    val busy = state.isSending || state.isUploadingImage || state.isSendingDealOffer

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .imePadding()
            .padding(KajHobeTheme.spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // + attachment (camera / photo library)
        Box {
            IconButton(onClick = { showAttachMenu = true }, enabled = !busy) {
                Icon(
                    Icons.Filled.AddCircle,
                    contentDescription = "Add photo",
                    tint = KajHobeTheme.colors.textSecondary,
                )
            }
            DropdownMenu(expanded = showAttachMenu, onDismissRequest = { showAttachMenu = false }) {
                DropdownMenuItem(
                    text = { Text("Camera") },
                    leadingIcon = { Icon(Icons.Filled.CameraAlt, contentDescription = null) },
                    onClick = {
                        showAttachMenu = false
                        requestCamera.launch(Manifest.permission.CAMERA)
                    },
                )
                DropdownMenuItem(
                    text = { Text("Photo Library") },
                    leadingIcon = { Icon(Icons.Filled.PhotoLibrary, contentDescription = null) },
                    onClick = {
                        showAttachMenu = false
                        pickImage.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    },
                )
            }
        }

        // $ deal offer (provider only), with an offer-count badge.
        if (state.isProvider) {
            BadgedBox(
                badge = { if (state.offerCount > 0) Badge { Text("${state.offerCount}") } },
            ) {
                IconButton(onClick = onOpenDealSheet, enabled = state.canSendOffer && !busy) {
                    Icon(
                        Icons.Filled.MonetizationOn,
                        contentDescription = "Send deal offer",
                        tint = if (state.canSendOffer) KajHobeTheme.colors.success else KajHobeTheme.colors.textTertiary,
                    )
                }
            }
        }

        OutlinedTextField(
            value = state.draft,
            onValueChange = onDraftChange,
            modifier = Modifier.weight(1f),
            placeholder = { Text("Message") },
            shape = RoundedCornerShape(24.dp),
            maxLines = 4,
            enabled = !state.isUploadingImage && !state.isSendingDealOffer,
        )
        IconButton(
            onClick = onSend,
            enabled = state.draft.isNotBlank() && !busy,
        ) {
            Icon(
                Icons.AutoMirrored.Filled.Send,
                contentDescription = "Send",
                tint = if (state.draft.isNotBlank()) MaterialTheme.colorScheme.primary else KajHobeTheme.colors.textTertiary,
            )
        }
    }
}

private fun createChatCaptureUri(context: Context): Uri {
    val dir = File(context.cacheDir, "captures").apply { mkdirs() }
    val file = File(dir, "chat_${System.currentTimeMillis()}.jpg")
    return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
}

// MARK: - Bubbles

@Composable
private fun MessageBubble(msg: ChatMessage, isMine: Boolean) {
    val bubbleColor = if (isMine) MaterialTheme.colorScheme.primary else KajHobeTheme.colors.subtleBackground
    val textColor = if (isMine) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isMine) Arrangement.End else Arrangement.Start,
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .background(
                    color = bubbleColor,
                    shape = RoundedCornerShape(
                        topStart = 16.dp,
                        topEnd = 16.dp,
                        bottomStart = if (isMine) 16.dp else 4.dp,
                        bottomEnd = if (isMine) 4.dp else 16.dp,
                    ),
                )
                .padding(horizontal = KajHobeTheme.spacing.md, vertical = KajHobeTheme.spacing.sm),
        ) {
            Text(
                text = msg.content,
                style = MaterialTheme.typography.bodyLarge,
                color = textColor,
                fontWeight = FontWeight.Normal,
            )
        }
    }
}

@Composable
private fun ImageBubble(msg: ChatMessage, isMine: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isMine) Arrangement.End else Arrangement.Start,
    ) {
        Box(
            modifier = Modifier
                .size(200.dp)
                .background(KajHobeTheme.colors.subtleBackground, RoundedCornerShape(12.dp)),
        ) {
            AsyncImage(
                model = msg.attachment_url,
                contentDescription = "Photo",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize().background(Color.Transparent, RoundedCornerShape(12.dp)),
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun DealOfferBubble(
    msg: ChatMessage,
    isMine: Boolean,
    status: String,
    canRespond: Boolean,
    onAccept: () -> Unit,
    onReject: () -> Unit,
) {
    val obj = msg.negotiation_data?.jsonObject
    val amount = obj?.get("amount")?.jsonPrimitive?.intOrNull
    val terms = obj?.get("terms")?.jsonPrimitive?.contentOrNull
    val timeline = obj?.get("timeline")?.jsonPrimitive?.contentOrNull
    val additional = obj?.get("additional_message")?.jsonPrimitive?.contentOrNull

    val (accent, bg) = when (status) {
        "accepted" -> KajHobeTheme.colors.success to KajHobeTheme.colors.success.copy(alpha = 0.10f)
        "rejected" -> MaterialTheme.colorScheme.error to MaterialTheme.colorScheme.error.copy(alpha = 0.08f)
        else -> KajHobeTheme.colors.success to KajHobeTheme.colors.subtleBackground
    }
    var showMenu by remember { mutableStateOf(false) }
    val menuEnabled = canRespond && status == "pending"

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isMine) Arrangement.End else Arrangement.Start,
    ) {
        Box {
            Column(
                modifier = Modifier
                    .widthIn(max = 300.dp)
                    .background(bg, RoundedCornerShape(16.dp))
                    .combinedClickable(
                        enabled = menuEnabled,
                        onClick = {},
                        onLongClick = { showMenu = true },
                    )
                    .padding(KajHobeTheme.spacing.md),
                verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.MonetizationOn, contentDescription = null, tint = accent, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.size(KajHobeTheme.spacing.xs))
                    Text("Deal Offer", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.weight(1f))
                    StatusPill(status = status, accent = accent)
                }
                amount?.let {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("Amount", style = MaterialTheme.typography.bodyMedium, color = KajHobeTheme.colors.textSecondary)
                        Text("৳$it", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = accent)
                    }
                }
                DealField("Terms & Conditions", terms)
                DealField("Duration", timeline)
                DealField("Message", additional)
                if (menuEnabled) {
                    Text(
                        "Long-press to accept or reject",
                        style = MaterialTheme.typography.labelSmall,
                        color = KajHobeTheme.colors.textTertiary,
                    )
                }
            }
            DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                DropdownMenuItem(
                    text = { Text("Accept Offer") },
                    leadingIcon = { Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = KajHobeTheme.colors.success) },
                    onClick = { showMenu = false; onAccept() },
                )
                DropdownMenuItem(
                    text = { Text("Reject Offer") },
                    leadingIcon = { Icon(Icons.Filled.Cancel, contentDescription = null, tint = MaterialTheme.colorScheme.error) },
                    onClick = { showMenu = false; onReject() },
                )
            }
        }
    }
}

@Composable
private fun DealField(label: String, value: String?) {
    if (value.isNullOrBlank()) return
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = KajHobeTheme.colors.textSecondary)
        Text(value, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun StatusPill(status: String, accent: Color) {
    val label = when (status) {
        "accepted" -> "Accepted"
        "rejected" -> "Rejected"
        else -> "Pending"
    }
    Text(
        label,
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.SemiBold,
        color = accent,
        modifier = Modifier
            .background(accent.copy(alpha = 0.15f), RoundedCornerShape(50))
            .padding(horizontal = KajHobeTheme.spacing.sm, vertical = 2.dp),
    )
}

// MARK: - Deal offer sheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DealOfferSheet(
    offerCount: Int,
    hasUnansweredOffer: Boolean,
    existingDealExists: Boolean,
    isSending: Boolean,
    onDismiss: () -> Unit,
    onSend: (amount: Int, terms: String?, timeline: String?, additional: String?) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var amount by remember { mutableStateOf("") }
    var terms by remember { mutableStateOf("") }
    var timeline by remember { mutableStateOf("") }
    var additional by remember { mutableStateOf("") }

    val amountValid = amount.toIntOrNull()?.let { it > 0 } == true
    val canSend = amountValid && !isSending && !hasUnansweredOffer && offerCount < 2 && !existingDealExists

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = KajHobeTheme.spacing.lg)
                .padding(bottom = KajHobeTheme.spacing.xl),
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
        ) {
            Text("Create Deal Offer", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)

            // Status block
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Offers Sent", color = KajHobeTheme.colors.textSecondary)
                Text(
                    "$offerCount/2",
                    fontWeight = FontWeight.Bold,
                    color = if (offerCount >= 2) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
                )
            }
            if (hasUnansweredOffer) {
                Text("Waiting for client response", color = KajHobeTheme.colors.warning, style = MaterialTheme.typography.bodySmall)
            }
            if (offerCount >= 2) {
                Text("Maximum offers reached", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            if (existingDealExists) {
                Text("A deal already exists for this job", color = KajHobeTheme.colors.success, style = MaterialTheme.typography.bodySmall)
            }

            OutlinedTextField(
                value = amount,
                onValueChange = { v -> amount = v.filter { it.isDigit() } },
                label = { Text("Amount (৳)") },
                placeholder = { Text("0") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = terms,
                onValueChange = { terms = it },
                label = { Text("Terms & Conditions") },
                placeholder = { Text("e.g. 4 hours work, materials included") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = timeline,
                onValueChange = { timeline = it },
                label = { Text("Duration / Timeline") },
                placeholder = { Text("e.g. 2 days, done by Friday") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = additional,
                onValueChange = { additional = it },
                label = { Text("Additional Message") },
                placeholder = { Text("Optional message with this offer") },
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(Modifier.height(KajHobeTheme.spacing.xs))
            Button(
                onClick = {
                    onSend(amount.toInt(), terms.ifBlank { null }, timeline.ifBlank { null }, additional.ifBlank { null })
                },
                enabled = canSend,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (isSending) "Sending Offer…" else "Send Deal Offer")
            }
            TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) { Text("Cancel") }
        }
    }
}

package com.kajhobe.app.ui.components

import android.Manifest
import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import coil3.compose.AsyncImage
import com.kajhobe.app.data.media.PickedMedia
import com.kajhobe.app.data.model.MediaType
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.io.File

/**
 * Photo/video picker for the Post Job form — mirrors iOS `MediaPickerView`.
 * Two actions ("Add Photos/Videos" via the system photo picker, and "Camera" via a
 * FileProvider capture), a horizontal strip of selected thumbnails with remove buttons,
 * and an empty state. Selection state is hoisted to the caller (the ViewModel).
 */
@Composable
fun MediaPicker(
    selected: List<PickedMedia>,
    maxSelections: Int,
    onAdd: (List<PickedMedia>) -> Unit,
    onRemove: (PickedMedia) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val atCapacity = selected.size >= maxSelections

    // System photo picker (images + videos, no runtime permission required).
    val pickMedia = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(maxSelections),
    ) { uris ->
        if (uris.isNotEmpty()) {
            onAdd(uris.map { PickedMedia(uri = it.toString(), type = mediaTypeOf(context, it)) })
        }
    }

    // Camera capture → a FileProvider URI we pre-create before launching.
    var pendingCameraUri by remember { mutableStateOf<Uri?>(null) }
    val takePicture = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        val uri = pendingCameraUri
        if (success && uri != null) {
            onAdd(listOf(PickedMedia(uri = uri.toString(), type = MediaType.IMAGE)))
        }
        pendingCameraUri = null
    }
    val requestCamera = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val uri = createCaptureUri(context)
            pendingCameraUri = uri
            takePicture.launch(uri)
        }
    }

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm)) {
        // Action buttons (blue = library, green = camera), matching iOS.
        Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm)) {
            MediaActionButton(
                icon = Icons.Filled.PhotoLibrary,
                label = "Add Photos/Videos",
                tint = MaterialTheme.colorScheme.primary,
                enabled = !atCapacity,
                onClick = {
                    pickMedia.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo),
                    )
                },
                modifier = Modifier.weight(1f),
            )
            MediaActionButton(
                icon = Icons.Filled.CameraAlt,
                label = "Camera",
                tint = KajHobeTheme.colors.success,
                enabled = !atCapacity,
                onClick = { requestCamera.launch(Manifest.permission.CAMERA) },
                modifier = Modifier.weight(1f),
            )
        }

        if (selected.isEmpty()) {
            // Empty state.
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(KajHobeTheme.colors.subtleBackground)
                    .padding(vertical = KajHobeTheme.spacing.xl),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.xs),
            ) {
                Icon(
                    Icons.Filled.PhotoLibrary,
                    contentDescription = null,
                    tint = KajHobeTheme.colors.textTertiary,
                    modifier = Modifier.size(40.dp),
                )
                Text(
                    "No media selected",
                    style = MaterialTheme.typography.bodyMedium,
                    color = KajHobeTheme.colors.textSecondary,
                )
                Text(
                    "Add up to $maxSelections photos or videos",
                    style = MaterialTheme.typography.bodySmall,
                    color = KajHobeTheme.colors.textTertiary,
                )
            }
        } else {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
            ) {
                selected.forEach { item ->
                    MediaThumbnail(item = item, onRemove = { onRemove(item) })
                }
            }
        }
    }
}

@Composable
private fun MediaActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    tint: Color,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val effectiveTint = if (enabled) tint else KajHobeTheme.colors.textTertiary
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(effectiveTint.copy(alpha = 0.1f))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = KajHobeTheme.spacing.md, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = effectiveTint, modifier = Modifier.size(20.dp))
        Text(label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = effectiveTint)
    }
}

@Composable
private fun MediaThumbnail(item: PickedMedia, onRemove: () -> Unit) {
    Box(modifier = Modifier.size(100.dp)) {
        Box(
            modifier = Modifier
                .size(100.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(KajHobeTheme.colors.subtleBackground),
            contentAlignment = Alignment.Center,
        ) {
            if (item.type == MediaType.VIDEO) {
                Icon(
                    Icons.Filled.Videocam,
                    contentDescription = null,
                    tint = KajHobeTheme.colors.textTertiary,
                    modifier = Modifier.size(32.dp),
                )
            }
            AsyncImage(
                model = item.uri,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(100.dp)
                    .clip(RoundedCornerShape(8.dp)),
            )
            if (item.type == MediaType.VIDEO) {
                Icon(
                    Icons.Filled.PlayCircle,
                    contentDescription = "Video",
                    tint = Color.White,
                    modifier = Modifier.size(32.dp),
                )
            }
        }
        // Remove (x) button, top-trailing.
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(2.dp)
                .size(22.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.6f))
                .clickable(onClick = onRemove),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Close, contentDescription = "Remove", tint = Color.White, modifier = Modifier.size(16.dp))
        }
    }
}

private fun mediaTypeOf(context: Context, uri: Uri): MediaType =
    if (context.contentResolver.getType(uri)?.startsWith("video") == true) MediaType.VIDEO else MediaType.IMAGE

private fun createCaptureUri(context: Context): Uri {
    val dir = File(context.cacheDir, "captures").apply { mkdirs() }
    val file = File(dir, "cam_${System.currentTimeMillis()}.jpg")
    return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
}

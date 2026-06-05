package com.kajhobe.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.kajhobe.app.data.model.MediaItem
import com.kajhobe.app.data.model.MediaType
import com.kajhobe.app.ui.theme.KajHobeTheme

/**
 * Compact strip of attachment thumbnails on a job card — mirrors iOS CompactMediaPreview
 * (KajHobe/Views/MediaCarouselView.swift:234). Shows up to 3 thumbnails (60dp, rounded 8),
 * a play overlay on videos, and a grey "+N" tile when there are more than 3.
 */
@Composable
fun CompactMediaPreview(
    mediaItems: List<MediaItem>,
    modifier: Modifier = Modifier,
) {
    val tile = 60.dp
    val shape = RoundedCornerShape(8.dp)
    val placeholderBg = KajHobeTheme.colors.subtleBackground

    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm)) {
        mediaItems.take(3).forEach { item ->
            Box(
                modifier = Modifier.size(tile).clip(shape).background(placeholderBg),
                contentAlignment = Alignment.Center,
            ) {
                // Fallback icon shows while loading / on error; the image covers it on success.
                Icon(
                    imageVector = if (item.type == MediaType.VIDEO) Icons.Filled.Videocam else Icons.Filled.Image,
                    contentDescription = null,
                    tint = KajHobeTheme.colors.textTertiary,
                )
                AsyncImage(
                    model = item.thumbnail_url ?: item.url,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.size(tile).clip(shape),
                )
                if (item.type == MediaType.VIDEO) {
                    Icon(
                        imageVector = Icons.Filled.PlayCircle,
                        contentDescription = null,
                        tint = Color.White,
                    )
                }
            }
        }

        if (mediaItems.size > 3) {
            Box(
                modifier = Modifier.size(tile).clip(shape).background(placeholderBg),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "+${mediaItems.size - 3}",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

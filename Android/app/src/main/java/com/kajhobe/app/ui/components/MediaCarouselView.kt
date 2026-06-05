package com.kajhobe.app.ui.components

import android.content.Intent
import androidx.core.net.toUri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import com.kajhobe.app.data.model.MediaItem
import com.kajhobe.app.data.model.MediaType
import com.kajhobe.app.ui.theme.KajHobeTheme

/**
 * Swipeable media carousel for the job detail screen — mirrors iOS MediaCarouselView
 * (KajHobe/Views/MediaCarouselView.swift). Full-bleed pager at a fixed [height], a white
 * page-indicator when there is more than one item, and tap-to-open a full-screen viewer
 * (fit-scaled images with a close button + "n / total" counter). Videos show a thumbnail +
 * play button and open in the system video player.
 */
@Composable
fun MediaCarouselView(
    mediaItems: List<MediaItem>,
    modifier: Modifier = Modifier,
    height: Dp = 300.dp,
) {
    val context = LocalContext.current
    val pagerState = rememberPagerState(pageCount = { mediaItems.size })
    var fullScreenIndex by remember { mutableIntStateOf(-1) }

    Box(modifier = modifier.fillMaxWidth().height(height)) {
        HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
            val item = mediaItems[page]
            when (item.type) {
                MediaType.IMAGE -> CarouselImage(
                    url = item.url,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize().clickable { fullScreenIndex = page },
                )
                MediaType.VIDEO -> VideoThumbnail(
                    item = item,
                    modifier = Modifier.fillMaxSize().clickable {
                        runCatching {
                            context.startActivity(
                                Intent(Intent.ACTION_VIEW).setDataAndType(item.url.toUri(), "video/*"),
                            )
                        }
                    },
                )
            }
        }

        // White page-indicator dots — iOS custom indicator (only when > 1 item).
        if (mediaItems.size > 1) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 16.dp)
                    .background(Color.Black.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            ) {
                repeat(mediaItems.size) { index ->
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .background(
                                color = if (index == pagerState.currentPage) Color.White else Color.White.copy(alpha = 0.5f),
                                shape = CircleShape,
                            ),
                    )
                }
            }
        }
    }

    if (fullScreenIndex >= 0) {
        MediaFullScreenViewer(
            mediaItems = mediaItems,
            initialIndex = fullScreenIndex,
            onClose = { fullScreenIndex = -1 },
        )
    }
}

@Composable
private fun CarouselImage(
    url: String,
    contentScale: ContentScale,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier.background(KajHobeTheme.colors.subtleBackground), contentAlignment = Alignment.Center) {
        Icon(Icons.Filled.Image, contentDescription = null, tint = KajHobeTheme.colors.textTertiary)
        AsyncImage(
            model = url,
            contentDescription = null,
            contentScale = contentScale,
            modifier = Modifier.fillMaxSize(),
        )
    }
}

@Composable
private fun VideoThumbnail(item: MediaItem, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier.background(KajHobeTheme.colors.subtleBackground),
        contentAlignment = Alignment.Center,
    ) {
        AsyncImage(
            model = item.thumbnail_url ?: item.url,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
        )
        Box(
            modifier = Modifier.size(60.dp).background(Color.Black.copy(alpha = 0.6f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.PlayArrow, contentDescription = "Play", tint = Color.White, modifier = Modifier.size(28.dp))
        }
    }
}

/** Full-screen pager viewer — iOS MediaFullScreenView (fit-scaled, close + "n / total"). */
@Composable
private fun MediaFullScreenViewer(
    mediaItems: List<MediaItem>,
    initialIndex: Int,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    val pagerState = rememberPagerState(initialPage = initialIndex, pageCount = { mediaItems.size })

    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
            HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
                val item = mediaItems[page]
                when (item.type) {
                    MediaType.IMAGE -> AsyncImage(
                        model = item.url,
                        contentDescription = null,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxSize(),
                    )
                    MediaType.VIDEO -> VideoThumbnail(
                        item = item,
                        modifier = Modifier.fillMaxSize().clickable {
                            runCatching {
                                context.startActivity(
                                    Intent(Intent.ACTION_VIEW).setDataAndType(item.url.toUri(), "video/*"),
                                )
                            }
                        },
                    )
                }
            }

            Icon(
                Icons.Filled.Close,
                contentDescription = "Close",
                tint = Color.White,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(16.dp)
                    .size(32.dp)
                    .clickable(onClick = onClose),
            )

            if (mediaItems.size > 1) {
                Text(
                    text = "${pagerState.currentPage + 1} / ${mediaItems.size}",
                    color = Color.White,
                    style = MaterialTheme.typography.labelLarge,
                    modifier = Modifier.align(Alignment.TopEnd).padding(20.dp),
                )
            }
        }
    }
}

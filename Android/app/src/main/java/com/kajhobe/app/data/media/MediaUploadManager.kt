package com.kajhobe.app.data.media

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import com.kajhobe.app.data.model.MediaItem
import com.kajhobe.app.data.model.MediaType
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.UUID
import kotlin.math.min

/**
 * A photo/video the user picked but has not uploaded yet. [uri] is a content:// string
 * (from the system photo picker or a FileProvider camera capture). Mirrors iOS
 * `SelectedMediaItem` — the in-flight selection before it becomes a [MediaItem].
 */
data class PickedMedia(
    val id: String = UUID.randomUUID().toString(),
    val uri: String,
    val type: MediaType,
)

/**
 * Uploads picked photos/videos to Supabase Storage and returns persisted [MediaItem]s.
 * Direct port of iOS `MediaUploadManager`: same `job-media` bucket, same `jobs/{uuid}.jpg`
 * /`jobs/{uuid}.mp4` path scheme, images resized to max 1920px + JPEG 0.8, videos uploaded
 * raw with a 1s thumbnail under `jobs/thumbnails/`.
 */
class MediaUploadManager(
    private val context: Context,
    private val client: SupabaseClient,
) {
    private val bucket get() = client.storage.from(BUCKET)

    /** Upload one picked item; returns the persisted MediaItem, or null on failure. */
    suspend fun upload(item: PickedMedia): MediaItem? = withContext(Dispatchers.IO) {
        runCatching {
            when (item.type) {
                MediaType.IMAGE -> uploadImage(Uri.parse(item.uri))
                MediaType.VIDEO -> uploadVideo(Uri.parse(item.uri))
            }
        }.getOrNull()
    }

    private suspend fun uploadImage(uri: Uri): MediaItem? {
        val bytes = compressImage(uri) ?: return null
        val path = "jobs/${UUID.randomUUID()}.jpg"
        bucket.upload(path, bytes) { contentType = ContentType.Image.JPEG }
        val url = bucket.publicUrl(path)
        return MediaItem(
            id = UUID.randomUUID().toString(),
            url = url,
            type = MediaType.IMAGE,
            thumbnail_url = url, // images: thumbnail == main URL (matches iOS)
        )
    }

    private suspend fun uploadVideo(uri: Uri): MediaItem? {
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        if (bytes.size > MAX_VIDEO_BYTES) return null
        val path = "jobs/${UUID.randomUUID()}.mp4"
        bucket.upload(path, bytes) { contentType = ContentType.Video.MP4 }
        val url = bucket.publicUrl(path)
        val thumbnailUrl = runCatching { uploadVideoThumbnail(uri) }.getOrNull()
        return MediaItem(
            id = UUID.randomUUID().toString(),
            url = url,
            type = MediaType.VIDEO,
            thumbnail_url = thumbnailUrl,
        )
    }

    private fun compressImage(uri: Uri): ByteArray? {
        val original = context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it)
        } ?: return null
        val scaled = scaleDown(original, MAX_IMAGE_DIMENSION)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 80, out)
        if (scaled !== original) scaled.recycle()
        original.recycle()
        return out.toByteArray()
    }

    private fun scaleDown(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val w = bitmap.width
        val h = bitmap.height
        if (w <= maxDimension && h <= maxDimension) return bitmap
        val scale = min(maxDimension.toFloat() / w, maxDimension.toFloat() / h)
        return Bitmap.createScaledBitmap(bitmap, (w * scale).toInt(), (h * scale).toInt(), true)
    }

    private suspend fun uploadVideoThumbnail(uri: Uri): String? {
        val retriever = MediaMetadataRetriever()
        val frame = try {
            retriever.setDataSource(context, uri)
            retriever.getFrameAtTime(1_000_000) // 1 second, matches iOS
        } finally {
            retriever.release()
        } ?: return null
        val out = ByteArrayOutputStream()
        frame.compress(Bitmap.CompressFormat.JPEG, 70, out)
        frame.recycle()
        val path = "jobs/thumbnails/${UUID.randomUUID()}.jpg"
        bucket.upload(path, out.toByteArray()) { contentType = ContentType.Image.JPEG }
        return bucket.publicUrl(path)
    }

    private companion object {
        const val BUCKET = "job-media"
        const val MAX_IMAGE_DIMENSION = 1920
        const val MAX_VIDEO_BYTES = 50 * 1024 * 1024 // 50 MB, matches iOS
    }
}

package com.kajhobe.app.ui.feature.messages

import com.kajhobe.app.data.model.parseIsoMillis
import java.text.DateFormat
import java.util.Date

/**
 * Relative-time formatter for `latest_message_time` on conversations, matching
 * the iOS Messages view (`MessagesView.swift:673-708`):
 *   < 1m      → "just now"
 *   < 1h      → "N min ago" / "1 min ago"
 *   < 1d      → "N h ago"   / "1 h ago"
 *   < 7d      → "N days ago" / "1 day ago"
 *   < 4w      → "N weeks ago" / "1 week ago"
 *   else      → short date (e.g. "6/8/26")
 *
 * On parse failure returns the raw input so we never blank the UI.
 */
internal fun formatRelativeConversationTime(iso: String?): String {
    if (iso.isNullOrBlank()) return ""
    val millis = parseIsoMillis(iso) ?: return iso
    return formatRelativeFromMillis(millis)
}

private fun formatRelativeFromMillis(targetMillis: Long, nowMillis: Long = System.currentTimeMillis()): String {
    val intervalSeconds = ((nowMillis - targetMillis) / 1000.0).coerceAtLeast(0.0)
    val minutes = (intervalSeconds / 60).toInt()
    val hours = (intervalSeconds / 3600).toInt()
    val days = (intervalSeconds / 86400).toInt()
    val weeks = (intervalSeconds / 604800).toInt()
    return when {
        minutes < 1 -> "just now"
        minutes < 60 -> if (minutes == 1) "1 min ago" else "$minutes mins ago"
        hours < 24 -> if (hours == 1) "1 h ago" else "$hours h ago"
        days < 7 -> if (days == 1) "1 day ago" else "$days days ago"
        weeks < 4 -> if (weeks == 1) "1 week ago" else "$weeks weeks ago"
        else -> DateFormat.getDateInstance(DateFormat.SHORT).format(Date(targetMillis))
    }
}

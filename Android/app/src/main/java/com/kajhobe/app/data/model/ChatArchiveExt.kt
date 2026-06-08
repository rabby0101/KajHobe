package com.kajhobe.app.data.model

/**
 * Whether this conversation is archived for the given user. Mirrors
 * iOS ConversationWithDetails.isArchived(for:).
 */
fun ConversationWithDetails.isArchivedFor(userId: String?): Boolean {
    val uid = userId ?: return false
    return if (client_id == uid) client_archived else provider_archived
}

/** Side of the conversation the given user is on. */
fun ConversationWithDetails.isClient(userId: String?): Boolean =
    userId != null && client_id == userId

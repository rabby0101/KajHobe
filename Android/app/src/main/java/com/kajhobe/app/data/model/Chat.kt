package com.kajhobe.app.data.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

/** iOS Conversation. */
@Serializable
data class Conversation(
    val id: String,
    val job_id: String,
    val client_id: String,
    val provider_id: String,
    val status: String,
    val client_unread_count: Int = 0,
    val provider_unread_count: Int = 0,
    val created_at: String,
    val updated_at: String,
)

/**
 * A conversation enriched with the linked job + the other participant's profile and
 * the last message, for the conversation-list UI. (iOS defines this in MessagesNetworking.)
 */
@Serializable
data class ConversationWithDetails(
    val id: String,
    val job_id: String,
    val client_id: String,
    val provider_id: String,
    val status: String,
    val client_unread_count: Int = 0,
    val provider_unread_count: Int = 0,
    val created_at: String,
    val updated_at: String,
    val job: Job? = null,
    val client_profile: SimpleProfile? = null,
    val provider_profile: SimpleProfile? = null,
    val last_message: ChatMessage? = null,
    // App-computed unread count for the current user (messages received & not yet read).
    val unread: Int = 0,
)

/**
 * Chat message — iOS ChatMessage.
 * [negotiation_data] is flexible JSON (a deal offer payload for negotiation messages);
 * decoded as a [JsonElement] to tolerate both jsonb objects and stringified JSON.
 */
@Serializable
data class ChatMessage(
    val id: String,
    val conversation_id: String,
    val sender_id: String,
    val content: String,
    val message_type: String, // "text", "image", "negotiation"
    val attachment_url: String? = null,
    val negotiation_data: JsonElement? = null,
    val read_at: String? = null,
    val created_at: String,
    val updated_at: String? = null,
) {
    val isImage: Boolean get() = message_type == "image"
    val isNegotiation: Boolean get() = message_type == "negotiation"
}

@Serializable
data class ChatMessageInsert(
    val conversation_id: String,
    val sender_id: String,
    val content: String,
    val message_type: String,
    val attachment_url: String? = null,
    val negotiation_data: JsonElement? = null,
)

// MARK: - Presence / typing / receipts

@Serializable
data class TypingIndicator(
    val conversation_id: String,
    val user_id: String,
    val user_name: String,
    val is_typing: Boolean,
    val timestamp: String,
)

@Serializable
data class PresenceUpdate(
    val user_id: String,
    val is_online: Boolean,
    val last_seen_at: String? = null,
)

@Serializable
data class ReadReceipt(
    val message_id: String,
    val user_id: String,
    val read_at: String,
)

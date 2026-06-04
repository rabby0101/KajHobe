package com.kajhobe.app.data.repository

import com.kajhobe.app.data.model.ChatMessage
import com.kajhobe.app.data.model.ChatMessageInsert
import com.kajhobe.app.data.model.Conversation
import com.kajhobe.app.data.model.ConversationWithDetails
import com.kajhobe.app.data.model.Job
import com.kajhobe.app.data.model.SimpleProfile
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.decodeRecord
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import java.time.Instant
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.mapNotNull

/** Conversations + messages + realtime — mirrors iOS MessagesNetworking (enabled on Android). */
class MessagesRepository(client: SupabaseClient) : BaseRepository(client) {

    /** The signed-in user's id (for distinguishing my messages from the other party's). */
    fun currentUserId(): String? = currentUserId

    /** Conversation list for the current user, enriched with job + other party + unread count. */
    suspend fun fetchConversations(): List<ConversationWithDetails> {
        val uid = currentUserId ?: return emptyList()

        val conversations = postgrest.from("conversations")
            .select {
                filter { or { eq("client_id", uid); eq("provider_id", uid) } }
                order("updated_at", Order.DESCENDING)
            }
            .decodeList<Conversation>()
        if (conversations.isEmpty()) return emptyList()

        // Batch-load the linked jobs and the participant profiles.
        val jobIds = conversations.map { it.job_id }.distinct()
        val userIds = conversations.flatMap { listOf(it.client_id, it.provider_id) }.distinct()

        val jobs = runCatching {
            postgrest.from("jobs").select { filter { isIn("id", jobIds) } }.decodeList<Job>().associateBy { it.id }
        }.getOrDefault(emptyMap())
        val profiles = runCatching {
            postgrest.from("profiles").select { filter { isIn("id", userIds) } }
                .decodeList<SimpleProfile>().associateBy { it.id }
        }.getOrDefault(emptyMap())

        // All messages for these conversations (one query), grouped — used for both the
        // last-message preview and the app-computed unread count.
        val messagesByConversation = runCatching {
            postgrest.from("messages")
                .select { filter { isIn("conversation_id", conversations.map { c -> c.id }) }; order("created_at", Order.DESCENDING) }
                .decodeList<ChatMessage>()
                .groupBy { it.conversation_id }
        }.getOrDefault(emptyMap())

        return conversations.map { c ->
            val msgs = messagesByConversation[c.id].orEmpty()
            ConversationWithDetails(
                id = c.id,
                job_id = c.job_id,
                client_id = c.client_id,
                provider_id = c.provider_id,
                status = c.status,
                client_unread_count = c.client_unread_count,
                provider_unread_count = c.provider_unread_count,
                created_at = c.created_at,
                updated_at = c.updated_at,
                job = jobs[c.job_id],
                client_profile = profiles[c.client_id],
                provider_profile = profiles[c.provider_id],
                last_message = msgs.firstOrNull(),
                unread = msgs.count { it.sender_id != uid && it.read_at == null },
            )
        }
    }

    /** Unread count for the current user on a conversation (app-computed). */
    fun unreadFor(conversation: ConversationWithDetails): Int = conversation.unread

    /** Mark received messages in a conversation as read (sets read_at). Called when the chat opens. */
    suspend fun markConversationRead(conversationId: String) {
        val uid = currentUserId ?: return
        runCatching {
            postgrest.from("messages").update({ set("read_at", Instant.now().toString()) }) {
                filter { eq("conversation_id", conversationId); neq("sender_id", uid) }
            }
        }
    }

    data class ChatHeader(val jobTitle: String?, val otherPartyName: String?)

    /** Title info for the chat top bar: the job title and the other participant's name. */
    suspend fun fetchConversationHeader(conversationId: String): ChatHeader? {
        val uid = currentUserId
        val convo = postgrest.from("conversations")
            .select { filter { eq("id", conversationId) }; limit(1) }
            .decodeSingleOrNull<Conversation>() ?: return null
        val otherId = if (convo.client_id == uid) convo.provider_id else convo.client_id
        val jobTitle = runCatching {
            postgrest.from("jobs").select { filter { eq("id", convo.job_id) }; limit(1) }
                .decodeSingleOrNull<Job>()?.title
        }.getOrNull()
        val otherName = runCatching {
            postgrest.from("profiles").select { filter { eq("id", otherId) }; limit(1) }
                .decodeSingleOrNull<SimpleProfile>()?.full_name
        }.getOrNull()
        return ChatHeader(jobTitle, otherName)
    }

    /** Messages in a conversation, oldest → newest. */
    suspend fun fetchMessages(conversationId: String, limit: Long = 100): List<ChatMessage> =
        postgrest.from("messages")
            .select {
                filter { eq("conversation_id", conversationId) }
                order("created_at", Order.ASCENDING)
                limit(limit)
            }
            .decodeList<ChatMessage>()

    /** Send a text message. */
    suspend fun sendMessage(conversationId: String, content: String): ChatMessage {
        val msg = ChatMessageInsert(
            conversation_id = conversationId,
            sender_id = currentUserId ?: "",
            content = content.trim(),
            message_type = "text",
        )
        return postgrest.from("messages").insert(msg) { select() }.decodeSingle<ChatMessage>()
    }

    /** Mark the conversation read for the current user (reset their unread counter). */
    suspend fun markRead(conversation: ConversationWithDetails) {
        val uid = currentUserId ?: return
        val column = if (conversation.client_id == uid) "client_unread_count" else "provider_unread_count"
        runCatching {
            postgrest.from("conversations").update({ set(column, 0) }) { filter { eq("id", conversation.id) } }
        }
    }

    // MARK: - Realtime

    /**
     * Realtime channel for one conversation. Caller must [RealtimeChannel.subscribe]/join,
     * collect [incomingMessages], and remove the channel when done.
     */
    fun conversationChannel(conversationId: String): RealtimeChannel =
        client.channel("chat:$conversationId")

    /** Single app-wide channel for the conversation list (iOS "public:messages" approach). */
    fun allMessagesChannel(): RealtimeChannel = client.channel("public:messages")

    /** Flow of every newly-inserted message (client filters to relevant conversations). */
    fun incomingAllMessages(channel: RealtimeChannel): Flow<ChatMessage> =
        channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "messages"
        }.mapNotNull { runCatching { it.decodeRecord<ChatMessage>() }.getOrNull() }

    /** Flow of newly-inserted messages for a conversation (server-side filtered). */
    fun incomingMessages(channel: RealtimeChannel, conversationId: String): Flow<ChatMessage> =
        channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "messages"
            filter("conversation_id", FilterOperator.EQ, conversationId)
        }.mapNotNull { runCatching { it.decodeRecord<ChatMessage>() }.getOrNull() }

    suspend fun joinChannel(channel: RealtimeChannel) = channel.subscribe()

    suspend fun leaveChannel(channel: RealtimeChannel) {
        runCatching { channel.unsubscribe() }
        runCatching { realtime.removeChannel(channel) }
    }
}

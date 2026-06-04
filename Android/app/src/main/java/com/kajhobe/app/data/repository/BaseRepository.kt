package com.kajhobe.app.data.repository

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.realtime.realtime
import io.github.jan.supabase.storage.storage

/**
 * Base for all repositories (mirrors iOS BaseNetworking). Provides convenient access
 * to the Supabase modules and the current user id.
 */
abstract class BaseRepository(protected val client: SupabaseClient) {
    protected val postgrest get() = client.postgrest
    protected val auth get() = client.auth
    protected val realtime get() = client.realtime
    protected val storage get() = client.storage

    /** Current authenticated user id, or null if signed out. */
    protected val currentUserId: String? get() = auth.currentUserOrNull()?.id

    /** Lightweight connectivity check (iOS BaseNetworking.testConnection). */
    suspend fun testConnection(): Boolean = runCatching {
        postgrest.from("jobs").select { limit(1) }
        true
    }.getOrDefault(false)
}

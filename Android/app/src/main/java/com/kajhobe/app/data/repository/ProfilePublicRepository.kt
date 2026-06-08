package com.kajhobe.app.data.repository

import com.kajhobe.app.data.model.PublicProfile
import io.github.jan.supabase.SupabaseClient

/**
 * Public-profile lookup. Backed by the `public_profiles` SQL view (the same source
 * the iOS in-app bell's `loadProviderProfile(providerId:)` reads from) so the
 * destination screen shows pre-computed stats: completed_jobs, avg_rating, total
 * earnings, trust level, service categories.
 *
 * Mirrors iOS `KajHobe/NotificationsView.swift:1581-1675` and `PublicProfileView.swift:181-209`.
 */
class ProfilePublicRepository(client: SupabaseClient) : BaseRepository(client) {

    /**
     * Fetch a single public profile by user id. Returns null if the row is missing
     * (mirrors the iOS "Profile not found" branch).
     */
    suspend fun fetchPublicProfile(userId: String): PublicProfile? {
        if (userId.isBlank()) return null
        return runCatching {
            postgrest.from("public_profiles")
                .select { filter { eq("id", userId.lowercase()) } }
                .decodeSingleOrNull<PublicProfile>()
        }.getOrNull()
    }
}

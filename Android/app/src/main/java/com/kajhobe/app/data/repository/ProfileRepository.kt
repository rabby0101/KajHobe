package com.kajhobe.app.data.repository

import com.kajhobe.app.data.model.Profile
import com.kajhobe.app.data.model.ProfileInsert
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.query.Columns
import java.time.Instant

/** User profiles — mirrors iOS ProfileNetworking. */
class ProfileRepository(client: SupabaseClient) : BaseRepository(client) {

    /** The signed-in user's id, or null. */
    fun currentUserIdOrNull(): String? = currentUserId

    /** Fetch a single profile by id. */
    suspend fun fetchProfile(userId: String): Profile? =
        postgrest.from("profiles")
            .select { filter { eq("id", userId) } }
            .decodeSingleOrNull<Profile>()

    /** The signed-in user's own profile. */
    suspend fun getCurrentUserProfile(): Profile? {
        val uid = currentUserId ?: return null
        return fetchProfile(uid)
    }

    /**
     * Ensure a profiles row exists for the current user; create a minimal one if missing.
     * Mirrors iOS ProfileNetworking.ensureUserProfile.
     */
    suspend fun ensureUserProfile(fullName: String? = null): Profile? {
        val user = auth.currentUserOrNull() ?: return null
        val existing = fetchProfile(user.id)
        if (existing != null) return existing

        val insert = ProfileInsert(
            id = user.id,
            email = user.email,
            full_name = fullName ?: user.email?.substringBefore("@"),
            user_type = "seeker",
            is_service_provider = false,
        )
        postgrest.from("profiles").insert(insert)
        return fetchProfile(user.id)
    }

    /** Update editable profile fields (bio, website, name, service-provider flag, categories). */
    suspend fun updateProfile(
        fullName: String? = null,
        bio: String? = null,
        website: String? = null,
        location: String? = null,
        isServiceProvider: Boolean? = null,
        favoriteCategories: List<String>? = null,
    ) {
        val uid = currentUserId ?: return
        postgrest.from("profiles").update({
            fullName?.let { set("full_name", it) }
            bio?.let { set("bio", it) }
            website?.let { set("website", it) }
            location?.let { set("location", it) }
            isServiceProvider?.let { set("is_service_provider", it) }
            favoriteCategories?.let { set("favorite_categories", it) }
            set("updated_at", Instant.now().toString())
        }) { filter { eq("id", uid) } }
    }

    /** Update presence (online flag + last-seen). Mirrors iOS PresenceManager writes. */
    suspend fun updatePresence(isOnline: Boolean) {
        val uid = currentUserId ?: return
        postgrest.from("profiles").update({
            set("is_online", isOnline)
            set("last_seen_at", Instant.now().toString())
        }) { filter { eq("id", uid) } }
    }

    /** Batch-load profiles for list display. */
    suspend fun batchLoadProfiles(ids: List<String>): Map<String, Profile> {
        if (ids.isEmpty()) return emptyMap()
        return postgrest.from("profiles")
            .select(Columns.ALL) { filter { isIn("id", ids.distinct()) } }
            .decodeList<Profile>()
            .associateBy { it.id }
    }
}

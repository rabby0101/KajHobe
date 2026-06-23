package com.kajhobe.app.data.repository

import com.kajhobe.app.data.model.Profile
import com.kajhobe.app.data.model.ProfileInsert
import com.kajhobe.app.data.model.ProviderVerification
import com.kajhobe.app.data.model.ProviderVerificationSubmit
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.query.Columns
import java.time.Instant

/** User profiles — mirrors iOS ProfileNetworking. */
class ProfileRepository(client: SupabaseClient) : BaseRepository(client) {

    /** The signed-in user's id, or null. */
    fun currentUserIdOrNull(): String? = currentUserId

    /** The auth account's phone in BD-local (01…) form, or null. A phone present
     *  here was verified at signup, so the verification form can mark it verified. */
    fun accountPhoneLocal(): String? {
        val raw = auth.currentUserOrNull()?.phone?.takeIf { it.isNotBlank() } ?: return null
        return if (raw.startsWith("880")) "0" + raw.substring(3) else raw
    }

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

    /** Update editable profile fields (bio, website, name, service-provider flag, provider details). */
    suspend fun updateProfile(
        fullName: String? = null,
        bio: String? = null,
        website: String? = null,
        location: String? = null,
        isServiceProvider: Boolean? = null,
        favoriteCategories: List<String>? = null,
        profession: String? = null,
        tagline: String? = null,
        experienceYears: Int? = null,
        hourlyRate: Double? = null,
        teamRate: Double? = null,
        teamHoursLabel: String? = null,
    ) {
        val uid = currentUserId ?: return
        postgrest.from("profiles").update({
            fullName?.let { set("full_name", it) }
            bio?.let { set("bio", it) }
            website?.let { set("website", it) }
            location?.let { set("location", it) }
            isServiceProvider?.let { set("is_service_provider", it) }
            favoriteCategories?.let { set("favorite_categories", it) }
            profession?.let { set("profession", it) }
            tagline?.let { set("tagline", it) }
            experienceYears?.let { set("experience_years", it) }
            hourlyRate?.let { set("hourly_rate", it) }
            teamRate?.let { set("team_rate", it) }
            teamHoursLabel?.let { set("team_hours_label", it) }
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

    // MARK: - Provider verification

    /** The signed-in user's verification request, or null if they haven't applied. */
    suspend fun fetchMyVerification(): ProviderVerification? {
        val uid = currentUserId ?: return null
        return postgrest.from("provider_verifications")
            .select { filter { eq("user_id", uid) } }
            .decodeSingleOrNull<ProviderVerification>()
    }

    /**
     * Upload a document to a PRIVATE provider bucket under `{uid}/...` (matches the
     * per-user-folder Storage RLS). Returns the stored object path.
     */
    suspend fun uploadProviderDoc(bucket: String, fileName: String, bytes: ByteArray): String {
        val uid = currentUserId ?: error("Not signed in")
        val path = "$uid/$fileName"
        storage.from(bucket).upload(path, bytes) { upsert = true }
        return path
    }

    /** Submit (or resubmit) the verification request; lands as `pending` for review. */
    suspend fun submitVerification(submit: ProviderVerificationSubmit) {
        postgrest.from("provider_verifications").upsert(submit) { onConflict = "user_id" }
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

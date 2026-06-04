package com.kajhobe.app.data.repository

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.user.UserInfo
import kotlinx.coroutines.flow.StateFlow

/** Authentication — mirrors the iOS AuthView + auth-state handling in KajHobeApp. */
class AuthRepository(
    client: SupabaseClient,
    private val profileRepository: ProfileRepository,
) : BaseRepository(client) {

    /** Observable auth state for the splash/auth gate. */
    val sessionStatus: StateFlow<SessionStatus> get() = auth.sessionStatus

    val currentUser: UserInfo? get() = auth.currentUserOrNull()

    suspend fun awaitInitialization() = auth.awaitInitialization()

    suspend fun signIn(email: String, password: String) {
        auth.signInWith(Email) {
            this.email = email.trim()
            this.password = password
        }
    }

    suspend fun signUp(email: String, password: String, fullName: String?) {
        auth.signUpWith(Email) {
            this.email = email.trim()
            this.password = password
        }
        // Best-effort profile bootstrap (RLS permitting). Ignored if the email needs confirmation.
        runCatching { profileRepository.ensureUserProfile(fullName) }
    }

    suspend fun signOut() {
        auth.signOut()
    }

    /** Creates/loads the profiles row for the signed-in user (iOS ProfileNetworking.ensureUserProfile). */
    suspend fun ensureUserProfile(fullName: String? = null) {
        profileRepository.ensureUserProfile(fullName)
    }
}

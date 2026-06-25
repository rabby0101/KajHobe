package com.kajhobe.app.data.repository

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Apple
import io.github.jan.supabase.auth.providers.Facebook
import io.github.jan.supabase.auth.providers.Google
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

    // Social login (browser-redirect OAuth). Launches an external browser / Custom
    // Tab; on return the Auth plugin completes the session via the kajhobe://
    // auth-callback deep link, and sessionStatus drives navigation.
    suspend fun signInWithGoogle() = auth.signInWith(Google)
    suspend fun signInWithApple() = auth.signInWith(Apple)
    suspend fun signInWithFacebook() = auth.signInWith(Facebook)

    /** Creates/loads the profiles row for the signed-in user (iOS ProfileNetworking.ensureUserProfile). */
    suspend fun ensureUserProfile(fullName: String? = null) {
        profileRepository.ensureUserProfile(fullName)
    }
}

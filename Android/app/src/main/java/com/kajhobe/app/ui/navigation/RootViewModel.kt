package com.kajhobe.app.ui.navigation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.repository.AuthRepository
import io.github.jan.supabase.auth.status.SessionStatus
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

enum class AuthGate { LOADING, AUTHENTICATED, UNAUTHENTICATED }

class RootViewModel(
    private val authRepository: AuthRepository,
) : ViewModel() {

    val gate: StateFlow<AuthGate> = authRepository.sessionStatus
        .map { status ->
            when (status) {
                is SessionStatus.Authenticated -> AuthGate.AUTHENTICATED
                is SessionStatus.NotAuthenticated -> AuthGate.UNAUTHENTICATED
                else -> AuthGate.LOADING
            }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AuthGate.LOADING)

    fun signOut() {
        viewModelScope.launch { runCatching { authRepository.signOut() } }
    }
}

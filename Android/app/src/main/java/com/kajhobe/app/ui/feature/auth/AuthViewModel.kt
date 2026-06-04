package com.kajhobe.app.ui.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.repository.AuthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AuthUiState(
    val email: String = "",
    val password: String = "",
    val fullName: String = "",
    val isSignUp: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val infoMessage: String? = null,
)

class AuthViewModel(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    fun onEmailChange(value: String) = _uiState.update { it.copy(email = value, errorMessage = null) }
    fun onPasswordChange(value: String) = _uiState.update { it.copy(password = value, errorMessage = null) }
    fun onFullNameChange(value: String) = _uiState.update { it.copy(fullName = value) }
    fun toggleMode() = _uiState.update {
        it.copy(isSignUp = !it.isSignUp, errorMessage = null, infoMessage = null)
    }

    fun submit() {
        val state = _uiState.value
        val email = state.email.trim()
        if (email.isBlank() || state.password.isBlank()) {
            _uiState.update { it.copy(errorMessage = "Email and password are required") }
            return
        }
        if (!isValidEmail(email)) {
            _uiState.update { it.copy(errorMessage = "Please enter a valid email (e.g. name@example.com)") }
            return
        }
        _uiState.update { it.copy(isLoading = true, errorMessage = null, infoMessage = null) }
        viewModelScope.launch {
            val result = runCatching {
                if (state.isSignUp) {
                    authRepository.signUp(state.email, state.password, state.fullName.ifBlank { null })
                } else {
                    authRepository.signIn(state.email, state.password)
                }
            }
            result.fold(
                onSuccess = {
                    // On success, sessionStatus drives navigation. For sign-up requiring email
                    // confirmation, no session arrives — surface an info message.
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            infoMessage = if (state.isSignUp) "Check your email to confirm your account." else null,
                        )
                    }
                    if (!state.isSignUp) runCatching { authRepository.ensureUserProfile() }
                },
                onFailure = { e ->
                    _uiState.update {
                        it.copy(isLoading = false, errorMessage = friendlyAuthError(e))
                    }
                },
            )
        }
    }

    private fun isValidEmail(email: String): Boolean =
        android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()

    /** Map verbose backend exceptions to a short, user-friendly message. */
    private fun friendlyAuthError(e: Throwable): String {
        val raw = e.message.orEmpty()
        return when {
            raw.contains("invalid_credentials", ignoreCase = true) ||
                raw.contains("Invalid login credentials", ignoreCase = true) ->
                "Invalid email or password."
            raw.contains("email_not_confirmed", ignoreCase = true) ->
                "Please confirm your email before signing in."
            raw.contains("user_already_exists", ignoreCase = true) ||
                raw.contains("already registered", ignoreCase = true) ->
                "An account with this email already exists."
            raw.contains("weak_password", ignoreCase = true) ||
                raw.contains("Password should be", ignoreCase = true) ->
                "Password is too weak (use at least 6 characters)."
            raw.contains("Unable to resolve host", ignoreCase = true) ||
                raw.contains("timeout", ignoreCase = true) ->
                "Network error — check your connection."
            else -> "Authentication failed. Please try again."
        }
    }
}

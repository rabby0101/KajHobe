package com.kajhobe.app.ui.feature.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.ui.components.PremiumInputField
import com.kajhobe.app.ui.components.PremiumLoadingView
import com.kajhobe.app.ui.components.PrimaryButton
import com.kajhobe.app.ui.components.TertiaryButton
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel

@Composable
fun AuthScreen(viewModel: AuthViewModel = koinViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = KajHobeTheme.spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Spacer(Modifier.height(48.dp))
            // Brand wordmark (the iOS app shows AppLogo here).
            Text(
                text = "KajHobe",
                style = MaterialTheme.typography.displayMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = "কাজ হবে",
                style = MaterialTheme.typography.titleMedium,
                color = KajHobeTheme.colors.textSecondary,
            )
            Spacer(Modifier.height(40.dp))

            if (state.isSignUp) {
                PremiumInputField(
                    value = state.fullName,
                    onValueChange = viewModel::onFullNameChange,
                    label = "Full name",
                )
                Spacer(Modifier.height(KajHobeTheme.spacing.md))
            }

            PremiumInputField(
                value = state.email,
                onValueChange = viewModel::onEmailChange,
                label = "Email",
                keyboardType = KeyboardType.Email,
            )
            Spacer(Modifier.height(KajHobeTheme.spacing.md))
            PremiumInputField(
                value = state.password,
                onValueChange = viewModel::onPasswordChange,
                label = "Password",
                isPassword = true,
                errorText = state.errorMessage,
            )
            Spacer(Modifier.height(KajHobeTheme.spacing.lg))

            if (state.isLoading) {
                PremiumLoadingView(modifier = Modifier.height(72.dp))
            } else {
                PrimaryButton(
                    text = if (state.isSignUp) "Create account" else "Sign in",
                    onClick = viewModel::submit,
                )
            }

            state.infoMessage?.let {
                Spacer(Modifier.height(KajHobeTheme.spacing.md))
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = KajHobeTheme.colors.success,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(Modifier.height(KajHobeTheme.spacing.md))
            TertiaryButton(
                text = if (state.isSignUp) "Already have an account? Sign in"
                else "New here? Create an account",
                onClick = viewModel::toggleMode,
            )
            Spacer(Modifier.height(48.dp))
        }
    }
}

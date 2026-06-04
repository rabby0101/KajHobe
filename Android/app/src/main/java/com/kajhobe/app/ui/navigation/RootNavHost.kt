package com.kajhobe.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.ui.feature.auth.AuthScreen
import com.kajhobe.app.ui.feature.splash.SplashScreen
import org.koin.androidx.compose.koinViewModel

/**
 * Top-level auth gate (iOS AppEntryView): splash while restoring the session,
 * the auth screen when signed out, the main tab shell when authenticated.
 */
@Composable
fun RootNavHost(rootViewModel: RootViewModel = koinViewModel()) {
    val gate by rootViewModel.gate.collectAsStateWithLifecycle()

    when (gate) {
        AuthGate.LOADING -> SplashScreen()
        AuthGate.UNAUTHENTICATED -> AuthScreen()
        AuthGate.AUTHENTICATED -> MainScaffold(onSignOut = rootViewModel::signOut)
    }
}

package com.kajhobe.app.ui.feature.splash

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kajhobe.app.ui.theme.KajHobeTheme

/** Animated splash shown while the session is restored — iOS AppEntryView loading state. */
@Composable
fun SplashScreen() {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "KajHobe",
            style = MaterialTheme.typography.displayMedium,
            color = MaterialTheme.colorScheme.primary,
        )
        Text(
            text = "কাজ হবে",
            style = MaterialTheme.typography.titleMedium,
            color = KajHobeTheme.colors.textSecondary,
            modifier = Modifier.padding(top = 4.dp),
        )
        CircularProgressIndicator(
            modifier = Modifier.padding(top = KajHobeTheme.spacing.xl),
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

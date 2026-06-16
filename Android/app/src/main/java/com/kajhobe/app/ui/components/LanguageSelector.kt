package com.kajhobe.app.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.R
import com.kajhobe.app.data.local.LanguageManager

/** Language picker — selecting a row switches the whole app live and persists. */
@Composable
fun LanguageSelector(modifier: Modifier = Modifier) {
    val current by LanguageManager.language.collectAsStateWithLifecycle()

    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = stringResource(R.string.language),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        LanguageManager.supported.forEach { code ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { LanguageManager.setLanguage(code) }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                RadioButton(
                    selected = code == current,
                    onClick = { LanguageManager.setLanguage(code) },
                )
                Text(LanguageManager.displayName(code), style = MaterialTheme.typography.bodyLarge)
            }
        }
    }
}

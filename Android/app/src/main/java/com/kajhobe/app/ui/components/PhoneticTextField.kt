package com.kajhobe.app.ui.components

import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.local.LanguageManager
import com.kajhobe.app.ui.theme.KajHobeTheme
import com.kajhobe.app.util.AvroPhonetic

// Convert each Latin word followed by a non-letter (a completed word), leaving a
// still-being-typed trailing run untouched. Already-Bangla text has no [A-Za-z]
// runs, so it is never re-converted.
private val completedWord = Regex("[A-Za-z]+(?=[^A-Za-z])")
private val anyWord = Regex("[A-Za-z]+")
private fun convertCompletedWords(raw: String): String =
    completedWord.replace(raw) { AvroPhonetic.transliterate(it.value) }
private fun convertAll(raw: String): String =
    anyWord.replace(raw) { AvroPhonetic.transliterate(it.value) }

/**
 * Text field with optional in-app Avro-style Bangla phonetic typing. Completed
 * words (followed by a space/punctuation) are transliterated as you type; the
 * trailing word converts on focus loss. The অ/A button toggles phonetic mode
 * (default ON when the app language is Bangla). Mirrors the web `PhoneticInput`.
 *
 * Use only for free text — never for email/phone/password/numeric fields.
 */
@Composable
fun PhoneticTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    singleLine: Boolean = true,
    maxLines: Int = if (singleLine) 1 else Int.MAX_VALUE,
    enabled: Boolean = true,
    leadingIcon: @Composable (() -> Unit)? = null,
) {
    val language by LanguageManager.language.collectAsStateWithLifecycle()
    var phonetic by rememberSaveable { mutableStateOf(language == "bn") }

    OutlinedTextField(
        value = value,
        onValueChange = { raw -> onValueChange(if (phonetic) convertCompletedWords(raw) else raw) },
        modifier = modifier.onFocusChanged { state ->
            if (!state.isFocused && phonetic) {
                val converted = convertAll(value)
                if (converted != value) onValueChange(converted)
            }
        },
        enabled = enabled,
        label = label?.let { { Text(it) } },
        placeholder = placeholder?.let { { Text(it) } },
        singleLine = singleLine,
        maxLines = maxLines,
        shape = MaterialTheme.shapes.medium,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
        leadingIcon = leadingIcon,
        trailingIcon = {
            TextButton(onClick = { phonetic = !phonetic }) {
                Text(if (phonetic) "অ" else "A")
            }
        },
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MaterialTheme.colorScheme.primary,
            unfocusedBorderColor = KajHobeTheme.colors.divider,
        ),
    )
}

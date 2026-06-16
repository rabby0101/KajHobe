package com.kajhobe.app.data.local

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

private val Context.languageDataStore by preferencesDataStore("app_language")

/**
 * App-wide language preference — the Android counterpart of iOS `LanguageManager`
 * and the web `LanguageContext`. Defaults to Bangla and persists the user's choice
 * in DataStore. The selected code drives a localized Configuration context (see
 * `ProvideAppLanguage`) so `stringResource` resolves to the chosen language live.
 */
object LanguageManager {

    const val DEFAULT_LANGUAGE = "bn"

    /** Supported language codes, mirroring iOS/web (Bangla default first). */
    val supported = listOf("bn", "en", "de")

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val key = stringPreferencesKey("language")

    private val _language = MutableStateFlow(DEFAULT_LANGUAGE)
    val language: StateFlow<String> = _language.asStateFlow()

    private var appContext: Context? = null

    /** Load the persisted language (call once from Application.onCreate). */
    fun init(context: Context) {
        val ctx = context.applicationContext
        appContext = ctx
        scope.launch {
            val stored = runCatching { ctx.languageDataStore.data.first()[key] }.getOrNull()
            if (stored != null && stored in supported) _language.value = stored
        }
    }

    fun setLanguage(code: String) {
        if (code !in supported) return
        _language.value = code
        val ctx = appContext ?: return
        scope.launch { runCatching { ctx.languageDataStore.edit { it[key] = code } } }
    }

    /** Native display name for a language code (shown in the picker). */
    fun displayName(code: String): String = when (code) {
        "bn" -> "বাংলা"
        "en" -> "English"
        "de" -> "Deutsch"
        else -> code
    }
}

package com.kajhobe.app.ui.i18n

import android.content.ContextWrapper
import android.content.res.AssetManager
import android.content.res.Configuration
import android.content.res.Resources
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.local.LanguageManager
import java.util.Locale

/**
 * Applies the user's selected app language to everything inside [content] by
 * overriding the Compose `LocalContext`/`LocalConfiguration` with a localized
 * Configuration context. This switches `stringResource` output live, without
 * recreating the Activity or depending on AppCompat — matching the custom
 * language managers used on iOS and web.
 *
 * The localized context is a [ContextWrapper] whose base remains the original
 * Activity context. This is important: `LocalActivityResultRegistryOwner` (and
 * other owners) resolve by walking `ContextWrapper.baseContext` up to the
 * Activity. A bare `createConfigurationContext()` result is detached from that
 * chain, which crashes `rememberLauncherForActivityResult` with
 * "No ActivityResultRegistryOwner was provided". Wrapping the Activity keeps the
 * owner chain intact while still serving localized resources.
 */
@Composable
fun ProvideAppLanguage(content: @Composable () -> Unit) {
    val language by LanguageManager.language.collectAsStateWithLifecycle()
    val context = LocalContext.current

    val localizedContext = remember(language, context) {
        val config = Configuration(context.resources.configuration)
        config.setLocale(Locale.forLanguageTag(language))
        val configContext = context.createConfigurationContext(config)
        object : ContextWrapper(context) {
            override fun getResources(): Resources = configContext.resources
            override fun getAssets(): AssetManager = configContext.assets
        }
    }

    CompositionLocalProvider(
        LocalContext provides localizedContext,
        LocalConfiguration provides localizedContext.resources.configuration,
    ) {
        content()
    }
}

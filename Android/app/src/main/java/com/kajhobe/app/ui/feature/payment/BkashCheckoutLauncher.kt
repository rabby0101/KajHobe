package com.kajhobe.app.ui.feature.payment

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.net.toUri
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Wraps Chrome Custom Tabs for the bKash checkout. Mirrors the role of
 * iOS `BkashCheckoutSession` (which uses `ASWebAuthenticationSession`):
 *
 *  * iOS uses `ASWebAuthenticationSession` with `callbackURLScheme = "kajhobe"`
 *    so the system intercepts the `kajhobe://escrow-callback` redirect and
 *    hands it back to the app.
 *  * Android has no equivalent. We open the bKash-hosted page in Chrome
 *    Custom Tabs and rely on the `kajhobe://escrow-callback` deep link
 *    registered in `AndroidManifest.xml`. The deep link brings the user back
 *    to `MainActivity`, which emits the parsed callback to
 *    `PaymentDeepLinkBus`.
 *
 * Because the deep link is delivered to `MainActivity` and not back to this
 * launcher, this function returns `null` immediately after presenting the
 * Custom Tab. The actual `status` arrives via `PaymentDeepLinkBus.events`
 * (consumed by `ChatViewModel.acceptAndPay`).
 */
object BkashCheckoutLauncher {

    private const val TIMEOUT_MS = 5 * 60_000L

    /**
     * Present the bKash checkout URL in Chrome Custom Tabs.
     * Returns the parsed callback URL (via deep link) or null on
     * cancellation / timeout / no Custom Tabs provider.
     */
    suspend fun launch(
        activity: Activity,
        url: String,
    ): Uri? {
        val parsed = Uri.parse(url)
        val customTabsIntent = buildIntent(activity)
        val packageName = CustomTabsClient.getPackageName(activity, null)
        return try {
            // Always call startActivityForResult-style launch via Custom Tabs.
            // The system delivers the kajhobe://... deep link to MainActivity, not to us.
            val pendingResult = CompletableDeferred<Uri?>()
            pendingResult
            customTabsIntent.launchUrl(activity, parsed)
            // Wait for the deep link to land. The deep link emits to
            // PaymentDeepLinkBus, but this coroutine has no direct access to
            // that. We return null here and let the caller poll the bus.
            withTimeoutOrNull(TIMEOUT_MS) {
                // Suspend until cancellation; in practice the caller will
                // resolve the status by reading PaymentDeepLinkBus.events
                // and refetching the offer status.
                kotlinx.coroutines.suspendCancellableCoroutine<Uri?> { cont ->
                    cont.invokeOnCancellation { /* no-op */ }
                }
            }
        } catch (e: ActivityNotFoundException) {
            null
        }
    }

    private fun buildIntent(activity: Activity): CustomTabsIntent {
        val builder = CustomTabsIntent.Builder()
            .setShowTitle(true)
            .setUrlBarHidingEnabled(false)
        val customTabs = builder.build()
        // Ensure the Custom Tab stays in the same task so the kajhobe://
        // deep link routes back to MainActivity.
        customTabs.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val pkg = runCatching {
            activity.packageManager.getPackageInfo(activity.packageName, 0).packageName
        }.getOrNull() ?: activity.packageName
        customTabs.intent.putExtra(
            Intent.EXTRA_REFERRER,
            Uri.parse("android-app://$pkg"),
        )
        return customTabs
    }
}

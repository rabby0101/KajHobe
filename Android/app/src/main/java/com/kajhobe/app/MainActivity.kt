package com.kajhobe.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.kajhobe.app.data.SupabaseConfig
import com.kajhobe.app.data.payment.EscrowDeepLink
import com.kajhobe.app.data.payment.PaymentDeepLinkBus
import com.kajhobe.app.ui.navigation.RootNavHost
import com.kajhobe.app.ui.theme.KajHobeTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            KajHobeTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    RootNavHost()
                }
            }
        }
        handleDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
    }

    /**
     * Inspect the launching intent for a bKash escrow callback and emit it on
     * the [PaymentDeepLinkBus]. Auth deep links (`kajhobe://auth-callback`) are
     * left alone — the Supabase Auth SDK handles them internally through the
     * `Auth` plugin's deep-link configuration.
     */
    private fun handleDeepLink(intent: Intent?) {
        val data: Uri = intent?.data ?: return
        val host = data.host ?: return
        when (host) {
            SupabaseConfig.ESCROW_CALLBACK_HOST -> {
                PaymentDeepLinkBus.emit(
                    EscrowDeepLink(
                        dealOfferId = data.getQueryParameter("deal_offer_id"),
                        status = data.getQueryParameter("status"),
                    ),
                )
            }
            // SupabaseConfig.DEEPLINK_HOST ("auth-callback") is consumed by the
            // Auth plugin; no manual handling needed.
        }
    }
}

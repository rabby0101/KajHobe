package com.kajhobe.app.data

import com.kajhobe.app.data.model.AppJson
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.serializer.KotlinXSerializer
import io.github.jan.supabase.storage.Storage

/** Backend configuration — shared with the iOS app (same Supabase project). */
object SupabaseConfig {
    const val URL = "https://xatlqnbrvgukuqewsxux.supabase.co"
    const val ANON_KEY =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhhdGxxbmJydmd1a3VxZXdzeHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk3MzgxMjgsImV4cCI6MjA2NTMxNDEyOH0.rBsGaNV-AcfqypS32p1BlL2B3cwGmWqC3bGabWuw1bo"

    // Deep-link callbacks. Must match the <intent-filter>s in AndroidManifest.xml and the
    // APP_DEEPLINK env var used by the bkash-webhook Edge Function.
    const val DEEPLINK_SCHEME = "kajhobe"
    const val DEEPLINK_HOST = "auth-callback"
    const val ESCROW_CALLBACK_HOST = "escrow-callback"
}

/**
 * Builds the singleton [SupabaseClient] with the same modules the iOS app uses
 * (Auth, Postgrest, Realtime, Storage, Functions). Uses the tolerant [AppJson] serializer to
 * mirror iOS's lenient decoding.
 */
fun createKajHobeSupabaseClient(): SupabaseClient =
    createSupabaseClient(
        supabaseUrl = SupabaseConfig.URL,
        supabaseKey = SupabaseConfig.ANON_KEY,
    ) {
        defaultSerializer = KotlinXSerializer(AppJson)

        install(Auth) {
            scheme = SupabaseConfig.DEEPLINK_SCHEME
            host = SupabaseConfig.DEEPLINK_HOST
            autoLoadFromStorage = true
            alwaysAutoRefresh = true
        }
        install(Postgrest)
        install(Realtime)
        install(Storage)
        install(Functions)
    }

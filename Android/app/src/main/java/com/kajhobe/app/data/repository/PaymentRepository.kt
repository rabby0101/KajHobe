package com.kajhobe.app.data.repository

import com.kajhobe.app.data.model.BkashCollectResponse
import com.kajhobe.app.data.model.EscrowTransaction
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.rpc
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Escrow + payment actions. Mirrors iOS `EscrowNetworking` and the `PaymentProvider`
 * seam (`BkashSandboxProvider` / `ManualPayoutProvider`).
 *
 *  * Collection is REAL against the bKash Tokenized Checkout sandbox, via the
 *    `bkash-collect` Edge Function.
 *  * Payout (merchant → provider) and refund are manual admin actions today
 *    (SECURITY DEFINER RPCs) because bKash B2C disbursement has no open sandbox.
 */
class PaymentRepository(client: SupabaseClient) : BaseRepository(client) {

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        coerceInputValues = true
    }

    // MARK: - bKash collection (Accept & Pay)

    /**
     * Start a bKash sandbox checkout for a deal OFFER; returns the URL to present.
     * On a confirmed capture the webhook creates the deal and holds the escrow.
     */
    suspend fun startCollection(dealOfferId: String): String {
        val body = buildJsonObject { put("deal_offer_id", dealOfferId) }
        val response = client.functions.invoke(function = "bkash-collect", body = body)
        val text = response.bodyAsText()
        val parsed = json.decodeFromString<BkashCollectResponse>(text)
        return parsed.bkash_url
    }

    // MARK: - Reads

    /** The escrow row for a deal (null if none exists yet). */
    suspend fun fetchEscrow(dealId: String): EscrowTransaction? = runCatching {
        postgrest.from("escrow_transactions")
            .select { filter { eq("deal_id", dealId) }; limit(1) }
            .decodeList<EscrowTransaction>()
            .firstOrNull()
    }.getOrNull()

    /** All escrow rows where the current user is buyer or provider, newest first. */
    suspend fun fetchMyEscrows(): List<EscrowTransaction> {
        val uid = currentUserId ?: return emptyList()
        return runCatching {
            postgrest.from("escrow_transactions")
                .select {
                    filter { or { eq("client_id", uid); eq("provider_id", uid) } }
                    order("created_at", Order.DESCENDING)
                }
                .decodeList<EscrowTransaction>()
        }.getOrDefault(emptyList())
    }

    // MARK: - Admin actions (manual payout leg)

    /**
     * Whether the signed-in user is in the `app_admins` allowlist (drives the
     * admin-only payout/refund affordances on the Escrow section).
     */
    suspend fun isCurrentUserAdmin(): Boolean {
        val uid = currentUserId ?: return false
        return runCatching {
            // The is_admin SQL function returns boolean. Decode directly.
            val response = postgrest.rpc(
                "is_admin",
                buildJsonObject { put("p_uid", uid) },
            )
            val boolValue: Boolean = response.decodeAs()
            boolValue
        }.getOrDefault(false)
    }

    suspend fun markPaidOut(escrowId: String, note: String? = null) {
        val params = buildJsonObject {
            put("p_escrow_id", escrowId)
            note?.let { put("p_notes", it) }
        }
        postgrest.rpc("escrow_mark_paid_out", params).decodeAs<JsonElement>()
    }

    suspend fun markRefunded(escrowId: String, note: String? = null) {
        val params = buildJsonObject {
            put("p_escrow_id", escrowId)
            note?.let { put("p_notes", it) }
        }
        postgrest.rpc("escrow_mark_refunded", params).decodeAs<JsonElement>()
    }
}

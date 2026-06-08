package com.kajhobe.app.data.model

import kotlinx.serialization.Serializable

/**
 * Lifecycle of the money held against a deal. Mirrors the Postgres `escrow_state` enum
 * (public.escrow_transactions.state) and iOS `EscrowState`.
 *
 *   pending   — deal exists, buyer hasn't paid yet
 *   held      — buyer paid into the merchant account; funds held
 *   released  — deal completed; owed to provider, not yet paid
 *   paid_out  — provider has received the money
 *   refunded  — returned to the buyer
 *   failed    — a collect/payout attempt failed
 */
@Serializable
enum class EscrowState {
    pending,
    held,
    released,
    paid_out,
    refunded,
    failed;

    /** Short human label for badges (mirrors iOS `EscrowState.label`). */
    val label: String
        get() = when (this) {
            pending -> "Awaiting payment"
            held -> "In escrow"
            released -> "Released"
            paid_out -> "Paid out"
            refunded -> "Refunded"
            failed -> "Payment failed"
        }
}

/**
 * One escrow row per deal (Postgres `public.escrow_transactions`). Mirrors iOS
 * `EscrowTransaction` 1:1. State changes happen server-side via DB triggers and
 * SECURITY DEFINER RPCs; the client only reads.
 */
@Serializable
data class EscrowTransaction(
    val id: String,
    val deal_id: String,
    val client_id: String,
    val provider_id: String,
    val amount: Int,
    val platform_fee: Int = 0,
    val provider_amount: Int,
    val state: EscrowState,
    val currency: String = "BDT",
    val collection_payment_id: String? = null,
    val collection_trx_id: String? = null,
    val payout_trx_id: String? = null,
    val provider_msisdn: String? = null,
    val deal_offer_id: String? = null,
    val held_at: String? = null,
    val released_at: String? = null,
    val paid_out_at: String? = null,
    val refunded_at: String? = null,
    val paid_out_by: String? = null,
    val notes: String? = null,
    val created_at: String? = null,
    val updated_at: String? = null,
) {
    val formattedAmount: String get() = "৳$amount"
    val formattedProviderAmount: String get() = "৳$provider_amount"
}

/** Decoded response from the `bkash-collect` Edge Function (mirrors iOS `CollectionStart`). */
@Serializable
data class BkashCollectResponse(
    val bkash_url: String,
    val payment_id: String,
)

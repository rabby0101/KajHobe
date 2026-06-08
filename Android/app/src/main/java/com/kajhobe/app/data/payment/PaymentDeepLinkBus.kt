package com.kajhobe.app.data.payment

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * One-shot deep-link events for the bKash escrow callback
 * (`kajhobe://escrow-callback?deal_offer_id=...&status=...`).
 *
 * Emitted by `MainActivity` from `onCreate` (cold launch via the deep link) and
 * `onNewIntent` (the app was already running when the user returned from bKash).
 * Consumed by `ChatViewModel.acceptAndPay()` to refetch the deal offer status
 * once the bKash webhook has finalized the offer.
 */
data class EscrowDeepLink(
    val dealOfferId: String?,
    val status: String?,
)

object PaymentDeepLinkBus {
    private val _events = MutableSharedFlow<EscrowDeepLink>(extraBufferCapacity = 4)
    val events: SharedFlow<EscrowDeepLink> = _events.asSharedFlow()

    fun emit(event: EscrowDeepLink) {
        _events.tryEmit(event)
    }
}

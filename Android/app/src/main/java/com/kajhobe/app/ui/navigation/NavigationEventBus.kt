package com.kajhobe.app.ui.navigation

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * App-wide navigation events — replaces iOS NotificationCenter posts
 * ("NavigateToMessages", "NavigateToNotifications", "NavigateToProfile", "NavigateToOffers").
 * FCM taps and in-app actions emit these; the main scaffold collects them.
 */
sealed interface NavEvent {
    data object ToMessages : NavEvent
    data object ToNotifications : NavEvent
    data object ToDashboard : NavEvent
    data class ToProfile(val userId: String) : NavEvent
    data class ToChat(val conversationId: String) : NavEvent
    data class ToJob(val jobId: String) : NavEvent
}

class NavigationEventBus {
    private val _events = MutableSharedFlow<NavEvent>(extraBufferCapacity = 16)
    val events: SharedFlow<NavEvent> = _events.asSharedFlow()

    fun emit(event: NavEvent) {
        _events.tryEmit(event)
    }
}

package com.kajhobe.app.ui.feature.notifications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.local.NotificationLocalState
import com.kajhobe.app.data.model.EnhancedNotification
import com.kajhobe.app.data.model.EnrichedJobInterest
import com.kajhobe.app.data.notifications.NotificationBadgeManager
import com.kajhobe.app.data.repository.DealsRepository
import com.kajhobe.app.data.repository.NotificationsRepository
import com.kajhobe.app.ui.navigation.NavEvent
import com.kajhobe.app.ui.navigation.NavigationEventBus
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class NotificationsUiState(
    val isLoading: Boolean = true,
    val feedItems: List<NotificationFeedItem> = emptyList(),
    val processingIds: Set<String> = emptySet(),
    // Bumped from NotificationLocalState.revision so rows recompute their unread highlight.
    val localRevision: Int = 0,
    val errorMessage: String? = null,
)

/**
 * Single chronological notifications feed — Android port of iOS `NotificationsView`'s logic.
 * Interests + business notifications are merged, sorted newest-first, and cleared items are
 * filtered out. Read/unread is owned by [NotificationLocalState]; the bell badge by
 * [NotificationBadgeManager].
 */
class NotificationsViewModel(
    private val repository: NotificationsRepository,
    private val localState: NotificationLocalState,
    private val badgeManager: NotificationBadgeManager,
    private val dealsRepository: DealsRepository,
    private val navBus: NavigationEventBus,
) : ViewModel() {

    private val _uiState = MutableStateFlow(NotificationsUiState())
    val uiState: StateFlow<NotificationsUiState> = _uiState.asStateFlow()

    /** Emits a deal id to navigate to Deal Details (deal_created tap). */
    private val _navigateToDeal = MutableSharedFlow<String>(extraBufferCapacity = 1)
    val navigateToDeal: SharedFlow<String> = _navigateToDeal.asSharedFlow()

    private var rawInterests: List<EnrichedJobInterest> = emptyList()
    private var rawBusiness: List<EnhancedNotification> = emptyList()

    init {
        viewModelScope.launch { repository.currentUid()?.let { localState.configure(it) } }
        // Re-render the feed (drop cleared rows, refresh unread highlight) on any local change.
        viewModelScope.launch {
            localState.revision.collect { rev -> rebuildFeed(rev) }
        }
        load()
    }

    /**
     * Load the feed. [silent] = true keeps the current list on screen with no loading view
     * (used on tab-resume); false shows the full loader.
     */
    fun load(silent: Boolean = false) {
        _uiState.update { it.copy(isLoading = if (silent) it.isLoading else true, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                val interests = repository.fetchInterestsForFeed()
                val business = repository.fetchEnhancedNotifications()
                interests to business
            }.onSuccess { (interests, business) ->
                rawInterests = interests
                rawBusiness = business
                rebuildFeed(localState.revision.value)
                _uiState.update { it.copy(isLoading = false) }
                badgeManager.refreshCounts()
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, errorMessage = e.message ?: "Failed to load notifications") }
            }
        }
    }

    private fun rebuildFeed(revision: Int) {
        val items = (rawInterests.map { NotificationFeedItem.Interest(it) } +
            rawBusiness.map { NotificationFeedItem.Business(it) })
            .filterNot { localState.isCleared(it.rawId) }
            .sortedByDescending { it.createdMillis() }
        _uiState.update { it.copy(feedItems = items, localRevision = revision) }
    }

    // MARK: - Per-row unread (mirrors iOS isInterestUnread / business isUnread)

    fun isUnread(item: NotificationFeedItem): Boolean = when (item) {
        is NotificationFeedItem.Interest ->
            item.interest.status.lowercase() == "pending" &&
                localState.isUnread(item.interest.id, item.interest.created_at)
        is NotificationFeedItem.Business ->
            localState.isUnread(item.notification.id, item.notification.created_at)
    }

    // MARK: - Actions

    /** Accept/reject an interest: mark read locally, update server, then refresh. */
    fun respond(interest: EnrichedJobInterest, accept: Boolean) {
        if (interest.id in _uiState.value.processingIds) return
        localState.markRead(interest.id)
        _uiState.update { it.copy(processingIds = it.processingIds + interest.id) }
        viewModelScope.launch {
            runCatching { repository.respondToInterest(interest, accept) }
                .onFailure { e -> _uiState.update { it.copy(errorMessage = e.message ?: "Action failed") } }
            // Re-fetch so the row reflects its new accepted/rejected status (kept, dulled).
            rawInterests = runCatching { repository.fetchInterestsForFeed() }.getOrDefault(rawInterests)
            rebuildFeed(localState.revision.value)
            _uiState.update { it.copy(processingIds = it.processingIds - interest.id) }
            badgeManager.refreshCounts()
        }
    }

    /** Opening a notification mutes it (device-local read state). */
    fun markRead(item: NotificationFeedItem) = localState.markRead(item.rawId)

    fun clear(item: NotificationFeedItem) = localState.clear(item.rawId)

    fun markAllRead() = localState.markRead(_uiState.value.feedItems.map { it.rawId })

    fun clearAll() = localState.clear(_uiState.value.feedItems.map { it.rawId })

    /**
     * Tap a business notification: mark read, and if it carries a jobId and is one of the
     * types that should open a deal, resolve the deal for its job and emit a navigate event
     * to Deal Details (mirrors iOS `handleBusinessNotificationTap` + `openDeal(forJobId:)`).
     *
     * Types routed to Deal Details: `deal_created`, `completion_request`, `completion_requested`.
     * The approval surface for completion requests moved from the Dashboard to Deal Details
     * (see iOS commit that moved deal-completion approval to Notifications → Deal Details).
     */
    fun onBusinessTap(notification: EnhancedNotification) {
        localState.markRead(notification.id)
        val jobId = notification.job_id ?: return
        when (notification.type) {
            "deal_created",
            "completion_request",
            "completion_requested" -> openDealForJob(jobId)
        }
    }

    /**
     * Resolve the active deal for [jobId] and emit its id so MainScaffold can navigate to
     * Deal Details. Mirrors iOS `openDeal(forJobId:)` (reuses fetchActiveDeals, which joins
     * job + profiles — same shape the Dashboard's active-deal tap uses).
     */
    private fun openDealForJob(jobId: String) {
        viewModelScope.launch {
            val deal = runCatching { dealsRepository.fetchActiveDeals() }
                .getOrDefault(emptyList())
                .firstOrNull { it.job_id == jobId }
            deal?.let { _navigateToDeal.emit(it.id) }
        }
    }

    /**
     * Tap an interest row: mark read locally and navigate to the sender's
     * public profile. Mirrors iOS `handleDefaultAction` for `interest_request`
     * (PushNotificationManager.swift:464-479 → MainTabView.swift:99-120).
     */
    fun onInterestTap(interest: EnrichedJobInterest) {
        localState.markRead(interest.id)
        navBus.emit(NavEvent.ToProfile(interest.provider_id))
    }
}

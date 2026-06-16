package com.kajhobe.app.ui.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.dashboard.DashboardCache
import com.kajhobe.app.data.dashboard.DashboardRealtime
import com.kajhobe.app.data.dashboard.DashboardSnapshot
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.data.repository.DealsRepository
import com.kajhobe.app.data.repository.ProfilePublicRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * State for the dashboard screen. Mirrors the iOS `DashboardView` state machine:
 * cache → network → realtime → timer.
 */
data class DashboardUiState(
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val data: DashboardData? = null,
    val activeDeals: List<Deal> = emptyList(),
    val myDeals: List<Deal> = emptyList(),
    val myReviews: List<ProviderReview> = emptyList(),
    val hasRealtimeUpdate: Boolean = false,
    val errorMessage: String? = null,
)

class DashboardViewModel(
    private val dealsRepository: DealsRepository,
    private val profilePublicRepository: ProfilePublicRepository,
    private val cache: DashboardCache,
    private val realtime: DashboardRealtime,
    private val supabase: SupabaseClient,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    private var autoRefreshJob: Job? = null
    private var realtimeIndicatorJob: Job? = null
    private var realtimeCollectorJob: Job? = null

    init { loadFromCacheThenNetwork() }

    private val currentUserId: String?
        get() = supabase.auth.currentUserOrNull()?.id

    /**
     * Seed the UI from cache (so the first frame paints), then refresh from
     * the network silently. Mirrors iOS `onAppear` cache-then-fetch flow.
     */
    fun loadFromCacheThenNetwork() {
        val snapshot = cache.peekOrLoadBlocking()
        if (snapshot != null) {
            _uiState.update {
                it.copy(
                    isLoading = false,
                    data = snapshot.dashboard,
                    activeDeals = snapshot.activeDeals,
                )
            }
        }
        load(silent = snapshot != null, forceRefresh = true)
    }

    /** Manual pull-to-refresh entry point. */
    fun refresh() = load(silent = true, forceRefresh = true)

    /**
     * Load dashboard data. [silent] = true keeps current data on screen with no
     * loading view. Best-effort analytics: never fails the dashboard.
     */
    fun load(silent: Boolean = false, forceRefresh: Boolean = false) {
        _uiState.update {
            it.copy(
                isLoading = if (silent) it.isLoading else true,
                isRefreshing = if (silent) true else it.isRefreshing,
                errorMessage = null,
            )
        }
        viewModelScope.launch {
            runCatching {
                val dataDeferred = async { dealsRepository.fetchDashboardData() }
                val activeDeferred = async {
                    runCatching { dealsRepository.fetchActiveDeals() }.getOrDefault(emptyList())
                }
                val data = dataDeferred.await()
                val activeDeals = activeDeferred.await().distinctBy { it.id }
                loadAnalytics()
                data to activeDeals
            }.onSuccess { (data, activeDeals) ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        data = data,
                        activeDeals = activeDeals,
                    )
                }
                val uid = currentUserId
                if (uid != null) {
                    cache.save(DashboardSnapshot(dashboard = data, activeDeals = activeDeals))
                }
            }.onFailure { e ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        errorMessage = e.message ?: "Failed to load dashboard",
                    )
                }
            }
        }
    }

    private suspend fun loadAnalytics() {
        val uid = currentUserId ?: return
        val deals = runCatching { dealsRepository.fetchMyDeals() }.getOrNull() ?: return
        val reviews = runCatching { profilePublicRepository.fetchReviews(uid) }.getOrNull() ?: emptyList()
        _uiState.update { it.copy(myDeals = deals, myReviews = reviews) }
    }

    // MARK: - Real-time

    fun subscribeRealtime() {
        val uid = currentUserId ?: return
        realtime.subscribe(uid.lowercase())
        realtimeCollectorJob?.cancel()
        realtimeCollectorJob = viewModelScope.launch {
            realtime.events.collect {
                _uiState.update { it.copy(hasRealtimeUpdate = true) }
                realtimeIndicatorJob?.cancel()
                realtimeIndicatorJob = launch {
                    delay(1_500)
                    _uiState.update { it.copy(hasRealtimeUpdate = false) }
                }
                load(silent = true, forceRefresh = true)
            }
        }
    }

    fun unsubscribeRealtime() {
        realtimeCollectorJob?.cancel()
        realtimeCollectorJob = null
        realtimeIndicatorJob?.cancel()
        realtimeIndicatorJob = null
        realtime.unsubscribe()
    }

    // MARK: - Auto-refresh (5 minutes — iOS parity)

    fun startAutoRefresh(intervalMillis: Long = 5L * 60L * 1_000L) {
        stopAutoRefresh()
        autoRefreshJob = viewModelScope.launch {
            while (isActive) {
                delay(intervalMillis)
                load(silent = true, forceRefresh = true)
            }
        }
    }

    fun stopAutoRefresh() {
        autoRefreshJob?.cancel()
        autoRefreshJob = null
    }

    override fun onCleared() {
        super.onCleared()
        stopAutoRefresh()
        unsubscribeRealtime()
    }
}

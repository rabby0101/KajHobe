package com.kajhobe.app.ui.feature.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.repository.DealsRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class DashboardUiState(
    val isLoading: Boolean = true,
    val data: DashboardData? = null,
    val activeDeals: List<Deal> = emptyList(),
    val errorMessage: String? = null,
)

class DashboardViewModel(
    private val dealsRepository: DealsRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    init { load() }

    /**
     * Load dashboard data. [silent] = true keeps current data on screen with no loading view
     * (used on tab-resume so navigation refreshes seamlessly); false shows the full loader.
     *
     * Mirrors iOS post-commit `loadDashboardData`: the pending-completion-requests fetch was
     * removed — completion approval is now driven from Notifications → Deal Details.
     */
    fun load(silent: Boolean = false) {
        _uiState.update { it.copy(isLoading = if (silent) it.isLoading else true, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                val data = async { dealsRepository.fetchDashboardData() }
                val deals = async { runCatching { dealsRepository.fetchActiveDeals() }.getOrDefault(emptyList()) }
                data.await() to deals.await()
            }.onSuccess { (data, deals) ->
                _uiState.update {
                    it.copy(isLoading = false, data = data, activeDeals = deals)
                }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, errorMessage = e.message ?: "Failed to load dashboard") }
            }
        }
    }
}

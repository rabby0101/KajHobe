package com.kajhobe.app.ui.feature.postjob

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.repository.JobsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class PostJobUiState(
    val title: String = "",
    val description: String = "",
    val category: String = "Technology & IT",
    val location: String = "Khulna Sadar",
    val budget: String = "",
    val isUrgent: Boolean = false,
    val isSubmitting: Boolean = false,
    val errorMessage: String? = null,
    val didPost: Boolean = false,
) {
    val isValid: Boolean
        get() = title.isNotBlank() && description.isNotBlank() &&
            (budget.toIntOrNull()?.let { it > 0 } == true)
}

class PostJobViewModel(
    private val jobsRepository: JobsRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(PostJobUiState())
    val uiState: StateFlow<PostJobUiState> = _uiState.asStateFlow()

    fun onTitleChange(v: String) = _uiState.update { it.copy(title = v, errorMessage = null) }
    fun onDescriptionChange(v: String) = _uiState.update { it.copy(description = v, errorMessage = null) }
    fun onCategoryChange(v: String) = _uiState.update { it.copy(category = v) }
    fun onLocationChange(v: String) = _uiState.update { it.copy(location = v) }
    fun onBudgetChange(v: String) = _uiState.update { it.copy(budget = v.filter { c -> c.isDigit() }) }
    fun onUrgentChange(v: Boolean) = _uiState.update { it.copy(isUrgent = v) }

    fun reset() = _uiState.update { PostJobUiState() }

    fun submit() {
        val s = _uiState.value
        val budget = s.budget.toIntOrNull()
        if (!s.isValid || budget == null) {
            _uiState.update { it.copy(errorMessage = "Please fill in a title, description, and a valid budget.") }
            return
        }
        _uiState.update { it.copy(isSubmitting = true, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                jobsRepository.createJob(
                    title = s.title,
                    description = s.description,
                    category = s.category,
                    location = s.location,
                    budget = budget,
                    urgent = s.isUrgent,
                )
            }.onSuccess {
                _uiState.update { PostJobUiState(didPost = true) }
            }.onFailure { e ->
                _uiState.update { it.copy(isSubmitting = false, errorMessage = e.message ?: "Failed to post job") }
            }
        }
    }

    fun consumePosted() = _uiState.update { it.copy(didPost = false) }
}

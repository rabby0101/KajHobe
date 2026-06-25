package com.kajhobe.app.ui.feature.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kajhobe.app.data.model.Profile
import com.kajhobe.app.data.model.ProviderVerification
import com.kajhobe.app.data.model.ProviderVerificationSubmit
import com.kajhobe.app.data.repository.PaymentRepository
import com.kajhobe.app.data.repository.ProfileRepository
import java.time.Instant
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ProfileUiState(
    val isLoading: Boolean = true,
    val profile: Profile? = null,
    val payoutNumber: String = "",
    val isEditing: Boolean = false,
    val isSaving: Boolean = false,
    val errorMessage: String? = null,
    val signedOut: Boolean = false,
    val editName: String = "",
    val editBio: String = "",
    val editWebsite: String = "",
    val editIsProvider: Boolean = false,
    val editProfession: String = "",
    val editTagline: String = "",
    val editExperience: String = "",
    val editHourlyRate: String = "",
    val editTeamRate: String = "",
    val editTeamHoursLabel: String = "",
    val editPayoutBkash: String = "",
    val verification: ProviderVerification? = null,
    val showVerificationDialog: Boolean = false,
    val submittingVerification: Boolean = false,
)

class ProfileViewModel(
    private val profileRepository: ProfileRepository,
    private val paymentRepository: PaymentRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init { load() }

    fun load(silent: Boolean = false) {
        if (!silent) _uiState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            val profile = profileRepository.getCurrentUserProfile()
            var payout = ""
            if (profile?.is_service_provider == true) {
                payout = paymentRepository.fetchMyPayoutNumber() ?: ""
            }
            val verification = runCatching { profileRepository.fetchMyVerification() }.getOrNull()
            _uiState.update {
                it.copy(
                    isLoading = false,
                    profile = profile,
                    payoutNumber = payout,
                    verification = verification,
                    errorMessage = if (profile == null) "Profile not found" else null,
                )
            }
        }
    }

    fun startEditing() {
        val p = _uiState.value.profile ?: return
        _uiState.update {
            it.copy(
                isEditing = true,
                editName = p.full_name ?: "",
                editBio = p.bio ?: "",
                editWebsite = p.website ?: "",
                editIsProvider = p.is_service_provider ?: false,
                editProfession = p.profession ?: "",
                editTagline = p.tagline ?: "",
                editExperience = p.experience_years?.toString() ?: "",
                editHourlyRate = p.hourly_rate?.let { formatAmount(it) } ?: "",
                editTeamRate = p.team_rate?.let { formatAmount(it) } ?: "",
                editTeamHoursLabel = p.team_hours_label ?: "",
                editPayoutBkash = it.payoutNumber,
            )
        }
    }

    fun cancelEditing() {
        _uiState.update { it.copy(isEditing = false) }
    }

    fun updateEditField(field: EditField, value: String) {
        _uiState.update { s ->
            when (field) {
                EditField.NAME -> s.copy(editName = value)
                EditField.BIO -> s.copy(editBio = value)
                EditField.WEBSITE -> s.copy(editWebsite = value)
                EditField.PROFESSION -> s.copy(editProfession = value)
                EditField.TAGLINE -> s.copy(editTagline = value)
                EditField.EXPERIENCE -> s.copy(editExperience = value)
                EditField.HOURLY_RATE -> s.copy(editHourlyRate = value)
                EditField.TEAM_RATE -> s.copy(editTeamRate = value)
                EditField.TEAM_HOURS -> s.copy(editTeamHoursLabel = value)
                EditField.PAYOUT_BKASH -> s.copy(editPayoutBkash = value)
            }
        }
    }

    fun toggleProvider() {
        _uiState.update { it.copy(editIsProvider = !it.editIsProvider) }
    }

    // MARK: - Provider verification

    fun openVerification() { _uiState.update { it.copy(showVerificationDialog = true) } }
    fun dismissVerification() { _uiState.update { it.copy(showVerificationDialog = false) } }

    /** The auth account's phone in 01… form (verified at signup), or null. */
    fun accountPhoneLocal(): String? = profileRepository.accountPhoneLocal()

    fun submitVerification(
        nidNumber: String,
        nidFront: ByteArray?,
        nidBack: ByteArray?,
        certs: List<ByteArray>,
        demoUrls: List<String>,
        phone: String,
    ) {
        if (_uiState.value.submittingVerification) return
        _uiState.update { it.copy(submittingVerification = true, errorMessage = null) }
        viewModelScope.launch {
            try {
                val uid = profileRepository.currentUserIdOrNull() ?: error("Not signed in")
                val stamp = System.currentTimeMillis()
                val frontPath = nidFront?.let { profileRepository.uploadProviderDoc("provider-nid", "nid-front-$stamp.jpg", it) }
                val backPath = nidBack?.let { profileRepository.uploadProviderDoc("provider-nid", "nid-back-$stamp.jpg", it) }
                val certPaths = certs.mapIndexed { i, bytes ->
                    profileRepository.uploadProviderDoc("provider-certificates", "cert-$stamp-$i.jpg", bytes)
                }
                val accountPhone = profileRepository.accountPhoneLocal()
                profileRepository.submitVerification(
                    ProviderVerificationSubmit(
                        user_id = uid,
                        status = "pending",
                        nid_number = nidNumber.trim(),
                        nid_front_path = frontPath,
                        nid_back_path = backPath,
                        phone = phone.ifBlank { accountPhone },
                        phone_verified = accountPhone != null,
                        certificate_paths = certPaths,
                        demo_video_urls = demoUrls,
                        submitted_at = Instant.now().toString(),
                    ),
                )
                load(silent = true)
                _uiState.update { it.copy(submittingVerification = false, showVerificationDialog = false) }
            } catch (e: Exception) {
                _uiState.update { it.copy(submittingVerification = false, errorMessage = "Submission failed: ${e.message}") }
            }
        }
    }

    fun save() {
        val s = _uiState.value
        if (s.isSaving) return

        val trimmedPayout = s.editPayoutBkash.trim()
        val finalPayout = if (s.editIsProvider && trimmedPayout.isNotBlank()) trimmedPayout else null
        if (finalPayout != null && !Regex("^01[0-9]{9}$").matches(finalPayout)) {
            _uiState.update { it.copy(errorMessage = "Payout bKash number must be 11 digits starting with 01") }
            return
        }

        _uiState.update { it.copy(isSaving = true, errorMessage = null) }
        viewModelScope.launch {
            try {
                val parsedExperience = if (s.editIsProvider) s.editExperience.trim().toIntOrNull() else null
                val parsedHourly = if (s.editIsProvider) s.editHourlyRate.trim().toDoubleOrNull() else null
                val parsedTeam = if (s.editIsProvider) s.editTeamRate.trim().toDoubleOrNull() else null
                val finalProfession = if (s.editIsProvider && s.editProfession.isNotBlank()) s.editProfession.trim() else null
                val finalTagline = if (s.editIsProvider && s.editTagline.isNotBlank()) s.editTagline.trim() else null
                val finalTeamHours = if (s.editIsProvider && s.editTeamHoursLabel.isNotBlank()) s.editTeamHoursLabel.trim() else null

                profileRepository.updateProfile(
                    fullName = s.editName,
                    bio = s.editBio,
                    website = s.editWebsite,
                    isServiceProvider = s.editIsProvider,
                    profession = finalProfession,
                    tagline = finalTagline,
                    experienceYears = parsedExperience,
                    hourlyRate = parsedHourly,
                    teamRate = parsedTeam,
                    teamHoursLabel = finalTeamHours,
                )

                if (finalPayout != null) {
                    paymentRepository.upsertMyPayoutNumber(finalPayout)
                }

                load(silent = true)
                _uiState.update { it.copy(isEditing = false, isSaving = false) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isSaving = false, errorMessage = "Failed to save: ${e.message}") }
            }
        }
    }

    fun signOut() {
        _uiState.update { it.copy(signedOut = true) }
    }

    private fun formatAmount(v: Double): String {
        val isWhole = v % 1.0 == 0.0
        return if (isWhole) "%.0f".format(v) else "%.2f".format(v)
    }
}

enum class EditField {
    NAME, BIO, WEBSITE, PROFESSION, TAGLINE, EXPERIENCE, HOURLY_RATE, TEAM_RATE, TEAM_HOURS, PAYOUT_BKASH
}

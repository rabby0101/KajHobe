package com.kajhobe.app.ui.feature.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import androidx.compose.ui.res.stringResource
import com.kajhobe.app.R
import com.kajhobe.app.data.model.Profile
import com.kajhobe.app.data.model.ProviderVerification
import com.kajhobe.app.ui.components.PhoneticTextField
import com.kajhobe.app.ui.components.VerifiedBadge
import com.kajhobe.app.ui.theme.KajHobeTheme
import com.kajhobe.app.ui.theme.WarmOrange
import org.koin.androidx.compose.koinViewModel

private enum class ProfileTab(val label: String) {
    ABOUT("About"),
    DETAILS("Details"),
    ACCOUNT("Account"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    onBack: () -> Unit,
    onSignOut: () -> Unit,
    viewModel: ProfileViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    if (state.signedOut) onSignOut()

    var showLogoutDialog by rememberSaveable { mutableStateOf(false) }
    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text("Logout") },
            text = { Text("Are you sure you want to logout? You will need to sign in again to access your account.") },
            confirmButton = {
                TextButton(onClick = { showLogoutDialog = false; viewModel.signOut() }) { Text("Logout", color = Color.Red) }
            },
            dismissButton = { TextButton(onClick = { showLogoutDialog = false }) { Text("Cancel") } },
        )
    }

    if (state.showVerificationDialog) {
        ProviderVerificationDialog(
            existing = state.verification,
            accountPhone = viewModel.accountPhoneLocal(),
            submitting = state.submittingVerification,
            onDismiss = { viewModel.dismissVerification() },
            onSubmit = { nid, front, back, certs, demos, phone ->
                viewModel.submitVerification(nid, front, back, certs, demos, phone)
            },
        )
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text("My Profile") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    if (state.profile != null) {
                        if (state.isEditing) {
                            TextButton(onClick = { viewModel.cancelEditing() }, enabled = !state.isSaving) {
                                Text("Cancel", color = Color.Red)
                            }
                            TextButton(onClick = { viewModel.save() }, enabled = !state.isSaving) {
                                Text(if (state.isSaving) "Saving…" else "Save", color = WarmOrange)
                            }
                        } else {
                            TextButton(onClick = { viewModel.startEditing() }) {
                                Text("Edit", color = WarmOrange)
                            }
                        }
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            state.isLoading -> {
                Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = WarmOrange)
                }
            }
            state.profile != null -> ProfileContent(
                profile = state.profile!!,
                isEditing = state.isEditing,
                editName = state.editName,
                editBio = state.editBio,
                editWebsite = state.editWebsite,
                editIsProvider = state.editIsProvider,
                editProfession = state.editProfession,
                editTagline = state.editTagline,
                editExperience = state.editExperience,
                editHourlyRate = state.editHourlyRate,
                editTeamRate = state.editTeamRate,
                editTeamHoursLabel = state.editTeamHoursLabel,
                editPayoutBkash = state.editPayoutBkash,
                payoutNumber = state.payoutNumber,
                verification = state.verification,
                onFieldChange = viewModel::updateEditField,
                onGetVerified = { viewModel.openVerification() },
                onShowLogout = { showLogoutDialog = true },
                modifier = Modifier.padding(innerPadding),
            )
            else -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(innerPadding).padding(KajHobeTheme.spacing.lg),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(Icons.Filled.Person, contentDescription = null, tint = KajHobeTheme.colors.textSecondary, modifier = Modifier.size(56.dp))
                    Spacer(Modifier.height(KajHobeTheme.spacing.md))
                    Text("Profile not available", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun ProfileContent(
    profile: Profile,
    isEditing: Boolean,
    editName: String,
    editBio: String,
    editWebsite: String,
    editIsProvider: Boolean,
    editProfession: String,
    editTagline: String,
    editExperience: String,
    editHourlyRate: String,
    editTeamRate: String,
    editTeamHoursLabel: String,
    editPayoutBkash: String,
    payoutNumber: String,
    verification: ProviderVerification?,
    onFieldChange: (EditField, String) -> Unit,
    onGetVerified: () -> Unit,
    onShowLogout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var selectedTab by rememberSaveable { mutableStateOf(ProfileTab.ABOUT) }

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        item { ProfileHeroSection(profile = profile, isEditing = isEditing, editName = editName, editTagline = editTagline, onNameChange = { onFieldChange(EditField.NAME, it) }, onTaglineChange = { onFieldChange(EditField.TAGLINE, it) }) }
        item { StatCardsRow(profile = profile) }
        item { TabStrip(selected = selectedTab, onSelected = { selectedTab = it }) }
        item {
            when (selectedTab) {
                ProfileTab.ABOUT -> AboutSection(profile = profile, isEditing = isEditing, editBio = editBio, editWebsite = editWebsite, onBioChange = { onFieldChange(EditField.BIO, it) }, onWebsiteChange = { onFieldChange(EditField.WEBSITE, it) })
                ProfileTab.DETAILS -> DetailsSection(profile = profile, isEditing = isEditing, editIsProvider = editIsProvider, editProfession = editProfession, editTagline = editTagline, editExperience = editExperience, editHourlyRate = editHourlyRate, editTeamRate = editTeamRate, editTeamHoursLabel = editTeamHoursLabel, editPayoutBkash = editPayoutBkash, payoutNumber = payoutNumber, verification = verification, onFieldChange = onFieldChange, onGetVerified = onGetVerified)
                ProfileTab.ACCOUNT -> AccountSection(profile = profile, onShowLogout = onShowLogout)
            }
        }
        item { Spacer(Modifier.height(40.dp)) }
    }
}

@Composable
private fun ProfileHeroSection(
    profile: Profile,
    isEditing: Boolean,
    editName: String,
    editTagline: String,
    onNameChange: (String) -> Unit,
    onTaglineChange: (String) -> Unit,
) {
    val name = if (isEditing) editName else (profile.full_name ?: "No name")
    val tagline = if (isEditing) editTagline else (profile.tagline ?: "")
    val profession = profile.profession ?: "User"
    val hourlyLabel = profile.hourly_rate
        ?.takeIf { it > 0 }
        ?.let { "৳${formatRate(it)}/hr" }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(280.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(Color(0xFF1A1A2E)),
    ) {
        val avatarUrl = profile.avatar_url
        if (!avatarUrl.isNullOrBlank()) {
            AsyncImage(
                model = avatarUrl,
                contentDescription = name,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            Box(
                modifier = Modifier.fillMaxSize().background(
                    Brush.linearGradient(listOf(WarmOrange.copy(alpha = 0.35f), WarmOrange.copy(alpha = 0.12f))),
                ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Person, contentDescription = null, tint = Color.White.copy(alpha = 0.25f), modifier = Modifier.size(100.dp))
            }
        }
        Box(
            modifier = Modifier.fillMaxSize().background(
                Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.65f)), startY = 0f, endY = Float.POSITIVE_INFINITY),
            ),
        )
        Column(modifier = Modifier.align(Alignment.BottomStart).padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Person, contentDescription = null, tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(12.dp))
                Spacer(Modifier.width(4.dp))
                Text(profession, color = Color.White.copy(alpha = 0.7f), style = MaterialTheme.typography.labelMedium)
            }
            Spacer(Modifier.height(4.dp))
            if (isEditing) {
                OutlinedTextField(
                    value = editName,
                    onValueChange = onNameChange,
                    singleLine = true,
                    textStyle = MaterialTheme.typography.headlineSmall.copy(color = Color.White, fontWeight = FontWeight.Bold),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = WarmOrange,
                        unfocusedBorderColor = Color.White.copy(alpha = 0.3f),
                        cursorColor = WarmOrange,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
            } else {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(name, color = Color.White, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    if (profile.is_verified_provider == true) VerifiedBadge(compact = true)
                }
            }
            Text(profile.email ?: "", color = Color.White.copy(alpha = 0.6f), style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.height(2.dp))
            if (isEditing) {
                OutlinedTextField(
                    value = editTagline,
                    onValueChange = onTaglineChange,
                    singleLine = true,
                    placeholder = { Text("Tagline", color = Color.White.copy(alpha = 0.4f)) },
                    textStyle = MaterialTheme.typography.bodyMedium.copy(color = Color.White.copy(alpha = 0.85f)),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = WarmOrange,
                        unfocusedBorderColor = Color.White.copy(alpha = 0.25f),
                        cursorColor = WarmOrange,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
            } else if (tagline.isNotBlank()) {
                Text(tagline, color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodyMedium)
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(top = 6.dp)) {
                val years = profile.experience_years?.takeIf { it > 0 }
                Text(
                    text = years?.let { "$it year${if (it == 1) "" else "s"} of experience" } ?: "New provider",
                    color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.labelSmall,
                )
                if (hourlyLabel != null) {
                    HourlyRateCapsule(rateLabel = hourlyLabel)
                }
            }
        }
    }
}

@Composable
private fun StatCardsRow(profile: Profile) {
    val completedJobs = profile.completed_jobs ?: 0
    val ratingText = if ((profile.average_rating ?: 0.0) > 0) "%.1f".format(profile.average_rating) else "New"
    val reviewCount = profile.ratings_count ?: 0
    val earnedText = profile.total_earnings?.let { "৳${formatLargeAmount(it)}" } ?: "৳0"

    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatCard("💼", completedJobs.toString(), "Completed", Color(0x26FF9F0A), Modifier.weight(1f))
        StatCard("⭐", ratingText, "Rating", Color(0x268E44AD), Modifier.weight(1f))
        StatCard("👥", reviewCount.toString(), "Customers", Color(0x26FF4081), Modifier.weight(1f))
        StatCard("💰", earnedText, "Earned", Color(0x264CAF50), Modifier.weight(1f))
    }
}

@Composable
private fun StatCard(emoji: String, value: String, label: String, tint: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.background(tint, RoundedCornerShape(16.dp)).padding(vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(emoji, style = MaterialTheme.typography.titleSmall)
        Text(value, color = MaterialTheme.colorScheme.onSurface, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, maxLines = 1)
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun TabStrip(selected: ProfileTab, onSelected: (ProfileTab) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surfaceVariant).padding(4.dp),
    ) {
        ProfileTab.entries.forEach { tab ->
            val isSel = tab == selected
            TextButton(
                onClick = { onSelected(tab) },
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(vertical = 10.dp),
                colors = ButtonDefaults.textButtonColors(containerColor = if (isSel) MaterialTheme.colorScheme.surface else Color.Transparent),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text(tab.label, style = MaterialTheme.typography.bodyMedium, fontWeight = if (isSel) FontWeight.SemiBold else FontWeight.Normal)
            }
        }
    }
}

@Composable
private fun AboutSection(
    profile: Profile,
    isEditing: Boolean,
    editBio: String,
    editWebsite: String,
    onBioChange: (String) -> Unit,
    onWebsiteChange: (String) -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        SectionCard(title = stringResource(R.string.profile_bio_label)) {
            if (isEditing) {
                PhoneticTextField(
                    value = editBio,
                    onValueChange = onBioChange,
                    modifier = Modifier.fillMaxWidth().height(120.dp),
                    placeholder = stringResource(R.string.profile_bio_placeholder),
                    singleLine = false,
                )
            } else {
                Text(
                    text = profile.bio ?: stringResource(R.string.profile_no_bio),
                    color = if (profile.bio == null) KajHobeTheme.colors.textSecondary else MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
        SectionCard(title = "Website") {
            if (isEditing) {
                OutlinedTextField(
                    value = editWebsite,
                    onValueChange = onWebsiteChange,
                    singleLine = true,
                    placeholder = { Text("https://...") },
                    colors = profileEditColors(),
                )
            } else {
                val ws = profile.website
                if (ws.isNullOrBlank()) {
                    Text("No website", color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.bodyMedium)
                } else {
                    Text(ws, color = WarmOrange, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
}

@Composable
private fun DetailsSection(
    profile: Profile,
    isEditing: Boolean,
    editIsProvider: Boolean,
    editProfession: String,
    editTagline: String,
    editExperience: String,
    editHourlyRate: String,
    editTeamRate: String,
    editTeamHoursLabel: String,
    editPayoutBkash: String,
    payoutNumber: String,
    verification: ProviderVerification?,
    onFieldChange: (EditField, String) -> Unit,
    onGetVerified: () -> Unit,
) {
    val isVerified = profile.is_verified_provider == true

    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        SectionCard(title = "Account Type") {
            when {
                isVerified -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Service Provider", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                        Text("Verified by KajHobe", color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.labelSmall)
                    }
                    VerifiedBadge()
                }
                verification?.status == "pending" -> Column {
                    Text("Verification pending", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                    Text("Your application is under review. We'll notify you once it's approved.", color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.labelSmall)
                }
                verification?.status == "rejected" -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Verification rejected", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = Color.Red)
                    verification.rejection_reason?.takeIf { it.isNotBlank() }?.let {
                        Text(it, color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.labelSmall)
                    }
                    TextButton(onClick = onGetVerified, contentPadding = PaddingValues(horizontal = 8.dp)) { Text("Reapply") }
                }
                else -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Become a Service Provider", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                        Text("Get verified to apply for jobs and offer services", color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.labelSmall)
                    }
                    Spacer(Modifier.width(12.dp))
                    TextButton(onClick = onGetVerified, contentPadding = PaddingValues(horizontal = 8.dp)) { Text("Get Verified") }
                }
            }
        }

        if (isVerified) {
            SectionCard(title = "Provider Details") {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (isEditing) {
                        profileEditField("Profession", editProfession, "e.g. Electrician") { onFieldChange(EditField.PROFESSION, it) }
                        profileEditField("Tagline", editTagline, "e.g. Quick & reliable service") { onFieldChange(EditField.TAGLINE, it) }
                        profileEditField("Years of experience", editExperience, "e.g. 8", KeyboardType.Number) { onFieldChange(EditField.EXPERIENCE, it) }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            profileEditField("Hourly fee (৳)", editHourlyRate, "e.g. 159", KeyboardType.Decimal, Modifier.weight(1f)) { onFieldChange(EditField.HOURLY_RATE, it) }
                            profileEditField("Team work fee (৳)", editTeamRate, "e.g. 1059", KeyboardType.Decimal, Modifier.weight(1f)) { onFieldChange(EditField.TEAM_RATE, it) }
                        }
                        profileEditField("Team hours label", editTeamHoursLabel, "e.g. 4-7 hrs") { onFieldChange(EditField.TEAM_HOURS, it) }
                        profileEditField("Payout bKash number (private)", editPayoutBkash, "01XXXXXXXXX", KeyboardType.Number) { onFieldChange(EditField.PAYOUT_BKASH, it) }
                        Text("Only used to pay you when a deal completes. Never shown to clients.", color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.labelSmall)
                    } else {
                        readOnlyRow("Profession", profile.profession)
                        readOnlyRow("Tagline", profile.tagline)
                        readOnlyRow("Experience", profile.experience_years?.let { "$it year${if (it == 1) "" else "s"}" })
                        readOnlyRow("Hourly fee", profile.hourly_rate?.let { "৳${formatRate(it)}" })
                        readOnlyRow("Team work fee", profile.team_rate?.let { "৳${formatRate(it)}" })
                        readOnlyRow("Team hours", profile.team_hours_label)
                        readOnlyRow("Payout bKash", payoutNumber.ifBlank { null })
                    }
                }
            }
        }
    }
}

@Composable
private fun AccountSection(profile: Profile, onShowLogout: () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        SectionCard(title = "Account Info") {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 4.dp)) {
                Icon(Icons.Filled.Email, contentDescription = null, tint = KajHobeTheme.colors.textSecondary, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(10.dp))
                Text(profile.email ?: "No email", color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.bodyMedium)
            }
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Language, contentDescription = null, tint = KajHobeTheme.colors.textSecondary, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(10.dp))
                Text(if (profile.is_service_provider == true) "Service Provider" else "Client", color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.bodyMedium)
            }
        }
        TextButton(
            onClick = onShowLogout,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.Red.copy(alpha = 0.1f)),
            contentPadding = PaddingValues(vertical = 14.dp),
        ) {
            Icon(Icons.AutoMirrored.Filled.Logout, contentDescription = null, tint = Color.Red, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text("Logout", color = Color.Red, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun SectionCard(title: String, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface, RoundedCornerShape(14.dp)).border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(14.dp)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        content()
    }
}

@Composable
private fun profileEditField(label: String, value: String, placeholder: String, keyboardType: KeyboardType = KeyboardType.Text, modifier: Modifier = Modifier, onValueChange: (String) -> Unit) {
    Column(modifier = modifier) {
        Text(label, color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.labelSmall)
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            placeholder = { Text(placeholder) },
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            modifier = Modifier.fillMaxWidth(),
            colors = profileEditColors(),
        )
    }
}

@Composable
private fun readOnlyRow(label: String, value: String?) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = KajHobeTheme.colors.textSecondary, style = MaterialTheme.typography.bodyMedium)
        Text(value ?: "—", color = if (value == null) KajHobeTheme.colors.textSecondary else MaterialTheme.colorScheme.onSurface, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun profileEditColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = WarmOrange,
    unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
    cursorColor = WarmOrange,
)

private fun formatRate(v: Double): String {
    val isWhole = v % 1.0 == 0.0
    return if (isWhole) "%.0f".format(v) else "%.2f".format(v)
}

private fun formatLargeAmount(v: Double): String {
    val whole = v.toLong()
    return when {
        v >= 100_000 -> "${whole / 1000}K"
        else -> whole.toString()
    }
}
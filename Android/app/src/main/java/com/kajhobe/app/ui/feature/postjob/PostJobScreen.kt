package com.kajhobe.app.ui.feature.postjob

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kajhobe.app.data.model.HardcodedServiceCategory
import com.kajhobe.app.data.model.KhulnaLocations
import com.kajhobe.app.ui.components.MediaPicker
import com.kajhobe.app.ui.components.PremiumInputField
import com.kajhobe.app.ui.components.PrimaryButton
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.androidx.compose.koinViewModel

@Composable
fun PostJobScreen(
    onPosted: () -> Unit,
    viewModel: PostJobViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(state.didPost) {
        if (state.didPost) {
            viewModel.consumePosted()
            onPosted()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(KajHobeTheme.spacing.lg),
        verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
    ) {
        Text("Post a Job", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)

        PremiumInputField(
            value = state.title,
            onValueChange = viewModel::onTitleChange,
            label = "Title",
            placeholder = "Enter a clear, descriptive title",
        )
        PremiumInputField(
            value = state.description,
            onValueChange = viewModel::onDescriptionChange,
            label = "Description",
            singleLine = false,
        )

        LabeledDropdown(
            label = "Category",
            options = HardcodedServiceCategory.categories.map { "${it.icon} ${it.name}" },
            selectedIndex = HardcodedServiceCategory.categories.indexOfFirst { it.name == state.category }.coerceAtLeast(0),
            onSelect = { idx -> viewModel.onCategoryChange(HardcodedServiceCategory.categories[idx].name) },
        )

        // Photos & Videos (optional) — mirrors iOS PostJobView media section.
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Photos & Videos", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Text("Optional", style = MaterialTheme.typography.bodySmall, color = KajHobeTheme.colors.textSecondary)
        }
        MediaPicker(
            selected = state.selectedMedia,
            maxSelections = MAX_MEDIA_SELECTIONS,
            onAdd = viewModel::addMedia,
            onRemove = viewModel::removeMedia,
        )

        LabeledDropdown(
            label = "Location",
            options = KhulnaLocations.all,
            selectedIndex = KhulnaLocations.all.indexOf(state.location).coerceAtLeast(0),
            onSelect = { idx -> viewModel.onLocationChange(KhulnaLocations.all[idx]) },
        )

        OutlinedTextField(
            value = state.budget,
            onValueChange = viewModel::onBudgetChange,
            label = { Text("Budget (৳)") },
            placeholder = { Text("0") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth(),
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text("Mark as urgent", style = MaterialTheme.typography.titleSmall)
                Text(
                    "Urgent jobs are highlighted to providers",
                    style = MaterialTheme.typography.bodySmall,
                    color = KajHobeTheme.colors.textSecondary,
                )
            }
            Switch(checked = state.isUrgent, onCheckedChange = viewModel::onUrgentChange)
        }

        state.errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
        }

        Spacer(Modifier.height(KajHobeTheme.spacing.sm))
        PrimaryButton(
            text = when {
                state.isUploadingMedia -> "Uploading media…"
                state.isSubmitting -> "Posting…"
                else -> "Post Job"
            },
            onClick = viewModel::submit,
            enabled = state.isValid && !state.isSubmitting,
        )
        Spacer(Modifier.height(KajHobeTheme.spacing.xl))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LabeledDropdown(
    label: String,
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = options.getOrElse(selectedIndex) { "" },
            onValueChange = {},
            readOnly = true,
            label = { Text(label) },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(androidx.compose.material3.MenuAnchorType.PrimaryNotEditable),
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEachIndexed { index, option ->
                DropdownMenuItem(
                    text = { Text(option) },
                    onClick = {
                        onSelect(index)
                        expanded = false
                    },
                )
            }
        }
    }
}

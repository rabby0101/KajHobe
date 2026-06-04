package com.kajhobe.app.ui.feature.home

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.HardcodedServiceCategory
import com.kajhobe.app.ui.theme.KajHobeTheme

private const val MAX_FAVORITES = 4

/** Bottom sheet for choosing up to 4 favorite categories — iOS FavoriteCategoriesSelector. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoriteCategoriesSheet(
    currentFavorites: List<String>,
    onDismiss: () -> Unit,
    onSave: (List<String>) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selected by remember { mutableStateOf(currentFavorites.take(MAX_FAVORITES).toSet()) }
    val categories = HardcodedServiceCategory.categories

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = KajHobeTheme.spacing.lg)
                .padding(bottom = KajHobeTheme.spacing.xl),
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
        ) {
            Text("Favorite Categories", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(
                "Choose up to $MAX_FAVORITES favorite categories",
                style = MaterialTheme.typography.bodyMedium,
                color = KajHobeTheme.colors.textSecondary,
            )
            Text(
                "${selected.size}/$MAX_FAVORITES selected",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = if (selected.size == MAX_FAVORITES) KajHobeTheme.colors.warning
                else MaterialTheme.colorScheme.primary,
            )

            categories.chunked(2).forEach { rowCats ->
                Row(horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md)) {
                    rowCats.forEach { category ->
                        val isSelected = category.name in selected
                        val atCap = selected.size >= MAX_FAVORITES && !isSelected
                        SelectableCategoryTile(
                            category = category,
                            isSelected = isSelected,
                            disabled = atCap,
                            onClick = {
                                selected = when {
                                    isSelected -> selected - category.name
                                    selected.size < MAX_FAVORITES -> selected + category.name
                                    else -> selected
                                }
                            },
                            modifier = Modifier.weight(1f),
                        )
                    }
                    if (rowCats.size == 1) Spacer(Modifier.weight(1f))
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth().padding(top = KajHobeTheme.spacing.sm),
                horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
            ) {
                TextButton(onClick = onDismiss, modifier = Modifier.weight(1f)) { Text("Cancel") }
                Button(
                    onClick = { onSave(selected.toList()) },
                    modifier = Modifier.weight(1f),
                ) { Text("Save") }
            }
        }
    }
}

@Composable
private fun SelectableCategoryTile(
    category: HardcodedServiceCategory,
    isSelected: Boolean,
    disabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val bg = when {
        isSelected -> MaterialTheme.colorScheme.primary
        else -> KajHobeTheme.colors.subtleBackground
    }
    val contentColor = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface

    Surface(
        modifier = modifier
            .heightIn(min = 116.dp)
            .alpha(if (disabled) 0.5f else 1f)
            .border(
                BorderStroke(2.dp, if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent),
                shape = RoundedCornerShape(16.dp),
            )
            .clickable(enabled = !disabled, onClick = onClick),
        color = bg,
        shape = RoundedCornerShape(16.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(KajHobeTheme.spacing.md),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.xs),
        ) {
            Text(category.icon, style = MaterialTheme.typography.headlineMedium)
            Text(
                category.name,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                color = contentColor,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                category.bengaliName,
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center,
                color = if (isSelected) Color.White.copy(alpha = 0.8f) else KajHobeTheme.colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

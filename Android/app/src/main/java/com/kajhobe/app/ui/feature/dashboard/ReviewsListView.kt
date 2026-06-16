package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.ui.components.ProviderReviewCard
import com.kajhobe.app.ui.theme.KajHobeTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReviewsListView(
    reviews: List<ProviderReview>,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Reviews") },
            navigationIcon = {
                TextButton(onClick = onClose) { Text("Done") }
            },
        )
        if (reviews.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.Star, contentDescription = null, tint = KajHobeTheme.colors.textSecondary)
                    Text("No reviews yet", color = KajHobeTheme.colors.textSecondary)
                }
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(reviews, key = { it.id }) { review ->
                    ProviderReviewCard(review = review)
                }
            }
        }
    }
}

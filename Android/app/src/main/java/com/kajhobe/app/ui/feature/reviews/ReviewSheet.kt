package com.kajhobe.app.ui.feature.reviews

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.kajhobe.app.ui.theme.KajHobeTheme
import kotlinx.coroutines.delay

private val StarAmber = Color(0xFFFFC107)
private val SuccessGreen = Color(0xFF34C759)
private val ErrorRed = Color(0xFFFF3B30)

/**
 * Interactive 1–5 star rating control — Android port of iOS `StarRatingInput`.
 * Tapping a star sets the rating with a small haptic tick.
 */
@Composable
fun StarRatingInput(
    rating: Int,
    onRatingChange: (Int) -> Unit,
    modifier: Modifier = Modifier,
    starSize: androidx.compose.ui.unit.Dp = 40.dp,
) {
    val haptics = LocalHapticFeedback.current
    Row(
        modifier = modifier.semantics { contentDescription = "Rating: $rating out of 5 stars" },
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        for (star in 1..5) {
            IconButton(
                onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onRatingChange(star)
                },
                modifier = Modifier.size(starSize + 8.dp),
            ) {
                Icon(
                    imageVector = if (star <= rating) Icons.Filled.Star else Icons.Outlined.StarBorder,
                    contentDescription = "$star star${if (star == 1) "" else "s"}",
                    tint = StarAmber,
                    modifier = Modifier.size(starSize),
                )
            }
        }
    }
}

/**
 * Review submission sheet — Android port of iOS `ReviewSheet`. Shown automatically
 * after approving a deal completion, and from the "Leave a Review" button on
 * completed deals. Skippable ("Maybe later"); auto-dismisses ~1.2s after success.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReviewSheet(
    reviewedUserName: String?,
    reviewedUserAvatar: String?,
    isSubmitting: Boolean,
    submitted: Boolean,
    errorMessage: String?,
    onSubmit: (rating: Int, comment: String?) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var rating by remember { mutableIntStateOf(0) }
    var comment by remember { mutableStateOf("") }

    // Success state lingers briefly so the user sees the confirmation, then closes.
    LaunchedEffect(submitted) {
        if (submitted) {
            delay(1200)
            onDismiss()
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = KajHobeTheme.spacing.md)
                .padding(bottom = KajHobeTheme.spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.md),
        ) {
            if (submitted) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = SuccessGreen,
                    modifier = Modifier.size(56.dp),
                )
                Text("Thanks for your review!", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                Text(
                    "It helps others find great people to work with.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = KajHobeTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.size(KajHobeTheme.spacing.md))
                return@Column
            }

            Text("How was your experience?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)

            // Counterparty identity
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Box(
                    modifier = Modifier.size(40.dp).clip(CircleShape).background(StarAmber.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center,
                ) {
                    if (!reviewedUserAvatar.isNullOrBlank()) {
                        AsyncImage(
                            model = reviewedUserAvatar,
                            contentDescription = null,
                            modifier = Modifier.size(40.dp).clip(CircleShape),
                        )
                    } else {
                        Text(
                            (reviewedUserName ?: "?").take(1).uppercase(),
                            color = StarAmber,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
                Text(
                    reviewedUserName ?: "Your counterparty",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium,
                )
            }

            StarRatingInput(rating = rating, onRatingChange = { rating = it })

            OutlinedTextField(
                value = comment,
                onValueChange = { comment = it },
                label = { Text("Share a few words (optional)") },
                minLines = 3,
                maxLines = 6,
                modifier = Modifier.fillMaxWidth(),
            )

            if (errorMessage != null) {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    color = ErrorRed.copy(alpha = 0.1f),
                ) {
                    Text(
                        errorMessage,
                        modifier = Modifier.padding(KajHobeTheme.spacing.sm),
                        color = ErrorRed,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(KajHobeTheme.spacing.sm),
            ) {
                TextButton(onClick = onDismiss, modifier = Modifier.weight(1f)) { Text("Maybe later") }
                Button(
                    onClick = { onSubmit(rating, comment.ifBlank { null }) },
                    enabled = rating > 0 && !isSubmitting,
                    colors = ButtonDefaults.buttonColors(containerColor = StarAmber, contentColor = Color.White),
                    modifier = Modifier.weight(1f),
                ) {
                    if (isSubmitting) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                        Spacer(Modifier.size(8.dp))
                    }
                    Text("Submit Review", fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

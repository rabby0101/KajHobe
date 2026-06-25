package com.kajhobe.app.ui.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.github.mikephil.charting.charts.BarChart
import com.github.mikephil.charting.charts.LineChart
import com.github.mikephil.charting.components.XAxis
import com.github.mikephil.charting.data.BarData
import com.github.mikephil.charting.data.BarDataSet
import com.github.mikephil.charting.data.BarEntry
import com.github.mikephil.charting.data.Entry
import com.github.mikephil.charting.data.LineData
import com.github.mikephil.charting.data.LineDataSet
import com.github.mikephil.charting.formatter.IndexAxisValueFormatter
import com.github.mikephil.charting.formatter.ValueFormatter
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.text.DecimalFormat
import java.time.format.DateTimeFormatter
import java.util.Locale

private val TAKA_FORMAT = DecimalFormat("#,##0")

private fun formatTaka(value: Double): String {
    val abs = kotlin.math.abs(value)
    return when {
        abs >= 1_000_000 -> "৳" + TAKA_FORMAT.format(value / 1_000_000) + "M"
        abs >= 1_000 -> "৳" + TAKA_FORMAT.format(value / 1_000) + "K"
        else -> "৳" + TAKA_FORMAT.format(value)
    }
}

private class TakaAxisFormatter : ValueFormatter() {
    override fun getFormattedValue(value: Float): String = formatTaka(value.toDouble())
}

@Composable
fun DashboardChartsSection(
    deals: List<Deal>,
    reviews: List<ProviderReview>,
    userId: String,
    modifier: Modifier = Modifier,
) {
    // Hide zero-amount months so the bar chart doesn't show empty slivers
    val moneyFlow = remember(deals, userId) {
        DashboardAnalytics.monthlyMoneyFlow(deals, userId).filter { it.amount > 0.0 }
    }
    val statusSlices = remember(deals) { DashboardAnalytics.statusBreakdown(deals) }
    val ratingPoints = remember(reviews) { DashboardAnalytics.ratingTrend(reviews) }

    PremiumCard(
        modifier = modifier.fillMaxWidth(),
        contentPadding = 0.dp,
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            SectionHeader(
                icon = Icons.Filled.Insights,
                tint = MaterialTheme.colorScheme.tertiary,
                title = "Analytics",
                trailing = {
                    InlineLegend(
                        items = listOf(
                            "Earned" to KajHobeTheme.colors.success,
                            "Spent" to KajHobeTheme.colors.accentOrange,
                        ),
                    )
                },
            )
            Spacer(Modifier.height(12.dp))

            Text(
                "Money flow",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.height(8.dp))
            if (moneyFlow.size < 2) {
                ChartPlaceholder("Needs more history")
            } else {
                MoneyFlowChart(points = moneyFlow)
            }

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 12.dp),
                color = KajHobeTheme.colors.divider,
            )

            Text(
                "Deal status",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.height(8.dp))
            if (statusSlices.isEmpty()) {
                ChartPlaceholder("No deals yet")
            } else {
                StatusBarList(slices = statusSlices)
            }

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 12.dp),
                color = KajHobeTheme.colors.divider,
            )

            Text(
                "Rating trend",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.height(8.dp))
            if (ratingPoints.size < 2) {
                ChartPlaceholder("Needs more reviews")
            } else {
                RatingTrendChart(points = ratingPoints)
            }
        }
    }
}

@Composable
private fun SectionHeader(
    icon: ImageVector,
    tint: Color,
    title: String,
    trailing: (@Composable () -> Unit)? = null,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        if (trailing != null) trailing()
    }
}

@Composable
private fun InlineLegend(items: List<Pair<String, Color>>) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        items.forEach { (label, color) ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(color))
                Spacer(Modifier.width(4.dp))
                Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurface)
            }
        }
    }
}

@Composable
private fun ChartPlaceholder(message: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.BarChart, contentDescription = null, tint = KajHobeTheme.colors.textSecondary)
            Spacer(Modifier.height(6.dp))
            Text(message, style = MaterialTheme.typography.bodySmall, color = KajHobeTheme.colors.textSecondary)
        }
    }
}

@Composable
private fun MoneyFlowChart(points: List<DashboardAnalytics.MoneyPoint>) {
    val earnedColor = KajHobeTheme.colors.success.toArgb()
    val spentColor = KajHobeTheme.colors.accentOrange.toArgb()
    val dividerColor = KajHobeTheme.colors.divider.toArgb()
    val secondaryTextColor = KajHobeTheme.colors.textSecondary.toArgb()
    val months = remember(points) { points.map { it.month }.distinct().sorted() }
    val labels = remember(months) {
        months.map { it.format(DateTimeFormatter.ofPattern("MMM", Locale.US)) }
    }

    AndroidView(
        modifier = Modifier.fillMaxWidth().height(160.dp),
        factory = { ctx ->
            BarChart(ctx).apply {
                description.isEnabled = false
                legend.isEnabled = false
                axisRight.isEnabled = false
                axisLeft.setDrawGridLines(true)
                axisLeft.gridColor = dividerColor
                axisLeft.textColor = secondaryTextColor
                axisLeft.valueFormatter = TakaAxisFormatter()
                axisLeft.axisMinimum = 0f
                xAxis.position = XAxis.XAxisPosition.BOTTOM
                xAxis.setDrawGridLines(false)
                xAxis.granularity = 1f
                xAxis.isGranularityEnabled = true
                xAxis.textColor = secondaryTextColor
                setNoDataText("")
            }
        },
        update = { chart ->
            val monthIndex = { d: java.time.OffsetDateTime -> months.indexOf(d) }
            val earnedEntries = points
                .filter { it.role == DashboardAnalytics.MoneyPoint.Role.earned }
                .map { BarEntry(monthIndex(it.month).toFloat(), it.amount.toFloat()) }
            val spentEntries = points
                .filter { it.role == DashboardAnalytics.MoneyPoint.Role.spent }
                .map { BarEntry(monthIndex(it.month).toFloat(), it.amount.toFloat()) }
            val earnedSet = BarDataSet(earnedEntries, "Earned").apply {
                color = earnedColor
                setDrawValues(false)
            }
            val spentSet = BarDataSet(spentEntries, "Spent").apply {
                color = spentColor
                setDrawValues(false)
            }
            val data = BarData(earnedSet, spentSet).apply { barWidth = 0.35f }
            chart.data = data
            chart.xAxis.valueFormatter = IndexAxisValueFormatter(labels)
            chart.groupBars(0f, 0.2f, 0.05f)
            chart.notifyDataSetChanged()
            chart.invalidate()
        },
    )
}

@Composable
private fun StatusBarList(slices: List<DashboardAnalytics.StatusSlice>) {
    val total = slices.sumOf { it.count }.coerceAtLeast(1)
    val colors = slices.map { statusColor(it.status) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        slices.forEachIndexed { idx, slice ->
            StatusBarRow(
                label = slice.status,
                count = slice.count,
                color = colors[idx],
                fraction = slice.count.toFloat() / total,
            )
        }
    }
}

@Composable
private fun StatusBarRow(label: String, count: Int, color: Color, fraction: Float) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(color))
            Spacer(Modifier.width(8.dp))
            Text(
                label,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            Text(
                count.toString(),
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(KajHobeTheme.colors.subtleBackground),
        ) {
            if (fraction > 0f) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(color),
                )
            }
        }
    }
}

@Composable
private fun RatingTrendChart(points: List<DashboardAnalytics.RatingPoint>) {
    val yellow = KajHobeTheme.colors.accentOrange.toArgb()
    val dividerColor = KajHobeTheme.colors.divider.toArgb()
    val secondaryTextColor = KajHobeTheme.colors.textSecondary.toArgb()
    val labels = remember(points) {
        points.map { it.month.format(DateTimeFormatter.ofPattern("MMM", Locale.US)) }
    }

    AndroidView(
        modifier = Modifier.fillMaxWidth().height(140.dp),
        factory = { ctx ->
            LineChart(ctx).apply {
                description.isEnabled = false
                legend.isEnabled = false
                axisRight.isEnabled = false
                xAxis.position = XAxis.XAxisPosition.BOTTOM
                xAxis.setDrawGridLines(false)
                xAxis.granularity = 1f
                xAxis.isGranularityEnabled = true
                xAxis.textColor = secondaryTextColor
                axisLeft.axisMinimum = 0f
                axisLeft.axisMaximum = 5f
                axisLeft.textColor = secondaryTextColor
                axisLeft.gridColor = dividerColor
                setNoDataText("")
            }
        },
        update = { chart ->
            val entries = points.map { Entry(it.month.monthValue.toFloat(), it.runningAverage.toFloat()) }
            val ds = LineDataSet(entries, "Rating").apply {
                color = yellow
                setCircleColor(yellow)
                circleRadius = 4f
                lineWidth = 2f
                setDrawValues(false)
                mode = LineDataSet.Mode.CUBIC_BEZIER
            }
            chart.data = LineData(ds)
            chart.xAxis.valueFormatter = IndexAxisValueFormatter(labels)
            chart.notifyDataSetChanged()
            chart.invalidate()
        },
    )
}

@Composable
private fun statusColor(status: String): Color = when (status.lowercase()) {
    "completed" -> KajHobeTheme.colors.success
    "in progress" -> MaterialTheme.colorScheme.primary
    "pending approval" -> KajHobeTheme.colors.accentOrange
    "disputed" -> MaterialTheme.colorScheme.error
    "resolved" -> MaterialTheme.colorScheme.tertiary
    else -> KajHobeTheme.colors.textSecondary
}

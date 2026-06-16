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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.outlined.Insights
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.github.mikephil.charting.charts.BarChart
import com.github.mikephil.charting.charts.LineChart
import com.github.mikephil.charting.charts.PieChart
import com.github.mikephil.charting.components.XAxis
import com.github.mikephil.charting.data.BarData
import com.github.mikephil.charting.data.BarDataSet
import com.github.mikephil.charting.data.BarEntry
import com.github.mikephil.charting.data.Entry
import com.github.mikephil.charting.data.LineData
import com.github.mikephil.charting.data.LineDataSet
import com.github.mikephil.charting.data.PieData
import com.github.mikephil.charting.data.PieDataSet
import com.github.mikephil.charting.data.PieEntry
import com.github.mikephil.charting.formatter.IndexAxisValueFormatter
import com.kajhobe.app.data.model.Deal
import com.kajhobe.app.data.model.ProviderReview
import com.kajhobe.app.ui.components.PremiumCard
import com.kajhobe.app.ui.theme.KajHobeTheme
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Analytics section of the Dashboard: money flow bar, status donut, rating-trend line.
 * Uses MPAndroidChart (Swift Charts equivalent on Android). Mirrors iOS
 * `DashboardChartsSection.swift` section-for-section.
 */
@Composable
fun DashboardChartsSection(
    deals: List<Deal>,
    reviews: List<ProviderReview>,
    userId: String,
    modifier: Modifier = Modifier,
) {
    val moneyFlow = remember(deals, userId) { DashboardAnalytics.monthlyMoneyFlow(deals, userId) }
    val statusSlices = remember(deals) { DashboardAnalytics.statusBreakdown(deals) }
    val ratingPoints = remember(reviews) { DashboardAnalytics.ratingTrend(reviews) }

    PremiumCard(modifier = modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.Insights, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
            Spacer(Modifier.width(8.dp))
            Text("Analytics", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(16.dp))
        Text("Money flow", style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(8.dp))
        if (moneyFlow.size < 2) {
            ChartPlaceholder("Needs more history")
        } else {
            MoneyFlowChart(points = moneyFlow)
        }
        Spacer(Modifier.height(16.dp))
        Text("Deal status", style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(8.dp))
        if (statusSlices.isEmpty()) {
            ChartPlaceholder("No deals yet")
        } else {
            StatusDonut(slices = statusSlices)
        }
        Spacer(Modifier.height(16.dp))
        Text("Rating trend", style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(8.dp))
        if (ratingPoints.size < 2) {
            ChartPlaceholder("Needs more reviews")
        } else {
            RatingTrendChart(points = ratingPoints)
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
    val months = remember(points) { points.map { it.month }.distinct().sorted() }
    val labels = remember(months) { months.map { it.format(DateTimeFormatter.ofPattern("MMM", Locale.US)) } }

    AndroidView(
        modifier = Modifier.fillMaxWidth().height(180.dp),
        factory = { ctx ->
            BarChart(ctx).apply {
                description.isEnabled = false
                legend.isEnabled = true
                axisRight.isEnabled = false
                axisLeft.setDrawGridLines(false)
                xAxis.position = XAxis.XAxisPosition.BOTTOM
                xAxis.setDrawGridLines(false)
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
            chart.invalidate()
        },
    )
}

@Composable
private fun StatusDonut(slices: List<DashboardAnalytics.StatusSlice>) {
    val colors = slices.map { statusColor(it.status) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        AndroidView(
            modifier = Modifier.size(130.dp),
            factory = { ctx ->
                PieChart(ctx).apply {
                    description.isEnabled = false
                    isDrawHoleEnabled = true
                    holeRadius = 60f
                    transparentCircleRadius = 0f
                    setUsePercentValues(false)
                    legend.isEnabled = false
                }
            },
            update = { chart ->
                val entries = slices.map { PieEntry(it.count.toFloat(), it.status) }
                val ds = PieDataSet(entries, "").apply {
                    setColors(colors.map { it.toArgb() })
                    setDrawValues(false)
                    sliceSpace = 2f
                }
                chart.data = PieData(ds)
                chart.invalidate()
            },
        )
        Spacer(Modifier.width(16.dp))
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            slices.forEach { slice ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(colors[slices.indexOf(slice)]),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        slice.status,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.weight(1f),
                    )
                    Text(slice.count.toString(), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun RatingTrendChart(points: List<DashboardAnalytics.RatingPoint>) {
    val yellow = KajHobeTheme.colors.accentOrange.toArgb()
    val labels = remember(points) { points.map { it.month.format(DateTimeFormatter.ofPattern("MMM", Locale.US)) } }

    AndroidView(
        modifier = Modifier.fillMaxWidth().height(140.dp),
        factory = { ctx ->
            LineChart(ctx).apply {
                description.isEnabled = false
                legend.isEnabled = false
                axisRight.isEnabled = false
                xAxis.position = XAxis.XAxisPosition.BOTTOM
                xAxis.setDrawGridLines(false)
                axisLeft.axisMinimum = 0f
                axisLeft.axisMaximum = 5f
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

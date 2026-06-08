package com.kajhobe.app.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Message
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Work
import androidx.compose.ui.graphics.vector.ImageVector
import android.net.Uri

/** The five bottom-nav tabs — mirrors iOS MainTabView. */
enum class TopLevelDestination(
    val route: String,
    val label: String,
    val icon: ImageVector,
) {
    JOBS("jobs", "Jobs", Icons.Filled.Work),
    MESSAGES("messages", "Messages", Icons.AutoMirrored.Filled.Message),
    POST("post", "Post", Icons.Filled.AddCircle),
    NOTIFICATIONS("notifications", "Notifications", Icons.Filled.Notifications),
    DASHBOARD("dashboard", "Dashboard", Icons.Filled.BarChart),
}

/** Detail/stack routes presented within the main graph. */
object Routes {
    const val JOB_DETAIL = "job/{jobId}"
    const val PUBLIC_PROFILE = "profile/{userId}"
    const val CHAT = "chat/{conversationId}"
    const val DEAL_DETAIL = "deal/{dealId}"

    // Home → vertical job lists
    const val ALL_JOBS = "jobs/list/{kind}"          // kind = near_you|featured|recent
    const val CATEGORY_JOBS = "jobs/category/{name}"
    const val JOBS_SEARCH = "jobs/search"

    fun jobDetail(jobId: String) = "job/$jobId"
    fun publicProfile(userId: String) = "profile/$userId"
    fun chat(conversationId: String) = "chat/$conversationId"
    fun dealDetail(dealId: String) = "deal/$dealId"
    fun allJobs(kindSlug: String) = "jobs/list/$kindSlug"
    fun categoryJobs(name: String) = "jobs/category/${Uri.encode(name)}"
}

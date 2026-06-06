package com.kajhobe.app.ui.navigation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.kajhobe.app.data.notifications.NotificationBadgeManager
import com.kajhobe.app.ui.components.PrimaryButton
import com.kajhobe.app.ui.feature.home.AllJobsScreen
import com.kajhobe.app.ui.feature.home.HomeScreen
import com.kajhobe.app.ui.feature.home.JobListKind
import com.kajhobe.app.ui.feature.jobs.JobDetailScreen
import com.kajhobe.app.ui.feature.dashboard.DashboardScreen
import com.kajhobe.app.ui.feature.dashboard.DealDetailScreen
import com.kajhobe.app.ui.feature.messages.ChatScreen
import com.kajhobe.app.ui.feature.messages.ConversationsScreen
import com.kajhobe.app.ui.feature.notifications.NotificationsScreen
import com.kajhobe.app.ui.feature.postjob.PostJobScreen
import com.kajhobe.app.ui.theme.KajHobeTheme
import org.koin.compose.koinInject

/**
 * Authenticated shell: bottom navigation over a nested NavHost (iOS MainTabView).
 * Tab bodies are placeholders until the feature phases fill them in.
 */
@Composable
fun MainScaffold(onSignOut: () -> Unit) {
    val navController = rememberNavController()
    val badgeManager = koinInject<NotificationBadgeManager>()
    val unreadCount by badgeManager.unreadCount.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { badgeManager.refreshCounts() }

    Scaffold(
        bottomBar = {
            NavigationBar {
                val navBackStackEntry by navController.currentBackStackEntryAsState()
                val currentDestination = navBackStackEntry?.destination
                TopLevelDestination.entries.forEach { dest ->
                    val selected = currentDestination?.hierarchy?.any { it.route == dest.route } == true
                    val showBadge = dest == TopLevelDestination.NOTIFICATIONS && unreadCount > 0
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(dest.route) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = {
                            if (showBadge) {
                                BadgedBox(badge = { Badge { Text(if (unreadCount > 99) "99+" else "$unreadCount") } }) {
                                    Icon(dest.icon, contentDescription = dest.label)
                                }
                            } else {
                                Icon(dest.icon, contentDescription = dest.label)
                            }
                        },
                        label = { Text(dest.label) },
                    )
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = TopLevelDestination.JOBS.route,
            modifier = Modifier.padding(innerPadding),
        ) {
            composable(TopLevelDestination.JOBS.route) {
                HomeScreen(
                    onJobClick = { jobId -> navController.navigate(Routes.jobDetail(jobId)) },
                    onViewAll = { kind -> navController.navigate(Routes.allJobs(kind.slug)) },
                    onCategoryClick = { name -> navController.navigate(Routes.categoryJobs(name)) },
                    onOpenSearch = { navController.navigate(Routes.JOBS_SEARCH) },
                )
            }
            composable(Routes.ALL_JOBS) { entry ->
                AllJobsScreen(
                    kind = JobListKind.fromSlug(entry.arguments?.getString("kind")),
                    categoryName = null,
                    isSearch = false,
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.jobDetail(jobId)) },
                )
            }
            composable(Routes.CATEGORY_JOBS) { entry ->
                AllJobsScreen(
                    kind = null,
                    categoryName = entry.arguments?.getString("name").orEmpty(),
                    isSearch = false,
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.jobDetail(jobId)) },
                )
            }
            composable(Routes.JOBS_SEARCH) {
                AllJobsScreen(
                    kind = null,
                    categoryName = null,
                    isSearch = true,
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.jobDetail(jobId)) },
                )
            }
            composable(Routes.JOB_DETAIL) { entry ->
                JobDetailScreen(
                    jobId = entry.arguments?.getString("jobId").orEmpty(),
                    onBack = { navController.popBackStack() },
                    onViewProfile = { userId -> navController.navigate(Routes.publicProfile(userId)) },
                )
            }
            composable(TopLevelDestination.MESSAGES.route) {
                ConversationsScreen(onOpenChat = { id -> navController.navigate(Routes.chat(id)) })
            }
            composable(Routes.CHAT) { entry ->
                ChatScreen(
                    conversationId = entry.arguments?.getString("conversationId").orEmpty(),
                    onBack = { navController.popBackStack() },
                )
            }
            composable(TopLevelDestination.POST.route) {
                PostJobScreen(onPosted = {
                    navController.navigate(TopLevelDestination.JOBS.route) {
                        popUpTo(navController.graph.findStartDestination().id) { saveState = false }
                        launchSingleTop = true
                    }
                })
            }
            composable(TopLevelDestination.NOTIFICATIONS.route) {
                NotificationsScreen(
                    onOpenDeal = { dealId -> navController.navigate(Routes.dealDetail(dealId)) },
                )
            }
            composable(TopLevelDestination.DASHBOARD.route) {
                DashboardScreen(
                    onSignOut = onSignOut,
                    onDealClick = { dealId -> navController.navigate(Routes.dealDetail(dealId)) },
                )
            }
            composable(Routes.DEAL_DETAIL) { entry ->
                DealDetailScreen(
                    dealId = entry.arguments?.getString("dealId").orEmpty(),
                    onBack = { navController.popBackStack() },
                    onOpenChat = { conversationId -> navController.navigate(Routes.chat(conversationId)) },
                )
            }
        }
    }
}

@Composable
private fun PlaceholderTab(title: String, onSignOut: (() -> Unit)? = null) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(KajHobeTheme.spacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(title, style = MaterialTheme.typography.headlineMedium)
        Text(
            "Coming soon",
            style = MaterialTheme.typography.bodyMedium,
            color = KajHobeTheme.colors.textSecondary,
            modifier = Modifier.padding(top = KajHobeTheme.spacing.sm),
        )
        if (onSignOut != null) {
            PrimaryButton(
                text = "Sign out",
                onClick = onSignOut,
                fillWidth = false,
                modifier = Modifier.padding(top = KajHobeTheme.spacing.xl),
            )
        }
    }
}

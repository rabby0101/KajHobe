package com.kajhobe.app.ui.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.kajhobe.app.data.notifications.MessageBadgeManager
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
import com.kajhobe.app.ui.feature.profile.PublicProfileScreen
import com.kajhobe.app.ui.feature.profile.ProfileScreen
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
    val messageBadgeManager = koinInject<MessageBadgeManager>()
    val navBus = koinInject<NavigationEventBus>()
    val unreadCount by badgeManager.unreadCount.collectAsStateWithLifecycle()
    val messageUnreadCount by messageBadgeManager.totalUnreadCount.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { badgeManager.refreshCounts() }

    // Switch between top-level tabs the same way a bottom-bar tap does: a pure tab
    // switch (no extra back-stack entry), so the bottom bar stays the way back. Used
    // for both bar taps and programmatic NavEvents (e.g. a notification falling back
    // to the Dashboard tab) so neither strands the user on a tab with no way back.
    val switchTab: (String) -> Unit = { route ->
        navController.navigate(route) {
            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }

    // App-wide navigation events (interest notification tap → sender's profile, etc.).
    // The bus is buffered (extraBufferCapacity = 16) so events emitted before this
    // LaunchedEffect starts are replayed instead of being lost.
    LaunchedEffect(Unit) {
        navBus.events.collect { event ->
            when (event) {
                is NavEvent.ToProfile ->
                    navController.navigate(Routes.publicProfile(event.userId))
                is NavEvent.ToChat ->
                    navController.navigate(Routes.chat(event.conversationId))
                is NavEvent.ToJob ->
                    navController.navigate(Routes.jobDetail(event.jobId))
                NavEvent.ToJobs -> switchTab(TopLevelDestination.JOBS.route)
                NavEvent.ToMessages -> switchTab(TopLevelDestination.MESSAGES.route)
                NavEvent.ToNotifications -> switchTab(TopLevelDestination.NOTIFICATIONS.route)
                NavEvent.ToDashboard -> switchTab(TopLevelDestination.DASHBOARD.route)
            }
        }
    }

    val currentDestination = navController.currentBackStackEntryAsState().value?.destination
    val isTopLevel = TopLevelDestination.entries.any { dest ->
        currentDestination?.hierarchy?.any { it.route == dest.route } == true
    }

    val isDark = KajHobeTheme.isDark
    val bottomBarBg = if (isDark) Color.Black else Color.White

    Scaffold(
        contentWindowInsets = WindowInsets.statusBars,
        bottomBar = {
            if (isTopLevel) {
                Column(
                    modifier = Modifier
                        .background(bottomBarBg)
                        .navigationBarsPadding(),
                ) {
                    HorizontalDivider(
                        thickness = 0.5.dp,
                        color = if (isDark) Color(0xFF272727) else Color(0xFFE5E5E5),
                    )
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(64.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceEvenly,
                    ) {
                        TopLevelDestination.entries.forEach { dest ->
                            val selected = currentDestination?.hierarchy?.any { it.route == dest.route } == true
                            val showNotifBadge = dest == TopLevelDestination.NOTIFICATIONS && unreadCount > 0
                            val showMessagesBadge = dest == TopLevelDestination.MESSAGES && messageUnreadCount > 0
                            val tabBadgeCount: Int? = when {
                                showNotifBadge -> unreadCount
                                showMessagesBadge -> messageUnreadCount
                                else -> null
                            }
                            val selectedIcon = if (isDark) Color.White else Color.Black
                            val unselectedIcon = if (isDark) Color(0xFFAAAAAA) else Color(0xFF606060)
                            YouTubeTabCell(
                                selected = selected,
                                selectedColor = selectedIcon,
                                unselectedColor = unselectedIcon,
                                badgeCount = tabBadgeCount,
                                onClick = { switchTab(dest.route) },
                                label = dest.label,
                                icon = dest.icon,
                                selectedIconVariant = dest.selectedIcon,
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
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
                    onMyProfile = { navController.navigate(Routes.MY_PROFILE) },
                    onNotificationSettings = { navController.navigate(Routes.NOTIFICATION_SETTINGS) },
                    onOpenJobs = {
                        navController.navigate(TopLevelDestination.JOBS.route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                        }
                    },
                    onPostJob = { navController.navigate(TopLevelDestination.POST.route) },
                    onDealClick = { dealId -> navController.navigate(Routes.dealDetail(dealId)) },
                )
            }
            composable(Routes.NOTIFICATION_SETTINGS) {
                com.kajhobe.app.ui.feature.dashboard.NotificationSettingsScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.DEAL_DETAIL) { entry ->
                DealDetailScreen(
                    dealId = entry.arguments?.getString("dealId").orEmpty(),
                    onBack = { navController.popBackStack() },
                    onOpenChat = { conversationId -> navController.navigate(Routes.chat(conversationId)) },
                )
            }
            composable(Routes.PUBLIC_PROFILE) { entry ->
                PublicProfileScreen(
                    userId = entry.arguments?.getString("userId").orEmpty(),
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.MY_PROFILE) {
                ProfileScreen(
                    onBack = { navController.popBackStack() },
                    onSignOut = onSignOut,
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

@Composable
private fun YouTubeTabCell(
    selected: Boolean,
    selectedColor: Color,
    unselectedColor: Color,
    badgeCount: Int?,
    onClick: () -> Unit,
    label: String,
    icon: ImageVector,
    selectedIconVariant: ImageVector,
    modifier: Modifier = Modifier,
) {
    val tint = if (selected) selectedColor else unselectedColor
    Column(
        modifier = modifier
            .fillMaxHeight()
            .clickable(
                onClick = onClick,
                indication = null,
                interactionSource = remember { MutableInteractionSource() },
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        TabIcon(
            badgeCount = badgeCount,
            tint = tint,
            icon = if (selected) selectedIconVariant else icon,
            contentDescription = label,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = label,
            color = tint,
            fontSize = 10.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun TabIcon(
    badgeCount: Int?,
    tint: Color,
    icon: ImageVector,
    contentDescription: String,
) {
    if (badgeCount != null) {
        BadgedBox(badge = { Badge { Text(if (badgeCount > 99) "99+" else "$badgeCount") } }) {
            Icon(
                imageVector = icon,
                contentDescription = contentDescription,
                tint = tint,
                modifier = Modifier.size(26.dp),
            )
        }
    } else {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = tint,
            modifier = Modifier.size(26.dp),
        )
    }
}

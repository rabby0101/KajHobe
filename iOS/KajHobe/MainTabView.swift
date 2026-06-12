import SwiftUI

struct MainTabView: View {
    @ObservedObject private var router = AppRouter.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var notificationBadgeManager = NotificationBadgeManager.shared
    @ObservedObject private var messageBadgeManager = MessageBadgeManager.shared
    @EnvironmentObject var pushNotificationManager: PushNotificationManager
    
    var body: some View {
        TabView(selection: $router.selectedTab) {
            JobsListView()
                .tabItem {
                    Image(systemName: "briefcase")
                    Text("jobs".localized)
                }
                .tag(AppRouter.Tab.jobs)

            MessagesView()
                .tabItem {
                    Image(systemName: messageBadgeManager.totalUnreadCount > 0 ? "message.fill" : "message")
                    Text("messages".localized)
                }
                .badge(messageBadgeManager.totalUnreadCount > 0 ? messageBadgeManager.totalUnreadCount : 0)
                .tag(AppRouter.Tab.messages)
                .environmentObject(messageBadgeManager)

            PostJobView()
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("post_a_job".localized)
                }
                .tag(AppRouter.Tab.postJob)

            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("dashboard".localized)
                }
                .tag(AppRouter.Tab.dashboard)

            NotificationsView()
                .tabItem {
                    Image(systemName: notificationBadgeManager.unreadCount > 0 ? "bell.fill" : "bell")
                    Text("notifications".localized)
                }
                .badge(notificationBadgeManager.unreadCount > 0 ? notificationBadgeManager.unreadCount : 0)
                .tag(AppRouter.Tab.notifications)
                .environmentObject(notificationBadgeManager)
        }
        .accentColor(.white)
        .gradientBackground()
        .environmentObject(router)
        .onAppear {
            // ViewModel will handle initialization when MessagesView appears
            setupNotificationObservers()
        }
        .task {
            // Guaranteed, idempotent boot of the realtime badge subscriptions once the
            // authenticated shell is visible — independent of authStateChanges timing.
            // start() is guarded by isStarting, so overlapping with the sign-in call is safe.
            await NotificationBadgeManager.shared.start()
            await MessageBadgeManager.shared.start()
        }
        .sheet(item: $router.presentedSheet) { destination in
            switch destination {
            case .deal(let deal):
                DealDetailView(deal: deal)
            case .conversation(let conversation):
                NavigationStack {
                    ChatView(conversation: conversation)
                }
            case .publicProfile(let userId):
                PublicProfileView(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToMessages"))) { _ in
            // Switch to Messages tab
            router.switchTab(.messages)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToJobs"))) { _ in
            // Switch to Jobs tab (used by PostJobView's back button)
            router.switchTab(.jobs)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConversation"))) { notification in
            // Posted by PushNotificationManager when a message push is tapped
            // (conversation id travels as the notification object).
            router.switchTab(.messages)
            if let conversationId = notification.object as? String {
                Task { await router.openConversation(id: conversationId) }
            }
        }
        .onChange(of: router.selectedTab) { _, newValue in
            switch newValue {
            case .jobs:
                // Do NOT post RefreshJobs here — the realtime subscription + .task already
                // keep the list fresh. Posting it on every tab switch caused a forced
                // spinner reload every time the user returned to the home tab.
                // Other screens (e.g. PostJobView) can still post RefreshJobs explicitly
                // when they need to force a reload after a mutation.
                break
            case .messages:
                break
            case .postJob:
                NotificationCenter.default.post(name: NSNotification.Name("RefreshPostJob"), object: nil)
            case .notifications:
                NotificationCenter.default.post(name: NSNotification.Name("RefreshNotifications"), object: nil)
            case .dashboard:
                NotificationCenter.default.post(name: NSNotification.Name("RefreshDashboard"), object: nil)
            }
        }
    }
    
    
    
    // MARK: - Push Notification Handlers
    private func setupNotificationObservers() {
        // Listen for navigation requests from push notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToNotifications"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in AppRouter.shared.switchTab(.notifications) }
        }

        // Handle profile navigation from notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToProfile"),
            object: nil,
            queue: .main
        ) { notification in
            if let userId = notification.object as? String {
                print("📱 Navigating to profile: \(userId)")
                Task { @MainActor in AppRouter.shared.present(.publicProfile(userId: userId)) }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToOffers"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in AppRouter.shared.switchTab(.dashboard) }
        }
        
        // Update badge count when notifications change
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NotificationsUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let count = notification.object as? Int {
                pushNotificationManager.updateBadgeCount(count)
            }
        }
    }
    
}

#Preview {
    MainTabView()
} 
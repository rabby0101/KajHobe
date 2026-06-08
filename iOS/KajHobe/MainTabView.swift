import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var profileToShow: String? = nil
    @State private var showProfileSheet = false
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var notificationBadgeManager = NotificationBadgeManager.shared
    @ObservedObject private var messageBadgeManager = MessageBadgeManager.shared
    @EnvironmentObject var pushNotificationManager: PushNotificationManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            JobsListView()
                .tabItem {
                    Image(systemName: "briefcase")
                    Text("jobs".localized)
                }
                .tag(0)
            
            MessagesView()
                .tabItem {
                    Image(systemName: messageBadgeManager.totalUnreadCount > 0 ? "message.fill" : "message")
                    Text("messages".localized)
                }
                .badge(messageBadgeManager.totalUnreadCount > 0 ? messageBadgeManager.totalUnreadCount : 0)
                .tag(1)
                .environmentObject(messageBadgeManager)
            
            PostJobView()
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("post_a_job".localized)
                }
                .tag(2)
            
            NotificationsView()
                .tabItem {
                    Image(systemName: notificationBadgeManager.unreadCount > 0 ? "bell.fill" : "bell")
                    Text("notifications".localized)
                }
                .badge(notificationBadgeManager.unreadCount > 0 ? notificationBadgeManager.unreadCount : 0)
                .tag(3)
                .environmentObject(notificationBadgeManager)
            
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("dashboard".localized)
                }
                .tag(4)
        }
        .accentColor(.white)
        .gradientBackground()
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
        .sheet(isPresented: $showProfileSheet) {
            if let userId = profileToShow {
                PublicProfileView(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToMessages"))) { notification in
            // Switch to Messages tab
            selectedTab = 1
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 0 { // Jobs tab
                // Do NOT post RefreshJobs here — the realtime subscription + .task already
                // keep the list fresh. Posting it on every tab switch caused a forced
                // spinner reload every time the user returned to the home tab.
                // Other screens (e.g. PostJobView) can still post RefreshJobs explicitly
                // when they need to force a reload after a mutation.
            } else if newValue == 1 { // Messages tab
                // Messaging disabled - no refresh needed
            } else if newValue == 2 { // Post Job tab
                NotificationCenter.default.post(name: NSNotification.Name("RefreshPostJob"), object: nil)
            } else if newValue == 3 { // Notifications tab
                NotificationCenter.default.post(name: NSNotification.Name("RefreshNotifications"), object: nil)
            } else if newValue == 4 { // Dashboard tab
                // Post notification to refresh dashboard when tab becomes active
                NotificationCenter.default.post(name: NSNotification.Name("RefreshDashboard"), object: nil)
                // print("📊 Dashboard tab selected - posting refresh notification")
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
            selectedTab = 3 // Switch to notifications tab
        }
        
        // Handle profile navigation from notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToProfile"),
            object: nil,
            queue: .main
        ) { notification in
            if let userId = notification.object as? String {
                profileToShow = userId
                showProfileSheet = true
                print("📱 Navigating to profile: \(userId)")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToOffers"),
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = 4 // Switch to dashboard tab for offers
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
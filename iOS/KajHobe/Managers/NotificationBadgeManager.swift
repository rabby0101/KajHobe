import SwiftUI
import Combine
import Supabase

/// Manages notification badge counts across the app
class NotificationBadgeManager: ObservableObject {
    static let shared = NotificationBadgeManager()
    
    @Published var unreadCount: Int = 0
    @Published var readCount: Int = 0
    @Published var archivedCount: Int = 0
    
    private let networking = NotificationsNetworking.shared
    private var cancellables = Set<AnyCancellable>()
    private var realtimeChannel: RealtimeChannelV2?
    
    private init() {
        setupRealtimeSubscription()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// Refresh notification counts
    func refreshCounts() async {
        do {
            let counts = try await networking.getNotificationCounts()
            
            await MainActor.run {
                self.unreadCount = counts.unread
                self.readCount = counts.read
                self.archivedCount = counts.archived
            }
            
            print("🔢 Updated notification counts: unread=\(counts.unread), read=\(counts.read), archived=\(counts.archived)")
        } catch {
            print("❌ Error refreshing notification counts: \(error)")
        }
    }
    
    /// Update counts when a notification state changes
    func updateCounts(oldState: NotificationState, newState: NotificationState) {
        DispatchQueue.main.async {
            // Decrease count from old state
            switch oldState {
            case .unread:
                self.unreadCount = max(0, self.unreadCount - 1)
            case .read:
                self.readCount = max(0, self.readCount - 1)
            case .archived:
                self.archivedCount = max(0, self.archivedCount - 1)
            }
            
            // Increase count for new state
            switch newState {
            case .unread:
                self.unreadCount += 1
            case .read:
                self.readCount += 1
            case .archived:
                self.archivedCount += 1
            }
        }
    }
    
    /// Add a new notification (always unread initially)
    func addNewNotification() {
        DispatchQueue.main.async {
            self.unreadCount += 1
        }
    }
    
    /// Mark multiple notifications as read
    func markNotificationsAsRead(_ count: Int) {
        DispatchQueue.main.async {
            let actualCount = min(count, self.unreadCount)
            self.unreadCount = max(0, self.unreadCount - actualCount)
            self.readCount += actualCount
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRealtimeSubscription() {
        Task {
            do {
                let user = try await supabase.auth.user()
                
                realtimeChannel = await networking.subscribeToNotifications(
                    userId: user.id.uuidString,
                    onNewNotification: { [weak self] notification in
                        self?.addNewNotification()
                    },
                    onNotificationUpdate: { [weak self] notification in
                        // Update counts based on notification state changes
                        // This is a simplified approach - in a real app you'd track the previous state
                        Task {
                            await self?.refreshCounts()
                        }
                    }
                )
                
                // Initial count refresh
                await refreshCounts()
                
            } catch {
                print("❌ Error setting up NotificationBadgeManager subscription: \(error)")
            }
        }
    }
    
    private func cleanup() {
        Task {
            await networking.unsubscribeFromNotifications(realtimeChannel)
        }
        realtimeChannel = nil
        cancellables.removeAll()
    }
}

// MARK: - SwiftUI Environment Key
struct NotificationBadgeManagerKey: EnvironmentKey {
    static let defaultValue = NotificationBadgeManager.shared
}

extension EnvironmentValues {
    var notificationBadgeManager: NotificationBadgeManager {
        get { self[NotificationBadgeManagerKey.self] }
        set { self[NotificationBadgeManagerKey.self] = newValue }
    }
}
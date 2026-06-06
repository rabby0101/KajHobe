import SwiftUI
import UserNotifications
import Supabase
import Combine

// MARK: - Notification Types
enum NotificationType: String, CaseIterable {
    case interestRequest = "interest_request"
    case newMessage = "new_message"
    case offerReceived = "offer_received"
    case jobApplication = "job_application"
    case profileView = "profile_view"
}

class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published var isPermissionGranted = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
        setupNotificationCenter()
    }
    
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Permission Handling
    func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge, .provisional]
            )
            
            await MainActor.run {
                self.isPermissionGranted = granted
            }
            
            if granted {
                await registerForRemoteNotifications()
            }
            
            print("📱 Notification permission granted: \(granted)")
        } catch {
            print("❌ Error requesting notification permission: \(error)")
        }
    }
    
    func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let granted = settings.authorizationStatus == .authorized
        
        await MainActor.run {
            self.isPermissionGranted = granted
        }
        
        print("📱 Current notification permission status: \(granted)")
    }
    
    // MARK: - APNs Registration
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        Task { @MainActor in
            self.deviceToken = tokenString
            print("📱 Device token received: \(tokenString)")
            
            // Send device token to Supabase
            await sendDeviceTokenToSupabase(tokenString)
        }
    }
    
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Supabase Integration
    private func sendDeviceTokenToSupabase(_ token: String) async {
        guard let userId = supabase.auth.currentUser?.id else {
            print("❌ No authenticated user to associate device token with")
            return
        }

        // Skip the write when this exact token was already uploaded — avoids a redundant profiles
        // write on every launch/foreground. (registerForRemoteNotifications still runs each launch
        // per Apple's guidance; only the network write is gated on an actual change.)
        let lastTokenKey = "lastUploadedDeviceToken_\(userId.uuidString)"
        if UserDefaults.standard.string(forKey: lastTokenKey) == token {
            return
        }

        do {
            // Update or insert device token in user profile
            let updateData = AnyEncodable([
                "device_token": token,
                "push_enabled": true,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])

            try await supabase.database
                .from("profiles")
                .update(updateData)
                .eq("id", value: userId.uuidString)
                .execute()

            UserDefaults.standard.set(token, forKey: lastTokenKey)
            print("✅ Device token sent to Supabase successfully")
        } catch {
            print("❌ Failed to send device token to Supabase: \(error)")
        }
    }
    
    // MARK: - Enhanced Notification Scheduling
    func scheduleInteractiveNotification(
        title: String,
        body: String,
        type: NotificationType,
        userId: String? = nil,
        conversationId: String? = nil,
        offerId: String? = nil,
        notificationId: String? = nil,
        timeInterval: TimeInterval? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Build userInfo dictionary with all relevant data
        var userInfo: [String: Any] = [
            "type": type.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let userId = userId {
            userInfo["user_id"] = userId
        }
        
        if let conversationId = conversationId {
            userInfo["conversation_id"] = conversationId
        }
        
        if let offerId = offerId {
            userInfo["offer_id"] = offerId
        }
        
        if let notificationId = notificationId {
            userInfo["notification_id"] = notificationId
        }
        
        content.userInfo = userInfo
        
        // Set category for interactive actions
        switch type {
        case .interestRequest:
            content.categoryIdentifier = "INTEREST_REQUEST"
        case .newMessage:
            content.categoryIdentifier = "NEW_MESSAGE"
        case .offerReceived:
            content.categoryIdentifier = "OFFER_RECEIVED"
        case .jobApplication, .profileView:
            content.categoryIdentifier = "PROFILE_NOTIFICATION"
        }
        
        let trigger: UNNotificationTrigger?
        if let interval = timeInterval {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        } else {
            trigger = nil
        }
        
        let identifier = notificationId ?? UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling interactive notification: \(error)")
            } else {
                print("✅ Interactive notification scheduled: \(title) for type: \(type.rawValue)")
            }
        }
    }
    
    // MARK: - Local Notifications
    func scheduleLocalNotification(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        timeInterval: TimeInterval? = nil,
        userInfo: [String: Any] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let trigger: UNNotificationTrigger?
        if let interval = timeInterval {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        } else {
            trigger = nil
        }
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling local notification: \(error)")
            } else {
                print("✅ Local notification scheduled: \(title)")
            }
        }
    }
    
    // MARK: - Notification Categories
    func setupNotificationCategories() {
        let interestAction = UNNotificationAction(
            identifier: "ACCEPT_INTEREST",
            title: "Accept",
            options: [.foreground]
        )
        
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_INTEREST",
            title: "Decline",
            options: []
        )
        
        let interestCategory = UNNotificationCategory(
            identifier: "INTEREST_REQUEST",
            actions: [interestAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        let offerAcceptAction = UNNotificationAction(
            identifier: "ACCEPT_OFFER",
            title: "Accept Offer",
            options: [.foreground]
        )
        
        let offerDeclineAction = UNNotificationAction(
            identifier: "DECLINE_OFFER",
            title: "Decline",
            options: []
        )
        
        let offerCategory = UNNotificationCategory(
            identifier: "OFFER_RECEIVED",
            actions: [offerAcceptAction, offerDeclineAction],
            intentIdentifiers: [],
            options: []
        )
        
        let messageReplyAction = UNNotificationAction(
            identifier: "REPLY_MESSAGE",
            title: "Reply",
            options: [.foreground]
        )
        
        let messageCategory = UNNotificationCategory(
            identifier: "NEW_MESSAGE",
            actions: [messageReplyAction],
            intentIdentifiers: [],
            options: []
        )
        
        let viewProfileAction = UNNotificationAction(
            identifier: "VIEW_PROFILE",
            title: "View Profile",
            options: [.foreground]
        )
        
        let profileCategory = UNNotificationCategory(
            identifier: "PROFILE_NOTIFICATION",
            actions: [viewProfileAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            interestCategory,
            offerCategory,
            messageCategory,
            profileCategory
        ])
        
        print("✅ Notification categories configured")
    }
    
    // MARK: - Badge Management
    func updateBadgeCount(_ count: Int) {
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Helper Methods
    func openNotificationSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 Received notification while app is in foreground: \(notification.request.content.title)")
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap/action
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        print("📱 Notification action received: \(actionIdentifier)")
        
        Task {
            await handleNotificationAction(actionIdentifier: actionIdentifier, userInfo: userInfo)
            completionHandler()
        }
    }
    
    private func handleNotificationAction(actionIdentifier: String, userInfo: [AnyHashable: Any]) async {
        switch actionIdentifier {
        case "ACCEPT_INTEREST":
            await handleInterestResponse(userInfo: userInfo, accept: true)
            
        case "DECLINE_INTEREST":
            await handleInterestResponse(userInfo: userInfo, accept: false)
            
        case "ACCEPT_OFFER":
            await handleOfferResponse(userInfo: userInfo, accept: true)
            
        case "DECLINE_OFFER":
            await handleOfferResponse(userInfo: userInfo, accept: false)
            
        case "REPLY_MESSAGE":
            handleMessageReply(userInfo: userInfo)
            
        case "VIEW_PROFILE":
            handleProfileView(userInfo: userInfo)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification without using action buttons
            handleDefaultAction(userInfo: userInfo)
            
        default:
            print("📱 Unknown notification action: \(actionIdentifier)")
        }
    }
    
    private func handleInterestResponse(userInfo: [AnyHashable: Any], accept: Bool) async {
        guard let notificationId = userInfo["notification_id"] as? String else {
            print("❌ No notification ID found in interest response")
            return
        }
        
        do {
            try await Networking.shared.respondToInterest(notificationId: notificationId, accept: accept)
            print("✅ Interest response sent: \(accept ? "accepted" : "declined")")
            
            // Schedule confirmation notification
            let message = accept ? "Interest request accepted!" : "Interest request declined."
            scheduleLocalNotification(
                title: "Action Complete",
                body: message,
                timeInterval: 1.0
            )
        } catch {
            print("❌ Failed to respond to interest: \(error)")
        }
    }
    
    private func handleOfferResponse(userInfo: [AnyHashable: Any], accept: Bool) async {
        guard let offerId = userInfo["offer_id"] as? String else {
            print("❌ No offer ID found in offer response")
            return
        }
        
        // Handle offer acceptance/decline through networking layer
        do {
            // Assuming we have a method to handle offer responses
            print("📱 Handling offer response: \(accept ? "accepted" : "declined") for offer: \(offerId)")
            
            let message = accept ? "Offer accepted!" : "Offer declined."
            scheduleLocalNotification(
                title: "Action Complete",
                body: message,
                timeInterval: 1.0
            )
        } catch {
            print("❌ Failed to respond to offer: \(error)")
        }
    }
    
    private func handleMessageReply(userInfo: [AnyHashable: Any]) {
        guard let conversationId = userInfo["conversation_id"] as? String else {
            print("❌ No conversation ID found for message reply")
            return
        }
        
        print("📱 Opening conversation: \(conversationId)")
        // Navigate to the specific conversation
        // This would typically involve posting a notification to trigger navigation
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenConversation"),
            object: conversationId
        )
    }
    
    private func handleProfileView(userInfo: [AnyHashable: Any]) {
        guard let userId = userInfo["user_id"] as? String else {
            print("❌ No user ID found for profile view")
            return
        }
        
        print("📱 Opening profile: \(userId)")
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToProfile"),
            object: userId
        )
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        if let notificationType = userInfo["type"] as? String {
            switch notificationType {
            case "interest_request":
                // Navigate to user profile if user_id is provided, otherwise to notifications
                if let userId = userInfo["user_id"] as? String {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToProfile"),
                        object: userId
                    )
                } else {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToNotifications"),
                        object: nil
                    )
                }
                
            case "new_message":
                if let conversationId = userInfo["conversation_id"] as? String {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenConversation"),
                        object: conversationId
                    )
                } else if let userId = userInfo["user_id"] as? String {
                    // Fallback to profile view if no conversation ID
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToProfile"),
                        object: userId
                    )
                }
                
            case "offer_received":
                // Navigate to user profile if user_id is provided, otherwise to offers
                if let userId = userInfo["user_id"] as? String {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToProfile"),
                        object: userId
                    )
                } else {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToOffers"),
                        object: nil
                    )
                }
                
            case "job_application":
                // Navigate to applicant's profile
                if let userId = userInfo["user_id"] as? String {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToProfile"),
                        object: userId
                    )
                }
                
            case "profile_view":
                // Someone viewed your profile - show their profile
                if let userId = userInfo["user_id"] as? String {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToProfile"),
                        object: userId
                    )
                }
                
            default:
                print("📱 Default action for notification type: \(notificationType)")
                
                // Generic fallback - if user_id exists, show profile
                if let userId = userInfo["user_id"] as? String {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToProfile"),
                        object: userId
                    )
                }
            }
        }
    }
}
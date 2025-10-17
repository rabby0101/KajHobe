import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("📱 App finished launching")
        return true
    }
    
    // MARK: - Push Notification Registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("📱 Successfully registered for remote notifications")
        PushNotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("📱 Failed to register for remote notifications: \(error)")
        PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(withError: error)
    }
    
    // MARK: - Background App Refresh
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📱 Received remote notification in background: \(userInfo)")
        
        // Handle silent push notifications for data sync
        if let contentAvailable = userInfo["content-available"] as? Int, contentAvailable == 1 {
            print("📱 Processing silent push notification")
            
            Task {
                do {
                    // Refresh notifications or other data
                    let _ = try await Networking.shared.fetchInterestNotifications(forceRefresh: true)
                    completionHandler(.newData)
                } catch {
                    print("❌ Failed to process silent push: \(error)")
                    completionHandler(.failed)
                }
            }
        } else {
            completionHandler(.noData)
        }
    }
    
    // MARK: - App State Changes
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 App will enter foreground")
        PushNotificationManager.shared.clearBadge()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("📱 App did become active")
        PushNotificationManager.shared.clearBadge()
    }
}
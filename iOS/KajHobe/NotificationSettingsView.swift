import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject var pushNotificationManager: PushNotificationManager
    @State private var notificationSettings: UNNotificationSettings?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            List {
                // Permission Status Section
                Section("Permission Status") {
                    HStack {
                        Image(systemName: permissionIcon)
                            .foregroundColor(permissionColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Push Notifications")
                                .font(.headline)
                            
                            Text(permissionStatusText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !pushNotificationManager.isPermissionGranted {
                            Button("Enable") {
                                Task {
                                    await pushNotificationManager.requestNotificationPermission()
                                    await loadNotificationSettings()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Device Token Section (for debugging)
                if let deviceToken = pushNotificationManager.deviceToken {
                    Section("Device Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Device Token")
                                .font(.headline)
                            
                            Text(deviceToken)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Notification Types Section
                Section("Notification Types") {
                    NotificationTypeRow(
                        icon: "hand.raised.fill",
                        title: "Job Interest Requests",
                        description: "When someone shows interest in your job",
                        isEnabled: .constant(true)
                    )
                    
                    NotificationTypeRow(
                        icon: "tag.fill",
                        title: "New Offers",
                        description: "When you receive an offer for a job",
                        isEnabled: .constant(true)
                    )
                    
                    NotificationTypeRow(
                        icon: "message.fill",
                        title: "New Messages",
                        description: "When you receive new chat messages",
                        isEnabled: .constant(true)
                    )
                    
                    NotificationTypeRow(
                        icon: "checkmark.circle.fill",
                        title: "Job Completion",
                        description: "When a job is marked as completed",
                        isEnabled: .constant(true)
                    )
                }
                
                // Settings Section
                Section("Advanced Settings") {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("Badge Count")
                            Text("Show unread count on app icon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(badgeStatus)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Sound")
                            Text("Play sound for notifications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(soundStatus)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading) {
                            Text("Lock Screen")
                            Text("Show on lock screen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(lockScreenStatus)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Actions Section
                Section("Actions") {
                    Button("Open System Settings") {
                        pushNotificationManager.openNotificationSettings()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Test Notification") {
                        testLocalNotification()
                    }
                    .foregroundColor(.green)
                    
                    Button("Clear Badge") {
                        pushNotificationManager.clearBadge()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadNotificationSettings()
            }
        }
        .task {
            await loadNotificationSettings()
        }
    }
    
    // MARK: - Computed Properties
    private var permissionIcon: String {
        guard let settings = notificationSettings else { return "questionmark.circle" }
        
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .ephemeral:
            return "clock.circle.fill"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var permissionColor: Color {
        guard let settings = notificationSettings else { return .gray }
        
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .ephemeral:
            return .blue
        @unknown default:
            return .gray
        }
    }
    
    private var permissionStatusText: String {
        guard let settings = notificationSettings else { return "Loading..." }
        
        switch settings.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .provisional:
            return "Provisional"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not Set"
        case .ephemeral:
            return "Temporary"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var badgeStatus: String {
        guard let settings = notificationSettings else { return "Unknown" }
        return settings.badgeSetting == .enabled ? "Enabled" : "Disabled"
    }
    
    private var soundStatus: String {
        guard let settings = notificationSettings else { return "Unknown" }
        return settings.soundSetting == .enabled ? "Enabled" : "Disabled"
    }
    
    private var lockScreenStatus: String {
        guard let settings = notificationSettings else { return "Unknown" }
        return settings.lockScreenSetting == .enabled ? "Enabled" : "Disabled"
    }
    
    // MARK: - Methods
    private func loadNotificationSettings() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.notificationSettings = settings
            self.isLoading = false
        }
    }
    
    private func testLocalNotification() {
        pushNotificationManager.scheduleLocalNotification(
            title: "Test Notification",
            body: "This is a test notification from KajHobe!",
            timeInterval: 1.0
        )
    }
}

// MARK: - Notification Type Row
struct NotificationTypeRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NotificationSettingsView()
        .environmentObject(PushNotificationManager.shared)
}
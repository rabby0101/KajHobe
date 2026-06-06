//
//  KajHobeApp.swift
//  KajHobe
//
//  Created by Sk Fazla Rabby on 22.06.25.
//

import SwiftUI
import Supabase
import Auth

@main
struct KajHobeApp: App {
    @State private var isAuthenticated = false
    @StateObject private var pushNotificationManager = PushNotificationManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Force schema refresh on app startup
        refreshSupabaseSchema()
        
        // Setup push notification categories
        PushNotificationManager.shared.setupNotificationCategories()
    }
    
    var body: some Scene {
        WindowGroup {
            AppEntryView()
                .environmentObject(pushNotificationManager)
        }
    }
}

struct AppEntryView: View {
    @State private var isAuthenticated = false
    @State private var isLoading = true
    @StateObject private var presenceManager = PresenceManager.shared
    @EnvironmentObject var pushNotificationManager: PushNotificationManager
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    Image("AppLogoOnDark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .pulse(color: .white, duration: 2.0)

                    // Simple loading indicator
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .frame(width: 8, height: 8)
                                .foregroundStyle(.white)
                                .opacity(0.6)
                                .scaleEffect(0.8)
                                .animation(
                                    Animation.easeInOut(duration: 0.8)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                    value: true
                                )
                        }
                    }

                    Text("Checking authentication...")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animatedContainer(delay: 0.2)
            } else if isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .gradientBackground(animated: true)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            presenceManager.handleAppBecomeActive()
            Task {
                await pushNotificationManager.checkNotificationPermission()
            }
            // The realtime socket often drops while backgrounded — rebuild the badge
            // subscriptions and re-sync both counts on every foreground.
            if isAuthenticated {
                Task {
                    await NotificationBadgeManager.shared.resubscribe()
                    await MessageBadgeManager.shared.resubscribe()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            presenceManager.handleAppResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            presenceManager.handleAppTerminate()
        }
        .task {
            await checkAuthenticationState()
            
            // Then listen for auth state changes
            for await state in supabase.auth.authStateChanges {
                await MainActor.run {
                    isAuthenticated = state.session != nil
                    print("🔄 Auth state changed: \(state.event), authenticated: \(isAuthenticated)")
                    
                    // Start/stop presence management based on auth state
                    if isAuthenticated {
                        presenceManager.startPresenceManagement()

                        // Request push notification permission when user logs in
                        Task {
                            await pushNotificationManager.requestNotificationPermission()
                        }

                        // (Re)bind the realtime badge subscriptions for the signed-in
                        // user. This runs AFTER the launch-time refreshSupabaseSchema()
                        // removeAllChannels() teardown, so the channels survive.
                        Task {
                            await NotificationBadgeManager.shared.start()
                            await MessageBadgeManager.shared.start()
                        }
                    } else {
                        presenceManager.stopPresenceManagement()

                        // Tear down badge subscriptions + reset counts on sign-out.
                        Task {
                            await NotificationBadgeManager.shared.stop()
                            await MessageBadgeManager.shared.stop()
                        }
                    }
                }
            }
        }
    }
    
    private func checkAuthenticationState() async {
        do {
            let _ = try await supabase.auth.session
            if supabase.auth.currentUser != nil {
                print("✅ Recovered existing session")
                await MainActor.run {
                    isAuthenticated = true
                }
            } else {
                print("❌ No existing session found")
                await MainActor.run {
                    isAuthenticated = false
                }
            }
        } catch {
            print("⚠️ Session recovery failed: \(error)")
            
            // If broken auth state, force sign out and redirect to login
            if error.localizedDescription.contains("sessionMissing") || 
               error.localizedDescription.contains("invalid") {
                print("🚨 Detected broken auth state - forcing sign out")
                try? await supabase.auth.signOut()
            }
            
            await MainActor.run {
                isAuthenticated = false
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

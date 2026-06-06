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
            // Optimistic launch: no blocking networked session check on the critical path.
            // `authStateChanges` emits `.initialSession` immediately with the locally-stored
            // session (or nil) once the SDK has loaded it — that first event ends the launch gate
            // with the correct value, and the token refreshes lazily in the background. Heavy
            // post-auth work runs only on sign-in events, NOT on every `.tokenRefreshed` (which
            // previously stacked presence timers and cancelled in-flight badge queries).
            for await state in supabase.auth.authStateChanges {
                await MainActor.run {
                    let isAuthed = state.session != nil
                    isAuthenticated = isAuthed
                    if isLoading { isLoading = false }
                    print("🔄 Auth state changed: \(state.event), authenticated: \(isAuthed)")

                    switch state.event {
                    case .initialSession, .signedIn:
                        guard isAuthed else { break }
                        presenceManager.startPresenceManagement()

                        // Request push notification permission when user logs in
                        Task {
                            await pushNotificationManager.requestNotificationPermission()
                        }

                        // (Re)bind the realtime badge subscriptions for the signed-in user.
                        Task {
                            await NotificationBadgeManager.shared.start()
                            await MessageBadgeManager.shared.start()
                        }
                    case .signedOut:
                        presenceManager.stopPresenceManagement()

                        // Tear down badge subscriptions + reset counts on sign-out.
                        Task {
                            await NotificationBadgeManager.shared.stop()
                            await MessageBadgeManager.shared.stop()
                        }

                        // Drop the cached conversation list so a different account can't
                        // surface the previous user's chats from disk.
                        ConversationsCache.shared.clear()
                    default:
                        // .tokenRefreshed / .userUpdated / etc. — no heavy fan-out re-run.
                        break
                    }
                }
            }
        }
    }
    
}

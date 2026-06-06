import Foundation
import SwiftUI
import Supabase
import Combine

class PresenceManager: ObservableObject {
    @Published var isOnline: Bool = false
    static let shared = PresenceManager()
    
    private var presenceUpdateTimer: Timer?
    private var responseTimeCalculationTimer: Timer?
    
    private init() {}
    
    func startPresenceManagement() {
        // Idempotent: invalidate any existing timers first. The run loop retains scheduled timers,
        // so without this a repeat call (e.g. multiple auth events) would stack duplicate timers,
        // each firing its own presence network write.
        presenceUpdateTimer?.invalidate()
        responseTimeCalculationTimer?.invalidate()

        // Update presence every 5 minutes
        presenceUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.updateUserPresence()
            }
        }
        
        // Calculate response times every hour
        responseTimeCalculationTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.calculateAndUpdateResponseTime()
            }
        }
        
        print("✅ Presence management started")
    }
    
    func stopPresenceManagement() {
        presenceUpdateTimer?.invalidate()
        responseTimeCalculationTimer?.invalidate()
        presenceUpdateTimer = nil
        responseTimeCalculationTimer = nil
        
        // Set user offline when stopping
        Task {
            try? await Networking.shared.updateUserPresence(isOnline: false)
        }
        
        print("✅ Presence management stopped")
    }
    
    private func updateUserPresence() async {
        do {
            try await Networking.shared.updateUserPresence(isOnline: true)
            print("✅ Background presence update completed")
        } catch {
            print("❌ Background presence update failed: \(error)")
        }
    }
    
    private func calculateAndUpdateResponseTime() async {
        guard let user = supabase.auth.currentUser else { return }
        
        do {
            if let averageTime = try await Networking.shared.calculateAverageResponseTime(userId: user.id.uuidString) {
                print("✅ Background response time calculation completed: \(averageTime) minutes")
            }
        } catch {
            print("❌ Background response time calculation failed: \(error)")
        }
    }
}

// MARK: - App Lifecycle Integration

extension PresenceManager {
    func handleAppBecomeActive() {
        Task {
            try? await Networking.shared.updateUserPresence(isOnline: true)
        }
    }
    
    func handleAppResignActive() {
        Task {
            try? await Networking.shared.updateUserPresence(isOnline: false)
        }
    }
    
    func handleAppTerminate() {
        Task {
            try? await Networking.shared.updateUserPresence(isOnline: false)
        }
        stopPresenceManagement()
    }
}
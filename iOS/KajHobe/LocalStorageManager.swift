import Foundation
import SwiftUI

// MARK: - Local Storage Manager
class LocalStorageManager {
    static let shared = LocalStorageManager()

    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default

    // MARK: - Storage Keys
    private enum StorageKeys {
        static let conversationsMetadata = "local_conversations_metadata"
        static let lastSyncTimestamp = "last_sync_timestamp"
        static let currentUserId = "current_user_id"
    }

    // MARK: - File Paths
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var conversationsDirectory: URL {
        documentsDirectory.appendingPathComponent("Conversations")
    }

    private init() {
        createDirectoriesIfNeeded()
    }

    // MARK: - Directory Setup
    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(
            at: conversationsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - Current User Management
    func setCurrentUser(_ userId: String) {
        userDefaults.set(userId, forKey: StorageKeys.currentUserId)
        print("📱 Set current user in local storage: \(userId)")
    }

    func getCurrentUserId() -> String? {
        return userDefaults.string(forKey: StorageKeys.currentUserId)
    }

    // MARK: - Sync Status
    func getLastSyncTimestamp() -> TimeInterval {
        return userDefaults.double(forKey: StorageKeys.lastSyncTimestamp)
    }

    func needsSync(maxAge: TimeInterval = 300) -> Bool { // 5 minutes default
        let lastSync = getLastSyncTimestamp()
        let now = Date().timeIntervalSince1970
        return (now - lastSync) > maxAge
    }

    // MARK: - Clear All Data
    func clearAllData() {
        print("🗑️ Clearing all local storage data...")

        // Remove UserDefaults data
        userDefaults.removeObject(forKey: StorageKeys.conversationsMetadata)
        userDefaults.removeObject(forKey: StorageKeys.lastSyncTimestamp)
        userDefaults.removeObject(forKey: StorageKeys.currentUserId)

        // Sync UserDefaults to disk
        userDefaults.synchronize()

        // Remove all conversation files
        do {
            try fileManager.removeItem(at: conversationsDirectory)
            print("🗑️ Removed conversations directory")
        } catch {
            print("⚠️ Could not remove conversations directory: \(error)")
        }

        // Recreate directory structure
        createDirectoriesIfNeeded()

        print("✅ Cleared all local storage data and reset timestamps")
    }
}

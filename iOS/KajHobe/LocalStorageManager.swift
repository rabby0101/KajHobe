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
    
    // MARK: - Conversations Storage (Removed with messaging functionality)
    /*
    func saveConversations(_ conversations: [ConversationWithJob]) {
        do {
            print("💾 Starting to save \(conversations.count) conversations to local storage")
            
            // Save lightweight metadata to UserDefaults for quick access
            let metadata = conversations.map { conversation in
                ConversationMetadata(
                    id: conversation.id,
                    jobId: conversation.job_id,
                    updatedAt: conversation.updated_at ?? "",
                    hasUnread: conversation.getUnreadCount(for: getCurrentUserId() ?? "") > 0,
                    latestMessagePreview: conversation.latest_message?.first?.content ?? ""
                )
            }
            
            print("💾 Encoding metadata for \(metadata.count) conversations")
            let metadataData = try JSONEncoder().encode(metadata)
            userDefaults.set(metadataData, forKey: StorageKeys.conversationsMetadata)
            print("💾 Metadata saved to UserDefaults")
            
            // Save full conversation data to individual files
            for (index, conversation) in conversations.enumerated() {
                let fileURL = conversationsDirectory.appendingPathComponent("\(conversation.id).json")
                let conversationData = try JSONEncoder().encode(conversation)
                try conversationData.write(to: fileURL)
                
                if index < 3 { // Log first 3 for debugging
                    print("💾 Saved conversation \(index): \(conversation.jobs?.title ?? "nil") - Latest: '\(conversation.latest_message?.first?.content ?? "nil")'")
                }
            }
            
            // Update last sync timestamp
            let timestamp = Date().timeIntervalSince1970
            userDefaults.set(timestamp, forKey: StorageKeys.lastSyncTimestamp)
            print("💾 Updated sync timestamp: \(timestamp)")
            
            print("✅ Successfully saved \(conversations.count) conversations to local storage")
            
        } catch {
            print("❌ Error saving conversations to local storage: \(error)")
        }
    }
    
    func loadConversations() -> [ConversationWithJob] {
        do {
            print("📱 Loading conversations from local storage...")
            
            // Load metadata first to get conversation list
            guard let metadataData = userDefaults.data(forKey: StorageKeys.conversationsMetadata),
                  let metadata = try? JSONDecoder().decode([ConversationMetadata].self, from: metadataData) else {
                print("📱 No conversation metadata found in local storage")
                return []
            }
            
            print("📱 Found metadata for \(metadata.count) conversations")
            
            // Load full conversation data from files
            var conversations: [ConversationWithJob] = []
            
            for (index, meta) in metadata.enumerated() {
                let fileURL = conversationsDirectory.appendingPathComponent("\(meta.id).json")
                
                if let data = try? Data(contentsOf: fileURL),
                   let conversation = try? JSONDecoder().decode(ConversationWithJob.self, from: data) {
                    conversations.append(conversation)
                    
                    if index < 3 { // Log first 3 for debugging
                        print("📱 Loaded conversation \(index): \(conversation.jobs?.title ?? "nil") - Latest: '\(conversation.latest_message?.first?.content ?? "nil")'")
                    }
                } else {
                    print("⚠️ Could not load conversation file: \(meta.id).json")
                }
            }
            
            // Sort by updated_at (most recent first)
            conversations.sort { (conv1, conv2) in
                let date1 = parseDate(conv1.updated_at ?? "")
                let date2 = parseDate(conv2.updated_at ?? "")
                return date1 > date2
            }
            
            print("📱 Loaded \(conversations.count) conversations from local storage")
            if let first = conversations.first {
                print("📱 First loaded conversation: \(first.jobs?.title ?? "nil") - Latest: '\(first.latest_message?.first?.content ?? "nil")'")
            }
            
            return conversations
            
        } catch {
            print("❌ Error loading conversations from local storage: \(error)")
            return []
        }
    }
    
    func updateConversation(_ updatedConversation: ConversationWithJob) {
        do {
            // Update the specific conversation file
            let fileURL = conversationsDirectory.appendingPathComponent("\(updatedConversation.id).json")
            let conversationData = try JSONEncoder().encode(updatedConversation)
            try conversationData.write(to: fileURL)
            
            // Update metadata
            if let metadataData = userDefaults.data(forKey: StorageKeys.conversationsMetadata),
               var metadata = try? JSONDecoder().decode([ConversationMetadata].self, from: metadataData) {
                
                if let index = metadata.firstIndex(where: { $0.id == updatedConversation.id }) {
                    // Update existing metadata
                    metadata[index] = ConversationMetadata(
                        id: updatedConversation.id,
                        jobId: updatedConversation.job_id,
                        updatedAt: updatedConversation.updated_at ?? "",
                        hasUnread: updatedConversation.getUnreadCount(for: getCurrentUserId() ?? "") > 0,
                        latestMessagePreview: updatedConversation.latest_message?.first?.content ?? ""
                    )
                } else {
                    // Add new metadata
                    let newMetadata = ConversationMetadata(
                        id: updatedConversation.id,
                        jobId: updatedConversation.job_id,
                        updatedAt: updatedConversation.updated_at ?? "",
                        hasUnread: updatedConversation.getUnreadCount(for: getCurrentUserId() ?? "") > 0,
                        latestMessagePreview: updatedConversation.latest_message?.first?.content ?? ""
                    )
                    metadata.append(newMetadata)
                }
                
                // Sort metadata by updated_at
                metadata.sort { parseDate($0.updatedAt) > parseDate($1.updatedAt) }
                
                let updatedMetadataData = try JSONEncoder().encode(metadata)
                userDefaults.set(updatedMetadataData, forKey: StorageKeys.conversationsMetadata)
            }
            
            print("📱 Updated conversation \(updatedConversation.id.prefix(8))... in local storage")
            
        } catch {
            print("❌ Error updating conversation in local storage: \(error)")
        }
    }
    
    func deleteConversation(id: String) {
        // Remove from metadata
        if let metadataData = userDefaults.data(forKey: StorageKeys.conversationsMetadata),
           var metadata = try? JSONDecoder().decode([ConversationMetadata].self, from: metadataData) {
            
            metadata.removeAll { $0.id == id }
            
            if let updatedMetadataData = try? JSONEncoder().encode(metadata) {
                userDefaults.set(updatedMetadataData, forKey: StorageKeys.conversationsMetadata)
            }
        }
        
        // Remove conversation file
        let fileURL = conversationsDirectory.appendingPathComponent("\(id).json")
        try? fileManager.removeItem(at: fileURL)
        
        print("📱 Deleted conversation \(id.prefix(8))... from local storage")
    }
    
    // MARK: - Messages Storage (for specific conversation)
    func addMessageToConversation(conversationId: String, message: ChatMessage) {
        // Load existing conversation
        let fileURL = conversationsDirectory.appendingPathComponent("\(conversationId).json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let conversation = try? JSONDecoder().decode(ConversationWithJob.self, from: data) else {
            print("⚠️ Could not load conversation \(conversationId) to add message")
            return
        }
        
        // Create updated conversation with new latest message
        let updatedConversation = ConversationWithJob(
            id: conversation.id,
            job_id: conversation.job_id,
            client_id: conversation.client_id,
            provider_id: conversation.provider_id,
            status: conversation.status,
            created_at: conversation.created_at,
            updated_at: message.created_at,
            jobs: conversation.jobs,
            client_profile: conversation.client_profile,
            provider_profile: conversation.provider_profile,
            latest_message: [message],
            unread_count: conversation.unread_count
        )
        
        updateConversation(updatedConversation)
    }
    */
    
    // MARK: - Sync Status
    func getLastSyncTimestamp() -> TimeInterval {
        return userDefaults.double(forKey: StorageKeys.lastSyncTimestamp)
    }
    
    func needsSync(maxAge: TimeInterval = 300) -> Bool { // 5 minutes default
        let lastSync = getLastSyncTimestamp()
        let now = Date().timeIntervalSince1970
        return (now - lastSync) > maxAge
    }
    
    // MARK: - Utilities
    private func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? Date.distantPast
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

// MARK: - Conversation Metadata Model
struct ConversationMetadata: Codable {
    let id: String
    let jobId: String
    let updatedAt: String
    let hasUnread: Bool
    let latestMessagePreview: String
}
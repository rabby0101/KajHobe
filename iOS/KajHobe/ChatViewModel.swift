import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Any] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = "Messaging functionality is disabled"
    @Published var messageText = ""
    @Published var isConnected = false
    @Published var connectionStatus: String = "Disabled"
    
    // Placeholder methods - all messaging functionality disabled
    
    func setupChat(conversation: Any?, currentUserId: String, currentUserProfile: Any?) async {
        // No-op
    }
    
    func cleanup() async {
        // No-op
    }
    
    func sendMessage() async {
        // No-op
    }
    
    func markMessagesAsRead() async {
        // No-op
    }
    
    func loadMessages() async {
        // No-op
    }
    
    func refreshMessages() async {
        // No-op
    }
}
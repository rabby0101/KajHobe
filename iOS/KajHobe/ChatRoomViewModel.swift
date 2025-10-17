import SwiftUI
import Combine

// MARK: - Chat Room View Model (Disabled)
final class ChatRoomViewModel: ObservableObject {
    @Published var session: Any? = nil
    @Published var showingSessionSheet: Bool = false
    @Published var messages: [Any] = []
    @Published var newMessage: String = ""
    
    // All chat room functionality has been disabled
    
    func fetchMessages() async {
        // No-op
    }
    
    func subscribeToMessages() async {
        // No-op  
    }
    
    func sendMessage() async {
        // No-op
    }
    
    func signInAnonymously() async {
        // No-op
    }
    
    func signOut() async {
        // No-op
    }
}
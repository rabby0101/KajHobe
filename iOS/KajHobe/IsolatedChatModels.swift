import Foundation

// MARK: - Isolated Chat Models (Disabled)
// All chat functionality has been disabled

struct ChatMessagesService {
    static func fetchMessages() async throws -> [[String: Any]] {
        // Return empty array - messaging disabled
        return []
    }
    
    static func sendMessage(_ content: String, userId: String) async throws -> [String: Any]? {
        // Return nil - messaging disabled
        return nil
    }
}

struct SimpleMessageModel {
    let id: String
    let content: String
    let userId: String
    let createdAt: String
    
    init(from json: [String: Any]) {
        self.id = json["id"] as? String ?? ""
        self.content = json["content"] as? String ?? ""
        self.userId = json["user_id"] as? String ?? ""
        self.createdAt = json["created_at"] as? String ?? ""
    }
}
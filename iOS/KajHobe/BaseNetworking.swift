import Foundation
import UIKit
import Foundation
import Supabase
import Auth
import PostgREST
import Combine

// MARK: - Networking Error
enum NetworkingError: Error, LocalizedError {
    case unauthorized(String)
    case validationError(String)
    case invalidData(String)
    case networkError(String)
    case notFound

    // Enhanced errors for messaging system
    case invalidResponse
    case decodingError
    case networkUnavailable
    case conversationNotFound
    case messageNotFound
    case invalidAttachment
    case uploadFailed
    case subscriptionFailed
    case rateLimited
    case insufficientPermissions
    case invalidMessageContent
    case conversationClosed

    /// The other party already filed a pending completion request for this deal.
    /// Mapped from the `completion_requests_one_pending_per_deal` unique-index
    /// violation (SQLSTATE 23505). The caller should re-route the user to the
    /// response sheet so they can approve or reject the existing request.
    case completionRequestAlreadyPending(dealId: String)

    var errorDescription: String? {
        switch self {
        case .unauthorized(let message):
            return message
        case .validationError(let message):
            return message
        case .invalidData(let message):
            return message
        case .networkError(let message):
            return message
        case .notFound:
            return "Resource not found"
        case .invalidResponse:
            return "Received invalid response from server"
        case .decodingError:
            return "Failed to decode server response"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .conversationNotFound:
            return "Conversation not found"
        case .messageNotFound:
            return "Message not found"
        case .invalidAttachment:
            return "Invalid attachment format"
        case .uploadFailed:
            return "Failed to upload attachment"
        case .subscriptionFailed:
            return "Failed to establish real-time connection"
        case .rateLimited:
            return "Too many requests. Please wait and try again"
        case .insufficientPermissions:
            return "Insufficient permissions to perform this action"
        case .invalidMessageContent:
            return "Message content is invalid or too long"
        case .conversationClosed:
            return "This conversation has been closed"
        case .completionRequestAlreadyPending:
            return "There's already a pending completion request for this deal"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .unauthorized:
            return "Please log in again"
        case .rateLimited:
            return "Wait a moment before sending another message"
        case .invalidMessageContent:
            return "Please check your message and try again"
        case .conversationClosed:
            return "This conversation is no longer active"
        default:
            return "Please try again later"
        }
    }
}

// MARK: - Optimized Conversation Response Model
@preconcurrency
struct OptimizedConversation: Codable, Sendable {
    let id: String
    let job_id: String
    let client_id: String
    let provider_id: String
    let status: String
    let created_at: String?
    let updated_at: String?
    let client_unread_count: Int
    let provider_unread_count: Int
    let jobs: Job?
    let client_profile: SimpleProfile?
    let provider_profile: SimpleProfile?
    
    // Helper computed property to get unread count for the current user
    func unreadCount(for userId: String) -> Int {
        if client_id.lowercased() == userId.lowercased() {
            return client_unread_count
        } else if provider_id.lowercased() == userId.lowercased() {
            return provider_unread_count
        }
        return 0
    }
}

// MARK: - Base Networking Class
@preconcurrency
class BaseNetworking: ObservableObject {
    @Published var objectWillChange = ObservableObjectPublisher()
    
    // MARK: - Test Connection
    func testConnection() async throws -> Bool {
        do {
            let _ = try await supabase
                .from("profiles")
                .select("count")
                .limit(1)
                .execute()
            
            print("Database connection test successful")
            return true
        } catch {
            print("Database connection test failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Database Connection Test
    func testDatabaseConnection() async throws {
        _ = try await testConnection()
    }

    // MARK: - Cache Management (Removed)
    // Cache functionality has been removed from the application
}
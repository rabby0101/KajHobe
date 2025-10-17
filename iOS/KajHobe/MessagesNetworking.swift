import Foundation
import Supabase
import Foundation
import UIKit
import Combine

// MARK: - Custom Conversation Model for Messages

struct ConversationWithDetails: Codable, Sendable, Identifiable {
    let id: String
    let job_id: String
    let client_id: String
    let provider_id: String
    let job_title: String
    let job_description: String
    let other_user_name: String
    let unread_count: Int
    let created_at: String
    let latest_message_time: String
}

// MARK: - Messages Networking Specialized Class
class MessagesNetworking: ObservableObject {
    static let shared = MessagesNetworking()
    private init() {}
    
    @Published var objectWillChange = ObservableObjectPublisher()
    
    // MARK: - Placeholder Methods
    // All messaging functionality has been disabled
    
    /// Fetch conversations where the user is either client or provider
    func fetchConversations(userId: String, forceRefresh: Bool = false) async throws -> [ConversationWithDetails] {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // Use Task to isolate the network operations
                    let result = try await self.performConversationFetch(userId: userId)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performConversationFetch(userId: String) async throws -> [ConversationWithDetails] {
        print("🔍 DEBUG: Starting conversation fetch for userId: \(userId)")
        
        // First, let's test if we can connect to the database at all
        do {
            let testQuery = try await supabase
                .from("conversations")
                .select("*")
                .limit(1)
                .execute()
            print("🔍 DEBUG: Database connection test - raw response: \(testQuery)")
        } catch {
            print("❌ DEBUG: Database connection test failed: \(error)")
            throw error
        }
        
        // The issue is that Supabase is returning Void instead of data
        // This suggests a configuration or permissions issue
        // For now, let's return empty array and log the issue for debugging
        
        let conversationData = try await supabase
            .from("conversations")
            .select("*")
            .or("client_id.eq.\(userId),provider_id.eq.\(userId)")
            .order("updated_at", ascending: false)
            .execute()
        
        print("🔍 DEBUG: Raw conversation data received: \(conversationData)")
        print("🔍 DEBUG: Response data type: \(type(of: conversationData.data))")
        print("🔍 DEBUG: Response value type: \(type(of: conversationData.value))")
        print("🔍 DEBUG: Response status: \(conversationData.response.statusCode)")
        
        // Check if we have actual data in the response
        let jsonData = conversationData.data
        if jsonData.count > 0 {
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
                if let conversationsArray = jsonObject as? [[String: Any]] {
                    print("🔍 DEBUG: Successfully parsed JSON data with \(conversationsArray.count) conversations")
                    return try await processConversations(conversationsArray, userId: userId)
                } else {
                    print("❌ DEBUG: JSON data is not an array of dictionaries: \(type(of: jsonObject))")
                }
            } catch {
                print("❌ DEBUG: JSON parsing error: \(error)")
            }
        } else {
            print("❌ DEBUG: No data received from Supabase")
        }
        
        // Return empty array if we can't get the data
        print("🔍 DEBUG: Returning empty conversations array due to data parsing issues")
        return []
    }
    
    private func processConversations(_ conversations: [[String: Any]], userId: String) async throws -> [ConversationWithDetails] {
        print("🔍 DEBUG: Processing \(conversations.count) conversations with batch optimization")
        
        // Extract unique job IDs and user IDs for batch fetching
        var uniqueJobIds = Set<String>()
        var uniqueUserIds = Set<String>()
        
        for conversationDict in conversations {
            if let jobId = conversationDict["job_id"] as? String,
               let clientId = conversationDict["client_id"] as? String,
               let providerId = conversationDict["provider_id"] as? String {
                uniqueJobIds.insert(jobId)
                uniqueUserIds.insert(clientId)
                uniqueUserIds.insert(providerId)
            }
        }
        
        print("🔍 DEBUG: Batch fetching \(uniqueJobIds.count) jobs and \(uniqueUserIds.count) profiles")
        
        // Batch fetch jobs (only need title now)
        let jobsData = try await supabase
            .from("jobs")
            .select("id, title")
            .in("id", values: Array(uniqueJobIds))
            .execute()
        
        var jobsMap: [String: [String: Any]] = [:]
        if let jobsArray = try? JSONSerialization.jsonObject(with: jobsData.data) as? [[String: Any]] {
            for job in jobsArray {
                if let id = job["id"] as? String {
                    jobsMap[id] = job
                }
            }
        }
        
        // Batch fetch latest messages for each conversation
        let uniqueConversationIds = Set(conversations.compactMap { $0["id"] as? String })
        print("🔍 DEBUG: Fetching latest messages for \(uniqueConversationIds.count) conversations")
        
        let latestMessagesData = try await supabase
            .from("messages")
            .select("conversation_id, content, created_at")
            .in("conversation_id", values: Array(uniqueConversationIds))
            .order("created_at", ascending: false)
            .execute()
        
        var latestMessagesMap: [String: [String: Any]] = [:]
        if let messagesArray = try? JSONSerialization.jsonObject(with: latestMessagesData.data) as? [[String: Any]] {
            // Group messages by conversation_id and keep only the latest one
            for message in messagesArray {
                if let conversationId = message["conversation_id"] as? String {
                    if latestMessagesMap[conversationId] == nil {
                        latestMessagesMap[conversationId] = message
                    }
                }
            }
        }
        
        // Batch fetch unread message counts based on read_at column
        print("🔍 DEBUG: Calculating unread counts for \(uniqueConversationIds.count) conversations")
        let unreadCountsData = try await supabase
            .from("messages")
            .select("conversation_id, sender_id, read_at")
            .in("conversation_id", values: Array(uniqueConversationIds))
            .is("read_at", value: nil) // Only unread messages
            .execute()
        
        var unreadCountsMap: [String: [String: Int]] = [:]
        if let unreadArray = try? JSONSerialization.jsonObject(with: unreadCountsData.data) as? [[String: Any]] {
            for unreadMessage in unreadArray {
                if let conversationId = unreadMessage["conversation_id"] as? String,
                   let senderId = unreadMessage["sender_id"] as? String {
                    if unreadCountsMap[conversationId] == nil {
                        unreadCountsMap[conversationId] = [:]
                    }
                    let currentCount = unreadCountsMap[conversationId]?[senderId] ?? 0
                    unreadCountsMap[conversationId]?[senderId] = currentCount + 1
                }
            }
        }
        
        // Batch fetch profiles
        let profilesData = try await supabase
            .from("profiles")
            .select("id, full_name")
            .in("id", values: Array(uniqueUserIds))
            .execute()
        
        var profilesMap: [String: [String: Any]] = [:]
        if let profilesArray = try? JSONSerialization.jsonObject(with: profilesData.data) as? [[String: Any]] {
            for profile in profilesArray {
                if let id = profile["id"] as? String {
                    profilesMap[id] = profile
                }
            }
        }
        
        print("🔍 DEBUG: Loaded \(jobsMap.count) jobs, \(profilesMap.count) profiles, \(latestMessagesMap.count) latest messages, and unread counts for \(unreadCountsMap.count) conversations")
        
        // Process conversations using cached data
        var detailedConversations: [ConversationWithDetails] = []
        
        for (index, conversationDict) in conversations.enumerated() {
            guard let id = conversationDict["id"] as? String,
                  let jobId = conversationDict["job_id"] as? String,
                  let clientId = conversationDict["client_id"] as? String,
                  let providerId = conversationDict["provider_id"] as? String,
                  let createdAt = conversationDict["created_at"] as? String else {
                print("❌ DEBUG: Failed to parse required fields for conversation \(index + 1)")
                continue
            }
            
            // Get job data from cache
            guard let jobData = jobsMap[jobId],
                  let jobTitle = jobData["title"] as? String else {
                print("❌ DEBUG: Missing job data for jobId: \(jobId)")
                continue
            }
            
            // Get latest message for this conversation
            let latestMessageContent = latestMessagesMap[id]?["content"] as? String ?? "No messages yet"
            let latestMessageTime = latestMessagesMap[id]?["created_at"] as? String ?? createdAt
            
            // Determine other user and get profile from cache
            let isUserClient = clientId == userId
            let otherUserId = isUserClient ? providerId : clientId
            
            guard let profileData = profilesMap[otherUserId],
                  let userName = profileData["full_name"] as? String else {
                print("❌ DEBUG: Missing profile data for userId: \(otherUserId)")
                continue
            }
            
            // Calculate unread count based on read_at column: count messages from other user that are unread
            let unreadCount = unreadCountsMap[id]?[otherUserId] ?? 0
            print("🔍 DEBUG: Conversation \(id): unread count from \(userName) = \(unreadCount)")
            
            let detailed = ConversationWithDetails(
                id: id,
                job_id: jobId,
                client_id: clientId,
                provider_id: providerId,
                job_title: jobTitle,
                job_description: latestMessageContent,
                other_user_name: userName,
                unread_count: unreadCount,
                created_at: createdAt,
                latest_message_time: latestMessageTime
            )
            
            detailedConversations.append(detailed)
        }
        
        print("🔍 DEBUG: Successfully processed \(detailedConversations.count) conversations with batch optimization")
        return detailedConversations
    }
    
    /// Fetch messages for a specific conversation
    func fetchMessages(conversationId: String, limit: Int = 50) async throws -> [ChatMessage] {
        print("🔍 MESSAGES DEBUG: Fetching messages for conversation: \(conversationId)")
        
        let messagesData = try await supabase
            .from("messages")
            .select("*")
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
        
        print("🔍 MESSAGES DEBUG: Raw messages data received: \(messagesData)")
        
        // Parse messages using JSON approach (similar to conversations)
        let jsonData = messagesData.data
        if jsonData.count > 0 {
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
                if let messagesArray = jsonObject as? [[String: Any]] {
                    print("🔍 MESSAGES DEBUG: Successfully parsed \(messagesArray.count) messages from JSON")
                    
                    var chatMessages: [ChatMessage] = []
                    for messageDict in messagesArray {
                        if let id = messageDict["id"] as? String,
                           let conversationId = messageDict["conversation_id"] as? String,
                           let senderId = messageDict["sender_id"] as? String,
                           let content = messageDict["content"] as? String,
                           let messageType = messageDict["message_type"] as? String,
                           let createdAt = messageDict["created_at"] as? String {
                            
                            let message = ChatMessage(
                                id: id,
                                conversation_id: conversationId,
                                sender_id: senderId,
                                content: content,
                                message_type: messageType,
                                attachment_url: messageDict["attachment_url"] as? String,
                                negotiation_data: messageDict["negotiation_data"] as? [String: Any],
                                read_at: messageDict["read_at"] as? String,
                                created_at: createdAt,
                                updated_at: messageDict["updated_at"] as? String
                            )
                            
                            chatMessages.append(message)
                        }
                    }
                    
                    // Reverse to show oldest first (since we ordered by DESC)
                    let orderedMessages = chatMessages.reversed()
                    print("🔍 MESSAGES DEBUG: Returning \(orderedMessages.count) messages")
                    return Array(orderedMessages)
                } else {
                    print("❌ MESSAGES DEBUG: JSON data is not an array of dictionaries")
                }
            } catch {
                print("❌ MESSAGES DEBUG: JSON parsing error: \(error)")
            }
        } else {
            print("🔍 MESSAGES DEBUG: No message data received")
        }
        
        return []
    }
    
    func sendMessage(conversationId: String, content: String, senderId: String) async throws {
        print("🔍 SEND MESSAGE DEBUG: Inserting message into database")
        print("🔍 SEND MESSAGE DEBUG: Conversation ID: \(conversationId)")
        print("🔍 SEND MESSAGE DEBUG: Content: \(content)")
        print("🔍 SEND MESSAGE DEBUG: Sender ID: \(senderId)")
        
        let messageData: [String: AnyEncodable] = [
            "conversation_id": AnyEncodable(conversationId),
            "sender_id": AnyEncodable(senderId),
            "content": AnyEncodable(content),
            "message_type": AnyEncodable("text"),
            "attachment_url": AnyEncodable(NSNull()),
            "negotiation_data": AnyEncodable(NSNull())
        ]
        
        let result = try await supabase
            .from("messages")
            .insert(messageData)
            .execute()
        
        print("✅ SEND MESSAGE DEBUG: Message inserted successfully")
        print("🔍 SEND MESSAGE DEBUG: Insert result: \(result)")
    }
    
    func sendImageMessage(conversationId: String, image: UIImage, senderId: String) async throws {
        print("🔍 SEND IMAGE DEBUG: Starting image upload and message creation")
        
        // Compress and prepare image for upload
        guard let imageData = compressImage(image) else {
            throw NSError(domain: "ImageCompression", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        // Generate unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString
        let filename = "messages/\(conversationId)_\(timestamp)_image_\(uuid).jpg"
        
        print("🔍 SEND IMAGE DEBUG: Uploading to filename: \(filename)")
        
        // Upload to Supabase Storage
        let uploadResult = try await supabase.storage
            .from("chat-images")
            .upload(path: filename, file: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        // Get public URL
        let publicURL = try supabase.storage
            .from("chat-images")
            .getPublicURL(path: filename)
        
        print("🔍 SEND IMAGE DEBUG: Image uploaded successfully. Public URL: \(publicURL)")
        
        // Create message with image data
        let messageData: [String: AnyEncodable] = [
            "conversation_id": AnyEncodable(conversationId),
            "sender_id": AnyEncodable(senderId),
            "content": AnyEncodable("📸 Photo"),
            "message_type": AnyEncodable("image"),
            "attachment_url": AnyEncodable(publicURL.absoluteString),
            "negotiation_data": AnyEncodable(NSNull())
        ]
        
        let result = try await supabase
            .from("messages")
            .insert(messageData)
            .execute()
        
        print("✅ SEND IMAGE DEBUG: Image message inserted successfully")
        print("🔍 SEND IMAGE DEBUG: Insert result: \(result)")
    }
    
    private func compressImage(_ image: UIImage) -> Data? {
        // Resize image if too large (max width/height 1200px)
        let maxDimension: CGFloat = 1200
        let resizedImage: UIImage
        
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            resizedImage = image
        }
        
        // Compress JPEG to reasonable quality (0.7 = good balance of quality/size)
        return resizedImage.jpegData(compressionQuality: 0.7)
    }
    
    func sendDealOffer(conversationId: String, amount: Int, terms: String?, timeline: String?, additionalMessage: String?, senderId: String) async throws {
        print("🔍 DEAL OFFER DEBUG: Creating deal offer in database")
        print("🔍 DEAL OFFER DEBUG: Amount: \(amount) cents, Terms: \(terms ?? "none"), Timeline: \(timeline ?? "none")")
        
        // First, get the conversation details to determine client_id
        let conversationData = try await supabase
            .from("conversations")
            .select("client_id, provider_id, job_id")
            .eq("id", value: conversationId)
            .execute()
        
        guard let conversationResponseData = try? JSONSerialization.jsonObject(with: conversationData.data) as? [[String: Any]],
              let conversation = conversationResponseData.first,
              let clientId = conversation["client_id"] as? String,
              let providerId = conversation["provider_id"] as? String,
              let jobId = conversation["job_id"] as? String else {
            throw NSError(domain: "ConversationLookup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get conversation details"])
        }
        
        print("🔍 DEAL OFFER DEBUG: Found conversation - Client: \(clientId), Provider: \(providerId), Job: \(jobId)")
        
        // Validate that the sender is the provider
        guard senderId == providerId else {
            throw NSError(domain: "DealOfferValidation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Only the service provider can send deal offers"])
        }
        
        // CRITICAL: Check if a deal already exists for this job (One job → One deal rule)
        let existingDealsData = try await supabase
            .from("deals")
            .select("id, provider_id")
            .eq("job_id", value: jobId)
            .execute()
        
        if let existingDealsResponse = try? JSONSerialization.jsonObject(with: existingDealsData.data) as? [[String: Any]] {
            if !existingDealsResponse.isEmpty {
                let existingDeal = existingDealsResponse[0]
                let existingProviderId = existingDeal["provider_id"] as? String
                
                if existingProviderId == providerId {
                    throw NSError(domain: "DealOfferValidation", code: 5, userInfo: [NSLocalizedDescriptionKey: "You already have an active deal for this job"])
                } else {
                    throw NSError(domain: "DealOfferValidation", code: 6, userInfo: [NSLocalizedDescriptionKey: "This job already has an active deal with another provider"])
                }
            }
        }
        
        print("🔍 DEAL OFFER DEBUG: No existing deals found for job \(jobId) - validation passed")
        
        // Check existing deal offers count for this conversation
        let existingOffersData = try await supabase
            .from("deal_offers")
            .select("id")
            .eq("conversation_id", value: conversationId)
            .eq("provider_id", value: providerId)
            .execute()
        
        if let existingOffersResponse = try? JSONSerialization.jsonObject(with: existingOffersData.data) as? [[String: Any]] {
            let existingCount = existingOffersResponse.count
            print("🔍 DEAL OFFER DEBUG: Found \(existingCount) existing offers")
            
            // Check for maximum offers
            guard existingCount < 2 else {
                throw NSError(domain: "DealOfferValidation", code: 3, userInfo: [NSLocalizedDescriptionKey: "Maximum of 2 deal offers allowed per conversation"])
            }
            
            // Check for unanswered offers
            let hasUnanswered = existingOffersResponse.contains { offer in
                let status = offer["status"] as? String
                let respondedAt = offer["responded_at"]
                return status == "pending" && (respondedAt is NSNull || respondedAt == nil)
            }
            
            guard !hasUnanswered else {
                throw NSError(domain: "DealOfferValidation", code: 4, userInfo: [NSLocalizedDescriptionKey: "Please wait for client response to your previous offer before sending another"])
            }
        }
        
        // Create the deal offer record in the deal_offers table
        let dealOfferData: [String: AnyEncodable] = [
            "conversation_id": AnyEncodable(conversationId),
            "provider_id": AnyEncodable(providerId),
            "client_id": AnyEncodable(clientId),
            "job_id": AnyEncodable(jobId),
            "amount": AnyEncodable(amount),
            "terms": AnyEncodable(terms),
            "timeline": AnyEncodable(timeline),
            "status": AnyEncodable("pending")
        ]
        
        let dealOfferResult = try await supabase
            .from("deal_offers")
            .insert(dealOfferData)
            .select()
            .execute()
        
        // Parse the deal offer ID from the response
        guard let dealOfferResponseData = try? JSONSerialization.jsonObject(with: dealOfferResult.data) as? [[String: Any]],
              let dealOffer = dealOfferResponseData.first,
              let dealOfferId = dealOffer["id"] as? String else {
            throw NSError(domain: "DealOfferCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create deal offer record"])
        }
        
        print("🔍 DEAL OFFER DEBUG: Created deal offer with ID: \(dealOfferId)")
        
        // Create the message content
        let amountDollars = Double(amount) / 100.0
        let formattedAmount = String(format: "%.0f", amountDollars)
        let termsText = terms?.isEmpty == false ? " - \(terms!)" : ""
        let content = "💰 Deal Offer: $\(formattedAmount)\(termsText)"
        
        // Create negotiation data structure
        var negotiationData: [String: Any] = [
            "amount": amount,
            "deal_offer_id": dealOfferId
        ]
        
        if let terms = terms, !terms.isEmpty {
            negotiationData["terms"] = terms
        }
        
        if let timeline = timeline, !timeline.isEmpty {
            negotiationData["timeline"] = timeline
        }
        
        if let additionalMessage = additionalMessage, !additionalMessage.isEmpty {
            negotiationData["additional_message"] = additionalMessage
        }
        
        // Create message with deal offer data
        let messageData: [String: AnyEncodable] = [
            "conversation_id": AnyEncodable(conversationId),
            "sender_id": AnyEncodable(senderId),
            "content": AnyEncodable(content),
            "message_type": AnyEncodable("deal_offer"),
            "attachment_url": AnyEncodable(NSNull()),
            "negotiation_data": AnyEncodable(negotiationData)
        ]
        
        let messageResult = try await supabase
            .from("messages")
            .insert(messageData)
            .execute()
        
        print("✅ DEAL OFFER DEBUG: Deal offer message created successfully")
        print("🔍 DEAL OFFER DEBUG: Message result: \(messageResult)")
    }
    
    func getOfferStatus(conversationId: String, providerId: String) async throws -> (totalOffers: Int, hasUnansweredOffer: Bool) {
        print("🔍 OFFER STATUS DEBUG: Checking offer status for conversation: \(conversationId)")
        
        // Get all deal offers for this conversation from this provider
        let offersData = try await supabase
            .from("deal_offers")
            .select("id, status, responded_at")
            .eq("conversation_id", value: conversationId)
            .eq("provider_id", value: providerId)
            .execute()
        
        guard let offersResponse = try? JSONSerialization.jsonObject(with: offersData.data) as? [[String: Any]] else {
            print("🔍 OFFER STATUS DEBUG: No offers found or failed to parse")
            return (totalOffers: 0, hasUnansweredOffer: false)
        }
        
        let totalOffers = offersResponse.count
        let hasUnanswered = offersResponse.contains { offer in
            let status = offer["status"] as? String
            let respondedAt = offer["responded_at"]
            return status == "pending" && (respondedAt is NSNull || respondedAt == nil)
        }
        
        print("🔍 OFFER STATUS DEBUG: Total offers: \(totalOffers), Has unanswered: \(hasUnanswered)")
        return (totalOffers: totalOffers, hasUnansweredOffer: hasUnanswered)
    }
    
    func respondToDealOffer(dealOfferId: String, conversationId: String, accept: Bool, senderId: String) async throws {
        print("🔍 DEAL RESPONSE DEBUG: Responding to deal offer \(dealOfferId) - Accept: \(accept)")
        
        // 1. Update the deal offer status in the deal_offers table
        // This will trigger automatic deal creation if accepted
        let statusValue = accept ? "accepted" : "rejected"
        let currentTime = ISO8601DateFormatter().string(from: Date())
        
        let updateResult = try await supabase
            .from("deal_offers")
            .update([
                "status": AnyEncodable(statusValue),
                "responded_at": AnyEncodable(currentTime)
            ])
            .eq("id", value: dealOfferId)
            .execute()
        
        print("🔍 DEAL RESPONSE DEBUG: Updated deal offer status to \(statusValue)")
        
        // 2. Create the response message with proper linking
        let content = accept ? "✅ Deal accepted" : "❌ Deal rejected"
        
        let responseData: [String: Any] = [
            "response": statusValue,
            "original_deal_offer_id": dealOfferId,
            "responded_at": currentTime
        ]
        
        let messageData: [String: AnyEncodable] = [
            "conversation_id": AnyEncodable(conversationId),
            "sender_id": AnyEncodable(senderId),
            "content": AnyEncodable(content),
            "message_type": AnyEncodable("deal_response"),
            "deal_offer_id": AnyEncodable(dealOfferId), // CRITICAL: Link to original offer
            "attachment_url": AnyEncodable(NSNull()),
            "negotiation_data": AnyEncodable(responseData)
        ]
        
        let messageResult = try await supabase
            .from("messages")
            .insert(messageData)
            .execute()
        
        print("✅ DEAL RESPONSE DEBUG: Created response message successfully")
        print("🔍 DEAL RESPONSE DEBUG: Message result: \(messageResult)")
    }
    
    /// Placeholder method - messaging functionality disabled
    func preloadConversationData(userId: String) async {
        // No-op
    }
    
    /// Placeholder method - messaging functionality disabled
    func subscribeToConversation(
        conversationId: String,
        onNewMessage: @escaping (Any) -> Void,
        onTypingChange: @escaping ([String]) -> Void
    ) async throws {
        // No-op
    }
    
    /// Placeholder method - messaging functionality disabled
    func unsubscribeFromConversation(conversationId: String) async {
        // No-op
    }
    
    /// Placeholder method - messaging functionality disabled
    func sendMessage(
        conversationId: String,
        message: String,
        senderId: String,
        messageType: String = "text",
        negotiationData: [String: Any]? = nil,
        attachmentUrl: String? = nil
    ) async throws -> Any? {
        throw NSError(domain: "MessagingDisabled", code: 0, userInfo: [NSLocalizedDescriptionKey: "Messaging functionality is disabled"])
    }
    
    /// Placeholder method - messaging functionality disabled
    func markMessagesAsRead(conversationId: String, userId: String) async throws {
        // No-op
    }
    
    /// Placeholder method - messaging functionality disabled
    func deleteConversation(conversationId: String) async throws {
        // No-op
    }
    
    /// Placeholder method - messaging functionality disabled
    func updateTypingStatus(conversationId: String, userId: String, isTyping: Bool) async {
        // No-op
    }
    
    /// Placeholder method - messaging functionality disabled
    func uploadImage(_ imageData: Data, fileName: String) async throws -> String {
        throw NSError(domain: "MessagingDisabled", code: 0, userInfo: [NSLocalizedDescriptionKey: "Messaging functionality is disabled"])
    }
    
    /// Placeholder method - messaging functionality disabled
    func testRealtimeConnection() async -> Bool {
        return false
    }
    
    /// Placeholder method - messaging functionality disabled
    func cleanup() async {
        // No-op
    }
}

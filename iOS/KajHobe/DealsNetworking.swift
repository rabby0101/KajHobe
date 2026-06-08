import Foundation
import Supabase
import Foundation
import Auth
import Combine

// MARK: - Deals Networking
class DealsNetworking: ObservableObject {
    static let shared = DealsNetworking()
    private init() {}
    
    @Published var objectWillChange = ObservableObjectPublisher()
    
    // MARK: - Supabase Client
    // Uses the global supabase client from Supabase.swift
    
    
    // MARK: - Deal Offers
    func createDealOffer(conversationId: String, amount: Int, terms: String?, timeline: String?) async throws -> DealOffer {
        do {
            let user = try supabase.auth.requireCurrentUser()
            print("🔄 [DEAL CREATION START] User: \(user.id), Conversation: \(conversationId), Amount: \(amount)")
            
            // Get conversation details to verify user is provider
            let conversationResponse = try await supabase
                .from("conversations")
                .select("*")
                .eq("id", value: conversationId)
                .single()
                .execute()
            
            // Extract basic conversation data for deal creation
            let conversationData = try JSONSerialization.jsonObject(with: conversationResponse.data) as! [String: Any]
            guard let clientId = conversationData["client_id"] as? String,
                  let jobId = conversationData["job_id"] as? String,
                  let providerId = conversationData["provider_id"] as? String else {
                throw NetworkingError.validationError("Invalid conversation data")
            }
            
            // Verify user is the provider
            guard providerId.lowercased() == user.id.uuidString.lowercased() else {
                throw NetworkingError.unauthorized("Only the service provider can create deal offers")
            }
            
            // Check if provider has already created offer(s) for this job
            let existingOffers = try await getAllDealsForJob(providerId: user.id.uuidString, jobId: jobId)
            print("🔍 [VALIDATION] Found \(existingOffers.count) existing offers")
            
            if !existingOffers.isEmpty {
                let latestOffer = existingOffers.first!
                if latestOffer.status == "pending" {
                    throw NetworkingError.validationError("You already have a pending offer for this job. Please wait for client response.")
                } else if latestOffer.status == "accepted" {
                    throw NetworkingError.validationError("Your offer has been accepted. A deal has been created for this job.")
                } else if latestOffer.status == "rejected" && existingOffers.count >= 2 {
                    throw NetworkingError.validationError("You have already sent your final offer. No more offers can be sent.")
                }
            }
            
            // Create deal offer data
            let dealOfferData = AnyEncodable([
                "conversation_id": conversationId,
                "provider_id": user.id.uuidString,
                "client_id": clientId,
                "job_id": jobId,
                "amount": amount,
                "terms": terms as Any,
                "timeline": timeline as Any,
                "status": "pending"
            ])
            
            // Insert deal offer
            let dealOfferResponse = try await supabase
                .from("deal_offers")
                .insert(dealOfferData)
                .select()
                .single()
                .execute()
            
            let dealOffer = try JSONDecoder().decode(DealOffer.self, from: dealOfferResponse.data)
            
            // Create system message for the deal offer
            var negotiationDict: [String: Any] = [
                "deal_offer_id": dealOffer.id,
                "amount": amount
            ]
            if let terms = terms {
                negotiationDict["terms"] = terms
            }
            if let timeline = timeline {
                negotiationDict["timeline"] = timeline
            }
            let negotiationData = AnyCodable(negotiationDict)
            
            let systemMessage = AnyEncodable([
                "conversation_id": conversationId,
                "sender_id": user.id.uuidString,
                "content": "💰 Deal Offer: $\(amount) - \(terms ?? "No terms specified")",
                "message_type": "deal_offer",
                "negotiation_data": negotiationData
            ])
            
            try await supabase
                .from("messages")
                .insert(systemMessage)
                .execute()
            
            return dealOffer
            
        } catch {
            print("❌ Error creating deal offer: \(error)")
            throw error
        }
    }
    
    func respondToDealOffer(dealOfferId: String, response: String, message: String?) async throws -> DealOffer {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // Get deal offer details
            let dealOfferResponse = try await supabase
                .from("deal_offers")
                .select("*")
                .eq("id", value: dealOfferId)
                .single()
                .execute()
            
            let dealOffer = try JSONDecoder().decode(DealOffer.self, from: dealOfferResponse.data)
            
            // Verify user is the client
            guard dealOffer.client_id.lowercased() == user.id.uuidString.lowercased() else {
                throw NetworkingError.unauthorized("Only the client can respond to deal offers")
            }
            
            // Check if deal has already been responded to
            guard dealOffer.status == "pending" else {
                throw NetworkingError.validationError("This deal offer has already been \(dealOffer.status)")
            }
            
            // Update deal offer status
            let updateData = AnyEncodable([
                "status": response,
                "responded_at": ISO8601DateFormatter().string(from: Date())
            ])
            
            let updatedDealOfferResponse = try await supabase
                .from("deal_offers")
                .update(updateData)
                .eq("id", value: dealOfferId)
                .select("id, conversation_id, provider_id, client_id, job_id, amount, terms, timeline, status, created_at, responded_at")
                .single()
                .execute()
            
            let updatedDealOffer: DealOffer
            let decoder = JSONDecoder()
            do {
                updatedDealOffer = try decoder.decode(DealOffer.self, from: updatedDealOfferResponse.data)
            } catch {
                // Fallback to manual parsing
                if let jsonObject = try? JSONSerialization.jsonObject(with: updatedDealOfferResponse.data) as? [String: Any] {
                    updatedDealOffer = DealOffer(
                        id: jsonObject["id"] as? String ?? dealOffer.id,
                        conversation_id: jsonObject["conversation_id"] as? String ?? dealOffer.conversation_id,
                        provider_id: jsonObject["provider_id"] as? String ?? dealOffer.provider_id,
                        client_id: jsonObject["client_id"] as? String ?? dealOffer.client_id,
                        job_id: jsonObject["job_id"] as? String ?? dealOffer.job_id,
                        amount: jsonObject["amount"] as? Int ?? dealOffer.amount,
                        terms: jsonObject["terms"] as? String ?? dealOffer.terms,
                        timeline: jsonObject["timeline"] as? String ?? dealOffer.timeline,
                        status: response,
                        created_at: jsonObject["created_at"] as? String ?? dealOffer.created_at,
                        responded_at: jsonObject["responded_at"] as? String
                    )
                } else {
                    updatedDealOffer = DealOffer(
                        id: dealOffer.id,
                        conversation_id: dealOffer.conversation_id,
                        provider_id: dealOffer.provider_id,
                        client_id: dealOffer.client_id,
                        job_id: dealOffer.job_id,
                        amount: dealOffer.amount,
                        terms: dealOffer.terms,
                        timeline: dealOffer.timeline,
                        status: response,
                        created_at: dealOffer.created_at,
                        responded_at: ISO8601DateFormatter().string(from: Date())
                    )
                }
            }
            
            // If accepted, create deal and mark job as taken
            if response == "accepted" {
                try await createDealFromAcceptedOffer(dealOffer: updatedDealOffer)
            }
            
            // Send notification for rejection
            if response == "rejected" {
                try await NotificationsNetworking.shared.createNotification(
                    type: "deal_rejected",
                    jobId: dealOffer.job_id,
                    fromUserId: user.id.uuidString,
                    toUserId: dealOffer.provider_id,
                    message: "Your deal offer was not accepted"
                )
            }
            
            return updatedDealOffer
            
        } catch {
            print("❌ Error responding to deal offer: \(error)")
            throw error
        }
    }
    
    private func createDealFromAcceptedOffer(dealOffer: DealOffer) async throws {
        print("🔍 [DEAL CREATION] Starting for offer ID: \(dealOffer.id)")
        
        // Check if a deal already exists for this deal offer ID
        let existingDealsResponse = try await supabase
            .from("deals")
            .select("id, deal_offer_id, status, created_at, job_id")
            .eq("deal_offer_id", value: dealOffer.id)
            .execute()
        
        // Parse response to check if any deals exist
        if let data = try? JSONSerialization.jsonObject(with: existingDealsResponse.data) as? [[String: Any]] {
            print("🔍 [DEAL CHECK] Found \(data.count) existing deals for offer ID: \(dealOffer.id)")
            
            if !data.isEmpty {
                // Print details of existing deals
                for (index, deal) in data.enumerated() {
                    print("🔍 [EXISTING DEAL \(index + 1)] ID: \(deal["id"] ?? "unknown"), Status: \(deal["status"] ?? "unknown"), Job: \(deal["job_id"] ?? "unknown")")
                }
                print("⚠️ Deal already exists for offer ID: \(dealOffer.id), skipping creation")
                return // Deal already exists, don't create another
            }
        }
        
        print("🔄 [DEAL CREATION] No existing deals found, creating new deal...")
        
        // Also check for existing deals by job_id and participants to catch edge cases
        let jobDealsResponse = try await supabase
            .from("deals")
            .select("id, deal_offer_id, status, job_id")
            .eq("job_id", value: dealOffer.job_id)
            .eq("client_id", value: dealOffer.client_id)
            .eq("provider_id", value: dealOffer.provider_id)
            .in("status", values: ["active", "in_progress"])
            .execute()
        
        if let jobDealsData = try? JSONSerialization.jsonObject(with: jobDealsResponse.data) as? [[String: Any]],
           !jobDealsData.isEmpty {
            print("⚠️ [DUPLICATE PREVENTION] Found \(jobDealsData.count) active deals for same job/participants:")
            for (index, deal) in jobDealsData.enumerated() {
                print("   Deal \(index + 1): ID=\(deal["id"] ?? "unknown"), OfferID=\(deal["deal_offer_id"] ?? "unknown"), Status=\(deal["status"] ?? "unknown")")
            }
            print("⚠️ Preventing duplicate deal creation for job: \(dealOffer.job_id)")
            return
        }
        
        // Create a deal record using dictionary
        let dealData: [String: Any] = [
            "deal_offer_id": dealOffer.id,
            "conversation_id": dealOffer.conversation_id,
            "provider_id": dealOffer.provider_id,
            "client_id": dealOffer.client_id,
            "job_id": dealOffer.job_id,
            "agreed_amount": dealOffer.amount,
            "agreed_terms": dealOffer.terms as Any,
            "timeline": dealOffer.timeline as Any,
            "status": "active"
        ]
        
        print("🔄 [DEAL CREATION] Inserting deal data: Job=\(dealOffer.job_id), Amount=\(dealOffer.amount)")
        
        try await supabase
            .from("deals")
            .insert(AnyEncodable(dealData))
            .execute()
        
        print("✅ [DEAL SUCCESS] New deal created for offer ID: \(dealOffer.id), Job: \(dealOffer.job_id)")
        
        // Update job status to "assigned"
        try await supabase
            .from("jobs")
            .update(["status": "assigned"])
            .eq("id", value: dealOffer.job_id)
            .execute()
        
        print("✅ [JOB UPDATE] Job \(dealOffer.job_id) marked as assigned")
    }

    func getDealCount(providerId: String, jobId: String) async throws -> Int {
        let response = try await supabase
            .from("deal_offers")
            .select("count")
            .eq("provider_id", value: providerId)
            .eq("job_id", value: jobId)
            .execute()
        
        // Parse count from response
        if let data = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
           let firstItem = data.first,
           let count = firstItem["count"] as? Int {
            return count
        }
        return 0
    }
    
    func getAllDealsForJob(providerId: String, jobId: String) async throws -> [DealOffer] {
        do {
            let response = try await supabase
                .from("deal_offers")
                .select("*")
                .eq("provider_id", value: providerId)
                .eq("job_id", value: jobId)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            let dealOffers = try decoder.decode([DealOffer].self, from: response.data)
            return dealOffers
        } catch {
            print("Error fetching deal offers: \(error)")
            return []
        }
    }
    
    func hasPendingDeal(providerId: String, jobId: String) async throws -> Bool {
        let dealOffers = try await getAllDealsForJob(providerId: providerId, jobId: jobId)
        return dealOffers.contains { $0.status == "pending" }
    }
    
    func hasAcceptedDeal(providerId: String, jobId: String) async throws -> Bool {
        let dealOffers = try await getAllDealsForJob(providerId: providerId, jobId: jobId)
        return dealOffers.contains { $0.status == "accepted" }
    }
    
    func fetchDealOffers(conversationId: String) async throws -> [DealOffer] {
        do {
            let response = try await supabase
                .from("deal_offers")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            let dealOffers = try decoder.decode([DealOffer].self, from: response.data)
            return dealOffers
        } catch {
            print("Error fetching deal offers: \(error)")
            throw error
        }
    }
    
    func fetchMyDeals() async throws -> [Deal] {
        do {
            let user = try supabase.auth.requireCurrentUser()
            let userIdUpper = user.id.uuidString.uppercased()
            let userIdLower = user.id.uuidString.lowercased()
            
            let response = try await supabase
                .from("deals")
                .select("*, job:jobs!job_id(*), client_profile:profiles!deals_client_id_fkey(*), provider_profile:profiles!deals_provider_id_fkey(*)")
                .or("client_id.eq.\(userIdUpper),provider_id.eq.\(userIdUpper),client_id.eq.\(userIdLower),provider_id.eq.\(userIdLower)")
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            let deals = try decoder.decode([Deal].self, from: response.data)
            return deals
        } catch {
            print("Error fetching my deals: \(error)")
            throw error
        }
    }
    
    // MARK: - Task Completion
    func requestTaskCompletion(dealId: String, message: String?) async throws -> CompletionRequest {
        do {
            let user = try supabase.auth.requireCurrentUser()
            print("🔍 [COMPLETION REQUEST] User requesting completion: \(user.id)")
            
            // First get the deal to determine if user is client or provider
            let dealResponse = try await supabase
                .from("deals")
                .select("client_id, provider_id")
                .eq("id", value: dealId)
                .single()
                .execute()

            guard let dealData = try? JSONSerialization.jsonObject(with: dealResponse.data) as? [String: Any],
                  let clientId = dealData["client_id"] as? String,
                  let providerId = dealData["provider_id"] as? String else {
                throw NetworkingError.invalidData("Could not get deal information")
            }
            
            // Determine requester type based on user ID
            let userIdLower = user.id.uuidString.lowercased()
            let requesterType: String
            if clientId.lowercased() == userIdLower {
                requesterType = "client"
            } else if providerId.lowercased() == userIdLower {
                requesterType = "provider"
            } else {
                throw NetworkingError.unauthorized("User is not part of this deal")
            }
            
            print("🔍 [COMPLETION REQUEST] User is: \(requesterType)")
            print("🔍 [COMPLETION REQUEST] Deal client_id: \(clientId)")
            print("🔍 [COMPLETION REQUEST] Deal provider_id: \(providerId)")
            
            let completionData: [String: Any] = [
                "deal_id": dealId,
                "requester_id": user.id.uuidString,
                "requester_type": requesterType,
                "request_message": message as Any
            ]
            
            let response = try await supabase
                .from("completion_requests")
                .insert(AnyEncodable(completionData))
                .select()
                .single()
                .execute()

            let completionRequest = try JSONDecoder().decode(CompletionRequest.self, from: response.data)

            // Update the deal to reflect completion request status.
            // NOTE: a DB trigger (`trigger_set_deal_completion_flags`) now sets
            // these flags automatically on INSERT, so this manual update is
            // redundant but kept for backwards compatibility with existing
            // trigger behavior on other code paths. Safe to keep.
            let completionUpdateData: [String: Any] = [
                "completion_status": "pending_approval",
                requesterType == "client" ? "client_completion_requested" : "provider_completion_requested": true,
                requesterType == "client" ? "client_completion_requested_at" : "provider_completion_requested_at": ISO8601DateFormatter().string(from: Date())
            ]

            try await supabase
                .from("deals")
                .update(AnyEncodable(completionUpdateData))
                .eq("id", value: dealId)
                .execute()

            print("✅ Task completion requested for deal: \(dealId) - deal status updated to pending_approval")
            return completionRequest

        } catch {
            // Translate the unique-index violation (SQLSTATE 23505) on
            // `completion_requests_one_pending_per_deal` into a typed error so
            // the caller can re-route the user to the response sheet.
            if let postgrestError = error as? PostgrestError,
               postgrestError.code == "23505",
               postgrestError.message.contains("completion_requests_one_pending_per_deal")
                   || postgrestError.message.contains("duplicate key value") {
                print("⚠️ [COMPLETION REQUEST] Another pending request already exists for deal: \(dealId)")
                throw NetworkingError.completionRequestAlreadyPending(dealId: dealId)
            }
            print("❌ Error requesting task completion: \(error)")
            throw error
        }
    }
    
    func respondToCompletionRequest(requestId: String, approve: Bool, message: String?) async throws {
        do {
            let user = try supabase.auth.requireCurrentUser()
            let status = approve ? "approved" : "rejected"
            let now = ISO8601DateFormatter().string(from: Date())
            
            let updateData = [
                "status": status,
                "responded_at": now,
                "response_message": message
            ]
            
            try await supabase
                .from("completion_requests")
                .update(updateData)
                .eq("id", value: requestId)
                .execute()
            
            // Always get the deal_id from the completion request for both approve and reject
            let completionRequestResponse = try await supabase
                .from("completion_requests")
                .select("deal_id")
                .eq("id", value: requestId)
                .single()
                .execute()
            
            if let data = try? JSONSerialization.jsonObject(with: completionRequestResponse.data) as? [String: Any],
               let dealId = data["deal_id"] as? String {
                
                if approve {
                    // Update deal status to completed
                    try await supabase
                        .from("deals")
                        .update(["status": "completed", "completed_at": now])
                        .eq("id", value: dealId)
                        .execute()
                    
                    // Get the job_id to update the job status too
                    let dealResponse = try await supabase
                        .from("deals")
                        .select("job_id")
                        .eq("id", value: dealId)
                        .single()
                        .execute()

                    if let dealData = try? JSONSerialization.jsonObject(with: dealResponse.data) as? [String: Any],
                       let jobId = dealData["job_id"] as? String {

                        // Update job status to completed
                        try await supabase
                            .from("jobs")
                            .update(["status": "completed"])
                            .eq("id", value: jobId)
                            .execute()

                        print("✅ Job \(jobId) marked as completed")
                    }

                    print("✅ Deal \(dealId) marked as completed")
                } else {
                    // Rejection: Reset deal status back to active and clear completion flags
                    let resetData: [String: Any] = [
                        "status": "active",
                        "completion_status": "in_progress",
                        "client_completion_requested": false,
                        "provider_completion_requested": false,
                        "client_completion_requested_at": NSNull(),
                        "provider_completion_requested_at": NSNull()
                    ]
                    
                    try await supabase
                        .from("deals")
                        .update(AnyEncodable(resetData))
                        .eq("id", value: dealId)
                        .execute()
                    
                    print("✅ Deal \(dealId) completion rejected - reset to active with cleared completion flags")
                }
            }
            
            print("✅ Completion request \(status) for request: \(requestId)")
            
        } catch {
            print("❌ Error responding to completion request: \(error)")
            throw error
        }
    }
    
    // MARK: - Dashboard Data
    func fetchDashboardData(forceRefresh: Bool = false) async throws -> DashboardData {
        // Cache has been removed - always fetch fresh data
        
        do {
            let user = try supabase.auth.requireCurrentUser()
            print("📊 Fetching dashboard data for user: \(user.id)")
            
            // First try using the database function to get dashboard data efficiently
            var dashboardDict: [String: Any]?
            
            do {
                let response = try await supabase.rpc(
                    "get_user_dashboard_data",
                    params: ["user_id": user.id.uuidString]
                ).execute()
                
                // Parse the response
                if let data = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
                   let dict = data.first {
                    dashboardDict = dict
                    print("📊 Successfully used database function")
                }
            } catch {
                print("⚠️ Database function failed, falling back to manual queries: \(error)")
                
                // Fallback to manual queries if function doesn't exist
                let userType = "client" // Simplified for now
                
                // Count active deals
                let activeDealsResponse = try await supabase
                    .from("deals")
                    .select("count")
                    .or("client_id.eq.\(user.id.uuidString),provider_id.eq.\(user.id.uuidString)")
                    .eq("status", value: "active")
                    .execute()
                
                let activeDealsCount = parseCountFromResponse(activeDealsResponse.data)
                
                // Count completed deals
                let completedDealsResponse = try await supabase
                    .from("deals")
                    .select("count")
                    .or("client_id.eq.\(user.id.uuidString),provider_id.eq.\(user.id.uuidString)")
                    .eq("status", value: "completed")
                    .execute()
                
                let completedDealsCount = parseCountFromResponse(completedDealsResponse.data)
                
                // Create manual dashboard dict
                dashboardDict = [
                    "user_type": userType,
                    "active_deals_count": activeDealsCount,
                    "completed_deals_count": completedDealsCount,
                    "pending_completion_requests": 0,
                    "total_earnings": 0.0,
                    "total_spent": 0.0,
                    "average_rating": 4.5,
                    "recent_deals": []
                ]
                print("📊 Used fallback manual queries")
            }
            
            // Parse the dashboard data
            if let dict = dashboardDict {
                
                // Extract values with proper type conversion
                let userType = dict["user_type"] as? String ?? "client"
                let activeDealsCount = (dict["active_deals_count"] as? NSNumber)?.intValue ?? 0
                let completedDealsCount = (dict["completed_deals_count"] as? NSNumber)?.intValue ?? 0
                let pendingCompletionRequests = (dict["pending_completion_requests"] as? NSNumber)?.intValue ?? 0
                let totalEarnings = (dict["total_earnings"] as? NSNumber)?.doubleValue ?? 0.0
                let totalSpent = (dict["total_spent"] as? NSNumber)?.doubleValue ?? 0.0
                let averageRating = (dict["average_rating"] as? NSNumber)?.doubleValue ?? 4.5
                
                // Parse recent deals
                var recentDeals: [DashboardDeal]?
                if let recentDealsArray = dict["recent_deals"] as? [[String: Any]] {
                    recentDeals = recentDealsArray.compactMap { dealDict -> DashboardDeal? in
                        guard let id = dealDict["id"] as? String,
                              let jobTitle = dealDict["job_title"] as? String,
                              let agreedAmount = dealDict["agreed_amount"] as? Int,
                              let completionStatus = dealDict["completion_status"] as? String,
                              let createdAt = dealDict["created_at"] as? String else {
                            return nil
                        }
                        
                        let otherPartyName = dealDict["other_party_name"] as? String
                        
                        return DashboardDeal(
                            id: id,
                            job_title: jobTitle,
                            agreed_amount: agreedAmount,
                            completion_status: completionStatus,
                            created_at: createdAt,
                            other_party_name: otherPartyName
                        )
                    }
                }
                
                let dashboardData = DashboardData(
                    user_type: userType,
                    active_deals_count: activeDealsCount,
                    completed_deals_count: completedDealsCount,
                    pending_completion_requests: pendingCompletionRequests,
                    total_earnings: totalEarnings,
                    total_spent: totalSpent,
                    average_rating: averageRating,
                    recent_deals: recentDeals
                )
                
                // Cache has been removed
                
                print("✅ Dashboard data fetched successfully: Active:\(activeDealsCount), Completed:\(completedDealsCount), Earnings:\(totalEarnings), Spent:\(totalSpent)")
                return dashboardData
                
            } else {
                // Fallback to empty dashboard data
                print("⚠️ No dashboard data returned, using fallback")
                let fallbackData = DashboardData(
                    user_type: "client",
                    active_deals_count: 0,
                    completed_deals_count: 0,
                    pending_completion_requests: 0,
                    total_earnings: 0.0,
                    total_spent: 0.0,
                    average_rating: 4.5,
                    recent_deals: nil
                )
                
                // Cache has been removed
                
                return fallbackData
            }
            
        } catch {
            print("❌ Error fetching dashboard data: \(error)")
            
            // Return fallback data on error to prevent UI crash
            let fallbackData = DashboardData(
                user_type: "client",
                active_deals_count: 0,
                completed_deals_count: 0,
                pending_completion_requests: 0,
                total_earnings: 0.0,
                total_spent: 0.0,
                average_rating: 4.5,
                recent_deals: nil
            )
            
            return fallbackData
        }
    }
    
    private func parseCountFromResponse(_ data: Data) -> Int {
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstItem = jsonArray.first,
               let count = firstItem["count"] as? Int {
                return count
            }
        } catch {
            print("❌ Error parsing count response: \(error)")
        }
        return 0
    }
    
    func fetchActiveDeals(forceRefresh: Bool = false) async throws -> [Deal] {
        // Cache has been removed - always fetch fresh data
        
        do {
            let user = try supabase.auth.requireCurrentUser()
            print("🔍 [ACTIVE DEALS] Fetching for user: \(user.id)")
            
            let userIdUpper = user.id.uuidString.uppercased()
            let userIdLower = user.id.uuidString.lowercased()
            print("🔍 [ACTIVE DEALS] User ID Upper: \(userIdUpper)")
            print("🔍 [ACTIVE DEALS] User ID Lower: \(userIdLower)")
            
            let response = try await supabase
                .from("deals")
                .select("*, job:jobs!job_id(*), client_profile:profiles!deals_client_id_fkey(*), provider_profile:profiles!deals_provider_id_fkey(*)")
                .or("client_id.eq.\(userIdUpper),provider_id.eq.\(userIdUpper),client_id.eq.\(userIdLower),provider_id.eq.\(userIdLower)")
                .in("status", values: ["active", "in_progress"])
                .order("created_at", ascending: false)
                .execute()
            
            print("🔍 [ACTIVE DEALS] Raw response size: \(response.data.count) bytes")
            
            // Debug: Print raw response  
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("🔍 [ACTIVE DEALS] Raw JSON Response:")
                print(jsonString)
                print("🔍 [ACTIVE DEALS] ========== END RAW JSON ==========")
            }
            
            let deals = try JSONDecoder().decode([Deal].self, from: response.data)
            
            // Debug: Print deal details
            for (index, deal) in deals.enumerated() {
                print("🔍 [DEAL \(index + 1)] ID: \(deal.id)")
                print("   Job ID: \(deal.job_id)")
                print("   Job Title: \(deal.job?.title ?? "NIL - Job data missing!")")
                print("   Job Data Present: \(deal.job != nil)")
                if let job = deal.job {
                    print("   Job Details: ID=\(job.id), Title=\(job.title), Status=\(job.status ?? "no status")")
                }
                print("   Amount: \(deal.agreed_amount)")
                print("   Status: \(deal.status)")
                print("   Client ID: \(deal.client_id)")
                print("   Provider ID: \(deal.provider_id)")
                print("   User ID (upper): \(userIdUpper)")
                print("   User ID (lower): \(userIdLower)")
                if let clientProfile = deal.client_profile {
                    print("   Client: \(clientProfile.full_name ?? "Unknown")")
                }
                if let providerProfile = deal.provider_profile {
                    print("   Provider: \(providerProfile.full_name ?? "Unknown")")
                }
            }
            
            // Cache has been removed
            
            print("✅ Fetched \(deals.count) active deals")
            return deals
            
        } catch {
            print("❌ Error fetching active deals: \(error)")
            throw error
        }
    }
    
    func fetchPendingCompletionRequests(forceRefresh: Bool = false) async throws -> [CompletionRequest] {
        // Cache has been removed - always fetch fresh data
        
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            let response = try await supabase
                .from("completion_requests")
                .select("*, deals(*, job:jobs(*)), requester_profile:profiles!completion_requests_requester_id_fkey(*)")
                .eq("status", value: "pending")
                .execute()
            
            let requests = try JSONDecoder().decode([CompletionRequest].self, from: response.data)
            print("🔍 [COMPLETION REQUESTS] Decoded \(requests.count) total completion requests")
            
            // Debug: Print all requests
            for (index, request) in requests.enumerated() {
                print("🔍 [REQUEST \(index + 1)] ID: \(request.id)")
                print("   Requester ID: \(request.requester_id)")
                print("   Requester Type: \(request.requester_type)")
                print("   Status: \(request.status)")
                if let deal = request.deals {
                    print("   Deal ID: \(deal.id)")
                    print("   Deal Client ID: \(deal.client_id)")
                    print("   Deal Provider ID: \(deal.provider_id)")
                    print("   Job Title: \(deal.job?.title ?? "No job data")")
                }
                if let requesterProfile = request.requester_profile {
                    print("   Requester Name: \(requesterProfile.full_name ?? "Unknown")")
                }
            }
            
            // Filter to only show requests where user needs to APPROVE (not the requester)
            let userRequests = requests.filter { request in
                guard let deal = request.deals else { 
                    print("🔍 [FILTER] Request \(request.id) has no deal data - skipping")
                    return false 
                }
                
                // Only show completion requests to the OTHER party who needs to approve
                // If client requested completion, show to provider
                // If provider requested completion, show to client
                let userIdLower = user.id.uuidString.lowercased()
                let shouldShow: Bool
                
                if request.requester_type == "client" {
                    // Client requested, show to provider
                    shouldShow = deal.provider_id.lowercased() == userIdLower
                    print("🔍 [FILTER] Client requested, checking if user (\(userIdLower)) is provider (\(deal.provider_id.lowercased())): \(shouldShow)")
                } else {
                    // Provider requested, show to client  
                    shouldShow = deal.client_id.lowercased() == userIdLower
                    print("🔍 [FILTER] Provider requested, checking if user (\(userIdLower)) is client (\(deal.client_id.lowercased())): \(shouldShow)")
                }
                
                return shouldShow
            }
            
            print("🔍 [COMPLETION REQUESTS] Total: \(requests.count), For current user: \(userRequests.count)")
            print("🔍 [COMPLETION REQUESTS] Current user ID: \(user.id.uuidString)")
            
            // Cache has been removed
            
            print("✅ Fetched \(userRequests.count) pending completion requests")
            return userRequests
            
        } catch {
            print("❌ Error fetching pending completion requests: \(error)")
            throw error
        }
    }
}
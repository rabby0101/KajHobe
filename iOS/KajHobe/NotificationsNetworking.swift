import Foundation
import Supabase
import Foundation
import Auth
import Functions

// Import BusinessNotification from BusinessNotificationsView
// BusinessNotification is defined in BusinessNotificationsView.swift

// MARK: - Simple data structures for notification operations
struct NotificationCountData: Codable, Sendable {
    let notification_state: String?
    let read: Bool?
}

// MARK: - Notifications Networking
@preconcurrency
class NotificationsNetworking: BaseNetworking {
    
    /// Simple interest status structure for the new 3-minute cooldown system
    struct SimpleInterestStatus {
        let canShowInterest: Bool
        let status: String // "none", "pending", "accepted", "rejected_cooldown", "rejected_expired", etc.
        let message: String
        let remainingCooldown: TimeInterval? // seconds remaining
        let recordExists: Bool
    }
    static let shared = NotificationsNetworking()
    private override init() { super.init() }
    
    // MARK: - Real-time Subscriptions
    
    /// Subscribe to real-time notification updates
    ///
    /// IMPORTANT: `postgresChange` MUST be invoked BEFORE `channel.subscribe()`.
    /// The iOS SDK (`RealtimeChannelV2._onPostgresChange`) silently drops new
    /// listeners on an already-subscribed channel (it `reportIssue`s and returns
    /// an empty subscription). Wrapping the listener setup in `Task { }` blocks
    /// that race with `subscribe()` is therefore a bug — and was the reason the
    /// notification badge wasn't updating in real-time. The listeners are now
    /// registered synchronously, then the channel is subscribed once.
    func subscribeToNotifications(
        userId: String,
        onNewNotification: @escaping (EnhancedNotification) -> Void,
        onNotificationUpdate: @escaping (EnhancedNotification) -> Void
    ) async -> RealtimeChannelV2 {
        let channel = supabase.realtimeV2.channel("notifications_\(userId)")

        // Register BOTH listeners synchronously, before subscribing.
        let insertions = await channel.postgresChange(
            InsertAction.self,
            table: "notifications"
        )
        let updates = await channel.postgresChange(
            UpdateAction.self,
            table: "notifications"
        )

        // Now subscribe — both listeners are attached.
        await channel.subscribe()
        print("🔔 Subscribed to real-time notifications for user: \(userId)")

        // Spawn background collectors for the two streams. Each is a long-running
        // task that will yield events as the server pushes them.
        Task {
            for await insertion in insertions {
                // Check if this notification is for the current user
                if let record = insertion.record as? [String: Any] {
                    let toUserId = record["to_user_id"] as? String ?? record["user_id"] as? String

                    if toUserId == userId,
                       let notification = try? parseNotificationFromRealtime(record) {
                        await MainActor.run {
                            onNewNotification(notification)
                        }
                    }
                }
            }
        }

        Task {
            for await update in updates {
                // Check if this notification is for the current user
                if let record = update.record as? [String: Any] {
                    let toUserId = record["to_user_id"] as? String ?? record["user_id"] as? String

                    if toUserId == userId,
                       let notification = try? parseNotificationFromRealtime(record) {
                        await MainActor.run {
                            onNotificationUpdate(notification)
                        }
                    }
                }
            }
        }

        return channel
    }
    
    /// Parse notification data from real-time subscription
    private func parseNotificationFromRealtime(_ record: [String: Any]?) throws -> EnhancedNotification? {
        guard let record = record else { return nil }
        
        // Convert the record dictionary to JSON data and decode
        let jsonData = try JSONSerialization.data(withJSONObject: record)
        let decoder = JSONDecoder()
        
        // Handle date formatting
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        return try decoder.decode(EnhancedNotification.self, from: jsonData)
    }
    
    /// Unsubscribe from real-time notifications
    func unsubscribeFromNotifications(_ channel: RealtimeChannelV2?) async {
        await channel?.unsubscribe()
        print("🔕 Unsubscribed from real-time notifications")
    }
    
    // MARK: - Enhanced Notification Management
    
    /// Fetch enhanced notifications with state filtering
    nonisolated func fetchEnhancedNotifications(state: NotificationState? = nil) async throws -> [EnhancedNotification] {
        print("🚀 STARTING fetchEnhancedNotifications method - THIS SHOULD APPEAR!")
        print("🚀 State parameter: \(state?.rawValue ?? "nil")")
        
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    let user = try await supabase.auth.user()
                    print("🔍 Fetching enhanced notifications for user: \(user.id.uuidString) with state: \(state?.rawValue ?? "all")")
                    
                    // Use raw response approach to avoid Sendable conformance issues
                    let rawResponse: PostgrestResponse<Data>
                    
                    if let state = state {
                        rawResponse = try await supabase
                            .from("notifications")
                            .select("*")
                            .or("to_user_id.eq.\(user.id.uuidString),user_id.eq.\(user.id.uuidString)")
                            .eq("notification_state", value: state.rawValue)
                            .neq("type", value: "message_received")
                            .order("created_at", ascending: false)
                            .execute()
                    } else {
                        rawResponse = try await supabase
                            .from("notifications")
                            .select("*")
                            .or("to_user_id.eq.\(user.id.uuidString),user_id.eq.\(user.id.uuidString)")
                            .neq("type", value: "message_received")
                            .order("created_at", ascending: false)
                            .execute()
                    }
                    
                    // Debug: Print raw JSON response
                    if let jsonString = String(data: rawResponse.data, encoding: .utf8) {
                        print("🐛 RAW JSON RESPONSE:")
                        print(jsonString)
                    }
                    
                    // Manual decoding in detached context
                    let decoder = JSONDecoder()
                    let notifications = try decoder.decode([EnhancedNotification].self, from: rawResponse.data)
                    
                    print("✅ Successfully fetched \(notifications.count) enhanced notifications using proper Sendable approach")
                    continuation.resume(returning: notifications)
                } catch {
                    print("❌ Error fetching enhanced notifications: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Update notification state (unread -> read -> archived)
    func updateNotificationState(_ notificationId: String, to state: NotificationState) async throws {
        do {
            let _ = try await supabase.auth.user()
            print("🔄 Updating notification \(notificationId) to state: \(state.rawValue)")
            
            let now = ISO8601DateFormatter().string(from: Date())
            var updateData: [String: Any] = ["notification_state": state.rawValue]
            
            switch state {
            case .read:
                updateData["read_at"] = now
            case .archived:
                updateData["archived_at"] = now
            case .unread:
                updateData["read_at"] = NSNull()
                updateData["archived_at"] = NSNull()
            }
            
            try await supabase
                .from("notifications")
                .update(AnyEncodable(updateData))
                .eq("id", value: notificationId)
                .execute()
            
            print("✅ Successfully updated notification state")
        } catch {
            print("❌ Error updating notification state: \(error)")
            throw error
        }
    }
    
    /// Mark multiple notifications as read
    func markNotificationsAsRead(_ notificationIds: [String]) async throws {
        do {
            let _ = try await supabase.auth.user()
            let now = ISO8601DateFormatter().string(from: Date())
            
            let updateData = AnyEncodable([
                "notification_state": NotificationState.read.rawValue,
                "read_at": now
            ])
            
            try await supabase
                .from("notifications")
                .update(updateData)
                .in("id", values: notificationIds)
                .execute()
            
            print("✅ Successfully marked \(notificationIds.count) notifications as read")
        } catch {
            print("❌ Error marking notifications as read: \(error)")
            throw error
        }
    }
    
    /// Get notification counts by state
    nonisolated func getNotificationCounts() async throws -> (unread: Int, read: Int, archived: Int) {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    let user = try await supabase.auth.user()
                    let userId = user.id.uuidString
                    print("🔢 Getting notification counts for user: \(userId)")

                    // 1) Business notifications (notifications table) — count only GENUINELY unread.
                    let rawResponse = try await supabase
                        .from("notifications")
                        .select("notification_state, read")
                        .or("user_id.eq.\(userId),to_user_id.eq.\(userId)")
                        .neq("type", value: "message_received")
                        .execute()

                    // Manual decoding in detached context
                    let decoder = JSONDecoder()
                    let countData = try decoder.decode([NotificationCountData].self, from: rawResponse.data)

                    var businessUnread = 0
                    var readCount = 0
                    var archivedCount = 0

                    for item in countData {
                        if let stateString = item.notification_state,
                           let state = NotificationState(rawValue: stateString) {
                            switch state {
                            case .unread: businessUnread += 1
                            case .read: readCount += 1
                            case .archived: archivedCount += 1
                            }
                        } else {
                            // No explicit notification_state (the large historical backlog
                            // was inserted with notification_state = NULL). Treat as READ:
                            // the bell counts ONLY rows explicitly marked 'unread'. This is
                            // what stops the old backlog from inflating the badge (the "206").
                            readCount += 1
                        }
                    }

                    // 2) Unread interest requests on the user's OWN jobs
                    //    (job_interests where jobs.client_id == user, status == pending, read == false).
                    var interestUnread = 0
                    do {
                        let interestResponse = try await supabase
                            .from("job_interests")
                            .select("id, jobs!inner(client_id)", head: true, count: .exact)
                            .eq("jobs.client_id", value: userId)
                            .eq("status", value: "pending")
                            .eq("read", value: false)
                            .execute()
                        interestUnread = interestResponse.count ?? 0
                    } catch {
                        print("⚠️ Could not count unread interests: \(error)")
                    }

                    let totalUnread = businessUnread + interestUnread
                    print("📊 Notification counts - Unread: \(totalUnread) (business \(businessUnread) + interests \(interestUnread)), Read: \(readCount), Archived: \(archivedCount)")
                    continuation.resume(returning: (unread: totalUnread, read: readCount, archived: archivedCount))
                } catch {
                    print("❌ Error getting notification counts: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Legacy Notification Management
    func fetchNotifications() async throws -> [NotificationItem] {
        do {
            let user = try await supabase.auth.user()
            
            let response = try await supabase
                .from("notifications")
                .select("*")
                .or("user_id.eq.\(user.id.uuidString),to_user_id.eq.\(user.id.uuidString)")
                .neq("type", value: "message_received") // Exclude message notifications
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            let notifications = try decoder.decode([NotificationItem].self, from: response.data)
            print("Successfully fetched \(notifications.count) notifications (excluding messages)")
            return notifications
        } catch {
            print("Error fetching notifications: \(error)")
            throw error
        }
    }
    
    func markNotificationAsRead(notificationId: String) async throws {
        do {
            let _ = try await supabase.auth.user()
            print("Marking notification as read: \(notificationId)")
            
            let updateData = AnyEncodable(["read": true])
            
            try await supabase
                .from("notifications")
                .update(updateData)
                .eq("id", value: notificationId)
                .execute()
            
            print("✅ Successfully marked notification as read")
            
        } catch {
            print("❌ Error marking notification as read: \(error)")
            throw error
        }
    }
    
    func createNotification(type: String, jobId: String, fromUserId: String, toUserId: String, message: String, offerData: OfferData? = nil) async throws {
        do {
            print("🔔 Creating notification:")
            print("   Type: \(type)")
            print("   Job ID: \(jobId)")
            print("   From User: \(fromUserId)")
            print("   To User: \(toUserId)")
            print("   Message: \(message)")
            
            // Validate UUIDs before sending
            let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
            let uuidRegex = try NSRegularExpression(pattern: uuidPattern)
            
            func isValidUUID(_ uuid: String) -> Bool {
                return uuidRegex.firstMatch(in: uuid, range: NSRange(location: 0, length: uuid.count)) != nil
            }
            
            guard isValidUUID(jobId) else {
                throw NetworkingError.invalidData("Invalid job_id UUID format: \(jobId)")
            }
            guard isValidUUID(fromUserId) else {
                throw NetworkingError.invalidData("Invalid from_user_id UUID format: \(fromUserId)")
            }
            guard isValidUUID(toUserId) else {
                throw NetworkingError.invalidData("Invalid to_user_id UUID format: \(toUserId)")
            }
            
            // Create notification data matching your database schema and RLS policies
            // Using both new schema (from_user_id, to_user_id) and legacy fields for compatibility
            let notificationData = AnyEncodable([
                "type": type,
                "title": type,
                "message": message,
                "job_id": jobId,
                "related_job_id": jobId, // For legacy compatibility
                "from_user_id": fromUserId, // This satisfies RLS policy: auth.uid() = from_user_id
                "to_user_id": toUserId,
                "user_id": toUserId, // Legacy field - recipient of notification
                "status": "pending",
                "read": false,
                "notification_state": "unread", // drives the bell/Business unread badge
                // Explicitly set unused UUID fields to null
                "related_proposal_id": NSNull(),
                "deal_offer_id": NSNull(),
                "completion_request_id": NSNull()
            ])
            
            try await supabase
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            print("✅ Successfully created notification in database")
            
            // Send push notification to the target user
            await sendPushNotification(
                toUserId: toUserId,
                title: getNotificationTitle(type: type),
                body: message,
                notificationType: type,
                data: [
                    "job_id": jobId,
                    "from_user_id": fromUserId,
                    "notification_type": type
                ]
            )
            
        } catch {
            print("❌ Error creating notification: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchPendingNotificationCount() async throws -> Int {
        do {
            let user = try await supabase.auth.user()
            
            let response = try await supabase
                .from("notifications")
                .select("count")
                .or("user_id.eq.\(user.id.uuidString),to_user_id.eq.\(user.id.uuidString)")
                .eq("read", value: false)
                .eq("status", value: "pending")
                .neq("type", value: "message_received")
                .execute()
            
            // Parse the count from response
            if let data = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
               let firstItem = data.first,
               let count = firstItem["count"] as? Int {
                return count
            }
            
            return 0
        } catch {
            print("Error fetching notification count: \(error)")
            return 0
        }
    }
    
    func clearNotification(notificationId: String) async throws {
        do {
            let user = try await supabase.auth.user()
            print("🗑️ Clearing individual notification: \(notificationId)")
            
            try await supabase
                .from("notifications")
                .delete()
                .eq("id", value: notificationId)
                .or("user_id.eq.\(user.id.uuidString),to_user_id.eq.\(user.id.uuidString)")
                .execute()
            
            print("✅ Successfully cleared notification: \(notificationId)")
            
        } catch {
            print("❌ Error clearing notification: \(error)")
            throw error
        }
    }
    
    func clearAllNotifications() async throws {
        do {
            let user = try await supabase.auth.user()
            print("🗑️ Clearing all notifications for user: \(user.id.uuidString)")
            
            try await supabase
                .from("notifications")
                .delete()
                .or("user_id.eq.\(user.id.uuidString),to_user_id.eq.\(user.id.uuidString)")
                .execute()
            
            print("✅ Successfully cleared all notifications")
            
        } catch {
            print("❌ Error clearing all notifications: \(error)")
            throw error
        }
    }
    
    func fetchInterestNotifications(forceRefresh: Bool = false) async throws -> [Notification] {
        // Cache has been removed - always fetch fresh data
        
        do {
            let user = try await supabase.auth.user()
            print("🌐 Fetching interest notifications from network...")
            print("🔍 User ID: \(user.id.uuidString)")
            
            let response = try await supabase
                .from("notifications")
                .select("*, jobs(*), from_user:profiles!notifications_from_user_id_fkey(*)")
                .or("user_id.eq.\(user.id.uuidString),to_user_id.eq.\(user.id.uuidString)")
                .eq("type", value: "show_interest")
                .order("created_at", ascending: false)
                .execute()
            
            print("🔍 Raw response data size: \(response.data.count) bytes")
            
            let decoder = JSONDecoder()
            let notifications = try decoder.decode([Notification].self, from: response.data)
            print("✅ Successfully fetched \(notifications.count) interest notifications")
            
            // Debug: print first notification if exists
            if let firstNotification = notifications.first {
                print("🔍 First notification: Type=\(firstNotification.type), Status=\(firstNotification.status), JobID=\(firstNotification.job_id)")
            }
            
            // Cache has been removed
            
            return notifications
        } catch {
            print("❌ Error fetching interest notifications: \(error)")
            throw error
        }
    }
    
    // MARK: - Interest Management
    func getInterestStatus(jobId: String) async throws -> String? {
        do {
            let user = try await supabase.auth.user()
            
            let response = try await supabase
                .from("job_interests")
                .select("status")
                .eq("job_id", value: jobId)
                .eq("provider_id", value: user.id.uuidString)
                .single()
                .execute()
            
            // Parse the status from the response directly since JobInterest struct doesn't have status
            if let data = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
               let status = data["status"] as? String {
                return status
            }
            return nil
        } catch {
            return nil
        }
    }
    
    func hasShownInterest(jobId: String) async throws -> Bool {
        do {
            // Use the detailed cooldown info to determine if interest can be shown
            let cooldownInfo = try await getInterestCooldownInfo(jobId: jobId)
            return !cooldownInfo.canShowInterest
        } catch {
            print("Error checking interest status: \(error)")
            return false
        }
    }
    
    func getInterestCooldownInfo(jobId: String) async throws -> (canShowInterest: Bool, remainingCooldown: TimeInterval?, interestCount: Int, lastStatus: String?) {
        do {
            let user = try await supabase.auth.user()
            print("🔍 getInterestCooldownInfo - JobId: \(jobId), UserId: \(user.id.uuidString)")
            
            // Count attempts from notifications table (actual attempts)
            let notificationsResponse = try await supabase
                .from("notifications")
                .select("id, status, created_at")
                .eq("job_id", value: jobId)
                .eq("from_user_id", value: user.id.uuidString)
                .eq("type", value: "show_interest")
                .order("created_at", ascending: false)
                .execute()
            
            let notificationsCount: Int
            if let notificationsData = try? JSONSerialization.jsonObject(with: notificationsResponse.data) as? [[String: Any]] {
                print("🔍 Found \(notificationsData.count) notifications: \(notificationsData)")
                notificationsCount = notificationsData.count
            } else {
                print("🔍 No notifications data found")
                notificationsCount = 0
            }
            
            // Get current status from job_interests table
            let response = try await supabase
                .from("job_interests")
                .select("id, status, created_at")
                .eq("job_id", value: jobId)
                .eq("provider_id", value: user.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
            
            if let data = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                let interestCount = notificationsCount // Use notifications count, not job_interests count
                
                // No interests - can show interest
                if interestCount == 0 {
                    return (canShowInterest: true, remainingCooldown: nil, interestCount: 0, lastStatus: nil)
                }
                
                // Maximum interests reached
                if interestCount >= 2 {
                    return (canShowInterest: false, remainingCooldown: nil, interestCount: interestCount, lastStatus: data.first?["status"] as? String)
                }
                
                // Exactly 1 interest - check status and cooldown
                if let firstInterest = data.first {
                    let status = firstInterest["status"] as? String ?? "pending"
                    
                    // If pending or accepted, cannot show more interest
                    if status == "pending" || status == "accepted" {
                        return (canShowInterest: false, remainingCooldown: nil, interestCount: interestCount, lastStatus: status)
                    }
                    
                    // If rejected, check cooldown period by looking up the notification actioned_at time
                    if status == "rejected" {
                        // Get the rejection time from the notifications table
                        let rejectionTime = try? await getRejectionTime(jobId: jobId, providerId: user.id.uuidString)
                        
                        if let rejectionTime = rejectionTime {
                            let cooldownPeriod: TimeInterval = 5 * 60 // 5 minutes
                            let cooldownEndTime = rejectionTime.addingTimeInterval(cooldownPeriod)
                            let now = Date()
                            
                            print("🕒 Rejection time: \(rejectionTime), Cooldown end: \(cooldownEndTime), Now: \(now)")
                            
                            if now < cooldownEndTime {
                                let remainingCooldown = cooldownEndTime.timeIntervalSince(now)
                                print("🚫 Still in cooldown: \(remainingCooldown)s remaining")
                                return (canShowInterest: false, remainingCooldown: remainingCooldown, interestCount: interestCount, lastStatus: status)
                            } else {
                                // Cooldown ended
                                print("✅ Cooldown ended - can show interest again")
                                return (canShowInterest: true, remainingCooldown: nil, interestCount: interestCount, lastStatus: status)
                            }
                        } else {
                            // If we can't get the rejection time, assume cooldown ended and allow second attempt
                            print("⚠️ Could not get rejection time, allowing second attempt")
                            return (canShowInterest: true, remainingCooldown: nil, interestCount: interestCount, lastStatus: status)
                        }
                    }
                    
                    // For any other status, check if it's something we don't handle
                    print("🔍 Unhandled status: \(status)")
                    return (canShowInterest: false, remainingCooldown: nil, interestCount: interestCount, lastStatus: status)
                }
            }
            
            return (canShowInterest: true, remainingCooldown: nil, interestCount: 0, lastStatus: nil)
        } catch {
            print("Error getting interest cooldown info: \(error)")
            return (canShowInterest: false, remainingCooldown: nil, interestCount: 0, lastStatus: nil)
        }
    }
    
    /// Handle interactive notification actions (Accept/Reject interest)
    func handleNotificationAction(_ notificationId: String, action: String, actionData: ActionData) async throws {
        do {
            print("🎯 Handling notification action: \(action)")
            
            switch action {
            case "accept":
                if let interestId = actionData.interest_id {
                    // Accept the interest and create conversation
                    try await acceptJobInterest(interestId: interestId)
                }
            case "reject":
                if let interestId = actionData.interest_id {
                    // Reject the interest
                    try await rejectJobInterest(interestId: interestId)
                }
            default:
                print("⚠️ Unknown notification action: \(action)")
            }
            
            // Mark notification as read after action
            try await updateNotificationState(notificationId, to: .read)
            
            print("✅ Successfully handled notification action")
        } catch {
            print("❌ Error handling notification action: \(error)")
            throw error
        }
    }
    
    /// Accept job interest and create conversation
    private func acceptJobInterest(interestId: String) async throws {
        let updateData = AnyEncodable([
            "status": "accepted",
            "actioned_at": ISO8601DateFormatter().string(from: Date())
        ])
        
        try await supabase
            .from("job_interests")
            .update(updateData)
            .eq("id", value: interestId)
            .execute()
        
        print("✅ Job interest accepted and conversation will be created by trigger")
    }
    
    /// Reject job interest
    private func rejectJobInterest(interestId: String) async throws {
        let updateData = AnyEncodable([
            "status": "rejected",
            "actioned_at": ISO8601DateFormatter().string(from: Date())
        ])
        
        try await supabase
            .from("job_interests")
            .update(updateData)
            .eq("id", value: interestId)
            .execute()
        
        print("✅ Job interest rejected")
    }

    func showInterest(jobId: String) async throws {
        try await showInterestWithMessage(jobId: jobId, message: "I'm interested in this job!")
    }
    
    func showInterestWithMessage(jobId: String, message: String) async throws {
        let user = try await supabase.auth.user()
        print("🔔 Showing interest in job \(jobId) with message: \(message)")
        print("🔍 Current auth user ID: \(user.id.uuidString)")
        
        // Use only database validation - no client-side validation
        print("🆕 Creating interest attempt via database function with validation")
        try await createInterestAttempt(jobId: jobId, message: message)
    }
    
    func createInterestAttempt(jobId: String, message: String) async throws {
        let user = try await supabase.auth.user()
        
        // First check the simple interest status
        let interestStatus = try await getSimpleInterestStatus(
            jobId: jobId, 
            providerId: user.id.uuidString
        )
        
        // Check if interest is allowed
        guard interestStatus.canShowInterest else {
            throw NetworkingError.validationError(interestStatus.message)
        }
        
        print("✅ Simple validation passed, creating/updating interest")
        
        // Get job details to find the client
        let jobResponse = try await supabase
            .from("jobs")
            .select("client_id, title")
            .eq("id", value: jobId)
            .single()
            .execute()
        
        guard let jobData = try? JSONSerialization.jsonObject(with: jobResponse.data) as? [String: Any],
              let clientId = jobData["client_id"] as? String,
              let jobTitle = jobData["title"] as? String else {
            throw NetworkingError.invalidData("Could not find job details")
        }
        
        // Prevent users from showing interest in their own jobs
        if user.id.uuidString == clientId {
            throw NetworkingError.validationError("You cannot show interest in your own job posting")
        }
        
        var interestId: String
        
        // If record exists, update it; otherwise create new one
        if interestStatus.recordExists {
            print("📝 Updating existing interest record to pending")
            // Update existing record status to pending and clear actioned_at
            let updateResult = try await supabase
                .from("job_interests")
                .update([
                    "status": AnyEncodable("pending"),
                    "message": AnyEncodable(message),
                    "actioned_at": AnyEncodable(NSNull()) // Clear actioned_at for new attempt
                ])
                .eq("job_id", value: jobId)
                .eq("provider_id", value: user.id.uuidString)
                .select()
                .execute()
            
            guard let updateResponseData = try? JSONSerialization.jsonObject(with: updateResult.data) as? [[String: Any]],
                  let interest = updateResponseData.first,
                  let id = interest["id"] as? String else {
                throw NetworkingError.invalidData("Could not update interest record")
            }
            interestId = id
        } else {
            print("📝 Creating new interest record")
            // Create new job_interests entry
            let insertResult = try await supabase
                .from("job_interests")
                .insert([
                    "job_id": AnyEncodable(jobId),
                    "provider_id": AnyEncodable(user.id.uuidString),
                    "status": AnyEncodable("pending"),
                    "message": AnyEncodable(message)
                ])
                .select()
                .execute()
            
            guard let insertResponseData = try? JSONSerialization.jsonObject(with: insertResult.data) as? [[String: Any]],
                  let interest = insertResponseData.first,
                  let id = interest["id"] as? String else {
                throw NetworkingError.invalidData("Could not create interest record")
            }
            interestId = id
        }
        
        // Create notification for the client (non-blocking)
        do {
            try await createNotification(
                type: "show_interest",
                jobId: jobId,
                fromUserId: user.id.uuidString,
                toUserId: clientId,
                message: "Someone showed interest in your job: \(jobTitle)"
            )
            print("🔔 Notification created for client: \(clientId)")
        } catch {
            print("⚠️ Failed to create notification, but interest was recorded successfully: \(error)")
        }
        
        print("✅ Successfully showed interest in job: \(jobId)")
        print("📝 Interest ID: \(interestId)")
    }
    
    private func createSubsequentInterestAttempt(jobId: String, message: String, userId: String, attemptNumber: Int) async throws {
        print("🔄 Creating subsequent interest attempt #\(attemptNumber)")
        
        // Get job details to find the client
        let jobResponse = try await supabase
            .from("jobs")
            .select("client_id")
            .eq("id", value: jobId)
            .single()
            .execute()
        
        guard let jobData = try? JSONSerialization.jsonObject(with: jobResponse.data) as? [String: Any],
              let clientId = jobData["client_id"] as? String else {
            throw NetworkingError.invalidData("Could not find job client")
        }
        
        // Update the existing rejected interest record to pending status (for subsequent attempt)
        let interestResult = try await supabase
            .from("job_interests")
            .update([
                "status": AnyEncodable("pending"),
                "message": AnyEncodable(message)
            ])
            .eq("job_id", value: jobId)
            .eq("provider_id", value: userId)
            .select()
            .execute()
        
        guard let interestResponseData = try? JSONSerialization.jsonObject(with: interestResult.data) as? [[String: Any]],
              let interest = interestResponseData.first,
              let interestId = interest["id"] as? String else {
            throw NetworkingError.invalidData("Failed to update interest record for attempt #\(attemptNumber)")
        }
        
        print("✅ Updated existing interest to pending for attempt #\(attemptNumber) with ID: \(interestId)")
        
        // Create notification for the client with attempt tracking (non-blocking)
        do {
            try await createNotification(
                type: "show_interest",
                jobId: jobId,
                fromUserId: userId,
                toUserId: clientId,
                message: "\(message) (Attempt #\(attemptNumber))"
            )
            print("🔔 Notification created for attempt #\(attemptNumber)")
        } catch {
            print("⚠️ Failed to create notification for attempt #\(attemptNumber), but interest was recorded successfully: \(error)")
        }
        
        print("✅ Successfully showed interest attempt #\(attemptNumber) in job: \(jobId)")
    }
    
    /// Records a rejection using the new cooldown manager system
    func recordInterestRejection(jobId: String, providerId: String, clientId: String) async throws {
        do {
            print("📝 Recording interest rejection via InterestCooldownManager")
            try await InterestCooldownManager.recordRejection(
                jobId: jobId, 
                providerId: providerId, 
                clientId: clientId
            )
            print("✅ Interest rejection recorded successfully")
        } catch {
            print("❌ Failed to record interest rejection: \(error)")
            throw error
        }
    }
    
    /// Gets the simple interest status for a provider and job  
    func getSimpleInterestStatus(jobId: String, providerId: String) async throws -> SimpleInterestStatus {
        print("🔍 Getting simple interest status - JobId: \(jobId), ProviderId: \(providerId)")
        
        // Validate inputs
        guard !jobId.isEmpty && !providerId.isEmpty else {
            throw NetworkingError.invalidData("Job ID and Provider ID cannot be empty")
        }
        
        // Use our simple database function with proper UUID casting
        let response = try await supabase
            .rpc("get_interest_status", params: [
                "p_job_id": AnyEncodable(jobId),
                "p_provider_id": AnyEncodable(providerId)
            ])
            .execute()
        
        guard let responseData = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            print("❌ Could not parse interest status response")
            throw NetworkingError.invalidData("Could not parse interest status response")
        }
        
        print("📊 Simple interest status response: \(responseData)")
        return try parseSimpleInterestStatus(responseData)
    }
    
    /// Legacy method for backward compatibility - delegates to simple version
    func getInterestCooldownStatus(jobId: String, providerId: String) async throws -> InterestCooldownManager.CooldownStatus {
        let simpleStatus = try await getSimpleInterestStatus(jobId: jobId, providerId: providerId)
        
        // Convert to legacy format for backward compatibility
        return InterestCooldownManager.CooldownStatus(
            canShowInterest: simpleStatus.canShowInterest,
            attemptCount: simpleStatus.recordExists ? 1 : 0,
            remainingCooldown: simpleStatus.remainingCooldown,
            isPermanentlyBlocked: false, // No permanent blocking in simple system
            lastRejectionTime: nil,
            nextAttemptTime: nil,
            isRateLimited: !simpleStatus.canShowInterest && simpleStatus.status != "none",
            rateLimitRemaining: simpleStatus.remainingCooldown
        )
    }
    
    private func parseValidationResponse(_ response: [String: Any]) throws -> InterestCooldownManager.CooldownStatus {
        let isAllowed = response["allowed"] as? Bool ?? false
        let reason = response["reason"] as? String ?? "unknown"
        let message = response["message"] as? String ?? "Unknown status"
        let attemptCount = response["attempt_count"] as? Int ?? 0
        let _ = response["permanent_block"] as? Bool ?? false
        
        // Handle database errors
        if reason == "database_error" {
            let errorDetail = response["error_detail"] as? String ?? "Unknown database error"
            print("❌ Database validation error: \(errorDetail)")
            throw NetworkingError.validationError(message)
        }
        
        if !isAllowed {
            switch reason {
            case "max_attempts_reached":
                return InterestCooldownManager.CooldownStatus(
                    canShowInterest: false,
                    attemptCount: attemptCount,
                    remainingCooldown: nil,
                    isPermanentlyBlocked: true,
                    lastRejectionTime: nil,
                    nextAttemptTime: nil,
                    isRateLimited: false,
                    rateLimitRemaining: nil
                )
            case "existing_interest":
                return InterestCooldownManager.CooldownStatus(
                    canShowInterest: false,
                    attemptCount: max(1, attemptCount),
                    remainingCooldown: nil,
                    isPermanentlyBlocked: false,
                    lastRejectionTime: nil,
                    nextAttemptTime: nil,
                    isRateLimited: true,
                    rateLimitRemaining: nil
                )
            case "cooldown_active":
                let remainingSeconds = response["remaining_seconds"] as? TimeInterval ?? 0
                let nextAttemptTimeString = response["next_attempt_time"] as? String
                let nextAttemptTime = nextAttemptTimeString != nil ? parseTimestamp(nextAttemptTimeString!) : nil
                
                return InterestCooldownManager.CooldownStatus(
                    canShowInterest: false,
                    attemptCount: attemptCount,
                    remainingCooldown: remainingSeconds,
                    isPermanentlyBlocked: false,
                    lastRejectionTime: nil,
                    nextAttemptTime: nextAttemptTime,
                    isRateLimited: false,
                    rateLimitRemaining: nil
                )
            case "rate_limited":
                let remainingSeconds = response["remaining_seconds"] as? TimeInterval ?? 0
                return InterestCooldownManager.CooldownStatus(
                    canShowInterest: false,
                    attemptCount: attemptCount,
                    remainingCooldown: nil,
                    isPermanentlyBlocked: false,
                    lastRejectionTime: nil,
                    nextAttemptTime: nil,
                    isRateLimited: true,
                    rateLimitRemaining: remainingSeconds
                )
            default:
                return InterestCooldownManager.CooldownStatus(
                    canShowInterest: false,
                    attemptCount: attemptCount,
                    remainingCooldown: nil,
                    isPermanentlyBlocked: false,
                    lastRejectionTime: nil,
                    nextAttemptTime: nil,
                    isRateLimited: true,
                    rateLimitRemaining: nil
                )
            }
        } else {
            // Allowed
            let _ = response["is_second_chance"] as? Bool ?? false
            return InterestCooldownManager.CooldownStatus(
                canShowInterest: true,
                attemptCount: attemptCount,
                remainingCooldown: nil,
                isPermanentlyBlocked: false,
                lastRejectionTime: nil,
                nextAttemptTime: nil,
                isRateLimited: false,
                rateLimitRemaining: nil
            )
        }
    }
    
    private func parseSimpleInterestStatus(_ response: [String: Any]) throws -> SimpleInterestStatus {
        let canShowInterest = response["can_show_interest"] as? Bool ?? false
        let status = response["status"] as? String ?? "unknown"
        let message = response["message"] as? String ?? "Unknown status"
        let remainingCooldown = response["remaining_cooldown"] as? TimeInterval
        let recordExists = response["record_exists"] as? Bool ?? false
        
        return SimpleInterestStatus(
            canShowInterest: canShowInterest,
            status: status,
            message: message,
            remainingCooldown: remainingCooldown,
            recordExists: recordExists
        )
    }
    
    private func parseTimestamp(_ timestamp: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: timestamp)
        }()
    }
    
    private func checkExistingInterest(jobId: String, userId: String) async throws -> Bool {
        print("🔍 checkExistingInterest - JobId: \(jobId), UserId: \(userId)")
        
        // Check if there are any previous interest attempts using notifications table (consistent with counting logic)
        let response = try await supabase
            .from("notifications")
            .select("id")
            .eq("job_id", value: jobId)
            .eq("from_user_id", value: userId)
            .eq("type", value: "show_interest")
            .execute()
        
        if let data = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
            let hasExisting = !data.isEmpty
            print("🔍 Existing interest check: \(hasExisting ? "Found \(data.count) previous attempt(s)" : "No previous attempts")")
            print("🔍 Raw query result: \(data)")
            return hasExisting
        }
        
        return false
    }
    
    private func getRejectionTime(jobId: String, providerId: String) async throws -> Date? {
        // Look up the most recent rejected notification for this job and provider
        let response = try await supabase
            .from("notifications")
            .select("actioned_at")
            .eq("job_id", value: jobId)
            .eq("from_user_id", value: providerId)
            .eq("type", value: "show_interest")
            .eq("status", value: "rejected")
            .order("actioned_at", ascending: false)
            .limit(1)
            .execute()
        
        if let data = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
           let firstNotification = data.first,
           let actionedAtString = firstNotification["actioned_at"] as? String {
            
            print("🔍 Found rejection time: \(actionedAtString)")
            return ISO8601DateFormatter().date(from: actionedAtString)
        }
        
        print("⚠️ No rejection time found for job: \(jobId), provider: \(providerId)")
        return nil
    }
    
    func respondToInterest(notificationId: String, accept: Bool) async throws {
        do {
            let user = try await supabase.auth.user()
            
            // Get notification details
            let notificationResponse = try await supabase
                .from("notifications")
                .select("*")
                .eq("id", value: notificationId)
                .single()
                .execute()
            
            let notification = try JSONDecoder().decode(Notification.self, from: notificationResponse.data)
            
            // Debug the notification details
            print("🔍 Responding to notification:")
            print("   Notification ID: \(notification.id)")
            print("   Current User ID: \(user.id.uuidString)")
            print("   Notification to_user_id: \(notification.to_user_id)")
            print("   Notification from_user_id: \(notification.from_user_id ?? "nil")")
            print("   Notification job_id: \(notification.job_id)")
            print("   Notification type: \(notification.type)")
            
            // Verify user is the recipient (case-insensitive UUID comparison)
            guard notification.to_user_id.lowercased() == user.id.uuidString.lowercased() else {
                print("❌ Authorization failed - user ID mismatch!")
                throw NetworkingError.unauthorized("You can only respond to your own notifications")
            }
            
            print("✅ Authorization successful - user can respond to this notification")
            
            // Update notification status
            let notificationStatus = accept ? "accepted" : "rejected"
            try await supabase
                .from("notifications")
                .update(["status": notificationStatus, "actioned_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: notificationId)
                .execute()
            
            // Get the provider ID from the notification (the person who showed interest)
            let providerId = notification.from_user_id ?? ""
            
            // Update job interest status
            try await supabase
                .from("job_interests")
                .update(["status": notificationStatus])
                .eq("job_id", value: notification.job_id)
                .eq("provider_id", value: providerId)
                .execute()
            
            if accept {
                print("🔄 Starting conversation creation process")
                print("📝 Job ID: \(notification.job_id)")
                print("📝 Client ID: \(user.id.uuidString)")
                print("📝 Provider ID: \(providerId)")
                
                // Validate required IDs before proceeding
                guard !notification.job_id.isEmpty,
                      !user.id.uuidString.isEmpty,
                      !providerId.isEmpty else {
                    print("❌ Missing required IDs for conversation creation")
                    throw NetworkingError.invalidData("Missing required IDs for conversation creation")
                }
                
                // Check if conversation already exists
                print("🔍 Checking for existing conversation...")
                let existingConversationResponse = try await supabase
                    .from("conversations")
                    .select("id")
                    .eq("job_id", value: notification.job_id)
                    .eq("client_id", value: user.id.uuidString)
                    .eq("provider_id", value: providerId)
                    .execute()
                
                print("📊 Existing conversation check response: \(existingConversationResponse.data.count) bytes")
                
                // Only create conversation if it doesn't exist
                if let data = try? JSONSerialization.jsonObject(with: existingConversationResponse.data) as? [[String: Any]] {
                    print("📊 Found \(data.count) existing conversations")
                    
                    if data.isEmpty {
                        print("🆕 Creating new conversation...")
                        
                        let conversationData: [String: Any] = [
                            "job_id": notification.job_id,
                            "client_id": user.id.uuidString,  // Client (job owner) who accepted
                            "provider_id": providerId,        // Provider who showed interest
                            "status": "active"
                        ]
                        
                        print("📝 Conversation data prepared: \(conversationData)")
                        
                        do {
                            let insertResponse = try await supabase
                                .from("conversations")
                                .insert(AnyEncodable(conversationData))
                                .execute()
                            
                            print("✅ Successfully created new conversation!")
                            print("📊 Insert response: \(insertResponse.data.count) bytes")
                        } catch {
                            print("❌ Failed to create conversation: \(error)")
                            print("❌ Error details: \(error.localizedDescription)")
                            // Don't throw - log the error but continue with the process
                        }
                    } else {
                        print("ℹ️ Conversation already exists between client and provider")
                    }
                } else {
                    print("❌ Failed to parse existing conversation response")
                }
                
                // Create notification for provider (non-blocking)
                print("🔔 Creating acceptance notification for provider...")
                do {
                    try await createNotification(
                        type: "interest_accepted",
                        jobId: notification.job_id,
                        fromUserId: user.id.uuidString,
                        toUserId: providerId,
                        message: "Your interest has been accepted! You can now chat with the client."
                    )
                    print("✅ Acceptance notification created successfully")
                } catch {
                    print("⚠️ Failed to create acceptance notification: \(error)")
                    // Don't throw - notification failure shouldn't prevent interest acceptance
                }
            } else {
                // Create notification for provider (non-blocking)
                print("🔔 Creating rejection notification for provider...")
                do {
                    try await createNotification(
                        type: "interest_rejected",
                        jobId: notification.job_id,
                        fromUserId: user.id.uuidString,
                        toUserId: providerId,
                        message: "Thank you for your interest. The client has chosen to proceed with other providers."
                    )
                    print("✅ Rejection notification created successfully")
                } catch {
                    print("⚠️ Failed to create rejection notification: \(error)")
                    // Don't throw - notification failure shouldn't prevent interest rejection
                }
            }
            
            print("✅ Successfully responded to interest: \(accept ? "accepted" : "rejected")")
            
        } catch {
            print("❌ Error responding to interest: \(error)")
            throw error
        }
    }
    
    // MARK: - Push Notification Helper Methods
    
    private func sendPushNotification(
        toUserId: String,
        title: String,
        body: String,
        notificationType: String,
        data: [String: Any] = [:]
    ) async {
        do {
            let pushPayload: [String: Any] = [
                "user_id": toUserId,
                "title": title,
                "body": body,
                "notification_type": notificationType,
                "data": data
            ]
            
            try await supabase.functions.invoke(
                "send-push-notification",
                options: FunctionInvokeOptions(
                    body: AnyEncodable(pushPayload)
                )
            )
            
            print("📱 Push notification request sent successfully to user: \(toUserId)")
            
        } catch {
            print("❌ Error sending push notification: \(error)")
            // Don't throw error - push notification failure shouldn't break the main flow
        }
    }
    
    private func getNotificationTitle(type: String) -> String {
        switch type {
        case "show_interest":
            return "New Interest Received!"
        case "interest_accepted":
            return "Interest Accepted!"
        case "interest_rejected":
            return "Interest Update"
        case "new_message":
            return "New Message"
        case "offer_received":
            return "New Offer Received!"
        case "offer_accepted":
            return "Offer Accepted!"
        case "offer_rejected":
            return "Offer Update"
        case "deal_completed":
            return "Deal Completed!"
        case "message_received":
            return "New Message"
        case "deal_offer_received":
            return "Deal Offer Received!"
        default:
            return "New Notification"
        }
    }
    
    // MARK: - Real-time Job Interest Notifications
    
    /// Fetch enriched job interests for real-time notifications
    func fetchEnrichedJobInterests() async throws -> [EnrichedJobInterest] {
        let user = try await supabase.auth.user()
        
        print("🔍 Fetching enriched job interests for user: \(user.id.uuidString)")
        
        // Get all pending job_interests first
        let response = try await supabase
            .from("job_interests")
            .select("*")
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
        
        guard let interestsData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
            throw NetworkingError.invalidData("Could not parse job interests response")
        }
        
        print("🔍 Found \(interestsData.count) pending job interests")
        
        var enrichedInterests: [EnrichedJobInterest] = []
        
        // Process each interest and fetch related data
        for interestData in interestsData {
            guard let id = interestData["id"] as? String,
                  let jobId = interestData["job_id"] as? String,
                  let providerId = interestData["provider_id"] as? String,
                  let status = interestData["status"] as? String,
                  let createdAt = interestData["created_at"] as? String else {
                continue
            }
            
            let message = interestData["message"] as? String
            let actionedAt = interestData["actioned_at"] as? String
            
            do {
                // Get job details and verify it belongs to current user
                let jobResponse = try await supabase
                    .from("jobs")
                    .select("id, title, client_id, budget, location")
                    .eq("id", value: jobId)
                    .eq("client_id", value: user.id.uuidString)
                    .limit(1)
                    .execute()
                
                guard let jobsArray = try? JSONSerialization.jsonObject(with: jobResponse.data) as? [[String: Any]],
                      let jobData = jobsArray.first,
                      let jobTitle = jobData["title"] as? String,
                      let jobClientId = jobData["client_id"] as? String else {
                    // Skip interests not for current user's jobs
                    continue
                }
                
                let jobBudget = jobData["budget"] as? Int
                let jobLocation = jobData["location"] as? String
                
                // Get provider details
                let profileResponse = try await supabase
                    .from("profiles")
                    .select("id, full_name, avatar_url")
                    .eq("id", value: providerId)
                    .limit(1)
                    .execute()
                
                var providerName: String?
                var providerAvatarUrl: String?
                
                if let profilesArray = try? JSONSerialization.jsonObject(with: profileResponse.data) as? [[String: Any]],
                   let profileData = profilesArray.first {
                    providerName = profileData["full_name"] as? String
                    providerAvatarUrl = profileData["avatar_url"] as? String
                }
                
                let enrichedInterest = EnrichedJobInterest(
                    id: id,
                    job_id: jobId,
                    provider_id: providerId,
                    status: status,
                    message: message,
                    created_at: createdAt,
                    actioned_at: actionedAt,
                    job_title: jobTitle,
                    job_client_id: jobClientId,
                    job_budget: jobBudget,
                    job_location: jobLocation,
                    provider_name: providerName,
                    provider_avatar_url: providerAvatarUrl,
                    provider_rating: nil // No rating field in profiles table
                )
                
                enrichedInterests.append(enrichedInterest)
            } catch {
                print("❌ Failed to fetch data for interest \(id): \(error)")
                continue
            }
        }
        
        print("✅ Fetched \(enrichedInterests.count) enriched job interests")
        return enrichedInterests
    }
    
    /// Subscribe to real-time job interest changes
    func subscribeToJobInterests(onNewInterest: @escaping (EnrichedJobInterest) -> Void) async throws -> RealtimeChannelV2 {
        let user = try await supabase.auth.user()
        
        print("🔄 Setting up real-time subscription for notifications")
        
        let channel = supabase.realtimeV2.channel("notifications_realtime")
        
        // Subscribe to INSERT events on notifications table for interest notifications
        let insertions = channel.postgresChange(
            InsertAction.self,
            table: "notifications",
            filter: "to_user_id=eq.\(user.id.uuidString)"
        )
        
        // Start the channel
        await channel.subscribe()
        
        // Handle incoming notification insertions
        Task {
            for await insertion in insertions {
                print("🔔 Received real-time notification!")
                await handleNotificationInsertion(insertion, currentUserId: user.id.uuidString, onNewInterest: onNewInterest)
            }
        }
        
        return channel
    }
    
    private func handleNotificationInsertion(_ action: HasRecord, currentUserId: String, onNewInterest: @escaping (EnrichedJobInterest) -> Void) async {
        do {
            print("🔍 Processing notification for user: \(currentUserId)")
            
            // Decode the notification data
            let decoder = JSONDecoder()
            let notification = try action.decodeRecord(decoder: decoder) as Notification
            print("📝 Decoded notification: Type=\(notification.type), Job=\(notification.job_id)")
            
            // Only process show_interest type notifications
            guard notification.type == "show_interest" else {
                print("📝 Notification type is '\(notification.type)', not 'show_interest', ignoring")
                return
            }
            
            // Make sure we have from_user_id (job_id is not optional)
            guard let fromUserId = notification.from_user_id else {
                print("📝 Notification missing from_user_id, ignoring")
                return
            }
            
            let jobId = notification.job_id
            
            // Get job information
            let jobResponse = try await supabase
                .from("jobs")
                .select("id, title, client_id, budget, location")
                .eq("id", value: jobId)
                .single()
                .execute()
            
            guard let jobData = try? JSONSerialization.jsonObject(with: jobResponse.data) as? [String: Any],
                  let jobTitle = jobData["title"] as? String,
                  let jobClientId = jobData["client_id"] as? String else {
                print("📝 Could not fetch job information, ignoring")
                return
            }
            
            // Get provider information
            let profileResponse = try await supabase
                .from("profiles")
                .select("id, full_name, avatar_url")
                .eq("id", value: fromUserId)
                .limit(1)
                .execute()
            
            var providerName: String?
            var providerAvatarUrl: String?
            
            if let profilesArray = try? JSONSerialization.jsonObject(with: profileResponse.data) as? [[String: Any]],
               let profileData = profilesArray.first {
                providerName = profileData["full_name"] as? String
                providerAvatarUrl = profileData["avatar_url"] as? String
            }
            
            // Create enriched interest from notification
            let enrichedInterest = EnrichedJobInterest(
                id: notification.id,
                job_id: jobId,
                provider_id: fromUserId,
                status: "pending", // New interest notifications are always pending
                message: notification.message,
                created_at: notification.created_at,
                actioned_at: notification.actioned_at,
                job_title: jobTitle,
                job_client_id: jobClientId,
                job_budget: jobData["budget"] as? Int,
                job_location: jobData["location"] as? String,
                provider_name: providerName,
                provider_avatar_url: providerAvatarUrl,
                provider_rating: nil // No rating field in profiles table
            )
            
            print("🔔 New interest notification received for job: \(jobTitle)")
            
            // Notify the UI on main actor
            await MainActor.run {
                onNewInterest(enrichedInterest)
            }
            
        } catch {
            print("❌ Failed to handle notification: \(error)")
        }
    }

    // MARK: - Business Notifications for Combined Notifications View

    /// Fetch business notifications from the notifications table
    nonisolated func fetchBusinessNotifications(limit: Int = 100) async throws -> [BusinessNotification] {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    let user = try await supabase.auth.user()
                    print("🔍 Fetching business notifications for user: \(user.id.uuidString)")

                    let response = try await supabase
                        .from("notifications")
                        .select("*")
                        .or("user_id.eq.\(user.id.uuidString),to_user_id.eq.\(user.id.uuidString)")
                        // Interest requests live on the Interests tab (job_interests); chat
                        // lives in Messages. Keep them out of the feed. deal_offer_received /
                        // deal_offer_responded are superseded by the rich "deal_created"
                        // notification, so they're filtered to avoid duplicates.
                        .neq("type", value: "message_received")
                        .neq("type", value: "show_interest")
                        .neq("type", value: "interest_request")
                        .neq("type", value: "deal_offer_received")
                        .neq("type", value: "deal_offer_responded")
                        .order("created_at", ascending: false)
                        .limit(limit)
                        .execute()

                    let decoder = JSONDecoder()
                    let notifications = try decoder.decode([BusinessNotification].self, from: response.data)

                    print("📱 Successfully fetched \(notifications.count) business notifications")
                    continuation.resume(returning: notifications)
                } catch {
                    print("❌ Error fetching business notifications: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Mark a business notification as read
    nonisolated func markBusinessNotificationAsRead(_ notificationId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    let updateData: [String: AnyJSON] = [
                        "notification_state": .string("read"),
                        "read_at": .string(ISO8601DateFormatter().string(from: Date()))
                    ]

                    try await supabase
                        .from("notifications")
                        .update(updateData)
                        .eq("id", value: notificationId)
                        .execute()

                    print("✅ Business notification \(notificationId) marked as read")
                    continuation.resume()
                } catch {
                    print("❌ Error marking business notification as read: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

}
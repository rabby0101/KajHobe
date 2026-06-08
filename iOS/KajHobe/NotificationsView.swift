import SwiftUI
import Supabase
import Auth

// MARK: - Job Interest Notification Model
struct JobInterestNotification: Identifiable, Codable {
    let id: String
    let job_id: String
    let provider_id: String
    let status: String
    let message: String?
    let created_at: String
    let job_title: String
    let client_id: String
    let provider_name: String?
    var read: Bool = false
}

// MARK: - Notification Category
/// Canonical color system for the unified feed: 4 tinted categories plus a
/// plain `.other` fallback. Unread cards are tinted in the category color
/// across the whole card; read cards fade to plain gray (color doubles as
/// the unread signal).
enum NotificationCategory {
    case interest          // Indigo
    case dealCreated       // Teal
    case completionRequest // Amber
    case dealCompleted     // Green
    case other             // Gray

    var color: Color {
        switch self {
        case .interest:           return .indigo
        case .dealCreated:        return .teal
        case .completionRequest:  return Color(red: 1.0, green: 0.70, blue: 0.0)
        case .dealCompleted:      return .green
        case .other:              return .gray
        }
    }

    var label: String {
        switch self {
        case .interest:          return "Interest"
        case .dealCreated:       return "Deal"
        case .completionRequest: return "Completion"
        case .dealCompleted:     return "Completed"
        case .other:             return "Update"
        }
    }

    /// Resolves a `BusinessNotification.type` string to a category.
    /// Order:
    ///   1. contains "completion" → "approved" ⇒ .dealCompleted, else ⇒ .completionRequest
    ///   2. "deal_completed" / contains "completed" ⇒ .dealCompleted
    ///   3. contains "deal" or "offer" ⇒ .dealCreated
    ///   4. contains "interest" ⇒ .interest
    ///   5. else ⇒ .other
    static func from(businessType rawType: String?) -> NotificationCategory {
        guard let t = rawType?.lowercased() else { return .other }
        if t.contains("completion") {
            return t.contains("approved") ? .dealCompleted : .completionRequest
        }
        if t == "deal_completed" || t.contains("completed") {
            return .dealCompleted
        }
        if t.contains("deal") || t.contains("offer") {
            return .dealCreated
        }
        if t.contains("interest") {
            return .interest
        }
        return .other
    }
}

// MARK: - Unified feed item
/// One entry in the single notifications feed — either an interest request
/// (from `job_interests`) or a business notification (from `notifications`).
/// Carries the resolved NotificationCategory used to color the row.
enum NotificationFeedItem: Identifiable {
    case interest(JobInterestNotification)
    case business(BusinessNotification)

    var id: String {
        switch self {
        case .interest(let i): return "interest_\(i.id)"
        case .business(let b): return "business_\(b.id)"
        }
    }

    var createdAt: String {
        switch self {
        case .interest(let i): return i.created_at
        case .business(let b): return b.created_at
        }
    }

    var category: NotificationCategory {
        switch self {
        case .interest:        return .interest
        case .business(let b): return NotificationCategory.from(businessType: b.type)
        }
    }
}

struct NotificationsView: View {
    // Device-local read/cleared state (drives unread highlight + clearing).
    @ObservedObject private var localState = NotificationLocalState.shared

    // Job Interests (existing)
    @State private var notifications: [JobInterestNotification] = []
    @State private var unifiedNotifications: [UnifiedNotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var processingNotificationIds: Set<String> = []
    @State private var loadingTask: Task<Void, Never>?
    @State private var lastButtonPressTime: TimeInterval = 0
    @State private var searchText: String = ""

    // Business Notifications (new)
    @State private var businessNotifications: [BusinessNotification] = []
    @State private var isLoadingBusiness = false
    @State private var businessErrorMessage: String?

    // Simple Profile Sheet State
    @State private var showingProviderProfile = false
    @State private var selectedProfile: SimplePublicProfile?
    @State private var isLoadingProfile = false

    // Deal Details sheet (opened by tapping a "deal created" notification)
    @State private var selectedDeal: DealWithCompletion?

    // MARK: - Job Interest Notifications (Convert existing to unified)
    private func convertJobInterestsToUnified() -> [UnifiedNotification] {
        return notifications.map { jobInterest in
            let notificationType: DatabaseNotificationType
            let title: String
            let message: String
            let isInteractive: Bool
            let priority: NotificationPriorityLevel
            
            switch jobInterest.status.lowercased() {
            case "pending":
                notificationType = .interestReceived
                title = "New Interest"
                message = "\(jobInterest.provider_name ?? "Someone") is interested in '\(jobInterest.job_title)'"
                isInteractive = true
                priority = .high
            case "accepted":
                notificationType = .interestAccepted
                title = "Interest Accepted"
                message = "You accepted interest from \(jobInterest.provider_name ?? "Provider")"
                isInteractive = false
                priority = .normal
            case "rejected":
                notificationType = .interestRejected
                title = "Interest Rejected"
                message = "You rejected interest from \(jobInterest.provider_name ?? "Provider")"
                isInteractive = false
                priority = .normal
            default:
                notificationType = .interestReceived
                title = "Interest Update"
                message = jobInterest.message ?? "Interest update"
                isInteractive = false
                priority = .normal
            }
            
            return UnifiedNotification(
                id: jobInterest.id,
                source: .jobInterest,
                type: notificationType,
                title: title,
                message: message,
                created_at: jobInterest.created_at,
                status: jobInterest.status,
                isInteractive: isInteractive,
                priority: priority,
                job_id: jobInterest.job_id,
                job_title: jobInterest.job_title,
                from_user_id: jobInterest.provider_id,
                from_user_name: jobInterest.provider_name,
                avatar_url: nil,
                sourceData: [
                    "id": jobInterest.id,
                    "job_id": jobInterest.job_id,
                    "provider_id": jobInterest.provider_id,
                    "status": jobInterest.status,
                    "message": jobInterest.message ?? "",
                    "job_title": jobInterest.job_title,
                    "provider_name": jobInterest.provider_name ?? ""
                ]
            )
        }
    }
    
    // MARK: - Unified Notification Loading
    private func loadAllUnifiedNotifications() async -> [UnifiedNotification] {
        print("🚀 Starting loadAllUnifiedNotifications")
        
        // Load all notification types in parallel
        async let jobInterestNotifs = convertJobInterestsToUnified()
        async let dealOfferNotifs = loadDealOfferNotifications()
        async let completionRequestNotifs = loadCompletionRequestNotifications()
        async let dealNotifs = loadDealNotifications()
        async let messageNotifs = loadMessageNotifications()
        
        // Wait for all to complete and merge
        let allNotifications = await [
            jobInterestNotifs,
            dealOfferNotifs,
            completionRequestNotifs,
            dealNotifs,
            messageNotifs
        ].flatMap { $0 }
        
        // Sort by created_at timestamp (most recent first)
        let sortedNotifications = allNotifications.sorted { notification1, notification2 in
            // Parse ISO timestamps
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let date1 = formatter.date(from: notification1.created_at) ?? Date.distantPast
            let date2 = formatter.date(from: notification2.created_at) ?? Date.distantPast
            
            return date1 > date2
        }
        
        print("✅ Loaded \(sortedNotifications.count) total unified notifications:")
        print("   - Job Interests: \(await jobInterestNotifs.count)")
        print("   - Deal Offers: \(await dealOfferNotifs.count)")
        print("   - Completion Requests: \(await completionRequestNotifs.count)")
        print("   - Deals: \(await dealNotifs.count)")
        print("   - Messages: \(await messageNotifs.count)")
        
        return sortedNotifications
    }
    
    // Computed property to filter unified notifications based on search text
    private var filteredUnifiedNotifications: [UnifiedNotification] {
        if searchText.isEmpty {
            return unifiedNotifications
        } else {
            return unifiedNotifications.filter { notification in
                // Search in various notification fields
                let title = notification.title.lowercased()
                let message = notification.message.lowercased()
                let fromUserName = notification.from_user_name?.lowercased() ?? ""
                let jobTitle = notification.job_title?.lowercased() ?? ""
                let searchLower = searchText.lowercased()
                
                return title.contains(searchLower) ||
                       message.contains(searchLower) ||
                       fromUserName.contains(searchLower) ||
                       jobTitle.contains(searchLower)
            }
        }
    }
    
    // MARK: - Deal Offer Notifications
    private func loadDealOfferNotifications() async -> [UnifiedNotification] {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // Get deal offers where the current user is the client (receiving offers)
            let response = try await supabase
                .from("deal_offers")
                .select("""
                    id,
                    conversation_id,
                    provider_id,
                    client_id,
                    job_id,
                    amount,
                    terms,
                    timeline,
                    status,
                    created_at,
                    jobs!inner(title),
                    profiles!deal_offers_provider_id_fkey(full_name, avatar_url)
                """)
                .eq("client_id", value: user.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
            
            // Parse the response manually
            if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                var unifiedNotifications: [UnifiedNotification] = []
                
                for item in jsonData {
                    guard let id = item["id"] as? String,
                          let provider_id = item["provider_id"] as? String,
                          let job_id = item["job_id"] as? String,
                          let amount = item["amount"] as? Int,
                          let status = item["status"] as? String,
                          let created_at = item["created_at"] as? String else {
                        continue
                    }
                    
                    // Extract job title
                    let job_title = (item["jobs"] as? [String: Any])?["title"] as? String ?? "Unknown Job"
                    
                    // Extract provider info
                    let provider_data = item["profiles"] as? [String: Any]
                    let provider_name = provider_data?["full_name"] as? String ?? "Unknown Provider"
                    let avatar_url = provider_data?["avatar_url"] as? String
                    
                    // Create notification based on status
                    let notificationType: DatabaseNotificationType
                    let title: String
                    let message: String
                    let isInteractive: Bool
                    let priority: NotificationPriorityLevel
                    
                    switch status.lowercased() {
                    case "pending":
                        notificationType = .dealOfferReceived
                        title = "New Deal Offer"
                        message = "\(provider_name) offered $\(amount) for '\(job_title)'"
                        isInteractive = true
                        priority = .high
                    case "accepted":
                        notificationType = .dealOfferAccepted
                        title = "Deal Offer Accepted"
                        message = "You accepted \(provider_name)'s offer of $\(amount)"
                        isInteractive = false
                        priority = .normal
                    case "rejected":
                        notificationType = .dealOfferRejected
                        title = "Deal Offer Rejected"
                        message = "You rejected \(provider_name)'s offer of $\(amount)"
                        isInteractive = false
                        priority = .normal
                    default:
                        continue
                    }
                    
                    let unifiedNotification = UnifiedNotification(
                        id: id,
                        source: .dealOffer,
                        type: notificationType,
                        title: title,
                        message: message,
                        created_at: created_at,
                        status: status,
                        isInteractive: isInteractive,
                        priority: priority,
                        job_id: job_id,
                        job_title: job_title,
                        from_user_id: provider_id,
                        from_user_name: provider_name,
                        avatar_url: avatar_url,
                        sourceData: item
                    )
                    
                    unifiedNotifications.append(unifiedNotification)
                }
                
                print("✅ Loaded \(unifiedNotifications.count) deal offer notifications")
                return unifiedNotifications
            }
        } catch {
            print("❌ Error loading deal offer notifications: \(error)")
        }
        
        return []
    }
    
    // MARK: - Completion Request Notifications
    private func loadCompletionRequestNotifications() async -> [UnifiedNotification] {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // Get completion requests where the current user needs to respond (client or provider)
            let response = try await supabase
                .from("completion_requests")
                .select("""
                    id,
                    deal_id,
                    requester_id,
                    requester_type,
                    request_message,
                    status,
                    responded_by,
                    responded_at,
                    response_message,
                    created_at,
                    deals!inner(
                        job_id,
                        client_id,
                        provider_id,
                        agreed_amount,
                        jobs(title)
                    )
                """)
                .or("deals.client_id.eq.\(user.id.uuidString),deals.provider_id.eq.\(user.id.uuidString)")
                .order("created_at", ascending: false)
                .execute()
            
            // Parse the response manually
            if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                var unifiedNotifications: [UnifiedNotification] = []
                
                for item in jsonData {
                    guard let id = item["id"] as? String,
                          let requester_id = item["requester_id"] as? String,
                          let requester_type = item["requester_type"] as? String,
                          let status = item["status"] as? String,
                          let created_at = item["created_at"] as? String,
                          let deal_data = item["deals"] as? [String: Any],
                          let client_id = deal_data["client_id"] as? String,
                          let provider_id = deal_data["provider_id"] as? String,
                          let agreed_amount = deal_data["agreed_amount"] as? Int else {
                        continue
                    }
                    
                    // Skip if the current user is the requester (they don't need to see their own request as notification)
                    if requester_id == user.id.uuidString {
                        continue
                    }
                    
                    // Extract job info
                    let job_data = deal_data["jobs"] as? [String: Any]
                    let job_title = job_data?["title"] as? String ?? "Unknown Job"
                    let job_id = deal_data["job_id"] as? String
                    
                    // Get requester name (we'll need to fetch this separately for now)
                    let requester_name = requester_type == "client" ? "Client" : "Provider"
                    let request_message = item["request_message"] as? String
                    
                    // Create notification based on status and user role
                    let notificationType: DatabaseNotificationType
                    let title: String
                    let message: String
                    let isInteractive: Bool
                    let priority: NotificationPriorityLevel
                    
                    switch status.lowercased() {
                    case "pending":
                        notificationType = .completionRequested
                        title = "Completion Request"
                        message = "\(requester_name) requested completion for '\(job_title)' ($\(agreed_amount))"
                        isInteractive = true
                        priority = .high
                    case "approved":
                        notificationType = .completionApproved
                        title = "Completion Approved"
                        message = "Completion approved for '\(job_title)'"
                        isInteractive = false
                        priority = .normal
                    case "rejected":
                        notificationType = .completionRejected
                        title = "Completion Rejected"
                        message = "Completion rejected for '\(job_title)'"
                        isInteractive = false
                        priority = .normal
                    default:
                        continue
                    }
                    
                    let unifiedNotification = UnifiedNotification(
                        id: id,
                        source: .completionRequest,
                        type: notificationType,
                        title: title,
                        message: message,
                        created_at: created_at,
                        status: status,
                        isInteractive: isInteractive,
                        priority: priority,
                        job_id: job_id,
                        job_title: job_title,
                        from_user_id: requester_id,
                        from_user_name: requester_name,
                        avatar_url: nil, // We can fetch this separately if needed
                        sourceData: item
                    )
                    
                    unifiedNotifications.append(unifiedNotification)
                }
                
                print("✅ Loaded \(unifiedNotifications.count) completion request notifications")
                return unifiedNotifications
            }
        } catch {
            print("❌ Error loading completion request notifications: \(error)")
        }
        
        return []
    }
    
    // MARK: - Deal Notifications
    private func loadDealNotifications() async -> [UnifiedNotification] {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // Get deals where the current user is involved (client or provider)
            let response = try await supabase
                .from("deals")
                .select("""
                    id,
                    job_id,
                    client_id,
                    provider_id,
                    agreed_amount,
                    status,
                    completion_status,
                    created_at,
                    completed_at,
                    jobs!inner(title),
                    profiles!deals_provider_id_fkey(full_name, avatar_url)
                """)
                .or("client_id.eq.\(user.id.uuidString),provider_id.eq.\(user.id.uuidString)")
                .order("created_at", ascending: false)
                .execute()
            
            // Parse the response manually
            if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                var unifiedNotifications: [UnifiedNotification] = []
                
                for item in jsonData {
                    guard let id = item["id"] as? String,
                          let client_id = item["client_id"] as? String,
                          let provider_id = item["provider_id"] as? String,
                          let agreed_amount = item["agreed_amount"] as? Int,
                          let status = item["status"] as? String,
                          let created_at = item["created_at"] as? String else {
                        continue
                    }
                    
                    // Extract job info
                    let job_data = item["jobs"] as? [String: Any]
                    let job_title = job_data?["title"] as? String ?? "Unknown Job"
                    let job_id = item["job_id"] as? String
                    
                    // Extract provider info
                    let provider_data = item["profiles"] as? [String: Any]
                    let provider_name = provider_data?["full_name"] as? String ?? "Provider"
                    let avatar_url = provider_data?["avatar_url"] as? String
                    
                    // Determine the other party's name based on current user role
                    let isCurrentUserClient = client_id == user.id.uuidString
                    let other_party_name = isCurrentUserClient ? provider_name : "Client"
                    let other_party_id = isCurrentUserClient ? provider_id : client_id
                    
                    // Create notifications for different deal events
                    let completion_status = item["completion_status"] as? String
                    let completed_at = item["completed_at"] as? String
                    
                    // Create deal created notification
                    let dealCreatedNotification = UnifiedNotification(
                        id: "\(id)_created",
                        source: .deal,
                        type: .dealCreated,
                        title: "Deal Created",
                        message: "Deal created with \(other_party_name) for '\(job_title)' ($\(agreed_amount))",
                        created_at: created_at,
                        status: status,
                        isInteractive: false,
                        priority: .normal,
                        job_id: job_id,
                        job_title: job_title,
                        from_user_id: other_party_id,
                        from_user_name: other_party_name,
                        avatar_url: avatar_url,
                        sourceData: item
                    )
                    unifiedNotifications.append(dealCreatedNotification)
                    
                    // Create deal completed notification if completed
                    if completion_status == "completed", let completed_at = completed_at {
                        let dealCompletedNotification = UnifiedNotification(
                            id: "\(id)_completed",
                            source: .deal,
                            type: .dealCompleted,
                            title: "Deal Completed",
                            message: "Deal with \(other_party_name) for '\(job_title)' has been completed",
                            created_at: completed_at,
                            status: "completed",
                            isInteractive: false,
                            priority: .high,
                            job_id: job_id,
                            job_title: job_title,
                            from_user_id: other_party_id,
                            from_user_name: other_party_name,
                            avatar_url: avatar_url,
                            sourceData: item
                        )
                        unifiedNotifications.append(dealCompletedNotification)
                    }
                }
                
                print("✅ Loaded \(unifiedNotifications.count) deal notifications")
                return unifiedNotifications
            }
        } catch {
            print("❌ Error loading deal notifications: \(error)")
        }
        
        return []
    }
    
    // MARK: - Message Notifications
    private func loadMessageNotifications() async -> [UnifiedNotification] {
        do {
            let user = try supabase.auth.requireCurrentUser()
            
            // Get recent messages where the current user is not the sender
            // We'll limit this to prevent too many message notifications
            let response = try await supabase
                .from("messages")
                .select("""
                    id,
                    conversation_id,
                    sender_id,
                    content,
                    message_type,
                    created_at,
                    conversations!inner(
                        job_id,
                        client_id,
                        provider_id,
                        jobs(title)
                    ),
                    profiles!messages_sender_id_fkey(full_name, avatar_url)
                """)
                .neq("sender_id", value: user.id.uuidString)
                .or("conversations.client_id.eq.\(user.id.uuidString),conversations.provider_id.eq.\(user.id.uuidString)")
                .order("created_at", ascending: false)
                .limit(20) // Limit to recent 20 messages to avoid clutter
                .execute()
            
            // Parse the response manually
            if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                var unifiedNotifications: [UnifiedNotification] = []
                
                for item in jsonData {
                    guard let id = item["id"] as? String,
                          let sender_id = item["sender_id"] as? String,
                          let content = item["content"] as? String,
                          let created_at = item["created_at"] as? String,
                          let conversation_data = item["conversations"] as? [String: Any] else {
                        continue
                    }
                    
                    // Extract job info
                    let job_data = conversation_data["jobs"] as? [String: Any]
                    let job_title = job_data?["title"] as? String ?? "Unknown Job"
                    let job_id = conversation_data["job_id"] as? String
                    
                    // Extract sender info
                    let sender_data = item["profiles"] as? [String: Any]
                    let sender_name = sender_data?["full_name"] as? String ?? "Someone"
                    let avatar_url = sender_data?["avatar_url"] as? String
                    
                    // Create message preview (limit length)
                    let message_preview = content.count > 50 ? String(content.prefix(50)) + "..." : content
                    
                    let messageNotification = UnifiedNotification(
                        id: id,
                        source: .message,
                        type: .messageReceived,
                        title: "New Message",
                        message: "\(sender_name) sent: \(message_preview)",
                        created_at: created_at,
                        status: "unread",
                        isInteractive: false, // Messages are informational, tap to view
                        priority: .normal,
                        job_id: job_id,
                        job_title: job_title,
                        from_user_id: sender_id,
                        from_user_name: sender_name,
                        avatar_url: avatar_url,
                        sourceData: item
                    )
                    
                    unifiedNotifications.append(messageNotification)
                }
                
                print("✅ Loaded \(unifiedNotifications.count) message notifications")
                return unifiedNotifications
            }
        } catch {
            print("❌ Error loading message notifications: \(error)")
        }
        
        return []
    }
    
    private var mainContentView: some View {
        VStack {
            if isLoading {
                ProgressView("Loading notifications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredUnifiedNotifications.isEmpty {
                emptyStateView
            } else {
                notificationsListView
            }

            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text(searchText.isEmpty ? "No notifications" : "No matching notifications")
                .font(.title2)
                .foregroundColor(.gray)

            Text(searchText.isEmpty ? "Job interests will appear here" : "Try adjusting your search terms")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notificationsListView: some View {
        List(filteredUnifiedNotifications) { notification in
            notificationRowView(notification)
        }
        .listStyle(PlainListStyle())
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await safeLoadUnifiedNotifications()
        }
    }

    private func notificationRowView(_ notification: UnifiedNotification) -> some View {
        UnifiedNotificationRow(
            notification: notification,
            isProcessing: processingNotificationIds.contains(notification.id),
            onAction: { action in
                Task {
                    do {
                        try await handleUnifiedNotificationAction(notification: notification, action: action)
                    } catch {
                        print("❌ Error handling notification action: \(error)")
                    }
                }
            }
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
        .onTapGesture {
            print("📱 Notification tapped: \(notification.title)")
            print("📱 Source: \(notification.source), Type: \(notification.type)")
            print("📱 From user ID: \(notification.from_user_id ?? "nil")")

            // Mark job interest as read when tapped
            Task {
                do {
                    print("🔄 Marking job interest as read: \(notification.title)")
                    print("🔄 Job Interest ID: \(notification.id)")

                    let updateData: [String: AnyJSON] = [
                        "read": .bool(true),
                        "read_at": .string(ISO8601DateFormatter().string(from: Date()))
                    ]

                    try await supabase
                        .from("job_interests")
                        .update(updateData)
                        .eq("id", value: notification.id)
                        .eq("read", value: false)
                        .execute()

                    print("✅ Job interest marked as read successfully")
                } catch {
                    print("❌ Error marking job interest as read: \(error)")
                }
            }

            if notification.source == .jobInterest,
               notification.type == .interestReceived || notification.type == .interestRequest,
               let providerId = notification.from_user_id {
                print("✅ Triggering profile load for provider: \(providerId)")
                loadProviderProfile(providerId: providerId)
            } else {
                print("❌ Tap conditions not met")
            }
        }
    }

    // MARK: - Unified Feed

    /// All notifications (interests + business) merged into one list, newest first.
    private var feedItems: [NotificationFeedItem] {
        let items = visibleInterests.map { NotificationFeedItem.interest($0) }
            + filteredBusinessNotifications.map { NotificationFeedItem.business($0) }
        return items.sorted { lhs, rhs in
            (NotificationLocalState.date(from: lhs.createdAt) ?? .distantPast) >
            (NotificationLocalState.date(from: rhs.createdAt) ?? .distantPast)
        }
    }

    private var feedContentView: some View {
        Group {
            if (isLoading || isLoadingBusiness) && feedItems.isEmpty {
                ProgressView("Loading notifications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if feedItems.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(feedItems) { item in
                        feedRow(item)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    clearFeedItem(item)
                                } label: {
                                    Label("Clear", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await safeLoadUnifiedNotifications()
                    await loadBusinessNotifications()
                }
            }

            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private func feedRow(_ item: NotificationFeedItem) -> some View {
        switch item {
        case .interest(let interest):
            InterestNotificationRow(
                interest: interest,
                isUnread: isInterestUnread(interest),
                isProcessing: processingNotificationIds.contains(interest.id),
                accent: item.category.color,
                category: item.category.label,
                onTap: {
                    markInterestRead(interest)
                    loadProviderProfile(providerId: interest.provider_id)
                },
                onAction: { accept in
                    Task { await actOnInterest(interest, accept: accept) }
                }
            )
        case .business(let notification):
            BusinessNotificationRow(
                notification: notification,
                isUnread: localState.isUnread(id: notification.id, createdAtISO: notification.created_at),
                accent: item.category.color,
                category: item.category.label,
                onTap: {
                    await handleBusinessNotificationTap(notification)
                }
            )
        }
    }

    private func clearFeedItem(_ item: NotificationFeedItem) {
        switch item {
        case .interest(let i):
            clearInterest(i)
        case .business(let b):
            localState.clear(b.id)
            NotificationBadgeManager.shared.recomputeFromLocal()
        }
    }

    // MARK: - Interests Tab (flat read/unread list)

    /// Interests visible in the list: not cleared, search-filtered, newest first.
    private var visibleInterests: [JobInterestNotification] {
        let base = notifications.filter { !localState.isCleared($0.id) }
        let filtered: [JobInterestNotification]
        if searchText.isEmpty {
            filtered = base
        } else {
            let s = searchText.lowercased()
            filtered = base.filter { n in
                n.job_title.lowercased().contains(s) ||
                (n.provider_name?.lowercased().contains(s) ?? false) ||
                (n.message?.lowercased().contains(s) ?? false)
            }
        }
        return filtered.sorted { $0.created_at > $1.created_at }
    }

    /// An interest is "unread" (bright) only while it is pending and not yet opened/cleared.
    private func isInterestUnread(_ interest: JobInterestNotification) -> Bool {
        interest.status.lowercased() == "pending" &&
        localState.isUnread(id: interest.id, createdAtISO: interest.created_at)
    }

    private func markInterestRead(_ interest: JobInterestNotification) {
        localState.markRead(interest.id)
        NotificationBadgeManager.shared.recomputeFromLocal()
    }

    private func clearInterest(_ interest: JobInterestNotification) {
        localState.clear(interest.id)
        NotificationBadgeManager.shared.recomputeFromLocal()
    }

    /// Accept or reject a single interest, then refresh the list + bell badge.
    private func actOnInterest(_ interest: JobInterestNotification, accept: Bool) async {
        guard !processingNotificationIds.contains(interest.id) else { return }
        await MainActor.run {
            _ = processingNotificationIds.insert(interest.id)
            localState.markRead(interest.id)   // acting on it counts as reading it
        }
        do {
            try await handleJobInterestAction(notification: interest, accept: accept)
        } catch {
            print("❌ Error handling interest action: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to process action: \(error.localizedDescription)"
            }
        }
        await MainActor.run { processingNotificationIds.remove(interest.id) }
        await safeLoadUnifiedNotifications()
        await NotificationBadgeManager.shared.refreshCounts()
    }

    // MARK: - Clear / Mark-all (whole feed)

    private func clearAllInFeed() {
        localState.clear(visibleInterests.map { $0.id } + filteredBusinessNotifications.map { $0.id })
        NotificationBadgeManager.shared.recomputeFromLocal()
    }

    private func markAllReadInFeed() {
        localState.markRead(visibleInterests.map { $0.id } + filteredBusinessNotifications.map { $0.id })
        NotificationBadgeManager.shared.recomputeFromLocal()
    }

    // MARK: - Business Notifications Helpers

    private var filteredBusinessNotifications: [BusinessNotification] {
        // Hide cleared notifications (device-local).
        var filtered = businessNotifications.filter { !localState.isCleared($0.id) }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { notification in
                notification.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                notification.displayMessage.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered.sorted { notification1, notification2 in
            // Sort by created_at, most recent first
            let date1 = ISO8601DateFormatter().date(from: notification1.created_at) ?? Date.distantPast
            let date2 = ISO8601DateFormatter().date(from: notification2.created_at) ?? Date.distantPast
            return date1 > date2
        }
    }

    private func loadBusinessNotifications() async {
        await MainActor.run {
            isLoadingBusiness = true
            businessErrorMessage = nil
        }

        do {
            let loadedNotifications = try await NotificationsNetworking.shared.fetchBusinessNotifications()

            await MainActor.run {
                self.businessNotifications = loadedNotifications
                self.isLoadingBusiness = false
            }

            print("📱 Loaded \(loadedNotifications.count) business notifications")
        } catch {
            await MainActor.run {
                self.businessErrorMessage = error.localizedDescription
                self.isLoadingBusiness = false
            }
            print("❌ Error loading business notifications: \(error)")
        }
    }

    private func handleBusinessNotificationTap(_ notification: BusinessNotification) async {
        print("📱 Business notification tapped: \(notification.displayTitle)")

        // Opening a notification mutes it (device-local read state).
        localState.markRead(notification.id)
        NotificationBadgeManager.shared.recomputeFromLocal()

        // A "deal created" notification opens the Deal Details view (same as the Dashboard).
        if notification.type == "deal_created", let jobId = notification.job_id {
            await openDeal(forJobId: jobId)
        }
    }

    /// Resolve the deal for a job and present Deal Details — mirrors the Dashboard's
    /// active-deal tap (reuses DealsNetworking.fetchActiveDeals, which joins job + profiles).
    private func openDeal(forJobId jobId: String) async {
        do {
            let deals = try await DealsNetworking.shared.fetchActiveDeals()
            guard let deal = deals.first(where: { $0.job_id == jobId }) else {
                print("ℹ️ No active deal found for job \(jobId); nothing to open.")
                return
            }
            let dealWithCompletion = DealWithCompletion(
                id: deal.id,
                job_id: deal.job_id,
                client_id: deal.client_id,
                provider_id: deal.provider_id,
                agreed_amount: deal.agreed_amount,
                agreed_terms: deal.agreed_terms,
                timeline: deal.timeline,
                status: deal.status,
                completion_status: deal.completion_status ?? "in_progress",
                client_completion_requested: deal.client_completion_requested ?? false,
                provider_completion_requested: deal.provider_completion_requested ?? false,
                client_completion_requested_at: deal.client_completion_requested_at,
                provider_completion_requested_at: deal.provider_completion_requested_at,
                created_at: deal.created_at,
                completed_at: deal.completed_at,
                job: deal.job,
                client_profile: deal.client_profile,
                provider_profile: deal.provider_profile,
                pending_completion_requests: nil
            )
            await MainActor.run { self.selectedDeal = dealWithCompletion }
        } catch {
            print("❌ Error opening deal for job \(jobId): \(error)")
        }
    }

    private func markBusinessNotificationAsRead(_ notification: BusinessNotification) async {
        // Retained for compatibility; local read state is the source of truth now.
        localState.markRead(notification.id)
        NotificationBadgeManager.shared.recomputeFromLocal()

        do {
            // (Legacy no-op-friendly server sync kept for cross-surface consistency.)
            try await NotificationsNetworking.shared.markBusinessNotificationAsRead(notification.id)

            print("✅ Business notification marked as read successfully")
        } catch {
            print("❌ Error marking business notification as read: \(error)")
        }
    }

    var body: some View {
        NavigationView {
            feedContentView
            .navigationTitle("Notifications")
            .searchable(text: $searchText, prompt: "Search notifications...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            markAllReadInFeed()
                        } label: {
                            Label("Mark all as read", systemImage: "checkmark.circle")
                        }
                        Button(role: .destructive) {
                            clearAllInFeed()
                        } label: {
                            Label("Clear all", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                loadingTask = Task {
                    if let uid = supabase.auth.currentUser?.id.uuidString {
                        await MainActor.run { NotificationLocalState.shared.configure(userId: uid) }
                    }
                    await safeLoadUnifiedNotifications()
                    await loadBusinessNotifications()
                }
            }
            .onDisappear {
                loadingTask?.cancel()
                loadingTask = nil
            }
            .sheet(item: $selectedDeal) { deal in
                DealDetailView(deal: deal)
            }
        }
        .sheet(isPresented: $showingProviderProfile) {
            if let profile = selectedProfile {
                PublicProfileDetailView(profile: profile.toPublicProfile())
                    .onAppear {
                        print("✅ PublicProfileDetailView appeared for: \(profile.full_name ?? "Unknown")")
                        print("✅ Profile ID: \(profile.id), Online: \(profile.is_online)")
                    }
            } else {
                VStack(spacing: 20) {
                    Text("Loading Profile...")
                        .font(.headline)
                    ProgressView()
                }
                .padding()
                .onAppear {
                    print("🚨 LOADING VIEW APPEARED - selectedProfile is nil, showingProviderProfile: \(showingProviderProfile)")
                }
            }
        }
    }
    
    // MARK: - Safe Loading Function for Unified Notifications
    private func safeLoadUnifiedNotifications() async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Create new loading task
        loadingTask = Task {
            await loadUnifiedNotifications()
        }
        
        await loadingTask?.value
    }
    
    private func loadUnifiedNotifications() async {
        // Check for cancellation early
        guard !Task.isCancelled else {
            print("🔄 Load interests task was cancelled")
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // The Interests tab shows ONLY job_interests (grouped by job). Deal offers,
        // completion requests, deals and messages live on the Business tab.
        await loadNotifications()

        await MainActor.run {
            self.isLoading = false
        }

        // Keep the bell badge in sync with the freshly-loaded interests.
        await NotificationBadgeManager.shared.refreshCounts()
    }
    
    // MARK: - Unified Notification Action Handler
    private func handleUnifiedNotificationAction(notification: UnifiedNotification, action: String) async throws {
        let currentTime = Date().timeIntervalSince1970
        
        // Prevent rapid button presses (within 500ms)
        guard currentTime - lastButtonPressTime > 0.5 else {
            print("⚠️ Button press too rapid, ignoring")
            return
        }
        
        // Prevent multiple simultaneous actions on the same notification
        guard !processingNotificationIds.contains(notification.id) else {
            print("⚠️ Already processing notification \(notification.id), ignoring duplicate action")
            return
        }
        
        lastButtonPressTime = currentTime
        processingNotificationIds.insert(notification.id)
        
        print("📝 ======= UNIFIED NOTIFICATION ACTION START =======")
        print("📝 Source: \(notification.source.rawValue)")
        print("📝 Type: \(notification.type.rawValue)")
        print("📝 Action: \(action)")
        print("📝 Notification ID: \(notification.id)")
        print("📝 ==========================================")
        
        Task {
            do {
                switch notification.source {
                case .jobInterest:
                    // Use existing job interest action handler
                    if let jobInterest = notifications.first(where: { $0.id == notification.id }) {
                        let accept = (action == "accept")
                        try await handleJobInterestAction(notification: jobInterest, accept: accept)
                    }
                    
                case .dealOffer:
                    await handleDealOfferAction(notification: notification, action: action)
                    
                case .completionRequest:
                    await handleCompletionRequestAction(notification: notification, action: action)
                    
                case .deal, .message:
                    // These are typically informational, maybe just navigate
                    print("ℹ️ Informational notification tapped: \(notification.source.rawValue)")
                }
                
                await MainActor.run {
                    self.processingNotificationIds.remove(notification.id)
                }
                
                // Refresh notifications after action
                await safeLoadUnifiedNotifications()
                
            } catch {
                print("❌ Error handling unified notification action: \(error)")
                await MainActor.run {
                    self.processingNotificationIds.remove(notification.id)
                    self.errorMessage = "Failed to process action: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Specific Action Handlers
    private func handleJobInterestAction(notification: JobInterestNotification, accept: Bool) async throws {
        let status = accept ? "accepted" : "rejected"
        
        do {
            let updateResponse = try await supabase
                .from("job_interests")
                .update([
                    "status": AnyEncodable(status),
                    "actioned_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
                ])
                .eq("id", value: notification.id)
                .execute()
            
            print("✅ Job interest status updated to: \(status)")
            
            // If accepted, create a conversation
            if accept {
                try await createConversation(notification: notification)
            }
            
        } catch {
            print("❌ Error updating job interest: \(error)")
            throw error
        }
    }
    
    private func handleDealOfferAction(notification: UnifiedNotification, action: String) async {
        // Implement deal offer actions (accept, reject, counter)
        print("🤝 Handling deal offer action: \(action)")
        
        // This would involve updating the deal_offers table
        // For now, just log the action
    }
    
    private func handleCompletionRequestAction(notification: UnifiedNotification, action: String) async {
        // Implement completion request actions (approve, reject)
        print("✅ Handling completion request action: \(action)")
        
        // This would involve updating the completion_requests table
        // For now, just log the action
    }
    
    private func safeLoadNotifications() async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Create new loading task
        loadingTask = Task {
            await loadNotifications()
        }
        
        await loadingTask?.value
    }
    
    private func loadNotifications() async {
        // Check for cancellation early
        guard !Task.isCancelled else {
            print("🔄 Load notifications task was cancelled")
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Check for cancellation before auth request
            guard !Task.isCancelled else {
                print("🔄 Load notifications task cancelled before auth")
                await MainActor.run { isLoading = false }
                return
            }
            
            // Get current user with error handling for cancelled requests
            let user: User
            do {
                user = try supabase.auth.requireCurrentUser()
                print("🔍 Loading notifications for user: \(user.id.uuidString)")
            } catch {
                // Handle cancelled request specifically
                if (error as NSError).code == -999 {
                    print("🔄 Auth request was cancelled, stopping notification load")
                    await MainActor.run { isLoading = false }
                    return
                } else {
                    throw error
                }
            }
            
            // Check for cancellation before database request
            guard !Task.isCancelled else {
                print("🔄 Load notifications task cancelled before database query")
                await MainActor.run { isLoading = false }
                return
            }
            
            // First, get job_interests with jobs data
            let response = try await supabase
                .from("job_interests")
                .select("""
                    id,
                    job_id,
                    provider_id,
                    status,
                    message,
                    read,
                    created_at,
                    jobs!inner(title, client_id)
                """)
                .eq("jobs.client_id", value: user.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
            
            print("🔍 Raw response data size: \(response.data.count) bytes")
            
            // Parse the response manually to handle nested structure
            if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                print("🔍 Found \(jsonData.count) job interest records")
                
                var parsedNotifications: [JobInterestNotification] = []
                
                // Collect unique provider IDs to fetch names
                let providerIds = Set(jsonData.compactMap { $0["provider_id"] as? String })
                
                // Fetch profile names for all providers
                var providerNames: [String: String] = [:]
                if !providerIds.isEmpty {
                    let profilesResponse = try await supabase
                        .from("profiles")
                        .select("id, full_name")
                        .in("id", values: Array(providerIds))
                        .execute()
                    
                    if let profilesData = try? JSONSerialization.jsonObject(with: profilesResponse.data) as? [[String: Any]] {
                        for profile in profilesData {
                            if let id = profile["id"] as? String,
                               let fullName = profile["full_name"] as? String {
                                providerNames[id] = fullName
                            }
                        }
                    }
                }
                
                // Now build the notifications with provider names
                for item in jsonData {
                    guard let id = item["id"] as? String,
                          let job_id = item["job_id"] as? String,
                          let provider_id = item["provider_id"] as? String,
                          let status = item["status"] as? String,
                          let created_at = item["created_at"] as? String else {
                        continue
                    }
                    
                    let message = item["message"] as? String
                    let read = item["read"] as? Bool ?? false

                    // Extract job title from nested jobs object
                    var job_title = "Unknown Job"
                    var client_id = ""
                    if let jobs = item["jobs"] as? [String: Any] {
                        job_title = jobs["title"] as? String ?? "Unknown Job"
                        client_id = jobs["client_id"] as? String ?? ""
                    }
                    
                    // Get provider name from our fetched data
                    let provider_name = providerNames[provider_id]
                    
                    let notification = JobInterestNotification(
                        id: id,
                        job_id: job_id,
                        provider_id: provider_id,
                        status: status,
                        message: message,
                        created_at: created_at,
                        job_title: job_title,
                        client_id: client_id,
                        provider_name: provider_name,
                        read: read
                    )
                    
                    parsedNotifications.append(notification)
                }
                
                await MainActor.run {
                    self.notifications = parsedNotifications
                    print("✅ Successfully loaded \(parsedNotifications.count) notifications with provider names")
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Failed to parse notifications data"
                }
            }
            
        } catch {
            print("❌ Error loading notifications: \(error)")
            
            // Don't show error message if task was cancelled
            if !Task.isCancelled && (error as NSError).code != -999 {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            } else {
                print("🔄 Task was cancelled, not showing error")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Handle Notification Actions
    private func handleNotificationAction(notification: JobInterestNotification, accept: Bool) {
        let currentTime = Date().timeIntervalSince1970
        
        // Prevent rapid button presses (within 500ms)
        guard currentTime - lastButtonPressTime > 0.5 else {
            print("⚠️ Button press too rapid, ignoring (last press was \(currentTime - lastButtonPressTime) seconds ago)")
            return
        }
        
        // Prevent multiple simultaneous actions on the same notification
        guard !processingNotificationIds.contains(notification.id) else {
            print("⚠️ Already processing notification \(notification.id), ignoring duplicate action")
            return
        }
        
        lastButtonPressTime = currentTime
        
        print("📝 ======= NOTIFICATION ACTION START =======")
        print("📝 handleNotificationAction called with accept: \(accept)")
        print("📝 Notification ID: \(notification.id)")
        print("📝 Provider: \(notification.provider_name ?? "Unknown")")
        print("📝 Job: \(notification.job_title)")
        print("📝 Current Status: \(notification.status)")
        print("📝 Action will be: \(accept ? "ACCEPT" : "REJECT")")
        print("📝 Expected final status: \(accept ? "accepted" : "rejected")")
        print("📝 ==========================================")
        
        processingNotificationIds.insert(notification.id)
        
        Task {
            do {
                let status = accept ? "accepted" : "rejected"
                print("🔄 STARTING DATABASE UPDATE:")
                print("🔄 Job Interest ID: \(notification.id)")
                print("🔄 New Status: \(status)")
                print("🔄 Accept Parameter: \(accept)")
                
                // Update the job_interests status
                let updateResponse = try await supabase
                    .from("job_interests")
                    .update([
                        "status": AnyEncodable(status),
                        "actioned_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
                    ])
                    .eq("id", value: notification.id)
                    .execute()
                
                print("✅ DATABASE UPDATE COMPLETED:")
                print("✅ Response size: \(updateResponse.data.count) bytes")
                print("✅ Final status should be: \(status)")
                
                // Verify the update by querying the record
                let verifyResponse = try await supabase
                    .from("job_interests")
                    .select("id, status")
                    .eq("id", value: notification.id)
                    .single()
                    .execute()
                
                if let verifyData = try? JSONSerialization.jsonObject(with: verifyResponse.data) as? [String: Any],
                   let actualStatus = verifyData["status"] as? String {
                    print("🔍 VERIFICATION: Actual status in database is now: \(actualStatus)")
                    if actualStatus != status {
                        print("❌ ERROR: Expected \(status) but database shows \(actualStatus)")
                    } else {
                        print("✅ VERIFICATION: Status correctly updated to \(actualStatus)")
                    }
                } else {
                    print("⚠️ Could not verify database update")
                }
                
                // If accepted, create a conversation
                if accept {
                    print("✅ Status is ACCEPTED - Creating conversation...")
                    try await createConversation(notification: notification)
                } else {
                    print("❌ Status is REJECTED - NOT creating conversation")
                }
                
                await MainActor.run {
                    // Remove from processing set
                    self.processingNotificationIds.remove(notification.id)
                }
                
                // Refresh the notifications list safely
                await safeLoadNotifications()
                
            } catch {
                print("❌ Error updating job interest status: \(error)")
                await MainActor.run {
                    self.processingNotificationIds.remove(notification.id)
                    self.errorMessage = "Failed to update status: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Create Conversation
    private func createConversation(notification: JobInterestNotification) async throws {
        print("🔄 Creating conversation for accepted job interest")
        print("   Job ID: \(notification.job_id)")
        print("   Client ID: \(notification.client_id)")
        print("   Provider ID: \(notification.provider_id)")
        
        // Check if conversation already exists to avoid duplicates
        let existingConversationResponse = try await supabase
            .from("conversations")
            .select("id")
            .eq("job_id", value: notification.job_id)
            .eq("client_id", value: notification.client_id)
            .eq("provider_id", value: notification.provider_id)
            .execute()
        
        // Parse the response to check if conversation exists
        if let data = try? JSONSerialization.jsonObject(with: existingConversationResponse.data) as? [[String: Any]],
           !data.isEmpty {
            print("ℹ️ Conversation already exists between client and provider")
            return
        }
        
        // Create new conversation
        let conversationData: [String: Any] = [
            "job_id": notification.job_id,
            "client_id": notification.client_id,  // Job owner (current user)
            "provider_id": notification.provider_id,  // Provider who showed interest
            "status": "active",
            "client_unread_count": 0,
            "provider_unread_count": 0
        ]
        
        print("📝 Creating conversation with data: \(conversationData)")
        
        let insertResponse = try await supabase
            .from("conversations")
            .insert(AnyEncodable(conversationData))
            .execute()
        
        print("✅ Successfully created new conversation!")
        print("📊 Insert response: \(insertResponse.data.count) bytes")
    }

    // MARK: - Simple Profile Loading

    private func loadProviderProfile(providerId: String) {
        print("🔍 Loading profile for provider ID: \(providerId)")
        print("🔍 Provider ID lowercase: \(providerId.lowercased())")
        isLoadingProfile = true
        // Show sheet immediately to display loading state
        showingProviderProfile = true

        Task {
            do {
                // Try both original and lowercase version since UUID might be case sensitive
                let response = try await supabase
                    .from("public_profiles")
                    .select()
                    .eq("id", value: providerId.lowercased())
                    .execute()

                print("🔍 Profile query response data size: \(response.data.count) bytes")

                // Let's see the raw response
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("🔍 Raw profile response: \(jsonString)")
                }

                if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                    print("🔍 Parsed JSON array count: \(jsonData.count)")

                    if let profileData = jsonData.first {
                        print("🔍 Profile data keys: \(profileData.keys)")

                        let profile = SimplePublicProfile(
                            id: profileData["id"] as? String ?? "",
                            full_name: profileData["full_name"] as? String,
                            avatar_url: profileData["avatar_url"] as? String,
                            bio: profileData["bio"] as? String,
                            location: profileData["location"] as? String,
                            website: profileData["website"] as? String,
                            is_service_provider: profileData["is_service_provider"] as? Bool ?? false,
                            created_at: profileData["created_at"] as? String ?? "",
                            completed_jobs: profileData["completed_jobs"] as? Int ?? 0,
                            avg_job_value: profileData["avg_job_value"] as? Double ?? 0.0,
                            total_earnings: profileData["total_earnings"] as? Double ?? 0.0,
                            avg_rating: profileData["avg_rating"] as? Double ?? 0.0,
                            review_count: profileData["review_count"] as? Int ?? 0,
                            is_online: profileData["is_online"] as? Bool ?? false,
                            last_seen_at: profileData["last_seen_at"] as? String,
                            average_response_time_minutes: profileData["average_response_time_minutes"] as? Int,
                            service_categories: profileData["service_categories"] as? [String] ?? [],
                            trust_level: profileData["trust_level"] as? String ?? "unverified",
                            last_updated: profileData["last_updated"] as? String ?? "",
                            profession: profileData["profession"] as? String,
                            tagline: profileData["tagline"] as? String,
                            experience_years: profileData["experience_years"] as? Int,
                            hourly_rate: profileData["hourly_rate"] as? Double,
                            team_rate: profileData["team_rate"] as? Double,
                            team_hours_label: profileData["team_hours_label"] as? String
                        )

                        print("✅ Successfully created profile: \(profile.full_name ?? "Unknown")")
                        print("🔍 Profile details - ID: \(profile.id), Jobs: \(profile.completed_jobs), Rating: \(profile.avg_rating), Trust: \(profile.trust_level)")

                        // Update UI on main actor with immediate sheet presentation
                        print("🚀 About to run MainActor.run block...")
                        do {
                            await MainActor.run {
                                print("🎭 INSIDE MainActor.run - Setting profile for: \(profile.full_name ?? "Unknown")")
                                print("🎭 Current selectedProfile before assignment: \(self.selectedProfile?.full_name ?? "nil")")
                                self.selectedProfile = profile
                                print("🎭 selectedProfile after assignment: \(self.selectedProfile?.full_name ?? "nil")")
                                self.isLoadingProfile = false
                                print("🎭 Profile successfully set and loading stopped")
                            }
                            print("🚀 MainActor.run completed successfully")
                        } catch {
                            print("❌ Error in MainActor.run: \(error)")
                        }
                    } else {
                        print("❌ No profile data found in response")
                        await MainActor.run {
                            self.isLoadingProfile = false
                        }
                    }
                } else {
                    print("❌ Failed to parse JSON response")
                    await MainActor.run {
                        self.isLoadingProfile = false
                    }
                }
            } catch {
                print("❌ Failed to load provider profile: \(error)")
                await MainActor.run {
                    self.isLoadingProfile = false
                }
            }
        }
    }
}

// MARK: - Notification Row View
struct NotificationRow: View {
    let notification: JobInterestNotification
    let isProcessing: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with provider name and status badge (only for non-pending)
            HStack {
                HStack {
                    Text(notification.provider_name ?? "Unknown Provider")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("showed interest in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Only show status badge for non-pending notifications
                if notification.status.lowercased() != "pending" {
                    NotificationStatusBadge(status: notification.status)
                }
            }
            
            // Job title
            Text(notification.job_title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Message if available
            if let message = notification.message, !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .cornerRadius(8)
            }
            
            // Bottom section with timestamp and action buttons
            HStack {
                Text(timeAgo(from: notification.created_at))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Show action buttons for pending notifications
                if notification.status.lowercased() == "pending" {
                    ActionButtons(
                        isProcessing: isProcessing,
                        onAccept: onAccept,
                        onReject: onReject
                    )
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
    }
    
    private func timeAgo(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return "Just now"
        }
        
        let timeInterval = Date().timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Notification Status Badge View
struct NotificationStatusBadge: View {
    let status: String
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "pending":
            return .orange
        case "accepted":
            return .green
        case "rejected":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Action Buttons View
struct ActionButtons: View {
    let isProcessing: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        HStack(spacing: 16) { // Increased spacing to prevent gesture conflicts
            // Accept Button (moved to left for conventional UX)
            Button(action: {
                print("🟢 [ActionButtons] Accept button tapped")
                onAccept()
            }) {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .medium))
                    }
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(minWidth: 80, minHeight: 36)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green)
                        .shadow(color: Color.green.opacity(0.3), radius: 2, x: 0, y: 1)
                )
            }
            .buttonStyle(PlainButtonStyle()) // Explicit button style to prevent gesture conflicts
            .disabled(isProcessing)
            .id("accept-button") // Unique identifier
            
            // Reject Button (moved to right)
            Button(action: {
                print("🔴 [ActionButtons] Reject button tapped")
                onReject()
            }) {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                    }
                    Text("Decline")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
                .frame(minWidth: 80, minHeight: 36)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle()) // Explicit button style to prevent gesture conflicts
            .disabled(isProcessing)
            .id("reject-button") // Unique identifier
        }
    }

}

// MARK: - Unified Notification Row View
struct UnifiedNotificationRow: View {
    let notification: UnifiedNotification
    let isProcessing: Bool
    let onAction: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with source type indicator and status badge
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        // Source type icon
                        sourceIcon
                            .foregroundColor(sourceColor)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(notification.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    if let fromUserName = notification.from_user_name {
                        Text("from \(fromUserName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status badge for interactive notifications
                if notification.isInteractive && notification.isUnread {
                    Circle()
                        .fill(notification.statusColor.color)
                        .frame(width: 12, height: 12)
                }
            }
            
            // Job title if available
            if let jobTitle = notification.job_title {
                Text("Job: \(jobTitle)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            // Message
            Text(notification.message)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .cornerRadius(8)
            
            // Bottom section with timestamp and action buttons
            HStack {
                Text(timeAgo(from: notification.created_at))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Show action buttons for interactive notifications
                if notification.isInteractive {
                    UnifiedActionButtons(
                        notification: notification,
                        isProcessing: isProcessing,
                        onAction: onAction
                    )
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
    }
    
    private var sourceIcon: Image {
        switch notification.source {
        case .jobInterest:
            return Image(systemName: "person.crop.circle.badge.plus")
        case .dealOffer:
            return Image(systemName: "hands.sparkles")
        case .completionRequest:
            return Image(systemName: "checkmark.circle")
        case .deal:
            return Image(systemName: "doc.text")
        case .message:
            return Image(systemName: "message")
        }
    }
    
    private var sourceColor: Color {
        switch notification.source {
        case .jobInterest:
            return .blue
        case .dealOffer:
            return .green
        case .completionRequest:
            return .orange
        case .deal:
            return .purple
        case .message:
            return .indigo
        }
    }
    
    private func timeAgo(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return "Just now"
        }
        
        let timeInterval = Date().timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Unified Action Buttons View
struct UnifiedActionButtons: View {
    let notification: UnifiedNotification
    let isProcessing: Bool
    let onAction: (String) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            switch notification.source {
            case .jobInterest:
                // Accept/Reject buttons for job interests
                jobInterestButtons
            case .dealOffer:
                // Accept/Reject/Counter buttons for deal offers
                dealOfferButtons
            case .completionRequest:
                // Approve/Reject buttons for completion requests
                completionRequestButtons
            default:
                // No action buttons for informational notifications
                EmptyView()
            }
        }
    }
    
    private var jobInterestButtons: some View {
        HStack(spacing: 12) {
            actionButton(title: "Accept", action: "accept", style: .primary)
            actionButton(title: "Decline", action: "reject", style: .secondary)
        }
    }
    
    private var dealOfferButtons: some View {
        HStack(spacing: 12) {
            actionButton(title: "Accept", action: "accept", style: .primary)
            actionButton(title: "Reject", action: "reject", style: .secondary)
        }
    }
    
    private var completionRequestButtons: some View {
        HStack(spacing: 12) {
            actionButton(title: "Approve", action: "approve", style: .primary)
            actionButton(title: "Reject", action: "reject", style: .secondary)
        }
    }
    
    private func actionButton(title: String, action: String, style: ActionButtonStyle) -> some View {
        Button(action: {
            onAction(action)
        }) {
            HStack(spacing: 6) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style == .primary ? .white : .primary))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: style == .primary ? "checkmark" : "xmark")
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(style == .primary ? .white : .red)
            .frame(minWidth: 80, minHeight: 36)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(style == .primary ? Color.green : Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style == .primary ? Color.clear : Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: (style == .primary ? Color.green : Color.clear).opacity(0.3), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isProcessing)
    }
    
    enum ActionButtonStyle {
        case primary, secondary
    }
}

// Extension to convert UnifiedNotification.NotificationColor to SwiftUI Color
extension UnifiedNotification.NotificationColor {
    var color: Color {
        switch self {
        case .brown: return .brown
        case .green: return .green
        case .red: return .red
        case .gray: return .gray
        }
    }
}

// MARK: - Business Notification Row Component
struct BusinessNotificationRow: View {
    let notification: BusinessNotification
    let isUnread: Bool
    let accent: Color
    let category: String
    let onTap: () async -> Void

    private var effectiveAccent: Color { isUnread ? accent : .gray }

    var body: some View {
        HStack(spacing: 12) {
            // Type icon (tinted with the category accent; gray when read)
            Image(systemName: notification.typeIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(effectiveAccent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(effectiveAccent.opacity(0.15)))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title and timestamp
                HStack(spacing: 6) {
                    Text(notification.displayTitle)
                        .font(.system(size: 16, weight: isUnread ? .semibold : .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Category chip (still rendered when read, in gray)
                    Text(category)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(effectiveAccent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(effectiveAccent.opacity(0.15))
                        .clipShape(Capsule())

                    Spacer()

                    Text(formattedDate(from: notification.created_at))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Message
                if !notification.displayMessage.isEmpty {
                    Text(notification.displayMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            // Unread indicator
            if isUnread {
                Circle()
                    .fill(effectiveAccent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        // Read notifications appear dull; unread are bright.
        .opacity(isUnread ? 1.0 : 0.7)
        // Unread: full card tinted in the category color. Read: plain gray.
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isUnread ? accent.opacity(0.15) : Color(.systemGray6).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnread ? accent.opacity(0.5) : Color(.systemGray5), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                await onTap()
            }
        }
    }

    private func formattedDate(from dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Interest Notification Row (flat)

/// A single interest request as a flat notification row: avatar, provider, job
/// title, the provider's message, and Accept/Reject (pending only). Unread rows
/// are bright; read rows are dulled.
struct InterestNotificationRow: View {
    let interest: JobInterestNotification
    let isUnread: Bool
    let isProcessing: Bool
    let accent: Color
    let category: String
    let onTap: () -> Void
    let onAction: (Bool) -> Void   // accept

    private var isPending: Bool { interest.status.lowercased() == "pending" }
    private var effectiveAccent: Color { isUnread ? accent : .gray }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(effectiveAccent.opacity(0.15)).frame(width: 40, height: 40)
                    Text(String((interest.provider_name ?? "?").prefix(1)).uppercased())
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(effectiveAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(interest.provider_name ?? "Someone")
                            .font(.system(size: 16, weight: isUnread ? .semibold : .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        categoryChip
                    }
                    Text(interest.job_title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(relativeTime(interest.created_at))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if isUnread {
                        Circle().fill(effectiveAccent).frame(width: 8, height: 8)
                    } else {
                        statusPill
                    }
                }
            }

            // Provider's interest message (the note they wrote when showing interest)
            if let message = interest.message,
               !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Accept / Reject (pending only)
            if isPending {
                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        onAction(false)
                    } label: {
                        Text("Reject").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isProcessing)

                    Button {
                        onAction(true)
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Accept")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isProcessing)
                }
            }
        }
        .padding(16)
        // Read rows appear dull; unread are bright.
        .opacity(isUnread ? 1.0 : 0.7)
        // Unread: full card tinted in the category color. Read: plain gray.
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isUnread ? accent.opacity(0.15) : Color(.systemGray6).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnread ? accent.opacity(0.5) : Color(.systemGray5), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var categoryChip: some View {
        Text(category)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(effectiveAccent)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(effectiveAccent.opacity(0.15))
            .clipShape(Capsule())
    }

    @ViewBuilder private var statusPill: some View {
        switch interest.status.lowercased() {
        case "accepted":
            pill("Accepted", .green)
        case "rejected":
            pill("Rejected", .red)
        default:
            EmptyView()
        }
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2).fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func relativeTime(_ iso: String) -> String {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = withFraction.date(from: iso) ?? plain.date(from: iso) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NotificationsView()
}

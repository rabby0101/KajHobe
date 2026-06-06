import SwiftUI
import Supabase

struct MessagesView: View {
    @State private var conversations: [ConversationWithDetails] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentUserProfile: Profile?
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var timeUpdateTimer: Timer?
    @ObservedObject private var messageBadgeManager = MessageBadgeManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    VStack {
                        ProgressView("Loading conversations...")
                        Text("Debug: Loading state is \(String(isLoading))")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    .onAppear {
                        print("🔍 UI DEBUG: MessagesView is showing loading state")
                    }
                } else if conversations.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "message.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("No Conversations Yet")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Start by showing interest in jobs or posting your own job to begin conversations with others.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(conversations.indices, id: \.self) { index in
                            if index < conversations.count {
                                let conversation = conversations[index]
                                NavigationLink(destination: ChatView(conversation: conversation)) {
                                    ConversationRow(conversation: conversation)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onAppear {
                                    print("🔍 UI DEBUG: Rendering conversation \(index + 1)/\(conversations.count): \(conversation.id)")
                                }
                            }
                        }
                    }
                    .refreshable {
                        await loadConversations(forceRefresh: true)
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                print("🔍 UI DEBUG: MessagesView.onAppear called")
                Task {
                    print("🔍 UI DEBUG: Starting loadConversations task")
                    await loadConversations()
                    print("🔍 UI DEBUG: loadConversations task completed")
                    
                    // Start real-time subscription after initial load
                    subscribeToMessages()
                    
                    // Start timer to update relative times every minute
                    startTimeUpdateTimer()
                    
                    // Refresh the messages tab badge (in case it drifted while the
                    // app was in the background or conversations changed).
                    await messageBadgeManager.refreshCounts()
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .onDisappear {
                cleanup()
                stopTimeUpdateTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: Foundation.Notification.Name.chatViewDidDisappear)) { _ in
                print("🔍 MESSAGES DEBUG: Received chatViewDidDisappear notification, refreshing conversations")
                Task {
                    await loadConversations(forceRefresh: true)
                    // Re-sync the messages tab badge after returning from a chat —
                    // local optimistic updates may have drifted from the server count.
                    await messageBadgeManager.refreshCounts()
                }
            }
        }
    }
    
    private func loadConversations(forceRefresh: Bool = false) async {
        print("🔍 UI DEBUG: Starting loadConversations, forceRefresh: \(forceRefresh)")
        
        // Set loading state immediately
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Get current user profile
            if currentUserProfile == nil {
                print("🔍 UI DEBUG: Fetching current user profile...")
                currentUserProfile = try await ProfileNetworking.shared.getCurrentUserProfile()
                print("🔍 UI DEBUG: Current user profile fetch completed")
            }
            
            guard let userProfile = currentUserProfile else {
                print("❌ UI DEBUG: Unable to load user profile")
                await MainActor.run {
                    errorMessage = "Unable to load user profile"
                    isLoading = false
                }
                return
            }
            
            print("🔍 UI DEBUG: User profile loaded - id: \(userProfile.id), name: \(userProfile.full_name ?? "N/A")")
            
            // Fetch conversations with timeout protection
            print("🔍 UI DEBUG: About to fetch conversations for userId: \(userProfile.id)")
            
            let fetchedConversations = try await Networking.shared.fetchConversations(
                userId: userProfile.id,
                forceRefresh: forceRefresh
            )
            
            print("🔍 UI DEBUG: Received \(fetchedConversations.count) conversations from networking layer")
            
            await MainActor.run {
                print("🔍 UI DEBUG: About to update UI state with \(fetchedConversations.count) conversations")
                self.conversations = fetchedConversations
                self.isLoading = false
                print("🔍 UI DEBUG: UI updated with \(self.conversations.count) conversations, isLoading: \(self.isLoading)")
            }
        } catch {
            print("❌ UI DEBUG: Error loading conversations: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("🔍 UI DEBUG: Error state set, isLoading: \(self.isLoading)")
            }
        }
    }
    
    private func subscribeToMessages() {
        print("🔍 REALTIME DEBUG: Setting up real-time subscription for messages")
        
        let channel = supabase.realtimeV2.channel("public:messages")
        let insertions = channel.postgresChange(InsertAction.self, table: "messages")
        
        // Store channel for cleanup
        realtimeChannel = channel
        
        Task {
            await channel.subscribe()
            print("🔍 REALTIME DEBUG: Successfully subscribed to messages channel")
            
            for await insertion in insertions {
                await handleNewMessage(insertion)
            }
        }
    }
    
    private func handleNewMessage(_ action: HasRecord) async {
        do {
            print("🔍 REALTIME DEBUG: New message received via real-time")
            
            // Access the record directly (it's already a JSONObject which is [String: AnyJSON])
            let record = action.record
            
            guard let conversationId = record["conversation_id"]?.stringValue,
                  let content = record["content"]?.stringValue,
                  let senderId = record["sender_id"]?.stringValue else {
                print("❌ REALTIME DEBUG: Failed to parse message data from record: \(record)")
                return
            }
            
            print("🔍 REALTIME DEBUG: Processing message for conversation: \(conversationId)")
            
            // Update the conversation list on main actor
            await MainActor.run {
                updateConversationWithNewMessage(
                    conversationId: conversationId,
                    newContent: content,
                    senderId: senderId
                )
            }
        } catch {
            print("❌ REALTIME DEBUG: Error handling new message: \(error)")
        }
    }
    
    private func updateConversationWithNewMessage(conversationId: String, newContent: String, senderId: String) {
        guard let currentUserId = currentUserProfile?.id else { return }
        
        // Find and update the affected conversation
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            var  updatedConversation = conversations[index]
            
            // Update latest message content and time
            let currentTime = ISO8601DateFormatter().string(from: Date())
            let newConversation = ConversationWithDetails(
                id: updatedConversation.id,
                job_id: updatedConversation.job_id,
                client_id: updatedConversation.client_id,
                provider_id: updatedConversation.provider_id,
                job_title: updatedConversation.job_title,
                job_description: newContent, // This shows the latest message
                other_user_name: updatedConversation.other_user_name,
                unread_count: senderId != currentUserId ? updatedConversation.unread_count + 1 : updatedConversation.unread_count,
                created_at: updatedConversation.created_at,
                latest_message_time: currentTime // Set to current time for new messages
            )
            
            // Remove old conversation and add updated one at the top
            conversations.remove(at: index)
            conversations.insert(newConversation, at: 0)
            
            print("✅ REALTIME DEBUG: Updated conversation \(conversationId) with new message")
        }
    }
    
    private func startTimeUpdateTimer() {
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            // Force UI refresh to update relative times
            Task { @MainActor in
                self.conversations = self.conversations // Trigger view update
            }
        }
    }
    
    private func stopTimeUpdateTimer() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
    }
    
    private func cleanup() {
        Task {
            await realtimeChannel?.unsubscribe()
            realtimeChannel = nil
            print("🔍 REALTIME DEBUG: Cleaned up real-time subscription")
        }
    }
}

struct ConversationRow: View {
    let conversation: ConversationWithDetails
    
    // Static formatters to avoid expensive creation on every render
    private static let isoFormatter = ISO8601DateFormatter()
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.job_title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("with \(conversation.other_user_name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if conversation.unread_count > 0 {
                        Text("\(conversation.unread_count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    
                    Text(formatDate(conversation.latest_message_time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(conversation.job_description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Try multiple date parsing strategies
        var date: Date?
        
        // First try with the standard ISO formatter
        date = Self.isoFormatter.date(from: dateString)
        
        // If that fails, try with fractional seconds
        if date == nil {
            let isoFormatterWithFractionalSeconds = ISO8601DateFormatter()
            isoFormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = isoFormatterWithFractionalSeconds.date(from: dateString)
        }
        
        // If still fails, try manual parsing
        if date == nil {
            let manualFormatter = DateFormatter()
            manualFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            date = manualFormatter.date(from: dateString)
        }
        
        // If still fails, try without fractional seconds
        if date == nil {
            let simpleFormatter = DateFormatter()
            simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            date = simpleFormatter.date(from: dateString)
        }
        
        guard let parsedDate = date else {
            print("❌ Failed to parse date: \(dateString)")
            return dateString
        }
        
        let relativeTime = formatRelativeTime(from: parsedDate)
        print("🔍 Date conversion: \(dateString) -> \(relativeTime)")
        return relativeTime
    }
    
    private func formatRelativeTime(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        // Just now (less than 1 minute)
        if timeInterval < 60 {
            return "just now"
        }
        
        // Minutes ago (1-59 minutes)
        let minutes = Int(timeInterval / 60)
        if minutes < 60 {
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        }
        
        // Hours ago (1-23 hours)
        let hours = Int(timeInterval / 3600)
        if hours < 24 {
            return hours == 1 ? "1 h ago" : "\(hours) h ago"
        }
        
        // Days ago (1-6 days)
        let days = Int(timeInterval / 86400)
        if days < 7 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        
        // Weeks ago (1-3 weeks)
        let weeks = Int(timeInterval / 604800)
        if weeks < 4 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }
        
        // More than a month - show actual date
        return Self.dateFormatter.string(from: date)
    }
}

#Preview {
    MessagesView()
}

import SwiftUI
import Supabase
import PhotosUI
import UIKit

extension Foundation.Notification.Name {
    static let chatViewDidDisappear = Foundation.Notification.Name("chatViewDidDisappear")
    static let dealResponseReceived = Foundation.Notification.Name("dealResponseReceived")
}


// MARK: - Chat View
struct ChatView: View {
    let conversation: ConversationWithDetails
    @State private var messages: [ChatMessage] = []
    @State private var newMessageText = ""
    @State private var isLoading = true
    // Current user's id read synchronously from the in-memory session (zero network). Used for
    // "is this my message" checks and as sender id — replaces a networked profiles SELECT that
    // was blocking the message load on open.
    // Lowercased to match Postgres' uuid representation (Swift's uuidString is uppercase).
    // sender_id / participant id comparisons against DB values depend on this.
    @State private var currentUserId: String? = supabase.auth.currentUser?.id.uuidString.lowercased()
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var isSending = false
    
    // Image picker states
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    @State private var selectedImage: UIImage?
    @State private var isUploadingImage = false
    
    // Deal offer states
    @State private var showingDealOfferSheet = false
    @State private var isSendingDealOffer = false
    @State private var offerCount = 0
    @State private var hasUnansweredOffer = false
    @State private var isLoadingOfferStatus = true
    @State private var existingDealExists = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack {
                    ProgressView("Loading messages...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "message")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("No Messages Yet")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Start the conversation about '\(conversation.job_title)'")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                }
            } else {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages.indices, id: \.self) { index in
                                let message = messages[index]
                                ChatMessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.sender_id == currentUserId
                                )
                                .id(message.id) // Add ID for ScrollViewReader
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) {
                        // Auto-scroll to bottom when new message arrives
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        // Scroll to bottom on initial load
                        if let lastMessage = messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Professional message input area
            VStack(spacing: 0) {
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                HStack(alignment: .bottom, spacing: 12) {
                    // Action buttons stack
                    HStack(spacing: 8) {
                        // Image attachment button
                        Button {
                            showingActionSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.gray)
                        }
                        .disabled(isUploadingImage || isSending || isSendingDealOffer)
                        
                        // Deal offer button (only for providers)
                        if isCurrentUserProvider() {
                            Button {
                                showingDealOfferSheet = true
                            } label: {
                                ZStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(canSendOffer() ? .green : .gray)
                                    
                                    // Offer counter badge
                                    if offerCount > 0 {
                                        Text("\(offerCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 16, height: 16)
                                            .background(Circle().fill(Color.red))
                                            .offset(x: 10, y: -10)
                                    }
                                }
                            }
                            .disabled(!canSendOffer() || isUploadingImage || isSending || isSendingDealOffer)
                        }
                    }
                    
                    // Text input container with custom styling
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Message", text: $newMessageText, axis: .vertical)
                            .font(.system(size: 16))
                            .lineLimit(1...6)
                            .disabled(isSending || isUploadingImage || isSendingDealOffer)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                            )
                            .onSubmit {
                                if !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending {
                                    Task {
                                        await sendMessage()
                                    }
                                }
                            }
                    }
                    
                    // Professional send button
                    Button {
                        Task {
                            await sendMessage()
                        }
                    } label: {
                        Group {
                            if isSending || isUploadingImage || isSendingDealOffer {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(
                                    (newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUploadingImage || isSendingDealOffer)
                                    ? Color.gray.opacity(0.4)
                                    : Color.blue
                                )
                        )
                    }
                    .disabled(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || isUploadingImage || isSendingDealOffer)
                    .animation(.easeInOut(duration: 0.2), value: newMessageText.isEmpty || isUploadingImage || isSendingDealOffer)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(
                Color(.systemBackground)
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: -1)
            )
        }
        .navigationTitle(conversation.other_user_name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            print("🔍 CHAT DEBUG: ChatView appeared for conversation: \(conversation.id)")
            Task {
                await loadChatData()
                await loadOfferStatus()
                
                // Start real-time subscription after initial load
                subscribeToMessages()
            }
        }
        .onDisappear {
            print("🔍 CHAT DEBUG: ChatView is disappearing for conversation: \(conversation.id)")
            cleanup()
            
            // Trigger a refresh of the conversations list to update unread counts
            NotificationCenter.default.post(name: .chatViewDidDisappear, object: nil)
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Add Photo"),
                buttons: [
                    .default(Text("Camera")) {
                        showingCamera = true
                    },
                    .default(Text("Photo Library")) {
                        showingImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        .onChange(of: selectedImage) {
            if let image = selectedImage {
                Task {
                    await sendImageMessage(image: image)
                }
            }
        }
        .sheet(isPresented: $showingDealOfferSheet) {
            DealOfferSheet(
                conversation: conversation,
                isSending: $isSendingDealOffer,
                currentUserId: currentUserId,
                offerCount: offerCount,
                hasUnansweredOffer: hasUnansweredOffer,
                existingDealExists: existingDealExists,
                onOfferSent: {
                    Task {
                        await loadOfferStatus()
                    }
                }
            )
        }
    }
    
    private func loadChatData() async {
        print("🔍 CHAT DEBUG: Loading chat data for conversation: \(conversation.id)")
        
        do {
            // The current user id is already resolved synchronously from the session, so we go
            // straight to fetching messages — no profile round-trip blocking the chat load.
            let fetchedMessages = try await MessagesNetworking.shared.fetchMessages(
                conversationId: conversation.id
            )
            
            await MainActor.run {
                self.messages = fetchedMessages
                self.isLoading = false
                print("🔍 CHAT DEBUG: Chat data loaded with \(self.messages.count) messages")
                
                // Mark unread messages as read for the current user
                Task {
                    await markMessagesAsRead()
                }
            }
            
        } catch {
            print("❌ CHAT DEBUG: Error loading chat data: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func subscribeToMessages() {
        print("🔍 CHAT REALTIME DEBUG: Setting up real-time subscription for conversation: \(conversation.id)")
        
        let channel = supabase.realtimeV2.channel("public:messages:chat:\(conversation.id)")
        let insertions = channel.postgresChange(InsertAction.self, table: "messages")
        
        // Store channel for cleanup
        realtimeChannel = channel
        
        Task {
            await channel.subscribe()
            print("🔍 CHAT REALTIME DEBUG: Successfully subscribed to messages channel for conversation: \(conversation.id)")
            print("🔍 CHAT REALTIME DEBUG: Starting to listen for insertions...")
            
            for await insertion in insertions {
                print("🔍 CHAT REALTIME DEBUG: *** INSERTION RECEIVED IN CHATVIEW ***")
                await handleNewMessage(insertion)
            }
        }
    }
    
    private func handleNewMessage(_ action: HasRecord) async {
        print("🔍 CHAT REALTIME DEBUG: New message received via real-time")
            
            // Use the exact same approach as MessagesView
            let record = action.record
            
            guard let conversationId = record["conversation_id"]?.stringValue,
                  let messageId = record["id"]?.stringValue,
                  let senderId = record["sender_id"]?.stringValue,
                  let content = record["content"]?.stringValue,
                  let messageType = record["message_type"]?.stringValue,
                  let createdAt = record["created_at"]?.stringValue else {
                print("❌ CHAT REALTIME DEBUG: Failed to parse message data from record: \(record)")
                return
            }
            
            // Only process messages for this specific conversation
            guard conversationId == conversation.id else {
                print("🔍 CHAT REALTIME DEBUG: Message for different conversation (\(conversationId)), ignoring")
                return
            }
            
            print("🔍 CHAT REALTIME DEBUG: Processing new message for current conversation: \(conversationId)")
            
            // Parse negotiation_data if present
            var negotiationData: [String: Any]? = nil
            if let negotiationDataValue = record["negotiation_data"] {
                if let jsonString = negotiationDataValue.stringValue {
                    // If it's a JSON string, parse it
                    if let jsonData = jsonString.data(using: .utf8) {
                        negotiationData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                    }
                } else {
                    // Try to extract from AnyJSON directly
                    switch negotiationDataValue {
                    case .object(let dict):
                        var extractedDict: [String: Any] = [:]
                        for (key, value) in dict {
                            extractedDict[key] = value.value
                        }
                        negotiationData = extractedDict
                    default:
                        negotiationData = nil
                    }
                }
            }
            
            print("🔍 CHAT REALTIME DEBUG: Parsed negotiation_data: \(negotiationData ?? [:])")
            
            // Create the new message using the same approach as MessagesView
            let newMessage = ChatMessage(
                id: messageId,
                conversation_id: conversationId,
                sender_id: senderId,
                content: content,
                message_type: messageType,
                attachment_url: record["attachment_url"]?.stringValue,
                negotiation_data: negotiationData,
                read_at: record["read_at"]?.stringValue,
                created_at: createdAt,
                updated_at: record["updated_at"]?.stringValue
            )
            
            // Update the messages list on main actor
            await MainActor.run {
                // Check if message already exists to avoid duplicates
                if !messages.contains(where: { $0.id == newMessage.id }) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        messages.append(newMessage)
                    }
                    print("✅ CHAT REALTIME DEBUG: Added new message to chat. Total messages: \(messages.count)")
                    print("✅ CHAT REALTIME DEBUG: New message content: '\(newMessage.content)'")
                    
                    // If this is a deal_response message, notify deal offer bubbles to refresh their status
                    if newMessage.message_type == "deal_response" {
                        print("🔍 DEAL RESPONSE REALTIME DEBUG: Deal response received, posting notification")
                        let dealOfferId = newMessage.negotiation_data?["original_deal_offer_id"] as? String
                        NotificationCenter.default.post(
                            name: .dealResponseReceived, 
                            object: nil, 
                            userInfo: ["dealOfferId": dealOfferId ?? ""]
                        )
                    }
                    
                    // Mark the new message as read if it's not from the current user
                    if newMessage.sender_id != currentUserId {
                        Task {
                            await markMessageAsRead(messageId: newMessage.id)
                        }
                    }
                } else {
                    print("🔍 CHAT REALTIME DEBUG: Message already exists, skipping duplicate")
                }
        }
    }
    
    private func markMessagesAsRead() async {
        guard let currentUserId = currentUserId else {
            print("❌ READ RECEIPT DEBUG: No current user id")
            return
        }
        
        // Find unread messages that are not from the current user
        let unreadMessages = messages.filter { message in
            message.sender_id != currentUserId && message.read_at == nil
        }
        
        guard !unreadMessages.isEmpty else {
            print("🔍 READ RECEIPT DEBUG: No unread messages to mark as read")
            return
        }
        
        print("🔍 READ RECEIPT DEBUG: Marking \(unreadMessages.count) messages as read using batch update")
        
        // Use batch update to mark all unread messages as read at once
        // This will properly trigger the database's unread count management
        await markAllUnreadMessagesAsRead(conversationId: conversation.id, currentUserId: currentUserId)
    }
    
    private func markAllUnreadMessagesAsRead(conversationId: String, currentUserId: String) async {
        do {
            // Count how many we're about to mark so we can decrement the
            // messages tab badge by the same number (optimistic local update).
            let unreadCount = messages.filter { $0.sender_id != currentUserId && $0.read_at == nil }.count

            let currentTime = ISO8601DateFormatter().string(from: Date())

            // Batch update all unread messages in this conversation that are NOT from the current user
            // This will trigger the database's automatic unread count management
            let result = try await supabase
                .from("messages")
                .update(["read_at": currentTime])
                .eq("conversation_id", value: conversationId)
                .neq("sender_id", value: currentUserId) // Not from current user
                .is("read_at", value: nil) // Only unread messages
                .execute()

            print("✅ READ RECEIPT DEBUG: Batch marked messages as read for conversation \(conversationId) at \(currentTime)")
            print("🔍 READ RECEIPT DEBUG: Database update result: \(result)")

            // Decrement the messages tab badge by however many we just marked read.
            // Clamped to 0 inside the manager.
            MessageBadgeManager.shared.decrement(by: unreadCount)
        } catch {
            print("❌ READ RECEIPT DEBUG: Error batch marking messages as read: \(error)")
        }
    }
    
    private func markMessageAsRead(messageId: String) async {
        do {
            let currentTime = ISO8601DateFormatter().string(from: Date())

            // Update only if read_at is currently NULL (not already read)
            let _ = try await supabase
                .from("messages")
                .update(["read_at": currentTime])
                .eq("id", value: messageId)
                .is("read_at", value: nil) // Only update if not already read
                .execute()

            print("✅ READ RECEIPT DEBUG: Marked message \(messageId) as read at \(currentTime)")

            // The chat is open and just read a single new incoming message —
            // decrement the messages tab badge by 1.
            MessageBadgeManager.shared.decrement(by: 1)
        } catch {
            print("❌ READ RECEIPT DEBUG: Error marking message as read: \(error)")
        }
    }
    
    private func sendImageMessage(image: UIImage) async {
        guard let currentUserId = currentUserId else {
            print("❌ SEND IMAGE DEBUG: No current user id")
            return
        }
        
        print("🔍 SEND IMAGE DEBUG: Starting image upload process")
        
        isUploadingImage = true
        
        do {
            // Upload image to Supabase Storage and send message
            try await MessagesNetworking.shared.sendImageMessage(
                conversationId: conversation.id,
                image: image,
                senderId: currentUserId
            )
            
            print("✅ SEND IMAGE DEBUG: Image message sent successfully")
            
        } catch {
            print("❌ SEND IMAGE DEBUG: Failed to send image: \(error)")
            // TODO: Show error alert to user
        }
        
        await MainActor.run {
            selectedImage = nil // Reset selected image
            isUploadingImage = false
        }
    }
    
    private func sendMessage() async {
        let trimmedText = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty,
              let currentUserId = currentUserId else {
            print("❌ SEND MESSAGE DEBUG: Cannot send - invalid text or user")
            return
        }
        
        print("🔍 SEND MESSAGE DEBUG: Sending message: '\(trimmedText)'")
        
        isSending = true
        
        do {
            // Send message via networking layer
            try await MessagesNetworking.shared.sendMessage(
                conversationId: conversation.id,
                content: trimmedText,
                senderId: currentUserId
            )
            
            // Clear the text field on successful send
            await MainActor.run {
                newMessageText = ""
                print("✅ SEND MESSAGE DEBUG: Message sent successfully")
            }
            
        } catch {
            print("❌ SEND MESSAGE DEBUG: Failed to send message: \(error)")
            // TODO: Show error alert to user
        }
        
        await MainActor.run {
            isSending = false
        }
    }
    
    private func loadOfferStatus() async {
        guard let currentUserId = currentUserId else {
            await MainActor.run {
                isLoadingOfferStatus = false
            }
            return
        }

        do {
            // The existing-deal check and the offer-status lookup are independent — run them
            // concurrently so the offer bar resolves in ~one round-trip instead of two.
            async let existingDeal: Void = checkExistingDeal()
            async let offerStatus = MessagesNetworking.shared.getOfferStatus(
                conversationId: conversation.id,
                providerId: currentUserId
            )

            _ = await existingDeal
            let status = try await offerStatus

            await MainActor.run {
                offerCount = status.totalOffers
                hasUnansweredOffer = status.hasUnansweredOffer
                isLoadingOfferStatus = false
                print("🔍 OFFER STATUS DEBUG: Loaded - Count: \(offerCount), Unanswered: \(hasUnansweredOffer), ExistingDeal: \(existingDealExists)")
            }
        } catch {
            print("❌ OFFER STATUS DEBUG: Failed to load offer status: \(error)")
            await MainActor.run {
                isLoadingOfferStatus = false
            }
        }
    }
    
    private func checkExistingDeal() async {
        do {
            // Check if any deal exists for this job (following the One job → One deal rule)
            let existingDealsData = try await supabase
                .from("deals")
                .select("id")
                .eq("job_id", value: conversation.job_id)
                .execute()
            
            if let existingDealsResponse = try? JSONSerialization.jsonObject(with: existingDealsData.data) as? [[String: Any]] {
                let dealExists = !existingDealsResponse.isEmpty
                await MainActor.run {
                    existingDealExists = dealExists
                    print("🔍 EXISTING DEAL DEBUG: Deal exists for job \(conversation.job_id): \(dealExists)")
                }
            }
        } catch {
            print("❌ EXISTING DEAL DEBUG: Failed to check existing deals: \(error)")
        }
    }
    
    private func canSendOffer() -> Bool {
        return !isLoadingOfferStatus && !existingDealExists && offerCount < 2 && !hasUnansweredOffer
    }
    
    private func isCurrentUserProvider() -> Bool {
        guard currentUserId != nil else { return false }
        
        // In the conversation structure, determine if current user is provider
        // This can be determined by checking the conversation's provider_id
        // For now, we'll use a simple approach - if the current user is NOT the client, they're the provider
        // You might want to add provider_id to the ConversationWithDetails model for more explicit checking
        
        return true // For now, allow all users to send offers - the backend validation will handle the actual restriction
    }
    
    private func cleanup() {
        Task {
            await realtimeChannel?.unsubscribe()
            realtimeChannel = nil
            print("🔍 CHAT REALTIME DEBUG: Cleaned up real-time subscription for conversation: \(conversation.id)")
        }
    }
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                if message.message_type == "deal_offer" {
                    // Deal offer message bubble
                    DealOfferBubble(message: message, isFromCurrentUser: isFromCurrentUser)
                } else if message.message_type == "image" {
                    // Image message bubble
                    VStack(spacing: 4) {
                        if let imageURL = message.attachment_url, let url = URL(string: imageURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: 200, maxHeight: 200)
                                    .clipped()
                                    .cornerRadius(12)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 200, height: 150)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    )
                            }
                        } else {
                            // Fallback if no image URL
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 200, height: 150)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 24))
                                            .foregroundColor(.gray)
                                        Text("Image unavailable")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                        
                        // Caption for image if content is not just the emoji
                        if message.content != "📸 Photo" && !message.content.isEmpty {
                            Text(message.content)
                                .font(.system(size: 14))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundColor(.primary)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(.systemBackground))
                            .shadow(
                                color: .black.opacity(0.1), 
                                radius: 2, 
                                x: 0, 
                                y: 1
                            )
                    )
                } else {
                    // Regular text message bubble
                    Text(message.content)
                        .font(.system(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    isFromCurrentUser 
                                    ? Color.blue
                                    : Color(.systemGray5)
                                )
                                .shadow(
                                    color: .black.opacity(0.05), 
                                    radius: 1, 
                                    x: 0, 
                                    y: 1
                                )
                        )
                        .foregroundColor(
                            isFromCurrentUser ? .white : .primary
                        )
                }
                
                Text(formatMessageTime(message.created_at))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 280, alignment: isFromCurrentUser ? .trailing : .leading)
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }
    
    private func formatMessageTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return ""
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - Deal Offer Bubble
struct DealOfferBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    // Current user's id from the in-memory session (zero network) — replaces a profiles SELECT
    // that was previously fetched just to read the id when responding to a deal.
    private let currentUserId: String? = supabase.auth.currentUser?.id.uuidString.lowercased()
    @State private var dealStatus: String = "pending" // pending, accepted, rejected
    // Accept-and-pay: the client must pay into escrow to accept, which is what creates the deal.
    @State private var isPaying: Bool = false
    @State private var payError: String?
    @State private var checkoutSession: BkashCheckoutSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, title, and status indicator
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text("Deal Offer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Status indicator
                statusIndicatorView
            }
            
            // Deal details from negotiation_data
            if let negotiationData = message.negotiation_data {
                VStack(alignment: .leading, spacing: 8) {
                    // Amount
                    if let amount = negotiationData["amount"] as? Int {
                        let amountDollars = Double(amount)
                        HStack {
                            Text("Amount:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.0f", amountDollars))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Terms
                    if let terms = negotiationData["terms"] as? String, !terms.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Terms & Conditions:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(terms)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Timeline
                    if let timeline = negotiationData["timeline"] as? String, !timeline.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(timeline)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Additional message
                    if let additionalMessage = negotiationData["additional_message"] as? String, !additionalMessage.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(additionalMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            // Accept & Pay / Reject are done via long-press (context menu). Surface a
            // payment error inline only if a checkout attempt failed, and a subtle
            // "opening bKash" hint while a checkout is in flight.
            if !isFromCurrentUser && dealStatus == "pending" {
                if isPaying {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.8)
                        Text("Opening bKash…").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                } else if let payError {
                    Text(payError).font(.system(size: 12)).foregroundColor(.red)
                }
            }

            // Status text
            if dealStatus != "pending" {
                HStack {
                    statusIcon
                    Text(dealStatus == "accepted" ? "Deal Accepted" : "Deal Rejected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(dealStatus == "accepted" ? .green : .red)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
        .frame(maxWidth: 300, alignment: .leading)
        .contextMenu {
            // Context menu only for received offers and pending status
            if !isFromCurrentUser && dealStatus == "pending" {
                Button {
                    acceptAndPay()
                } label: {
                    Label("Accept & Pay", systemImage: "creditcard.fill")
                }
                
                Button {
                    print("🔍 CONTEXT MENU DEBUG: Reject button tapped")
                    Task {
                        await respondToDeal(accept: false)
                    }
                } label: {
                    Label("Reject Offer", systemImage: "xmark.circle.fill")
                }
            } else {
                // Debug info for why context menu isn't showing
                Button("Debug Info") {
                    print("🔍 CONTEXT MENU DEBUG: isFromCurrentUser: \(isFromCurrentUser)")
                    print("🔍 CONTEXT MENU DEBUG: dealStatus: \(dealStatus)")
                }
            }
        }
        .onAppear {
            Task {
                await loadDealStatus()
            }
        }
        .task {
            // Also run when the view is created (for real-time messages)
            await loadDealStatus()
        }
        .onChange(of: message.id) {
            // Reload status when message changes (covers negotiation data updates)
            Task {
                await loadDealStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dealResponseReceived)) { notification in
            // Check if this notification is for our deal offer
            if let notificationDealOfferId = notification.userInfo?["dealOfferId"] as? String,
               let ourDealOfferId = message.negotiation_data?["deal_offer_id"] as? String,
               notificationDealOfferId == ourDealOfferId {
                print("🔍 DEAL BUBBLE REALTIME DEBUG: Received deal response notification for our offer")
                Task {
                    await loadDealStatus()
                }
            }
        }
    }
    
    // MARK: - Status Indicator Views
    @ViewBuilder
    private var statusIndicatorView: some View {
        Group {
            switch dealStatus {
            case "accepted":
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            case "rejected":
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            default:
                Image(systemName: "clock.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
            }
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        Group {
            switch dealStatus {
            case "accepted":
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            case "rejected":
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Card Styling
    private var cardBackgroundColor: Color {
        switch dealStatus {
        case "accepted":
            return isFromCurrentUser ? Color.green.opacity(0.1) : Color.green.opacity(0.05)
        case "rejected":
            return isFromCurrentUser ? Color.red.opacity(0.1) : Color.red.opacity(0.05)
        default:
            return isFromCurrentUser ? Color.blue.opacity(0.1) : Color(.systemGray6)
        }
    }
    
    private var cardBorderColor: Color {
        switch dealStatus {
        case "accepted":
            return Color.green.opacity(0.4)
        case "rejected":
            return Color.red.opacity(0.4)
        default:
            return isFromCurrentUser ? Color.blue.opacity(0.3) : Color.green.opacity(0.3)
        }
    }
    
    // MARK: - Functions
    private func loadDealStatus() async {
        // Check if this deal offer has been responded to by looking for deal_offer_id
        // in the negotiation_data or by checking the deal_offers table
        guard let negotiationData = message.negotiation_data,
              let dealOfferId = negotiationData["deal_offer_id"] as? String else {
            return
        }
        
        do {
            // Query the deal_offers table to get the current status
            let result = try await supabase
                .from("deal_offers")
                .select("status")
                .eq("id", value: dealOfferId)
                .single()
                .execute()
            
            let data = result.data
            if let statusValue = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = statusValue["status"] as? String {
                await MainActor.run {
                    dealStatus = status
                }
            }
        } catch {
            print("❌ DEAL STATUS DEBUG: Failed to load deal status: \(error)")
        }
    }
    
    private func respondToDeal(accept: Bool) async {
        print("🔍 DEAL RESPONSE DEBUG: respondToDeal called with accept: \(accept)")
        print("🔍 DEAL RESPONSE DEBUG: Current user id: \(currentUserId ?? "nil")")
        print("🔍 DEAL RESPONSE DEBUG: Negotiation data: \(message.negotiation_data ?? [:])")

        guard let currentUserId = currentUserId else {
            print("❌ DEAL RESPONSE DEBUG: No current user ID")
            return
        }
        
        guard let negotiationData = message.negotiation_data else {
            print("❌ DEAL RESPONSE DEBUG: No negotiation data")
            return
        }
        
        guard let dealOfferId = negotiationData["deal_offer_id"] as? String else {
            print("❌ DEAL RESPONSE DEBUG: No deal_offer_id in negotiation data")
            print("🔍 DEAL RESPONSE DEBUG: Available keys: \(Array(negotiationData.keys))")
            return
        }
        
        print("🔍 DEAL RESPONSE DEBUG: All required data available - proceeding with response")
        print("🔍 DEAL RESPONSE DEBUG: Deal Offer ID: \(dealOfferId)")
        print("🔍 DEAL RESPONSE DEBUG: Conversation ID: \(message.conversation_id)")
        
        do {
            try await MessagesNetworking.shared.respondToDealOffer(
                dealOfferId: dealOfferId,
                conversationId: message.conversation_id,
                accept: accept,
                senderId: currentUserId
            )
            
            await MainActor.run {
                dealStatus = accept ? "accepted" : "rejected"
                print("✅ DEAL RESPONSE DEBUG: Updated UI status to: \(dealStatus)")
            }
            
            print("✅ DEAL RESPONSE DEBUG: Deal response sent successfully")
            
        } catch {
            print("❌ DEAL RESPONSE DEBUG: Failed to respond to deal: \(error)")
            if let nsError = error as NSError? {
                print("❌ DEAL RESPONSE DEBUG: Error domain: \(nsError.domain)")
                print("❌ DEAL RESPONSE DEBUG: Error code: \(nsError.code)")
                print("❌ DEAL RESPONSE DEBUG: Error description: \(nsError.localizedDescription)")
            }
        }
    }

    /// Accept the offer by paying its amount into escrow. The bKash capture is what
    /// flips the offer to accepted and creates the deal (server-side). No payment → no deal.
    private func acceptAndPay() {
        guard let negotiationData = message.negotiation_data,
              let dealOfferId = negotiationData["deal_offer_id"] as? String else {
            payError = "This offer can't be paid (missing offer id)."
            return
        }
        Task {
            await MainActor.run { isPaying = true; payError = nil }
            do {
                let url = try await EscrowNetworking.shared.startCollection(dealOfferId: dealOfferId)
                let session = BkashCheckoutSession()
                await MainActor.run { self.checkoutSession = session }
                session.start(url: url, scheme: "kajhobe") { result in
                    Task { @MainActor in
                        self.checkoutSession = nil
                        if case .success(let callback) = result {
                            let status = BkashCheckoutSession.status(from: callback)
                            if status == "success" {
                                self.dealStatus = "accepted"
                            } else {
                                self.payError = "Payment not completed (\(status ?? "cancelled"))."
                            }
                        }
                        self.isPaying = false
                        await self.loadDealStatus()
                    }
                }
            } catch {
                await MainActor.run {
                    self.payError = error.localizedDescription
                    self.isPaying = false
                }
            }
        }
    }
}

// MARK: - Deal Offer Sheet
struct DealOfferSheet: View {
    let conversation: ConversationWithDetails
    @Binding var isSending: Bool
    let currentUserId: String?
    let offerCount: Int
    let hasUnansweredOffer: Bool
    let existingDealExists: Bool
    let onOfferSent: () -> Void
    
    @State private var amount: String = ""
    @State private var terms: String = ""
    @State private var timeline: String = ""
    @State private var additionalMessage: String = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Offer Status Section
                Section(header: Text("Offer Status")) {
                    HStack {
                        Text("Offers Sent:")
                        Spacer()
                        Text("\(offerCount)/2")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(offerCount >= 2 ? .red : .primary)
                    }
                    
                    if hasUnansweredOffer {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("Waiting for client response")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                        }
                    }
                    
                    if offerCount >= 2 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Maximum offers reached")
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                        }
                    }
                    
                    if existingDealExists {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("A deal already exists for this job")
                                .foregroundColor(.green)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                }
                
                Section(header: Text("Deal Details")) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$")
                        TextField("0", text: $amount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terms & Conditions")
                            .font(.system(size: 16, weight: .medium))
                        TextField("e.g., 4 hours work, materials included", text: $terms, axis: .vertical)
                            .lineLimit(1...3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration/Timeline")
                            .font(.system(size: 16, weight: .medium))
                        TextField("e.g., 2 days, completed by Friday", text: $timeline, axis: .vertical)
                            .lineLimit(1...2)
                    }
                }
                
                Section(header: Text("Additional Message")) {
                    TextField("Optional message with this offer...", text: $additionalMessage, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section {
                    Button {
                        Task {
                            await sendDealOffer()
                        }
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Sending Offer...")
                            } else {
                                Image(systemName: "dollarsign.circle.fill")
                                Text("Send Deal Offer")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(amount.isEmpty || isSending || hasUnansweredOffer || offerCount >= 2 || existingDealExists)
                }
            }
            .navigationTitle("Create Deal Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSending)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
    
    private func sendDealOffer() async {
        guard let currentUserId = currentUserId,
              let amountDouble = Double(amount) else {
            print("❌ DEAL OFFER DEBUG: Invalid amount or no user id")
            return
        }
        
        let amount = Int(amountDouble)
        
        print("🔍 DEAL OFFER DEBUG: Sending deal offer")
        
        isSending = true
        
        do {
            try await MessagesNetworking.shared.sendDealOffer(
                conversationId: conversation.id,
                amount: amount,
                terms: terms.isEmpty ? nil : terms,
                timeline: timeline.isEmpty ? nil : timeline,
                additionalMessage: additionalMessage.isEmpty ? nil : additionalMessage,
                senderId: currentUserId
            )
            
            print("✅ DEAL OFFER DEBUG: Deal offer sent successfully")
            
            await MainActor.run {
                onOfferSent() // Refresh offer status
                dismiss()
            }
            
        } catch {
            print("❌ DEAL OFFER DEBUG: Failed to send deal offer: \(error)")
            
            await MainActor.run {
                if let nsError = error as NSError? {
                    errorMessage = nsError.localizedDescription
                } else {
                    errorMessage = "Failed to send deal offer. Please try again."
                }
                showingError = true
            }
        }
        
        await MainActor.run {
            isSending = false
        }
    }
}

// MARK: - Image Picker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            conversation: ConversationWithDetails(
                id: "preview-id",
                job_id: "job-id",
                client_id: "client-id",
                provider_id: "provider-id",
                job_title: "Need help with iOS app",
                job_description: "Looking for an experienced iOS developer",
                other_user_name: "John Doe",
                unread_count: 3,
                created_at: "2024-01-15T10:30:00Z",
                latest_message_time: "2024-01-15T10:45:00Z"
            )
        )
    }
}

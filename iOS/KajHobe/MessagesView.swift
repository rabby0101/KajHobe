import SwiftUI
import Supabase

/// Which conversations the "All / Unread" pill row is filtering to.
enum ConversationFilter: CaseIterable {
    case all
    case unread

    var title: String {
        switch self {
        case .all: return "All"
        case .unread: return "Unread"
        }
    }
}

struct MessagesView: View {
    @State private var conversations: [ConversationWithDetails] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    // Current user's id read synchronously from the in-memory session (zero network) — used to
    // resolve "which side am I" in the realtime handler. Replaces a networked profiles SELECT.
    // Lowercased to match Postgres' uuid representation (Swift's uuidString is uppercase, DB ids
    // are lowercase). String comparisons against client_id/provider_id/sender_id depend on this.
    @State private var currentUserId: String? = supabase.auth.currentUser?.id.uuidString.lowercased()
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var timeUpdateTimer: Timer?
    // Coalesce overlapping loads (onAppear + refreshable + chatViewDidDisappear can fire together).
    @State private var isLoadingConversations = false
    @ObservedObject private var messageBadgeManager = MessageBadgeManager.shared

    // Redesign state: live search text, the active All/Unread pill, and whether the
    // Archived sheet is presented.
    @State private var searchText = ""
    @State private var selectedFilter: ConversationFilter = .all
    @State private var showArchived = false

    private let accent = KajHobeDesignSystem.Colors.warmOrange

    // MARK: - Derived lists

    /// Conversations the current user has NOT archived (the universe the main list draws from).
    private var activeConversations: [ConversationWithDetails] {
        guard let uid = currentUserId else { return conversations }
        return conversations.filter { !$0.isArchived(for: uid) }
    }

    /// Conversations the current user HAS archived (powers the Archived sheet + toolbar badge).
    private var archivedConversations: [ConversationWithDetails] {
        guard let uid = currentUserId else { return [] }
        return conversations.filter { $0.isArchived(for: uid) }
    }

    /// Count of active conversations with unread messages — shown on the Unread pill.
    private var unreadConversationCount: Int {
        activeConversations.filter { $0.unread_count > 0 }.count
    }

    /// Final list shown in the main list: active → filtered by pill → filtered by search.
    private var visibleConversations: [ConversationWithDetails] {
        var result = activeConversations

        if selectedFilter == .unread {
            result = result.filter { $0.unread_count > 0 }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { conversation in
                conversation.job_title.lowercased().contains(query) ||
                conversation.other_user_name.lowercased().contains(query) ||
                conversation.job_description.lowercased().contains(query)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if conversations.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        searchBar
                        filterPills
                        conversationList
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showArchived = true
                    } label: {
                        Image(systemName: archivedConversations.isEmpty ? "archivebox" : "archivebox.fill")
                            .foregroundColor(accent)
                    }
                    .accessibilityLabel("Archived conversations")
                }
            }
            .sheet(isPresented: $showArchived) {
                ArchivedConversationsView(
                    conversations: archivedConversations,
                    currentUserId: currentUserId
                ) { conversation in
                    setArchived(conversation, archived: false)
                }
            }
            .onAppear {
                print("🔍 UI DEBUG: MessagesView.onAppear called")
                Task {
                    // Seed instantly from cache (in-memory → disk) so the list paints on the
                    // first frame — even on a cold start — instead of showing a spinner. The
                    // fetch below then refreshes silently in the background.
                    if conversations.isEmpty, let uid = currentUserId {
                        if let cached = ConversationsCache.shared.peek(userId: uid) {
                            print("🔍 UI DEBUG: Seeded \(cached.count) conversations from memory cache")
                            conversations = cached
                        } else if let disk = await ConversationsCache.shared.load(userId: uid) {
                            print("🔍 UI DEBUG: Seeded \(disk.count) conversations from disk cache")
                            conversations = disk
                        }
                    }

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

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            ProgressView("Loading conversations...")
        }
        .onAppear {
            print("🔍 UI DEBUG: MessagesView is showing loading state")
        }
    }

    private var emptyStateView: some View {
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
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search conversations", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var filterPills: some View {
        HStack(spacing: 10) {
            ForEach(ConversationFilter.allCases, id: \.self) { filter in
                pill(for: filter)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func pill(for filter: ConversationFilter) -> some View {
        let isSelected = selectedFilter == filter
        let showBadge = filter == .unread && unreadConversationCount > 0

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Text(filter.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if showBadge {
                    Text("\(unreadConversationCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? accent : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white : accent)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(isSelected ? accent : Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var conversationList: some View {
        Group {
            if visibleConversations.isEmpty {
                noResultsView
            } else {
                List {
                    ForEach(visibleConversations) { conversation in
                        ZStack {
                            // Hide the default NavigationLink chevron/insets for a cleaner row.
                            NavigationLink(destination: ChatView(conversation: conversation)) {
                                EmptyView()
                            }
                            .opacity(0)

                            ConversationRow(conversation: conversation)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                setArchived(conversation, archived: true)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(accent)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadConversations(forceRefresh: true)
                }
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: selectedFilter == .unread ? "checkmark.circle" : "magnifyingglass")
                .font(.system(size: 52))
                .foregroundColor(.gray.opacity(0.5))
            Text(noResultsMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var noResultsMessage: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No conversations match your search."
        }
        if selectedFilter == .unread {
            return "You're all caught up — no unread messages."
        }
        return "No conversations to show."
    }

    // MARK: - Archive

    /// Optimistically flips the current user's archive flag, then persists it. On failure we
    /// reload from the server to undo the optimistic change.
    private func setArchived(_ conversation: ConversationWithDetails, archived: Bool) {
        guard let uid = currentUserId else { return }
        let isClient = conversation.client_id.lowercased() == uid.lowercased()

        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            withAnimation {
                conversations[index] = conversation.settingArchived(forClient: isClient, archived)
            }
        }

        Task {
            do {
                try await Networking.shared.setConversationArchived(
                    conversationId: conversation.id,
                    userId: uid,
                    isClient: isClient,
                    archived: archived
                )
                if let uid = currentUserId {
                    ConversationsCache.shared.save(conversations, userId: uid)
                }
            } catch {
                print("❌ ARCHIVE DEBUG: Failed to set archived=\(archived): \(error)")
                await loadConversations(forceRefresh: true)
            }
        }
    }

    // MARK: - Loading

    private func loadConversations(forceRefresh: Bool = false) async {
        // Coalesce overlapping triggers (onAppear / refreshable / chatViewDidDisappear) so they
        // don't race and cancel each other's in-flight queries.
        if isLoadingConversations {
            print("🔍 UI DEBUG: loadConversations already in flight — skipping")
            return
        }
        isLoadingConversations = true
        defer { isLoadingConversations = false }

        print("🔍 UI DEBUG: Starting loadConversations, forceRefresh: \(forceRefresh)")

        // Silent refresh: only show the blocking spinner on a genuine first load (nothing to show
        // yet). On revisits the existing list stays on screen and the fetch runs in the background,
        // swapping in fresh data when it returns — no "blink to blank" flash.
        await MainActor.run {
            if conversations.isEmpty {
                isLoading = true
            }
            errorMessage = nil
        }

        do {
            // Resolve the signed-in user id from the in-memory session (no network round-trip).
            guard let userId = supabase.auth.currentUser?.id.uuidString.lowercased() else {
                print("❌ UI DEBUG: Unable to load user profile")
                await MainActor.run {
                    errorMessage = "Unable to load user profile"
                    isLoading = false
                }
                return
            }
            currentUserId = userId

            print("🔍 UI DEBUG: About to fetch conversations for userId: \(userId)")

            let fetchedConversations = try await Networking.shared.fetchConversations(
                userId: userId,
                forceRefresh: forceRefresh
            )

            print("🔍 UI DEBUG: Received \(fetchedConversations.count) conversations from networking layer")

            await MainActor.run {
                print("🔍 UI DEBUG: About to update UI state with \(fetchedConversations.count) conversations")
                self.conversations = fetchedConversations
                self.isLoading = false
                print("🔍 UI DEBUG: UI updated with \(self.conversations.count) conversations, isLoading: \(self.isLoading)")
            }

            // Persist for instant paint on the next visit / cold start (in-memory + disk).
            ConversationsCache.shared.save(fetchedConversations, userId: userId)
        } catch is CancellationError {
            // A newer load superseded this one (e.g. pull-to-refresh during onAppear). Benign.
            print("🔍 UI DEBUG: loadConversations cancelled — ignoring")
        } catch let urlError as URLError where urlError.code == .cancelled {
            print("🔍 UI DEBUG: loadConversations URL request cancelled (-999) — ignoring")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("🔍 UI DEBUG: loadConversations cancelled (-999) — ignoring")
            } else {
                print("❌ UI DEBUG: Error loading conversations: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("🔍 UI DEBUG: Error state set, isLoading: \(self.isLoading)")
                }
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
        guard let currentUserId = currentUserId else { return }

        // Find and update the affected conversation
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            let updatedConversation = conversations[index]

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
                other_user_avatar: updatedConversation.other_user_avatar,
                unread_count: senderId != currentUserId ? updatedConversation.unread_count + 1 : updatedConversation.unread_count,
                created_at: updatedConversation.created_at,
                latest_message_time: currentTime, // Set to current time for new messages
                client_archived: updatedConversation.client_archived,
                provider_archived: updatedConversation.provider_archived
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

    private let accent = KajHobeDesignSystem.Colors.warmOrange

    // Static formatters to avoid expensive creation on every render
    private static let isoFormatter = ISO8601DateFormatter()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.other_user_name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(formatDate(conversation.latest_message_time))
                        .font(.caption)
                        .foregroundColor(conversation.unread_count > 0 ? accent : .secondary)
                }

                Text(conversation.job_title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(alignment: .center, spacing: 8) {
                    Text(conversation.job_description)
                        .font(.subheadline)
                        .foregroundColor(conversation.unread_count > 0 ? .primary : .secondary)
                        .fontWeight(conversation.unread_count > 0 ? .medium : .regular)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if conversation.unread_count > 0 {
                        Text("\(conversation.unread_count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: 20)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var avatar: some View {
        Group {
            if let avatarUrl = conversation.other_user_avatar, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 0.5))
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(accent.opacity(0.18))
            .overlay(
                Text(String(conversation.other_user_name.prefix(1)).uppercased())
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(accent)
            )
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
            return dateString
        }

        return formatRelativeTime(from: parsedDate)
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

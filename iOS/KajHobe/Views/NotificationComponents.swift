import SwiftUI

// MARK: - 3D Stacked Notification Card Components

/// A 3D stacked notification card that matches the reference design
struct StackedNotificationCard: View {
    let notification: EnhancedNotification
    let stackIndex: Int
    let maxStackCount: Int = 3
    let onAction: (String) -> Void
    
    @State private var isAnimating = false
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            // Background cards (stacked effect)
            if stackIndex < maxStackCount {
                ForEach(1..<min(maxStackCount, stackIndex + 3), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(height: 120)
                        .offset(y: CGFloat(index * 2))
                        .scaleEffect(1.0 - CGFloat(index) * 0.02)
                        .opacity(0.3 - Double(index) * 0.1)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
            
            // Main notification card
            notificationCardContent
                .offset(dragOffset)
                .scaleEffect(isAnimating ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAnimating)
                .animation(.interactiveSpring(), value: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                            
                            // Handle swipe actions if needed
                            if abs(value.translation.width) > 100 {
                                handleSwipeAction(value.translation.width > 0 ? "right" : "left")
                            }
                        }
                )
        }
        .padding(.horizontal, 16)
    }
    
    private var notificationCardContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // User avatar or notification icon
                notificationAvatar
                
                // Notification content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Blue dot for unread notifications
                        if notification.isUnread {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    Text(notification.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            
            // Interactive actions (if applicable)
            if notification.isInteractive, let actions = notification.action_data?.actions {
                actionButtons(actions)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                Spacer()
                    .frame(height: 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
        .frame(minHeight: 100)
    }
    
    private var notificationAvatar: some View {
        Group {
            if let avatarUrl = notification.avatar_url, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    defaultNotificationIcon
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                defaultNotificationIcon
            }
        }
    }
    
    private var defaultNotificationIcon: some View {
        ZStack {
            Circle()
                .fill(notificationIconBackground)
                .frame(width: 44, height: 44)
            
            Image(systemName: notificationIconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(notificationIconColor)
        }
    }
    
    private var notificationIconName: String {
        switch notification.type {
        case "interest_request":
            return "person.wave.2"
        case "deal_created":
            return "hands.sparkles"
        case "completion_request":
            return "checkmark.circle"
        default:
            return "bell"
        }
    }
    
    private var notificationIconBackground: Color {
        switch notification.priority {
        case .high:
            return Color.red.opacity(0.1)
        case .normal:
            return Color.blue.opacity(0.1)
        case .low:
            return Color.gray.opacity(0.1)
        }
    }
    
    private var notificationIconColor: Color {
        switch notification.priority {
        case .high:
            return Color.red
        case .normal:
            return Color.blue
        case .low:
            return Color.gray
        }
    }
    
    private func actionButtons(_ actions: [NotificationAction]) -> some View {
        HStack(spacing: 12) {
            ForEach(actions.indices, id: \.self) { index in
                let action = actions[index]
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAnimating = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isAnimating = false
                        onAction(action.type)
                    }
                } label: {
                    Text(action.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(actionTextColor(action.style))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(actionBackgroundColor(action.style))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding(.top, 12)
    }
    
    private func actionTextColor(_ style: String) -> Color {
        switch style {
        case "primary":
            return .white
        case "secondary":
            return .blue
        case "destructive":
            return .red
        default:
            return .primary
        }
    }
    
    private func actionBackgroundColor(_ style: String) -> Color {
        switch style {
        case "primary":
            return .blue
        case "secondary":
            return Color.blue.opacity(0.1)
        case "destructive":
            return Color.red.opacity(0.1)
        default:
            return Color.gray.opacity(0.1)
        }
    }
    
    private func handleSwipeAction(_ direction: String) {
        // Handle swipe gestures for quick actions
        print("Swiped \(direction) on notification \(notification.id)")
    }
}

// MARK: - Time Section Header

struct NotificationTimeSectionHeader: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("View All") {
                // Handle view all action
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Notification Tab Selector

struct NotificationTabSelector: View {
    @Binding var selectedTab: NotificationState
    let counts: (unread: Int, read: Int, archived: Int)
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach([NotificationState.unread, .read, .archived], id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(tabTitle(tab))
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                        
                        if selectedTab == tab {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 2)
                                .transition(.scale)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 16)
    }
    
    private func tabTitle(_ tab: NotificationState) -> String {
        let count: Int
        switch tab {
        case .unread:
            count = counts.unread
        case .read:
            count = counts.read
        case .archived:
            count = counts.archived
        }
        
        let title = tab.rawValue.capitalized
        return count > 0 ? "\(title)" : title
    }
}

// MARK: - Empty State View

struct NotificationEmptyState: View {
    let state: NotificationState
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    private var emptyStateIcon: String {
        switch state {
        case .unread:
            return "bell.slash"
        case .read:
            return "checkmark.circle"
        case .archived:
            return "archivebox"
        }
    }
    
    private var emptyStateTitle: String {
        switch state {
        case .unread:
            return "No new notifications"
        case .read:
            return "No read notifications"
        case .archived:
            return "No archived notifications"
        }
    }
    
    private var emptyStateMessage: String {
        switch state {
        case .unread:
            return "You'll see interest requests and updates here"
        case .read:
            return "Notifications you've read will appear here"
        case .archived:
            return "Archived notifications will appear here"
        }
    }
}

// MARK: - Enhanced Interest Request Notification with Public Profile

/// Enhanced interest request notification that displays public profile information
/// This provides rich context about the service provider when they show interest
struct EnhancedInterestRequestNotification: View {
    let notification: EnhancedNotification
    let onAction: (String) -> Void

    @State private var publicProfile: PublicProfile?
    @State private var isLoadingProfile = false
    @State private var showFullProfile = false

    private let publicProfileNetworking = PublicProfileNetworking()

    var body: some View {
        VStack(spacing: 0) {
            // Standard notification header
            standardNotificationHeader

            // Public profile section (if loaded)
            if let profile = publicProfile {
                profilePreviewSection(profile)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else if isLoadingProfile {
                profileLoadingSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Action buttons
            if notification.isInteractive, let actions = notification.action_data?.actions {
                enhancedActionButtons(actions)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
        .task {
            await loadProviderProfile()
        }
        .sheet(isPresented: $showFullProfile) {
            if let profile = publicProfile {
                PublicProfileDetailView(profile: profile)
            }
        }
    }

    private var standardNotificationHeader: some View {
        HStack(spacing: 12) {
            // Notification icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
            }

            // Notification content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    // Priority indicator
                    if notification.priority == .high {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    } else if notification.isUnread {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(notification.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(notification.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }

    private func profilePreviewSection(_ profile: PublicProfile) -> some View {
        Button(action: { showFullProfile = true }) {
            VStack(spacing: 12) {
                // Separator
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
                    .padding(.horizontal, 0)

                // Profile preview
                HStack(spacing: 12) {
                    // Avatar with online indicator
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: profile.avatar_url ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())

                        if profile.isOnline {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(profile.full_name ?? "Unknown Provider")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            TrustBadge(trustLevel: profile.trustLevelEnum, compact: true)
                        }

                        HStack(spacing: 12) {
                            // Rating
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text(profile.formattedRating)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }

                            // Job count
                            Text(profile.formattedJobCount)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Response time
                            if profile.average_response_time_minutes != nil {
                                Text("• \(profile.responseTimeText) response")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Top service categories
                        if !profile.topServiceCategories.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(profile.topServiceCategories.prefix(2), id: \.self) { category in
                                    Text(category)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }

                                if profile.topServiceCategories.count > 2 {
                                    Text("+\(profile.topServiceCategories.count - 2) more")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Spacer()

                    // View profile indicator
                    VStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .foregroundColor(.blue)

                        Text("View Profile")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var profileLoadingSection: some View {
        VStack(spacing: 12) {
            // Separator
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)

            // Loading skeleton
            HStack(spacing: 12) {
                // Avatar skeleton
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .redacted(reason: .placeholder)

                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 16)
                        .cornerRadius(4)
                        .redacted(reason: .placeholder)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 14)
                        .cornerRadius(4)
                        .redacted(reason: .placeholder)
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private func enhancedActionButtons(_ actions: [NotificationAction]) -> some View {
        HStack(spacing: 12) {
            ForEach(actions, id: \.id) { action in
                Button(action: {
                    onAction(action.id)
                }) {
                    HStack(spacing: 6) {
                        if let systemIcon = action.systemIcon {
                            Image(systemName: systemIcon)
                                .font(.caption)
                        }
                        Text(action.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(buttonForegroundColor(for: action))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(buttonBackgroundColor(for: action))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func buttonBackgroundColor(for action: NotificationAction) -> Color {
        switch action.style {
        case "primary":
            return .blue
        case "danger":
            return .red
        default:
            return Color(.systemGray5)
        }
    }

    private func buttonForegroundColor(for action: NotificationAction) -> Color {
        switch action.style {
        case "primary", "danger":
            return .white
        default:
            return .primary
        }
    }

    private func loadProviderProfile() async {
        guard let providerId = notification.from_user_id else { return }

        isLoadingProfile = true

        do {
            // Try to load public profile summary first for faster display
            publicProfile = try await publicProfileNetworking.fetchPublicProfile(providerId)
        } catch {
            print("❌ Failed to load public profile for \(providerId): \(error)")
        }

        isLoadingProfile = false
    }
}


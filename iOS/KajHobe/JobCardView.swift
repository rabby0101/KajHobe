import SwiftUI
import Auth
import Supabase

// Removed duplicate sensoryFeedback extension to avoid conflicts with SwiftUI's built-in method

struct JobCardView: View {
    let job: Job
    // Bulk data injected by the parent list so the card resolves ownership/status without any
    // per-card network calls. When nil (search/category screens, preview) the card falls back to
    // its own lookups — using the cached `currentUser` (no networked auth.user()).
    private let injectedCurrentUserId: String?
    private let injectedInterestedJobIds: Set<String>?
    private let injectedViewedJobIds: Set<String>?

    @State private var currentUserId: String?
    @State private var jobStatus: JobStatus = .new
    @State private var didMarkViewed = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var isBookmarked = false
    @State private var showingShareSheet = false
    
    // Callback for when job is deleted
    var onJobDeleted: (() -> Void)?
    
    // Callback for when continue chat is pressed (removed for now)
    // var onOpenConversation: ((ConversationWithJob) -> Void)?
    
    // Initialize isOwnJob based on current user check
    @State private var isOwnJob: Bool
    
    enum JobStatus {
        case new
        case viewed
        case interested
        
        var displayText: String {
            switch self {
            case .new:
                return "New"
            case .viewed:
                return "Viewed"
            case .interested:
                return "Interested"
            }
        }
        
        var color: Color {
            switch self {
            case .new:
                return .blue
            case .viewed:
                return .orange
            case .interested:
                return .green
            }
        }
    }
    
    init(job: Job,
         currentUserId: String? = nil,
         interestedJobIds: Set<String>? = nil,
         viewedJobIds: Set<String>? = nil,
         onJobDeleted: (() -> Void)? = nil,
         onOpenConversation: (() -> Void)? = nil) {
        self.job = job
        self.injectedCurrentUserId = currentUserId
        self.injectedInterestedJobIds = interestedJobIds
        self.injectedViewedJobIds = viewedJobIds
        self.onJobDeleted = onJobDeleted
        // Resolve ownership synchronously from the injected or cached user id (no network),
        // so the card is correct from the first frame with no flash.
        let uid = currentUserId ?? supabase.auth.currentUser?.id.uuidString
        self._isOwnJob = State(initialValue: uid != nil && job.client_id.lowercased() == uid!.lowercased())
    }

    /// Status shown in the card badge. Derived reactively from injected bulk data when present
    /// (so it updates as the list's lookups load), otherwise from the per-card `jobStatus` state.
    private var effectiveStatus: JobStatus {
        if let interested = injectedInterestedJobIds, let viewed = injectedViewedJobIds {
            if interested.contains(job.id) { return .interested }
            if viewed.contains(job.id) { return .viewed }
            return .new
        }
        return jobStatus
    }
    
    // Define color schemes for different categories
    private var cardColor: Color {
        switch job.category.lowercased() {
        case let category where category.contains("technology") || category.contains("it"):
            return Color.purple.opacity(0.1)
        case let category where category.contains("home") || category.contains("repair"):
            return Color.blue.opacity(0.1)
        case let category where category.contains("education") || category.contains("tutoring"):
            return Color.green.opacity(0.1)
        case let category where category.contains("design") || category.contains("creative"):
            return Color.orange.opacity(0.1)
        default:
            return Color.cyan.opacity(0.1)
        }
    }
    
    private var accentColor: Color {
        switch job.category.lowercased() {
        case let category where category.contains("technology") || category.contains("it"):
            return Color.purple
        case let category where category.contains("home") || category.contains("repair"):
            return Color.blue
        case let category where category.contains("education") || category.contains("tutoring"):
            return Color.green
        case let category where category.contains("design") || category.contains("creative"):
            return Color.orange
        default:
            return Color.cyan
        }
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text(job.category)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.2))
                .cornerRadius(8)
            
            Spacer()
            
            urgentAndDeleteButtons
        }
    }
    
    @ViewBuilder
    private var urgentAndDeleteButtons: some View {
        HStack(spacing: 8) {
            if job.urgent == true {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("Urgent")
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Delete button for job owners
            if isOwnJob {
                Button(action: {
                    // Add haptic feedback for destructive action
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    @ViewBuilder
    private var jobTitleSection: some View {
        Text(job.title)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .lineLimit(2)
    }
    
    @ViewBuilder
    private var jobDescriptionSection: some View {
        Text(job.description)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(3)
    }
    
    @ViewBuilder
    private var budgetAndLocationSection: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(accentColor)
                Text("৳\(job.budget)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.gray)
                Text(job.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var footerSection: some View {
        HStack {
            Text("Posted \(formatDate(job.created_at ?? ""))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !isOwnJob {
                // Show job status
                HStack(spacing: 4) {
                    Circle()
                        .fill(effectiveStatus.color)
                        .frame(width: 6, height: 6)
                    Text(effectiveStatus.displayText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(effectiveStatus.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(effectiveStatus.color.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("Your Job")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }

    var body: some View {
        NavigationLink(destination: JobDetailView(job: job)) {
            VStack(alignment: .leading, spacing: 12) {
                headerSection

                // Media Preview (if available)
                if let mediaItems = job.media_urls, !mediaItems.isEmpty {
                    CompactMediaPreview(mediaItems: mediaItems)
                }

                jobTitleSection
                jobDescriptionSection
                budgetAndLocationSection
                Divider()
                footerSection
            }
            .padding(16)
            .background(cardColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            // Context menu for enhanced interactions
            if !isOwnJob {
                Button(action: {
                    Task {
                        await toggleBookmark()
                    }
                }) {
                    Label(isBookmarked ? "Remove Bookmark" : "Bookmark Job", 
                          systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
                }
                
                Button(action: {
                    showingShareSheet = true
                }) {
                    Label("Share Job", systemImage: "square.and.arrow.up")
                }
                
                Button(action: {
                    Task {
                        await markJobAsViewed()
                    }
                }) {
                    Label("Mark as Viewed", systemImage: "eye")
                }
            } else {
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Label("Delete Job", systemImage: "trash")
                }
                .foregroundColor(.red)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isOwnJob {
                Button(action: {
                    Task {
                        await toggleBookmark()
                    }
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .tint(isBookmarked ? .orange : .blue)
                
                Button(action: {
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .tint(.green)
            } else {
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                }
                .tint(.red)
            }
        }
        .task {
            // Ownership: resolve from the injected/cached user id — synchronous, no network.
            let uid = injectedCurrentUserId ?? supabase.auth.currentUser?.id.uuidString
            currentUserId = uid
            if let uid = uid {
                isOwnJob = job.client_id.lowercased() == uid.lowercased()
            }
            // Status: if the list injected bulk lookups, `effectiveStatus` already derives it with
            // zero queries. Only fall back to per-card lookups when no bulk data was provided.
            if injectedInterestedJobIds == nil || injectedViewedJobIds == nil {
                await checkJobStatus()
            }
            await checkBookmarkStatus()
        }
        .onTapGesture {
            // Mark as viewed when tapped
            Task {
                await markJobAsViewed()
            }
        }
        .alert("Delete Job", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Add haptic feedback for destructive action
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
                Task {
                    await deleteJob()
                }
            }
        } message: {
            Text("Are you sure you want to delete this job? This action cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [createJobShareText()])
        }
    }
    
    /// Fallback per-card status lookup, used only when the parent list did NOT inject bulk
    /// interest/viewed sets (e.g. search/category screens). Uses the cached `currentUser` id —
    /// no networked `auth.user()`.
    private func checkJobStatus() async {
        guard !isOwnJob, let userId = supabase.auth.currentUser?.id.uuidString else { return }

        let hasInterest = await checkIfJobInterested(jobId: job.id, userId: userId)
        let hasViewed = await checkIfJobViewed(jobId: job.id, userId: userId)

        await MainActor.run {
            if hasInterest {
                self.jobStatus = .interested
            } else if hasViewed {
                self.jobStatus = .viewed
            } else {
                self.jobStatus = .new
            }
        }
    }
    
    private func checkIfJobViewed(jobId: String, userId: String) async -> Bool {
        do {
            // Check if there's a record in job_views table
            let response = try await supabase
                .from("job_views")
                .select("id")
                .eq("job_id", value: jobId)
                .eq("user_id", value: userId)
                .execute()
            
            let data = String(data: response.data, encoding: .utf8) ?? "[]"
            return !data.contains("[]")
        } catch {
            print("Error checking job viewed status: \(error)")
            return false
        }
    }
    
    private func checkIfJobInterested(jobId: String, userId: String) async -> Bool {
        do {
            // Check if there's a record in job_interests table
            let response = try await supabase
                .from("job_interests")
                .select("id")
                .eq("job_id", value: jobId)
                .eq("provider_id", value: userId)
                .execute()
            
            let data = String(data: response.data, encoding: .utf8) ?? "[]"
            return !data.contains("[]")
        } catch {
            print("Error checking job interest status: \(error)")
            return false
        }
    }
    
    private func markJobAsViewed() async {
        // Dedupe: only write once per card per session (this fires on tap and from the context
        // menu) to avoid repeated upserts on re-renders/re-taps. Also skip if the list already
        // told us the job is viewed.
        guard !isOwnJob, !didMarkViewed,
              !(injectedViewedJobIds?.contains(job.id) ?? false),
              let userId = currentUserId ?? supabase.auth.currentUser?.id.uuidString else { return }
        didMarkViewed = true

        do {
            // Insert directly into job_views table with upsert
            let _ = try await supabase
                .from("job_views")
                .upsert([
                    "job_id": job.id,
                    "user_id": userId,
                    "viewed_at": ISO8601DateFormatter().string(from: Date())
                ])
                .execute()
            
            print("✅ Successfully marked job as viewed")
            
            // Update local status
            await MainActor.run {
                if self.jobStatus == .new {
                    self.jobStatus = .viewed
                    print("📱 Updated local status to viewed")
                }
            }
        } catch {
            print("❌ Error marking job as viewed: \(error)")
        }
    }
    
    private func deleteJob() async {
        guard isOwnJob else {
            print("❌ Cannot delete job - not the owner")
            return
        }
        
        await MainActor.run {
            isDeleting = true
        }
        
        do {
            try await Networking.shared.deleteJob(jobId: job.id)
            
            await MainActor.run {
                isDeleting = false
                // Call the callback to refresh the parent view
                onJobDeleted?()
            }
            
            print("✅ Successfully deleted job: \(job.title)")
        } catch {
            await MainActor.run {
                isDeleting = false
            }
            print("❌ Failed to delete job: \(error)")
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .none
            displayFormatter.timeStyle = .none
            displayFormatter.doesRelativeDateFormatting = true
            
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                displayFormatter.dateStyle = .short
                return displayFormatter.string(from: date)
            }
        }
        return "Recently"
    }
    
    private func toggleBookmark() async {
        guard !isOwnJob, let userId = currentUserId else { return }
        
        do {
            if isBookmarked {
                // Remove bookmark
                let _ = try await supabase
                    .from("job_bookmarks")
                    .delete()
                    .eq("job_id", value: job.id)
                    .eq("user_id", value: userId)
                    .execute()
            } else {
                // Add bookmark
                let _ = try await supabase
                    .from("job_bookmarks")
                    .insert([
                        "job_id": job.id,
                        "user_id": userId,
                        "bookmarked_at": ISO8601DateFormatter().string(from: Date())
                    ])
                    .execute()
            }
            
            await MainActor.run {
                self.isBookmarked.toggle()
            }
        } catch {
            print("Error toggling bookmark: \(error)")
        }
    }
    
    private func checkBookmarkStatus() async {
        guard !isOwnJob, let userId = currentUserId else { return }
        
        do {
            let response = try await supabase
                .from("job_bookmarks")
                .select("id")
                .eq("job_id", value: job.id)
                .eq("user_id", value: userId)
                .execute()
            
            let data = String(data: response.data, encoding: .utf8) ?? "[]"
            await MainActor.run {
                self.isBookmarked = !data.contains("[]")
            }
        } catch {
            print("Error checking bookmark status: \(error)")
        }
    }
    
    private func createJobShareText() -> String {
        return """
        🔥 Job Opportunity: \(job.title)
        
        📋 Category: \(job.category)
        💰 Budget: ৳\(job.budget)
        📍 Location: \(job.location)
        
        \(job.description)
        
        #KajHobe #JobOpportunity #\(job.category.replacingOccurrences(of: " ", with: ""))
        """
    }
}

// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Share Sheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {}
}

#Preview {
    JobCardView(job: Job(
        id: "1",
        title: "Build a Mobile App",
        description: "Looking for a skilled developer to build a cross-platform mobile application with modern UI design and seamless user experience.",
        category: "Technology",
        location: "Remote",
        status: "open",
        urgent: true,
        created_at: "2024-01-01T00:00:00Z",
        updated_at: "2024-01-01T00:00:00Z",
        client_id: "sample-client-id",
        budget: 1500,
        media_urls: nil
    ))
    .padding()
}

 

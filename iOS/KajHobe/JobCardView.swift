import SwiftUI
import Auth
import Supabase

// Removed duplicate sensoryFeedback extension to avoid conflicts with SwiftUI's built-in method

struct JobCardView: View {
    let job: Job
    @State private var currentUserId: String?
    @State private var jobStatus: JobStatus = .new
    @State private var userProfile: Profile?
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
    
    init(job: Job, onJobDeleted: (() -> Void)? = nil, onOpenConversation: (() -> Void)? = nil) {
        self.job = job
        self.onJobDeleted = onJobDeleted
        // Try to determine ownership immediately if user is available
        self._isOwnJob = State(initialValue: false)
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
                        .fill(jobStatus.color)
                        .frame(width: 6, height: 6)
                    Text(jobStatus.displayText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(jobStatus.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(jobStatus.color.opacity(0.1))
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
            await checkJobOwnership()
            await loadUserProfile()
            await checkJobStatus()
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
    
    private func loadUserProfile() async {
        do {
            let profile = try await Networking.shared.getCurrentUserProfile()
            await MainActor.run {
                self.userProfile = profile
            }
        } catch {
            print("Error loading user profile: \(error)")
        }
    }
    
    private func checkJobOwnership() async {
        do {
            let user = try await supabase.auth.user()
            await MainActor.run {
                self.currentUserId = user.id.uuidString
                // Use case-insensitive comparison for UUID matching
                self.isOwnJob = job.client_id.lowercased() == user.id.uuidString.lowercased()
            }
            
            print("Job ownership check - Job client: \(job.client_id), Current user: \(user.id.uuidString), Is own job: \(isOwnJob)")
        } catch {
            print("Error checking job ownership: \(error)")
        }
    }
    
    private func checkJobStatus() async {
        guard !isOwnJob else { 
            print("📝 Skipping status check - this is user's own job")
            return 
        }
        
        do {
            let user = try await supabase.auth.user()
            let userId = user.id.uuidString
            
            print("🔍 Checking job status - Job ID: \(job.id), User ID: \(userId)")
            
            // Check if user has shown interest in this job
            let hasInterest = await checkIfJobInterested(jobId: job.id, userId: userId)
            print("💚 Has interest: \(hasInterest)")
            
            // Check if user has viewed this job
            let hasViewed = await checkIfJobViewed(jobId: job.id, userId: userId)
            print("👀 Has viewed: \(hasViewed)")
            
            await MainActor.run {
                let oldStatus = self.jobStatus
                if hasInterest {
                    self.jobStatus = .interested
                } else if hasViewed {
                    self.jobStatus = .viewed
                } else {
                    self.jobStatus = .new
                }
                print("📊 Status changed from \(oldStatus.displayText) to \(self.jobStatus.displayText)")
            }
        } catch {
            print("❌ Error checking job status: \(error)")
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
        guard !isOwnJob, let userId = currentUserId else { return }
        
        do {
            print("🔍 Marking job as viewed - Job ID: \(job.id), User ID: \(userId)")
            
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

 

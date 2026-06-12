import SwiftUI
import Supabase
import Auth

struct DealDetailView: View {
    @State private var deal: DealWithCompletion
    @Environment(\.presentationMode) var presentationMode
    @State private var currentUser: User?
    @State private var isUserClient: Bool = false
    @State private var isProcessing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingCompletionRequest = false
    @State private var showingCompletionResponse = false
    @State private var showingDisputeSheet = false
    @State private var disputeReason = ""
    @State private var showingReviewSheet = false
    // nil = not yet checked; drives whether "Leave a Review" or "Reviewed" shows.
    @State private var hasReviewedCounterparty: Bool? = nil

    init(deal: DealWithCompletion) {
        self._deal = State(initialValue: deal)
    }

    private let networking = Networking.shared
    private let reviewNetworking = PublicProfileNetworking()

    /// The other party of the deal from the current user's perspective.
    private var counterpartyId: String {
        isUserClient ? deal.provider_id : deal.client_id
    }

    private var counterpartyProfile: SimpleProfile? {
        isUserClient ? deal.provider_profile : deal.client_profile
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    dealHeaderSection
                        .animatedContainer(delay: 0.1)
                    
                    // Job Information Section
                    jobInformationSection
                        .animatedContainer(delay: 0.2)
                    
                    // Participants Section
                    participantsSection
                        .animatedContainer(delay: 0.3)
                    
                    // Deal Terms Section
                    dealTermsSection
                        .animatedContainer(delay: 0.4)

                    // Escrow & Payment Section
                    EscrowSectionView(dealId: deal.id)
                        .animatedContainer(delay: 0.45)

                    // Progress Tracking Section
                    progressTrackingSection
                        .animatedContainer(delay: 0.5)
                    
                    // Actions Section
                    actionsSection
                        .animatedContainer(delay: 0.6)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Deal Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        navigateToMessages()
                    }) {
                        Image(systemName: "message.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadUserContext()
                await refreshReviewStatus()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingCompletionRequest) {
            CompletionRequestView(deal: deal) {
                showingCompletionRequest = false
                // Refresh deal data after completion request
                Task {
                    await refreshDealData()
                }
            }
        }
        .sheet(isPresented: $showingCompletionResponse) {
            // Handle completion response if needed
            Text("Completion Response")
        }
        .sheet(isPresented: $showingDisputeSheet) {
            DisputeReasonView(reason: $disputeReason, isProcessing: isProcessing) {
                Task { await handleOpenDispute() }
            }
        }
        .sheet(isPresented: $showingReviewSheet) {
            ReviewSheet(
                jobId: deal.job_id,
                reviewedUserId: counterpartyId,
                reviewedUserName: counterpartyProfile?.full_name ?? "Unknown User",
                reviewedUserAvatar: counterpartyProfile?.avatar_url
            ) {
                hasReviewedCounterparty = true
            }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var dealHeaderSection: some View {
        VStack(spacing: 16) {
            // Status Badge and Amount
            HStack {
                statusBadge
                Spacer()
                VStack(alignment: .trailing) {
                    Text("৳\(deal.agreed_amount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Agreed Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Deal ID and Creation Date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deal #\(String(deal.id.prefix(8)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let createdAt = deal.created_at {
                        Text("Created \(formatDate(createdAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    statusColor.opacity(0.1),
                    statusColor.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Job Information Section
    @ViewBuilder
    private var jobInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Job Information", icon: "briefcase.fill", color: .blue)
            
            if let job = deal.job {
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(job.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Label(job.category, systemImage: "tag.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        if job.urgent == true {
                            Label("Urgent", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if !job.location.isEmpty {
                        Label(job.location, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if job.budget > 0 {
                        HStack {
                            Text("Budget: ৳\(job.budget)")
                                .font(.caption)
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Participants Section
    @ViewBuilder
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Participants", icon: "person.2.fill", color: .green)
            
            VStack(spacing: 12) {
                // Client Card
                if let client = deal.client_profile {
                    ParticipantCard(
                        profile: client,
                        role: "Client",
                        roleColor: .blue,
                        isCurrentUser: isUserClient
                    )
                }
                
                // Provider Card
                if let provider = deal.provider_profile {
                    ParticipantCard(
                        profile: provider,
                        role: "Service Provider",
                        roleColor: .green,
                        isCurrentUser: !isUserClient
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Deal Terms Section
    @ViewBuilder
    private var dealTermsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Deal Terms", icon: "doc.text.fill", color: .orange)
            
            VStack(alignment: .leading, spacing: 8) {
                if let terms = deal.agreed_terms, !terms.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terms & Conditions")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(terms)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let timeline = deal.timeline, !timeline.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timeline")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(timeline)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                if deal.agreed_terms?.isEmpty != false && deal.timeline?.isEmpty != false {
                    Text("No specific terms or timeline specified")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Progress Tracking Section
    @ViewBuilder
    private var progressTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Progress", icon: "chart.line.uptrend.xyaxis", color: .purple)
            
            DealProgressTimeline(deal: deal)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Actions Section
    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Completion action logic based on status and user role
            if deal.completion_status == "in_progress" {
                // Check if current user has already requested completion
                let hasUserRequestedCompletion = (isUserClient && deal.client_completion_requested == true) || 
                                               (!isUserClient && deal.provider_completion_requested == true)
                
                if hasUserRequestedCompletion {
                    // Show waiting state
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text("Completion Requested")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(true)
                } else {
                    // Show completion request button
                    Button(action: {
                        showingCompletionRequest = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Request Completion")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isProcessing)
                }
            }
            
            if deal.completion_status == "pending_approval" {
                // Check if the current user has sent a completion request and is waiting for response
                let hasUserSentRequest = (isUserClient && deal.client_completion_requested == true) ||
                                        (!isUserClient && deal.provider_completion_requested == true)
                
                if hasUserSentRequest {
                    // Show "Request Pending" for the person who sent the request
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text("Request Pending")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(true)
                } else {
                    // Show approval buttons for the person who needs to respond
                    HStack(spacing: 12) {
                        Button("Approve") {
                            Task { await handleCompletionResponse(approved: true) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(isProcessing)
                        
                        Button("Request Changes") {
                            Task { await handleCompletionResponse(approved: false) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(isProcessing)
                    }
                }
            }
            
            if deal.completion_status == "completed" {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Deal Completed")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(true)

                if hasReviewedCounterparty == true {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("review_submitted_badge".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(10)
                } else if hasReviewedCounterparty == false {
                    Button(action: { showingReviewSheet = true }) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("leave_review".localized)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                }
            }

            // Under dispute — frozen until an admin resolves it.
            if deal.completion_status == "disputed" {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.shield.fill")
                        Text("Under Dispute")
                    }
                    Text("An admin is reviewing this deal. The payment stays in escrow until it's resolved.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .opacity(0.9)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            // Dispute settled by an admin.
            if deal.completion_status == "resolved" {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Dispute Resolved")
                    }
                    Text("An admin settled this deal. See the payment section for how it was split.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .opacity(0.9)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.indigo.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            // Open a dispute — available on an active deal that isn't already
            // disputed/resolved/completed. The DB RPC enforces escrow is held.
            if deal.completion_status == "in_progress" || deal.completion_status == "pending_approval" {
                Button(action: { showingDisputeSheet = true }) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble.fill")
                        Text("Report a Problem / Open Dispute")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                .disabled(isProcessing)
            }

            // Message button
            Button(action: {
                withAnimation(AnimationSystem.Presets.bouncy) {
                    navigateToMessages()
                }
            }) {
                HStack {
                    Image(systemName: "message.fill")
                    Text("Send Message")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(10)
            }
            .pulse(color: Color.blue)
        }
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
            Spacer()
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(deal.completion_status.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var statusColor: Color {
        switch deal.completion_status {
        case "completed":
            return .green
        case "pending_approval":
            return .orange
        case "in_progress":
            return .blue
        case "disputed":
            return .red
        case "resolved":
            return .indigo
        default:
            return .gray
        }
    }
    
    // MARK: - Helper Functions
    private func loadUserContext() async {
        do {
            currentUser = try supabase.auth.requireCurrentUser()
            if let userId = currentUser?.id {
                // Lowercase both sides: Swift's uuidString is uppercase, DB uuids are lowercase.
                isUserClient = (deal.client_id.lowercased() == userId.uuidString.lowercased())
            }
        } catch {
            print("Error loading user context: \(error)")
        }
    }
    
    private func handleCompletionResponse(approved: Bool) async {
        isProcessing = true
        
        do {
            // Find the pending completion request for this deal
            let completionRequests = try await networking.fetchPendingCompletionRequests(forceRefresh: true)
            
            if let request = completionRequests.first(where: { $0.deal_id == deal.id }) {
                // Respond to the completion request
                try await networking.respondToCompletionRequest(
                    requestId: request.id,
                    approve: approved,
                    message: approved ? "Approved" : "Please make the requested changes"
                )

                // Refresh deal data to reflect the changes
                await refreshDealData()

                // The deal just completed — prompt for a review unless one
                // already exists (the DB unique constraint is the backstop).
                if approved {
                    await refreshReviewStatus()
                    if hasReviewedCounterparty != true {
                        showingReviewSheet = true
                    }
                }

            } else {
                errorMessage = "No pending completion request found"
                showingError = true
            }
        } catch {
            errorMessage = "Failed to respond to completion request: \(error.localizedDescription)"
            showingError = true
        }
        
        isProcessing = false
    }

    /// Check whether the current user already reviewed the counterparty, so the
    /// completed-deal UI can show "Leave a Review" vs "Reviewed". Only relevant
    /// once the deal is completed.
    private func refreshReviewStatus() async {
        guard deal.completion_status == "completed" else { return }
        do {
            hasReviewedCounterparty = try await reviewNetworking.hasReviewed(
                jobId: deal.job_id,
                reviewedId: counterpartyId
            )
        } catch {
            // Leave as nil (unknown) — the button stays hidden rather than
            // risking a duplicate-review error surface.
            print("Failed to check review status: \(error)")
        }
    }

    private func handleOpenDispute() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await networking.openDispute(
                dealId: deal.id,
                reason: disputeReason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            await MainActor.run {
                showingDisputeSheet = false
                disputeReason = ""
            }
            await refreshDealData()
        } catch {
            await MainActor.run {
                showingDisputeSheet = false
                errorMessage = "Couldn't open the dispute: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func refreshDealData() async {
        do {
            // Fetch updated deal information
            let activeDeals = try await networking.fetchActiveDeals(forceRefresh: true)
            if let updatedDeal = activeDeals.first(where: { $0.id == deal.id }) {
                // Convert Deal to DealWithCompletion if needed
                self.deal = DealWithCompletion(
                    id: updatedDeal.id,
                    job_id: updatedDeal.job_id,
                    client_id: updatedDeal.client_id,
                    provider_id: updatedDeal.provider_id,
                    agreed_amount: updatedDeal.agreed_amount,
                    agreed_terms: updatedDeal.agreed_terms,
                    timeline: updatedDeal.timeline,
                    status: updatedDeal.status,
                    completion_status: updatedDeal.completion_status ?? "in_progress",
                    client_completion_requested: updatedDeal.client_completion_requested ?? false,
                    provider_completion_requested: updatedDeal.provider_completion_requested ?? false,
                    client_completion_requested_at: updatedDeal.client_completion_requested_at,
                    provider_completion_requested_at: updatedDeal.provider_completion_requested_at,
                    created_at: updatedDeal.created_at,
                    completed_at: updatedDeal.completed_at,
                    job: updatedDeal.job,
                    client_profile: deal.client_profile, // Keep existing profile data
                    provider_profile: deal.provider_profile // Keep existing profile data
                )
            }
        } catch {
            print("Failed to refresh deal data: \(error)")
        }
    }
    
    private func navigateToMessages() {
        // Dismiss this modal first
        presentationMode.wrappedValue.dismiss()
        
        // Post notification to switch to Messages tab and optionally navigate to specific conversation
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToMessages"), 
            object: nil,
            userInfo: [
                "jobId": deal.job_id,
                "clientId": deal.client_id,
                "providerId": deal.provider_id
            ]
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        AppDateFormatter.mediumDateShortTime(dateString)
    }
}

// MARK: - Supporting Views

struct ParticipantCard: View {
    let profile: SimpleProfile
    let role: String
    let roleColor: Color
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: profile.avatar_url ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.full_name ?? "Unknown User")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(role)
                    .font(.caption)
                    .foregroundColor(roleColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(roleColor.opacity(0.1))
                    .cornerRadius(4)
                
                // Location info would need to be fetched from full Profile if needed
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

struct DealProgressTimeline: View {
    let deal: DealWithCompletion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Deal Created
            timelineItem(
                title: "Deal Created",
                subtitle: formatDate(deal.created_at),
                icon: "handshake.fill",
                color: .green,
                isCompleted: true
            )
            
            // In Progress
            timelineItem(
                title: "Work in Progress",
                subtitle: "Service being provided",
                icon: "gearshape.fill",
                color: .blue,
                isCompleted: deal.completion_status != "pending_approval"
            )
            
            // Completion Requests
            if deal.client_completion_requested == true {
                timelineItem(
                    title: "Client Requested Completion",
                    subtitle: formatDate(deal.client_completion_requested_at),
                    icon: "person.fill.checkmark",
                    color: .orange,
                    isCompleted: true
                )
            }
            
            if deal.provider_completion_requested == true {
                timelineItem(
                    title: "Provider Requested Completion",
                    subtitle: formatDate(deal.provider_completion_requested_at),
                    icon: "checkmark.circle.fill",
                    color: .orange,
                    isCompleted: true
                )
            }
            
            // Completed
            timelineItem(
                title: "Deal Completed",
                subtitle: deal.completed_at != nil ? formatDate(deal.completed_at) : "Pending completion",
                icon: "checkmark.seal.fill",
                color: .green,
                isCompleted: deal.completion_status == "completed"
            )
        }
    }
    
    @ViewBuilder
    private func timelineItem(
        title: String,
        subtitle: String?,
        icon: String,
        color: Color,
        isCompleted: Bool
    ) -> some View {
        HStack(spacing: 12) {
            // Timeline indicator
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isCompleted ? color : .gray)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(isCompleted ? color.opacity(0.1) : Color.gray.opacity(0.1))
                    )
                
                if title != "Deal Completed" {
                    Rectangle()
                        .fill(isCompleted ? color.opacity(0.3) : Color.gray.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? .primary : .secondary)
                
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private func formatDate(_ dateString: String?) -> String {
        AppDateFormatter.shortDateShortTime(dateString, fallback: dateString ?? "")
    }
}

// MARK: - Dispute Reason Sheet

struct DisputeReasonView: View {
    @Binding var reason: String
    let isProcessing: Bool
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text("Open a dispute")
                        .font(.title3).fontWeight(.semibold)
                }

                Text("If something went wrong and you can't agree on completion, opening a dispute freezes the deal. The payment stays safely in escrow while an admin reviews it and decides how to split it.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("What's the problem?")
                    .font(.subheadline).fontWeight(.medium)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $reason)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    if reason.isEmpty {
                        Text("Describe what happened…")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

                Button(action: onSubmit) {
                    HStack {
                        if isProcessing { ProgressView().tint(.white) }
                        Text(isProcessing ? "Opening…" : "Open Dispute")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isProcessing)

                Spacer()
            }
            .padding()
            .navigationTitle("Dispute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isProcessing)
                }
            }
        }
    }
}

#Preview {
    DealDetailView(deal: DealWithCompletion(
        id: "preview-id",
        job_id: "job-id",
        client_id: "client-id",
        provider_id: "provider-id",
        agreed_amount: 5000,
        agreed_terms: "Complete the task as discussed",
        timeline: "Within 3 days",
        status: "active",
        completion_status: "in_progress",
        client_completion_requested: false,
        provider_completion_requested: false,
        client_completion_requested_at: nil,
        provider_completion_requested_at: nil,
        created_at: "2024-01-01T00:00:00Z",
        completed_at: nil,
        job: Job(
            id: "job-id",
            title: "Fix My Computer",
            description: "My computer is running slowly and needs optimization",
            category: "Technology Services",
            location: "Khulna, Bangladesh",
            status: "in_progress",
            urgent: true,
            created_at: "2024-01-01T00:00:00Z",
            updated_at: "2024-01-01T00:00:00Z",
            client_id: "client-id",
            budget: 8000,
            media_urls: nil
        ),
        client_profile: SimpleProfile(
            id: "client-id",
            full_name: "John Doe",
            avatar_url: nil,
            is_online: true,
            last_seen_at: "2024-01-01T00:00:00Z",
            average_response_time_minutes: 15
        ),
        provider_profile: SimpleProfile(
            id: "provider-id",
            full_name: "Jane Smith",
            avatar_url: nil,
            is_online: false,
            last_seen_at: "2024-01-01T00:00:00Z",
            average_response_time_minutes: 30
        )
    ))
}
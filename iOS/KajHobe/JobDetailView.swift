//
//  JobDetailView.swift
//  KajHobe
//
//  Created by Khondker Oishe on 6/15/24.
//

import SwiftUI
import Supabase

struct JobDetailView: View {
    let job: Job
    @State private var profile: Profile?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var interestStatus: String? = nil
    @State private var isShowingInterest = false
    @State private var isOwnJob = false
    @State private var existingConversation: Any?
    @State private var currentUserProfile: Profile?
    @State private var isServiceProvider = false
    @State private var showingConversation = false
    
    // Simplified interest status tracking
    @State private var simpleInterestStatus: NotificationsNetworking.SimpleInterestStatus?
    @State private var refreshTimer: Timer?
    @Environment(\.dismiss) var dismiss
    
    // Add new state for custom interest message
    @State private var showingInterestSheet = false
    @State private var customInterestMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Media Carousel (if available)
                        if let mediaItems = job.media_urls, !mediaItems.isEmpty {
                            MediaCarouselView(mediaItems: mediaItems, height: 300)
                                .cornerRadius(0)
                        }

                        // Header section with title and urgency
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(job.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if job.urgent ?? false {
                                    Text("URGENT")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                            }
                            
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.secondary)
                                Text(job.location)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("$\(job.budget)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        
                        // Category and Status
                        HStack {
                            Label(job.category, systemImage: "tag")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            StatusBadge(status: job.status ?? "unknown")
                        }
                        .padding(.horizontal)
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(job.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        
                        // Posted date
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Posted")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(formatDate(job.created_at ?? ""))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        
                        Spacer(minLength: 100) // Extra space for the floating button
                    }
                    .padding(.horizontal)
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    
                    if !isOwnJob && isServiceProvider {
                        if existingConversation != nil {
                            // Continue chat button
                            Button(action: {
                                showingConversation = true
                            }) {
                                HStack {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 18))
                                    Text("Continue Chat")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        } else if interestStatus == "rejected_cooldown" {
                            // Show cooldown status
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.orange)
                                    Text("Cooldown Active")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                                
                                Text(simpleInterestStatus?.message ?? "Please wait before trying again")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        } else if interestStatus == "rejected_expired" {
                            // Can show interest again (cooldown ended)
                            Button(action: {
                                showingInterestSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 18))
                                    Text("Show Interest Again")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        } else if interestStatus == "accepted" {
                            // Interest accepted - show chat button
                            Button(action: {
                                if existingConversation != nil {
                                    // Navigate to existing conversation
                                    showingConversation = true
                                } else {
                                    // Fallback: create conversation if it doesn't exist
                                    Task {
                                        await createConversationAndNavigate()
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 18))
                                    Text(existingConversation != nil ? "Show Chat" : "Start Chat")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        } else if interestStatus == "pending" {
                            // Interest shown, waiting for response
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                                Text("Interest Shown")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        } else {
                            // Show interest button (no interest shown yet or default case)
                            Button(action: {
                                showingInterestSheet = true
                            }) {
                                HStack {
                                    if isShowingInterest {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 18))
                                    }
                                    Text(isShowingInterest ? "Sending..." : "Show Interest")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isShowingInterest ? Color.gray : Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(isShowingInterest || !(simpleInterestStatus?.canShowInterest ?? true))
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        }
                    } else if isOwnJob {
                        // Show conversation button for job owners if there's an existing conversation
                        if existingConversation != nil {
                            Button(action: {
                                showingConversation = true
                            }) {
                                HStack {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 18))
                                    Text("View Conversations")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await checkOwnership()
                await checkUserServiceProviderStatus()
                
                if !isOwnJob && isServiceProvider {
                    await checkInterestStatus()
                }
                
                // Check for existing conversations for both job owners and service providers
                await checkExistingConversation()
            }
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .sheet(isPresented: $showingInterestSheet) {
            CustomInterestSheet(
                jobTitle: job.title,
                message: $customInterestMessage,
                onSend: {
                    showingInterestSheet = false
                    showInterestWithMessage()
                },
                onCancel: {
                    showingInterestSheet = false
                    customInterestMessage = ""
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
            .presentationContentInteraction(.scrolls)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
        .navigationDestination(isPresented: $showingConversation) {
            VStack(spacing: 20) {
                Image(systemName: "message.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("Messaging Disabled")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Messaging functionality has been temporarily disabled.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func checkOwnership() async {
        do {
            let user = try supabase.auth.requireCurrentUser()
            let userId = user.id.uuidString
            
            await MainActor.run {
                isOwnJob = (job.client_id.lowercased() == userId.lowercased())
            }
            
            // print("Job ownership check - Job client: \(job.client_id), Current user: \(userId), Is own job: \(isOwnJob)")
        } catch {
            // print("Error checking ownership: \(error)")
        }
    }
    
    private func checkUserServiceProviderStatus() async {
        do {
            let user = try supabase.auth.requireCurrentUser()
            let userId = user.id.uuidString
            
            // Fetch user profile from database
            let response = try await supabase
                .from("profiles")
                .select("*")
                .eq("id", value: userId)
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(Profile.self, from: response.data)
            
            await MainActor.run {
                self.currentUserProfile = profile
                // Check if user is a service provider
                self.isServiceProvider = profile.is_service_provider == true || profile.user_type?.lowercased() == "provider"
            }
            
            // print("Service provider check - User type: \(profile.user_type ?? "nil"), Is service provider: \(profile.is_service_provider ?? false), Final result: \(isServiceProvider)")
        } catch {
            // print("Error checking service provider status: \(error)")
            await MainActor.run {
                self.isServiceProvider = false // Default to false if we can't determine
            }
        }
    }
    
    private func checkInterestStatus() async {
        guard let currentUser = supabase.auth.currentUser else { return }
        
        do {
            // Use simplified server-side validation
            let simpleStatus = try await NotificationsNetworking.shared.getSimpleInterestStatus(
                jobId: job.id,
                providerId: currentUser.id.uuidString
            )
            
            await MainActor.run {
                self.simpleInterestStatus = simpleStatus
                self.interestStatus = simpleStatus.status
                
                print("🔍 JobDetailView: Simple status=\(simpleStatus.status), canShow=\(simpleStatus.canShowInterest), message=\(simpleStatus.message)")
                
                // Start refresh timer if we're in a cooldown state
                if simpleStatus.status == "rejected_cooldown" {
                    startRefreshTimer()
                } else {
                    stopRefreshTimer()
                }
            }
        } catch {
            print("Error checking interest status: \(error)")
        }
    }
    
    private func startRefreshTimer() {
        stopRefreshTimer() // Clear any existing timer
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                await checkInterestStatus()
            }
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func checkExistingConversation() async {
        do {
            guard let currentUserProfile = currentUserProfile else { return }
            
            // Fetch conversations for current user and find one for this job
            let conversations = try await Networking.shared.fetchConversations(userId: currentUserProfile.id)
            
            // Since fetchConversations returns [Any], we need to safely handle the type casting
            // For now, messaging is disabled, so we set existingConversation to nil
            await MainActor.run {
                existingConversation = nil
            }
        } catch {
            print("Error checking existing conversation: \(error)")
            await MainActor.run {
                existingConversation = nil
            }
        }
    }
    
    private func createConversationAndNavigate() async {
        do {
            guard let currentUserProfile = currentUserProfile else { return }
            
            // Create conversation between job client and service provider
            let conversation = try await Networking.shared.createConversation(
                jobId: job.id,
                clientId: job.client_id,
                providerId: currentUserProfile.id
            )
            
            await MainActor.run {
                existingConversation = conversation
                showingConversation = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create conversation: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func showInterestWithMessage() {
        // Additional safety check to prevent job owners from showing interest
        if isOwnJob {
            errorMessage = "You cannot show interest in your own job posting."
            showingError = true
            return
        }
        
        // Check if user is a service provider
        if !isServiceProvider {
            errorMessage = "Only service providers can show interest in jobs."
            showingError = true
            return
        }
        
        isShowingInterest = true
        
        Task {
            do {
                // Double-check ownership before proceeding
                let user = try supabase.auth.requireCurrentUser()
                if job.client_id.lowercased() == user.id.uuidString.lowercased() {
                    await MainActor.run {
                        errorMessage = "You cannot show interest in your own job posting."
                        showingError = true
                        isShowingInterest = false
                    }
                    return
                }
                
                // Use the simplified interest system
                let message = customInterestMessage.isEmpty ? "I'm interested in this job!" : customInterestMessage
                try await NotificationsNetworking.shared.createInterestAttempt(jobId: job.id, message: message)
                
                await MainActor.run {
                    isShowingInterest = false
                    customInterestMessage = ""
                }
                
                // Check for conversation again in case interest was auto-accepted
                // and refresh all states
                await checkInterestStatus()
                await checkExistingConversation()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to show interest: \(error.localizedDescription)"
                    showingError = true
                    isShowingInterest = false
                }
            }
        }
    }
    
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "open":
            return .green
        case "in_progress":
            return .orange
        case "completed":
            return .blue
        case "cancelled":
            return .red
        default:
            return .gray
        }
    }
    
    private var statusText: String {
        switch status.lowercased() {
        case "open":
            return "Open"
        case "in_progress":
            return "In Progress"
        case "completed":
            return "Completed"
        case "cancelled":
            return "Cancelled"
        default:
            return status.capitalized
        }
    }
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
}

#Preview {
    JobDetailView(job: Job(
        id: "1",
        title: "Web Development",
        description: "Need a responsive website",
        category: "Technology",
        location: "Dhaka, Bangladesh",
        status: "open",
        urgent: true,
        created_at: "2024-01-01T00:00:00Z",
        updated_at: "2024-01-01T00:00:00Z",
        client_id: "client123",
        budget: 50000,
        media_urls: nil
    ))
}

// MARK: - Custom Interest Sheet
struct CustomInterestSheet: View {
    let jobTitle: String
    @Binding var message: String
    let onSend: () -> Void
    let onCancel: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Show Interest")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Let the client know why you're interested in:")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(jobTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Message input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Message")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextEditor(text: $message)
                        .focused($isTextFieldFocused)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    
                    if message.isEmpty {
                        Text("Example: \"Hi! I have 5 years of experience in web development and I'm excited to help you create a responsive website. I can start immediately and deliver within your timeline.\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: onSend) {
                        Text("Send Interest")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Show Interest")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}


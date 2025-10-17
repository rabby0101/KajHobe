import SwiftUI
import Supabase
import Auth
import PostgREST

struct DealRejectionNotificationView: View {
    let notification: Notification
    @Binding var isPresented: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("Deal Rejected")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(notification.message ?? "Your deal offer was rejected")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Job information
                if let job = notification.job {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Job Details")
                            .font(.headline)
                        
                        Text(job.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(job.location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        // Add haptic feedback for destructive action
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Conversation")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "message")
                            Text("Keep Talking")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Deal Rejected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
        .alert("Delete Conversation", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Add haptic feedback for destructive action
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
                Task {
                    await deleteConversation()
                }
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
    }
    
    private func deleteConversation() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Find the conversation for this job and provider
            let user = try await supabase.auth.user()
            
            let response = try await supabase
                .from("conversations")
                .select("id")
                .eq("job_id", value: notification.job_id)
                .eq("provider_id", value: user.id.uuidString)
                .single()
                .execute()
            
            let conversationData = try JSONDecoder().decode([String: String].self, from: response.data)
            
            if conversationData["id"] != nil {
                // try await Networking.shared.deleteConversation(conversationId: conversationId) // Removed with messaging
                
                await MainActor.run {
                    isLoading = false
                    isPresented = false
                }
                
                // print("✅ Conversation deleted successfully")
            } else {
                throw NSError(domain: "ConversationError", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Conversation not found"
                ])
            }
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            // print("❌ Error deleting conversation: \(error)")
        }
    }
}

#Preview {
    DealRejectionNotificationView(
        notification: Notification(
            id: "1",
            type: "deal_rejected",
            job_id: "1",
            from_user_id: "1",
            to_user_id: "2",
            status: "pending",
            message: "Your deal offer was rejected. The client found a better offer.",
            offer_data: nil,
            completion_request_id: nil,
            actioned_at: nil,
            created_at: "2024-01-01T00:00:00Z",
            job: Job(
                id: "1",
                title: "Fix Kitchen Sink",
                description: "Need to fix a leaky kitchen sink",
                category: "plumbing",
                location: "Khulna, Bangladesh",
                status: "open",
                urgent: false,
                created_at: "2024-01-01T00:00:00Z",
                updated_at: "2024-01-01T00:00:00Z",
                client_id: "1",
                budget: 500,
                media_urls: nil
            ),
            from_profile: nil
        ),
        isPresented: .constant(true)
    )
} 

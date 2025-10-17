import SwiftUI

struct CompletionRequestView: View {
    let deal: DealWithCompletion
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var message = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Deal Details")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Job")
                            Spacer()
                            Text(deal.job?.title ?? "Unknown Job")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Amount")
                            Spacer()
                            Text("$\(deal.agreed_amount)")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        if let terms = deal.agreed_terms {
                            HStack {
                                Text("Terms")
                                Spacer()
                                Text(terms)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        
                        if let timeline = deal.timeline {
                            HStack {
                                Text("Timeline")
                                Spacer()
                                Text(timeline)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                
                Section(header: Text("Request Completion")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Are you ready to mark this task as completed?")
                            .font(.subheadline)
                        
                        Text("The other party will be notified and asked to confirm completion.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Optional message", text: $message, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                if showingError && !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Mark as Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send Request") {
                        Task {
                            await requestCompletion()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
    
    private func requestCompletion() async {
        isLoading = true
        errorMessage = ""
        showingError = false
        
        do {
            _ = try await Networking.shared.requestTaskCompletion(
                dealId: deal.id,
                message: message.isEmpty ? nil : message
            )
            
            await MainActor.run {
                onComplete()
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isLoading = false
            }
        }
    }
}

struct CompletionResponseView: View {
    let request: CompletionRequest
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var response = "approved"
    @State private var message = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Completion Request")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Requested by")
                            Spacer()
                            Text(request.requester_profile?.full_name ?? "Unknown")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Role")
                            Spacer()
                            Text(request.requester_type.capitalized)
                                .fontWeight(.medium)
                        }
                        
                        if let requestMessage = request.request_message, !requestMessage.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Message:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(requestMessage)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                
                Section(header: Text("Your Response")) {
                    Picker("Response", selection: $response) {
                        Text("Approve Completion").tag("approved")
                        Text("Reject Request").tag("rejected")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    TextField("Optional response message", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if response == "approved" {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("This will mark the task as completed and close the deal.")
                                    .font(.caption)
                            }
                        } else {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("This will reject the completion request. The deal will remain active.")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                if showingError && !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Respond to Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(response == "approved" ? "Approve" : "Reject") {
                        Task {
                            await respondToRequest()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
    
    private func respondToRequest() async {
        isLoading = true
        errorMessage = ""
        showingError = false
        
        do {
            try await Networking.shared.respondToCompletionRequest(
                requestId: request.id,
                approve: response == "approved",
                message: message.isEmpty ? nil : message
            )
            
            await MainActor.run {
                onComplete()
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isLoading = false
            }
        }
    }
}

// Preview removed due to iOS 26 beta compilation issues
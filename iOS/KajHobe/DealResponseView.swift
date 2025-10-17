import SwiftUI

struct DealResponseView: View {
    let dealOffer: DealOffer
    @Binding var isPresented: Bool
    @State private var response = "accepted" // "accepted" or "rejected"
    @State private var message = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Deal Offer Details")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Amount")
                            Spacer()
                            Text("$\(dealOffer.amount)")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        if let terms = dealOffer.terms {
                            HStack {
                                Text("Terms")
                                Spacer()
                                Text(terms)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        
                        if let timeline = dealOffer.timeline {
                            HStack {
                                Text("Timeline")
                                Spacer()
                                Text(timeline)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                
                Section(header: Text("Your Response")) {
                    Picker("Response", selection: $response) {
                        Text("Accept").tag("accepted")
                        Text("Reject").tag("rejected")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    TextField("Optional message", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Respond to Deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(response == "accepted" ? "Accept" : "Reject") {
                        Task {
                            await respondToDealOffer()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
    
    private func respondToDealOffer() async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await Networking.shared.respondToDealOffer(
                dealOfferId: dealOffer.id,
                response: response,
                message: message.isEmpty ? nil : message
            )
            
            await MainActor.run {
                isLoading = false
                isPresented = false
            }
            
            // print("✅ Deal offer response sent successfully")
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            // print("❌ Error responding to deal offer: \(error)")
        }
    }
}

#Preview {
    DealResponseView(
        dealOffer: DealOffer(
            id: "1",
            conversation_id: "1",
            provider_id: "2",
            client_id: "1",
            job_id: "1",
            amount: 450,
            terms: "I'll fix the sink and replace the faucet",
            timeline: "2-3 days",
            status: "pending",
            created_at: "2024-01-01T00:00:00Z",
            responded_at: nil
        ),
        isPresented: .constant(true)
    )
} 
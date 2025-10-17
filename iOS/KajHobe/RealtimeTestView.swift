import SwiftUI

// MARK: - Realtime Test View (Disabled)
// This view has been disabled as messaging/realtime functionality is removed

struct RealtimeTestView: View {
    @State private var testResult: String = "Realtime testing disabled"
    @State private var isConnected: Bool = false
    @State private var testMessage: String = ""
    @State private var receivedMessages: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status (Always Disconnected)
                HStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 12, height: 12)
                    
                    Text("Realtime Disabled")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                // Test Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Results:")
                            .font(.headline)
                        
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text("Realtime functionality has been disabled.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                
                // Disabled Test Controls
                VStack(spacing: 12) {
                    Button("Test Connection (Disabled)") {
                        // No-op
                    }
                    .disabled(true)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.gray)
                    .cornerRadius(8)
                    
                    HStack {
                        TextField("Test message (disabled)", text: $testMessage)
                            .disabled(true)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Button("Send") {
                            // No-op
                        }
                        .disabled(true)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.gray)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Realtime Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    RealtimeTestView()
}
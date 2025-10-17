import SwiftUI

// MARK: - Start Session Sheet (Disabled)
// This sheet has been disabled as messaging functionality is removed

struct StartSessionSheet: View {
    @Binding var isPresented: Bool
    @Binding var session: Any?
    @State private var displayName: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "message.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("Chat Disabled")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Chat functionality has been temporarily disabled")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Button("Close") {
                    isPresented = false
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Chat Unavailable")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var session: Any? = nil
    
    return StartSessionSheet(isPresented: $isPresented, session: $session)
}
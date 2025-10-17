import SwiftUI

// MARK: - Chat Text Field View (Disabled)
struct ChatTextFieldView: View {
    @Binding var message: String
    var onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Messaging disabled", text: $message)
                .disabled(true)
                .padding(12)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            Button(action: {}) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.gray)
            }
            .disabled(true)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
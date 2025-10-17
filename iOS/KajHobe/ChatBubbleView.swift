import SwiftUI

// MARK: - Chat Bubble View (Disabled)
// This file has been disabled as messaging functionality is removed

struct ChatBubbleView: View {
    let message: Any?
    let isFromCurrentUser: Bool
    let otherParticipant: Any?
    let showAvatar: Bool
    let showTimestamp: Bool
    let onDealResponse: (Bool, String?) async -> Void
    
    var body: some View {
        VStack {
            Text("Chat bubbles are disabled")
                .foregroundColor(.gray)
                .padding()
        }
    }
}

#Preview {
    ChatBubbleView(
        message: nil,
        isFromCurrentUser: false,
        otherParticipant: nil,
        showAvatar: true,
        showTimestamp: true,
        onDealResponse: { _, _ in }
    )
}
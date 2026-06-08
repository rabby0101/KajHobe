import SwiftUI

/// The Archived conversations sheet, opened from the archive-box button in the Messages
/// toolbar. It draws from the same in-memory conversation array that `MessagesView` already
/// loaded — no separate fetch — and reuses the redesigned `ConversationRow`. Swiping a row
/// un-archives it (via the `onUnarchive` callback), which flips the current user's archive
/// flag back to false and returns the chat to the main list.
struct ArchivedConversationsView: View {
    let conversations: [ConversationWithDetails]
    let currentUserId: String?
    let onUnarchive: (ConversationWithDetails) -> Void

    @Environment(\.dismiss) private var dismiss

    private let accent = KajHobeDesignSystem.Colors.warmOrange

    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            ZStack {
                                NavigationLink(destination: ChatView(conversation: conversation)) {
                                    EmptyView()
                                }
                                .opacity(0)

                                ConversationRow(conversation: conversation)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    onUnarchive(conversation)
                                } label: {
                                    Label("Unarchive", systemImage: "tray.and.arrow.up")
                                }
                                .tint(accent)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            Text("No Archived Conversations")
                .font(.title3)
                .fontWeight(.medium)
            Text("Conversations you archive will appear here. Swipe an archived chat to restore it.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

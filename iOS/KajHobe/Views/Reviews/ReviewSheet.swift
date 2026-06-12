import SwiftUI

/// Review submission sheet shown after a deal completes (auto-prompt) or from
/// the "Leave review" button on a completed deal. Skippable via "Maybe later".
struct ReviewSheet: View {
    let jobId: String
    let reviewedUserId: String
    let reviewedUserName: String
    let reviewedUserAvatar: String?
    var onSubmitted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @FocusState private var commentFocused: Bool

    private let networking = PublicProfileNetworking()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if showSuccess {
                    successContent
                } else {
                    formContent
                }
            }
            .navigationTitle("review_sheet_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    private var formContent: some View {
        VStack(spacing: 20) {
            // Header: who is being reviewed
            VStack(spacing: 8) {
                AsyncImage(url: URL(string: reviewedUserAvatar ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                        .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())

                Text(String(format: "review_sheet_subtitle".localized, reviewedUserName))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top)

            StarRatingInput(rating: $rating)

            // Optional comment
            VStack(alignment: .leading, spacing: 8) {
                Text("review_comment_label".localized)
                    .font(.headline)

                TextEditor(text: $comment)
                    .focused($commentFocused)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )

                if comment.isEmpty {
                    Text("review_comment_placeholder".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal)

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text("review_submit".localized)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(rating == 0 ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(rating == 0 || isSubmitting)

                Button {
                    dismiss()
                } label: {
                    Text("review_maybe_later".localized)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .disabled(isSubmitting)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("review_thanks".localized)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                dismiss()
            }
        }
    }

    private func submit() async {
        guard rating > 0 else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            _ = try await networking.submitReview(
                jobId: jobId,
                reviewedId: reviewedUserId,
                rating: rating,
                comment: comment
            )
            onSubmitted?()
            showSuccess = true
        } catch let error as PublicProfileNetworking.ReviewError {
            switch error {
            case .alreadyReviewed:
                // Friendly note, then close — nothing actionable for the user.
                errorMessage = error.errorDescription
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            case .jobNotCompleted:
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = "review_error_generic".localized
        }
    }
}

#Preview {
    ReviewSheet(
        jobId: "preview-job",
        reviewedUserId: "preview-user",
        reviewedUserName: "Rahim Mia",
        reviewedUserAvatar: nil
    )
}

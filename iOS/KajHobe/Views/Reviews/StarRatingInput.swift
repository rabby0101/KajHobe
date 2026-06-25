import SwiftUI

/// Interactive 1–5 star rating control used by ReviewSheet.
/// Tapping a star sets the rating; the whole control is exposed to VoiceOver
/// as a single adjustable element so users can swipe up/down to change it.
struct StarRatingInput: View {
    @Binding var rating: Int
    var starSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundColor(star <= rating ? .yellow : Color(.systemGray3))
                    .onTapGesture {
                        guard rating != star else { return }
                        rating = star
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("review_rating_accessibility_label".localized)
        .accessibilityValue(String(format: "review_rating_accessibility_value".localized, rating))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(rating + 1, 5)
            case .decrement: rating = max(rating - 1, 1)
            @unknown default: break
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var rating = 3
        var body: some View { StarRatingInput(rating: $rating) }
    }
    return PreviewWrapper()
}

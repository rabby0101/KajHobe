import SwiftUI

/// A single shimmering placeholder shape. Theme-aware (light/dark) via system
/// background colors. Mirrors the Android `ShimmerBox`: a highlight band that slides
/// strictly left → right (single direction, no autoreverse) so there's no vertical motion.
struct SkeletonBox: View {
    var cornerRadius: CGFloat = 8

    @State private var animate = false

    private var base: Color { Color(.systemGray5) }
    private var highlight: Color { Color(.systemGray3) }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(base)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [base, highlight, base]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 0.7)
                    // Slide the band from fully off the left edge to fully off the right.
                    // The animation is scoped to `animate` only (via .animation(_:value:)),
                    // so it never bleeds into the rest of the home screen.
                    .offset(x: animate ? w * 0.85 : -w * 0.85)
                    .animation(
                        .linear(duration: 1.3).repeatForever(autoreverses: false),
                        value: animate
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .onAppear { animate = true }
    }
}

/// Shimmer placeholder that mirrors the Jobs home layout (favorite-categories grid +
/// two horizontal job carousels). Shown until the first jobs data arrives — i.e. only
/// on a true cold start with no cached jobs. The iOS counterpart of Android's `HomeSkeleton`.
struct JobsHomeSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // "Your Favorite Categories" header + 2x2 grid
            skeletonHeader
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonBox(cornerRadius: 12)
                        .frame(height: 100)
                }
            }
            .padding(.horizontal, 24)

            // A carousel section: header + a row of wide cards
            skeletonHeader
            carouselRow(cardWidth: 280)

            // A second carousel section
            skeletonHeader
            carouselRow(cardWidth: 300)
        }
        .padding(.vertical, 16)
    }

    private var skeletonHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBox().frame(width: 200, height: 20)
                SkeletonBox().frame(width: 150, height: 12)
            }
            Spacer()
            SkeletonBox().frame(width: 48, height: 18)
        }
        .padding(.horizontal, 24)
    }

    private func carouselRow(cardWidth: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    skeletonCard.frame(width: cardWidth)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonBox().frame(width: 160, height: 16)
            SkeletonBox().frame(maxWidth: .infinity).frame(height: 12)
            SkeletonBox().frame(maxWidth: .infinity).frame(height: 12)
            Spacer().frame(height: 4)
            HStack {
                SkeletonBox().frame(width: 90, height: 12)
                Spacer()
                SkeletonBox().frame(width: 56, height: 16)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

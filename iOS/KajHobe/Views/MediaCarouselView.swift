import SwiftUI
import AVKit

/// Carousel view for displaying job media (photos and videos)
struct MediaCarouselView: View {
    let mediaItems: [Job.MediaItem]
    let height: CGFloat

    @State private var selectedIndex = 0
    @State private var showFullScreen = false

    var body: some View {
        VStack(spacing: 0) {
            // Main carousel
            TabView(selection: $selectedIndex) {
                ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                    MediaItemView(item: item, height: height)
                        .tag(index)
                        .onTapGesture {
                            showFullScreen = true
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: height)

            // Custom page indicator
            if mediaItems.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<mediaItems.count, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .offset(y: -16)
            }
        }
        .sheet(isPresented: $showFullScreen) {
            MediaFullScreenView(mediaItems: mediaItems, selectedIndex: $selectedIndex)
        }
    }
}

// MARK: - Media Item View

struct MediaItemView: View {
    let item: Job.MediaItem
    let height: CGFloat

    var body: some View {
        Group {
            switch item.type {
            case .image:
                AsyncImage(url: URL(string: item.url)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemGray6))

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemGray6))

                    @unknown default:
                        EmptyView()
                    }
                }

            case .video:
                VideoPlayerView(url: URL(string: item.url)!, thumbnailURL: item.thumbnail_url)
            }
        }
        .frame(height: height)
        .clipped()
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let url: URL
    let thumbnailURL: String?

    @State private var showPlayer = false

    var body: some View {
        ZStack {
            // Thumbnail or placeholder
            if let thumbnailURL = thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    default:
                        Color(.systemGray6)
                    }
                }
            } else {
                Color(.systemGray6)
            }

            // Play button overlay
            Button(action: { showPlayer = true }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 60, height: 60)

                    Image(systemName: "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            VideoFullScreenPlayer(url: url)
        }
    }
}

// MARK: - Video Full Screen Player

struct VideoFullScreenPlayer: View {
    let url: URL

    @Environment(\.dismiss) var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
                .ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }

            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Full Screen Media View

struct MediaFullScreenView: View {
    let mediaItems: [Job.MediaItem]
    @Binding var selectedIndex: Int

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            TabView(selection: $selectedIndex) {
                ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                    ZStack {
                        Color.black

                        if item.type == .image {
                            AsyncImage(url: URL(string: item.url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()

                                default:
                                    ProgressView()
                                }
                            }
                        } else {
                            VideoFullScreenPlayer(url: URL(string: item.url)!)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(selectedIndex + 1) / \(mediaItems.count)")
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Compact Media Preview (for cards)

struct CompactMediaPreview: View {
    let mediaItems: [Job.MediaItem]
    let size: CGFloat = 60

    var body: some View {
        HStack(spacing: 8) {
            ForEach(mediaItems.prefix(3)) { item in
                AsyncImage(url: URL(string: item.thumbnail_url ?? item.url)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                    default:
                        Rectangle()
                            .fill(Color(.systemGray6))
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                Image(systemName: item.type == .video ? "video" : "photo")
                                    .foregroundColor(.gray)
                            }
                    }
                }
                .overlay {
                    if item.type == .video {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                }
            }

            if mediaItems.count > 3 {
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("+\(mediaItems.count - 3)")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview("Carousel") {
    MediaCarouselView(
        mediaItems: [
            Job.MediaItem(url: "https://picsum.photos/400/300", type: .image),
            Job.MediaItem(url: "https://picsum.photos/400/301", type: .image),
            Job.MediaItem(url: "https://picsum.photos/400/302", type: .image)
        ],
        height: 250
    )
}

#Preview("Compact") {
    CompactMediaPreview(
        mediaItems: [
            Job.MediaItem(url: "https://picsum.photos/400/300", type: .image),
            Job.MediaItem(url: "https://picsum.photos/400/301", type: .image),
            Job.MediaItem(url: "https://picsum.photos/400/302", type: .video, thumbnail_url: "https://picsum.photos/400/302")
        ]
    )
    .padding()
}

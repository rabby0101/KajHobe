import SwiftUI
import PhotosUI
import AVFoundation

/// View for selecting and displaying multiple photos and videos
struct MediaPickerView: View {
    @Binding var selectedMedia: [SelectedMediaItem]
    let maxSelections: Int

    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with add buttons
            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $photosPickerItems,
                    maxSelectionCount: maxSelections,
                    matching: .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Add Photos/Videos")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                Button(action: { showCamera = true }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Camera")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            // Display selected media
            if !selectedMedia.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(selectedMedia) { item in
                            MediaThumbnailView(item: item) {
                                removeMedia(item)
                            }
                        }
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("No media selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Add up to \(maxSelections) photos or videos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .onChange(of: photosPickerItems) { _, newItems in
            Task {
                await loadPhotosPickerItems(newItems)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                addCameraImage(image)
            }
        }
    }

    private func loadPhotosPickerItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            // Check if we've reached max selections
            if selectedMedia.count >= maxSelections {
                break
            }

            // Check if item is already selected
            if selectedMedia.contains(where: { $0.pickerItem?.itemIdentifier == item.itemIdentifier }) {
                continue
            }

            // Determine type
            let isVideo = item.supportedContentTypes.contains(.movie) ||
                         item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) })

            // Load preview data
            if isVideo {
                if let movie = try? await item.loadTransferable(type: VideoPickerTransferable.self),
                   let url = movie.url {
                    await MainActor.run {
                        selectedMedia.append(SelectedMediaItem(
                            pickerItem: item,
                            type: .video,
                            videoURL: url
                        ))
                    }
                }
            } else {
                if let imageData = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: imageData) {
                    await MainActor.run {
                        selectedMedia.append(SelectedMediaItem(
                            pickerItem: item,
                            type: .image,
                            image: uiImage
                        ))
                    }
                }
            }
        }

        // Clear picker items after loading
        await MainActor.run {
            photosPickerItems = []
        }
    }

    private func addCameraImage(_ image: UIImage) {
        guard selectedMedia.count < maxSelections else { return }

        selectedMedia.append(SelectedMediaItem(
            type: .image,
            image: image
        ))
    }

    private func removeMedia(_ item: SelectedMediaItem) {
        selectedMedia.removeAll { $0.id == item.id }
    }
}

// MARK: - Selected Media Item

struct SelectedMediaItem: Identifiable {
    let id: String
    let pickerItem: PhotosPickerItem?
    let type: MediaItemType
    var image: UIImage?
    var videoURL: URL?

    enum MediaItemType {
        case image
        case video
    }

    init(id: String = UUID().uuidString, pickerItem: PhotosPickerItem? = nil, type: MediaItemType, image: UIImage? = nil, videoURL: URL? = nil) {
        self.id = id
        self.pickerItem = pickerItem
        self.type = type
        self.image = image
        self.videoURL = videoURL
    }
}

// MARK: - Media Thumbnail View

struct MediaThumbnailView: View {
    let item: SelectedMediaItem
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail content
            Group {
                if item.type == .image, let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if item.type == .video, let videoURL = item.videoURL {
                    VideoThumbnailView(url: videoURL)
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .offset(x: 8, y: -8)
        }
    }
}

// MARK: - Video Thumbnail View

struct VideoThumbnailView: View {
    let url: URL

    var body: some View {
        if let thumbnail = generateThumbnail(from: url) {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay {
                    Image(systemName: "video")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                }
        }
    }

    private func generateThumbnail(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void

    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedMedia: [SelectedMediaItem] = []

        var body: some View {
            VStack {
                MediaPickerView(selectedMedia: $selectedMedia, maxSelections: 5)
                    .padding()

                Spacer()

                Text("Selected: \(selectedMedia.count)")
                    .font(.caption)
            }
        }
    }

    return PreviewWrapper()
}

import Foundation
import SwiftUI
import PhotosUI
import AVFoundation
import Supabase
import Combine

/// Manager for handling media uploads to Supabase Storage
@MainActor
class MediaUploadManager: ObservableObject {
    static let shared = MediaUploadManager()

    @Published var uploadProgress: [String: Double] = [:]
    @Published var isUploading = false

    private let storageBucket = "job-media"
    private let maxImageSize: Int64 = 10 * 1024 * 1024  // 10 MB
    private let maxVideoSize: Int64 = 50 * 1024 * 1024  // 50 MB

    private init() {}

    // MARK: - Upload Multiple Media Items

    /// Uploads multiple photos and videos, returns array of MediaItem
    func uploadMediaItems(_ items: [PhotosPickerItem]) async throws -> [Job.MediaItem] {
        isUploading = true
        defer { isUploading = false }

        var uploadedItems: [Job.MediaItem] = []

        for item in items {
            do {
                if let mediaItem = try await uploadPhotoPickerItem(item) {
                    uploadedItems.append(mediaItem)
                }
            } catch {
                print("❌ Error uploading media item: \(error)")
                // Continue with other items even if one fails
            }
        }

        return uploadedItems
    }

    /// Uploads a UIImage directly, returns MediaItem
    func uploadImage(_ image: UIImage) async throws -> Job.MediaItem {
        let itemId = UUID().uuidString
        uploadProgress[itemId] = 0.0

        defer {
            uploadProgress.removeValue(forKey: itemId)
        }

        // Convert UIImage to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw MediaUploadError.failedToProcessImage
        }

        uploadProgress[itemId] = 0.2

        // Compress if needed
        let compressedData = try compressImageIfNeeded(imageData)

        uploadProgress[itemId] = 0.4

        // Generate unique filename
        let fileName = "jobs/\(UUID().uuidString).jpg"

        // Upload to Supabase Storage
        let uploadedPath = try await uploadToStorage(data: compressedData, path: fileName, contentType: "image/jpeg")

        uploadProgress[itemId] = 0.8

        // Get public URL
        let publicURL = try getPublicURL(for: uploadedPath)

        uploadProgress[itemId] = 1.0

        return Job.MediaItem(
            id: itemId,
            url: publicURL,
            type: .image,
            thumbnail_url: publicURL
        )
    }

    /// Uploads a video from URL directly, returns MediaItem
    func uploadVideo(from videoURL: URL) async throws -> Job.MediaItem {
        let itemId = UUID().uuidString
        uploadProgress[itemId] = 0.0

        defer {
            uploadProgress.removeValue(forKey: itemId)
        }

        // Get video data
        let videoData = try Data(contentsOf: videoURL)

        // Validate size
        if Int64(videoData.count) > maxVideoSize {
            throw MediaUploadError.fileTooLarge
        }

        uploadProgress[itemId] = 0.2

        // Generate unique filename
        let fileName = "jobs/\(UUID().uuidString).mp4"

        // Upload to Supabase Storage
        let uploadedPath = try await uploadToStorage(data: videoData, path: fileName, contentType: "video/mp4")

        uploadProgress[itemId] = 0.6

        // Get public URL
        let publicURL = try getPublicURL(for: uploadedPath)

        // Generate thumbnail
        let thumbnailURL = try? await generateVideoThumbnail(from: videoURL, itemId: itemId)

        uploadProgress[itemId] = 1.0

        return Job.MediaItem(
            id: itemId,
            url: publicURL,
            type: .video,
            thumbnail_url: thumbnailURL
        )
    }

    // MARK: - Upload Single PhotoPicker Item

    private func uploadPhotoPickerItem(_ item: PhotosPickerItem) async throws -> Job.MediaItem? {
        let itemId = UUID().uuidString
        uploadProgress[itemId] = 0.0

        defer {
            uploadProgress.removeValue(forKey: itemId)
        }

        // Check if it's an image or video
        if item.supportedContentTypes.contains(.image) || item.supportedContentTypes.contains(where: { $0.conforms(to: .image) }) {
            return try await uploadImage(from: item, itemId: itemId)
        } else if item.supportedContentTypes.contains(.movie) || item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            return try await uploadVideo(from: item, itemId: itemId)
        }

        return nil
    }

    // MARK: - Upload Image

    private func uploadImage(from item: PhotosPickerItem, itemId: String) async throws -> Job.MediaItem? {
        guard let imageData = try await item.loadTransferable(type: Data.self) else {
            throw MediaUploadError.failedToLoadImage
        }

        // Validate size
        if Int64(imageData.count) > maxImageSize {
            throw MediaUploadError.fileTooLarge
        }

        // Compress if needed
        let compressedData = try compressImageIfNeeded(imageData)

        uploadProgress[itemId] = 0.3

        // Generate unique filename
        let fileName = "jobs/\(UUID().uuidString).jpg"

        // Upload to Supabase Storage
        let uploadedPath = try await uploadToStorage(data: compressedData, path: fileName, contentType: "image/jpeg")

        uploadProgress[itemId] = 0.8

        // Get public URL
        let publicURL = try getPublicURL(for: uploadedPath)

        uploadProgress[itemId] = 1.0

        return Job.MediaItem(
            id: itemId,
            url: publicURL,
            type: .image,
            thumbnail_url: publicURL // For images, thumbnail is the same as the main URL
        )
    }

    // MARK: - Upload Video

    private func uploadVideo(from item: PhotosPickerItem, itemId: String) async throws -> Job.MediaItem? {
        guard let movie = try await item.loadTransferable(type: VideoPickerTransferable.self),
              let videoURL = movie.url else {
            throw MediaUploadError.failedToLoadVideo
        }

        // Get video data
        let videoData = try Data(contentsOf: videoURL)

        // Validate size
        if Int64(videoData.count) > maxVideoSize {
            throw MediaUploadError.fileTooLarge
        }

        uploadProgress[itemId] = 0.2

        // Generate unique filename
        let fileName = "jobs/\(UUID().uuidString).mp4"

        // Upload to Supabase Storage
        let uploadedPath = try await uploadToStorage(data: videoData, path: fileName, contentType: "video/mp4")

        uploadProgress[itemId] = 0.6

        // Get public URL
        let publicURL = try getPublicURL(for: uploadedPath)

        // Generate thumbnail
        let thumbnailURL = try? await generateVideoThumbnail(from: videoURL, itemId: itemId)

        uploadProgress[itemId] = 1.0

        return Job.MediaItem(
            id: itemId,
            url: publicURL,
            type: .video,
            thumbnail_url: thumbnailURL
        )
    }

    // MARK: - Storage Operations

    private func uploadToStorage(data: Data, path: String, contentType: String) async throws -> String {
        try await supabase.storage
            .from(storageBucket)
            .upload(
                path,
                data: data,
                options: .init(contentType: contentType)
            )

        return path
    }

    private func getPublicURL(for path: String) throws -> String {
        try supabase.storage
            .from(storageBucket)
            .getPublicURL(path: path)
            .absoluteString
    }

    // MARK: - Image Compression

    private func compressImageIfNeeded(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw MediaUploadError.failedToProcessImage
        }

        // Resize if too large
        let maxDimension: CGFloat = 1920
        let resizedImage: UIImage

        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            resizedImage = image
        }

        // Compress to JPEG with quality 0.8
        guard let compressedData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw MediaUploadError.failedToProcessImage
        }

        return compressedData
    }

    // MARK: - Video Thumbnail Generation

    private func generateVideoThumbnail(from videoURL: URL, itemId: String) async throws -> String {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        let thumbnail = UIImage(cgImage: cgImage)

        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            throw MediaUploadError.failedToGenerateThumbnail
        }

        // Upload thumbnail
        let thumbnailPath = "jobs/thumbnails/\(UUID().uuidString).jpg"
        let uploadedPath = try await uploadToStorage(data: thumbnailData, path: thumbnailPath, contentType: "image/jpeg")

        return try getPublicURL(for: uploadedPath)
    }

    // MARK: - Delete Media

    func deleteMedia(at path: String) async throws {
        // Extract path from full URL if needed
        let cleanPath = path.components(separatedBy: storageBucket + "/").last ?? path

        try await supabase.storage
            .from(storageBucket)
            .remove(paths: [cleanPath])
    }
}

// MARK: - Video Transferable

struct VideoPickerTransferable: Transferable {
    let url: URL?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url!)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "video-\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// MARK: - Errors

enum MediaUploadError: LocalizedError {
    case failedToLoadImage
    case failedToLoadVideo
    case failedToProcessImage
    case failedToGenerateThumbnail
    case fileTooLarge
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .failedToLoadImage:
            return "Failed to load image from picker"
        case .failedToLoadVideo:
            return "Failed to load video from picker"
        case .failedToProcessImage:
            return "Failed to process image"
        case .failedToGenerateThumbnail:
            return "Failed to generate video thumbnail"
        case .fileTooLarge:
            return "File is too large. Max 10MB for images, 50MB for videos"
        case .uploadFailed:
            return "Failed to upload media to server"
        }
    }
}

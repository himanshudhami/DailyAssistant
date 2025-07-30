//
//  AttachmentService.swift
//  AINoteTakingApp
//
//  Service for handling attachment file operations and creation.
//  Manages file storage, thumbnail generation, and attachment metadata.
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import UIKit

// MARK: - Attachment Service Errors
enum AttachmentServiceError: LocalizedError {
    case imageConversionFailed
    case fileWriteFailed
    case directoryCreationFailed
    case thumbnailGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to JPEG"
        case .fileWriteFailed:
            return "Failed to write file to disk"
        case .directoryCreationFailed:
            return "Failed to create attachments directory"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        }
    }
}

// MARK: - Attachment Service
@MainActor
class AttachmentService {
    
    // MARK: - Singleton
    static let shared = AttachmentService()
    private init() {}
    
    // MARK: - Private Properties
    private lazy var attachmentsDirectory: URL = {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("Attachments")
    }()
    
    // MARK: - Public Methods
    
    /// Creates an image attachment from a UIImage
    /// - Parameters:
    ///   - image: The source image
    ///   - compressionQuality: JPEG compression quality (0.0 to 1.0)
    ///   - thumbnailSize: Size for the thumbnail
    /// - Returns: Created attachment
    /// - Throws: AttachmentServiceError if creation fails
    func createImageAttachment(
        from image: UIImage,
        compressionQuality: CGFloat = 0.8,
        thumbnailSize: CGSize = CGSize(width: 200, height: 200)
    ) async throws -> Attachment {
        
        // Ensure attachments directory exists
        try createAttachmentsDirectoryIfNeeded()
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            throw AttachmentServiceError.imageConversionFailed
        }
        
        // Generate unique filename
        let fileName = "\(UUID().uuidString).jpg"
        let imageURL = attachmentsDirectory.appendingPathComponent(fileName)
        
        // Write image to disk
        do {
            try imageData.write(to: imageURL)
        } catch {
            throw AttachmentServiceError.fileWriteFailed
        }
        
        // Create thumbnail
        let thumbnailData = try await createThumbnail(from: image, size: thumbnailSize)
        
        // Create and return attachment
        return Attachment(
            fileName: fileName,
            fileExtension: "jpg",
            mimeType: "image/jpeg",
            fileSize: Int64(imageData.count),
            localURL: imageURL,
            thumbnailData: thumbnailData,
            type: .image
        )
    }
    
    /// Creates a thumbnail from an image
    /// - Parameters:
    ///   - image: Source image
    ///   - size: Desired thumbnail size
    /// - Returns: Thumbnail data as JPEG
    /// - Throws: AttachmentServiceError if thumbnail creation fails
    private func createThumbnail(from image: UIImage, size: CGSize) async throws -> Data? {
        let resizedImage = await resizeImage(image, to: size)
        
        guard let thumbnailData = resizedImage.jpegData(compressionQuality: 0.7) else {
            throw AttachmentServiceError.thumbnailGenerationFailed
        }
        
        return thumbnailData
    }
    
    /// Resizes an image to the specified size
    /// - Parameters:
    ///   - image: Source image
    ///   - size: Target size
    /// - Returns: Resized image
    private func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderer = UIGraphicsImageRenderer(size: size)
                let resizedImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                continuation.resume(returning: resizedImage)
            }
        }
    }
    
    /// Creates the attachments directory if it doesn't exist
    /// - Throws: AttachmentServiceError if directory creation fails
    private func createAttachmentsDirectoryIfNeeded() throws {
        do {
            try FileManager.default.createDirectory(
                at: attachmentsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw AttachmentServiceError.directoryCreationFailed
        }
    }
    
    /// Deletes an attachment file from disk
    /// - Parameter attachment: The attachment to delete
    /// - Returns: True if deletion was successful
    func deleteAttachment(_ attachment: Attachment) async -> Bool {
        let localURL = attachment.localURL
        
        do {
            try FileManager.default.removeItem(at: localURL)
            return true
        } catch {
            print("❌ Failed to delete attachment file: \(error)")
            return false
        }
    }
    
    /// Gets the size of the attachments directory
    /// - Returns: Total size in bytes
    func getAttachmentsDirectorySize() async -> Int64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: 0)
                    return
                }
                
                var totalSize: Int64 = 0
                
                if let enumerator = FileManager.default.enumerator(at: self.attachmentsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                    for case let fileURL as URL in enumerator {
                        do {
                            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                            totalSize += Int64(resourceValues.fileSize ?? 0)
                        } catch {
                            // Continue with other files
                        }
                    }
                }
                
                continuation.resume(returning: totalSize)
            }
        }
    }
    
    /// Cleans up orphaned attachment files (files not referenced by any note)
    /// - Parameter referencedFileNames: Set of file names that are still referenced
    /// - Returns: Number of files cleaned up
    func cleanupOrphanedFiles(referencedFileNames: Set<String>) async -> Int {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: 0)
                    return
                }
                
                var cleanedCount = 0
                
                do {
                    let fileURLs = try FileManager.default.contentsOfDirectory(
                        at: self.attachmentsDirectory,
                        includingPropertiesForKeys: nil
                    )
                    
                    for fileURL in fileURLs {
                        let fileName = fileURL.lastPathComponent
                        if !referencedFileNames.contains(fileName) {
                            try FileManager.default.removeItem(at: fileURL)
                            cleanedCount += 1
                        }
                    }
                } catch {
                    print("❌ Failed to cleanup orphaned files: \(error)")
                }
                
                continuation.resume(returning: cleanedCount)
            }
        }
    }
}

//
//  FileImportManager.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import UIKit
import PDFKit
import Vision
import UniformTypeIdentifiers
import Combine

// MARK: - Import Result Types
struct ImportResult {
    let success: Bool
    let attachment: Attachment?
    let extractedText: String?
    let error: String?
}

struct ProcessedFileContent {
    let text: String
    let metadata: FileMetadata
    let thumbnail: UIImage?
}

struct FileMetadata {
    let fileName: String
    let fileSize: Int64
    let mimeType: String
    let creationDate: Date?
    let modificationDate: Date?
}

// MARK: - File Import Manager
@MainActor
class FileImportManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private struct ImportConfig {
        static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
        static let supportedImageTypes: [UTType] = [.jpeg, .png, .heic, .tiff, .gif]
        static let supportedDocumentTypes: [UTType] = [.pdf, .plainText, .rtf, .html]
        static let thumbnailSize = CGSize(width: 200, height: 200)
    }
    
    // MARK: - Initialization
    init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        let attachmentsDir = documentsDirectory.appendingPathComponent("Attachments")
        let thumbnailsDir = documentsDirectory.appendingPathComponent("Thumbnails")
        
        try? fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Main Import Methods
    func importFile(from url: URL) async -> ImportResult {
        isProcessing = true
        processingProgress = 0
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0
            }
        }
        
        do {
            // Step 1: Validate file
            await updateProgress(0.1)
            try validateFile(at: url)
            
            // Step 2: Get file metadata
            await updateProgress(0.2)
            let metadata = try getFileMetadata(from: url)
            
            // Step 3: Copy file to app directory
            await updateProgress(0.3)
            let localURL = try copyFileToAppDirectory(from: url, metadata: metadata)
            
            // Step 4: Determine file type and process accordingly
            await updateProgress(0.4)
            let fileType = determineAttachmentType(from: url)
            
            // Step 5: Extract text content
            await updateProgress(0.6)
            let extractedText = try await extractTextContent(from: localURL, type: fileType)
            
            // Step 6: Generate thumbnail
            await updateProgress(0.8)
            let thumbnail = try await generateThumbnail(from: localURL, type: fileType)
            
            // Step 7: Create attachment
            await updateProgress(1.0)
            let attachment = createAttachment(
                from: localURL,
                metadata: metadata,
                type: fileType,
                thumbnail: thumbnail
            )
            
            return ImportResult(
                success: true,
                attachment: attachment,
                extractedText: extractedText,
                error: nil
            )
            
        } catch {
            await MainActor.run {
                errorMessage = "Import failed: \(error.localizedDescription)"
            }
            
            return ImportResult(
                success: false,
                attachment: nil,
                extractedText: nil,
                error: error.localizedDescription
            )
        }
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            processingProgress = progress
        }
    }
    
    // MARK: - File Validation
    private func validateFile(at url: URL) throws {
        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileImportError.fileNotFound
        }
        
        // Check file size
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        guard fileSize <= ImportConfig.maxFileSize else {
            throw FileImportError.fileTooLarge
        }
        
        // Check if file type is supported
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
        guard let contentType = resourceValues.contentType,
              isSupportedFileType(contentType) else {
            throw FileImportError.unsupportedFileType
        }
    }
    
    private func isSupportedFileType(_ contentType: UTType) -> Bool {
        return ImportConfig.supportedImageTypes.contains(contentType) ||
               ImportConfig.supportedDocumentTypes.contains(contentType)
    }
    
    // MARK: - File Processing
    private func getFileMetadata(from url: URL) throws -> FileMetadata {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
        
        return FileMetadata(
            fileName: url.lastPathComponent,
            fileSize: attributes[.size] as? Int64 ?? 0,
            mimeType: resourceValues.contentType?.preferredMIMEType ?? "application/octet-stream",
            creationDate: attributes[.creationDate] as? Date,
            modificationDate: attributes[.modificationDate] as? Date
        )
    }
    
    private func copyFileToAppDirectory(from sourceURL: URL, metadata: FileMetadata) throws -> URL {
        let attachmentsDir = documentsDirectory.appendingPathComponent("Attachments")
        let fileName = "\(UUID().uuidString)_\(metadata.fileName)"
        let destinationURL = attachmentsDir.appendingPathComponent(fileName)
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
    
    private func determineAttachmentType(from url: URL) -> AttachmentType {
        guard let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return .other
        }
        
        if contentType.conforms(to: .image) {
            return .image
        } else if contentType.conforms(to: .pdf) {
            return .pdf
        } else if contentType.conforms(to: .text) || contentType.conforms(to: .rtf) {
            return .document
        } else if contentType.conforms(to: .audio) {
            return .audio
        } else if contentType.conforms(to: .movie) {
            return .video
        }
        
        return .other
    }
    
    // MARK: - Text Extraction
    private func extractTextContent(from url: URL, type: AttachmentType) async throws -> String? {
        switch type {
        case .pdf:
            return try extractTextFromPDF(url)
        case .image:
            return try await performOCR(on: url)
        case .document:
            return try extractTextFromDocument(url)
        default:
            return nil
        }
    }
    
    func extractTextFromPDF(_ url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw FileImportError.pdfProcessingFailed
        }
        
        var extractedText = ""
        
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                extractedText += pageText + "\n"
            }
        }
        
        return extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func performOCR(on imageURL: URL) async throws -> String {
        guard let image = UIImage(contentsOfFile: imageURL.path),
              let cgImage = image.cgImage else {
            throw FileImportError.imageProcessingFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func extractTextFromDocument(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        
        if let text = String(data: data, encoding: .utf8) {
            return text
        } else if let text = String(data: data, encoding: .ascii) {
            return text
        } else {
            throw FileImportError.textExtractionFailed
        }
    }
    
    // MARK: - Thumbnail Generation
    private func generateThumbnail(from url: URL, type: AttachmentType) async throws -> Data? {
        switch type {
        case .image:
            return try generateImageThumbnail(from: url)
        case .pdf:
            return try generatePDFThumbnail(from: url)
        default:
            return nil
        }
    }
    
    private func generateImageThumbnail(from url: URL) throws -> Data? {
        guard let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        
        let thumbnail = image.resizedForImport(to: ImportConfig.thumbnailSize)
        return thumbnail.jpegData(compressionQuality: 0.8)
    }
    
    private func generatePDFThumbnail(from url: URL) throws -> Data? {
        guard let pdfDocument = PDFDocument(url: url),
              let firstPage = pdfDocument.page(at: 0) else {
            return nil
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: ImportConfig.thumbnailSize)
        
        let thumbnail = renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: ImportConfig.thumbnailSize))
            
            context.cgContext.translateBy(x: 0, y: ImportConfig.thumbnailSize.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            
            let scaleX = ImportConfig.thumbnailSize.width / pageRect.width
            let scaleY = ImportConfig.thumbnailSize.height / pageRect.height
            let scale = min(scaleX, scaleY)
            
            context.cgContext.scaleBy(x: scale, y: scale)
            firstPage.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return thumbnail.jpegData(compressionQuality: 0.8)
    }
    
    // MARK: - Attachment Creation
    private func createAttachment(
        from url: URL,
        metadata: FileMetadata,
        type: AttachmentType,
        thumbnail: Data?
    ) -> Attachment {
        return Attachment(
            fileName: metadata.fileName,
            fileExtension: url.pathExtension,
            mimeType: metadata.mimeType,
            fileSize: metadata.fileSize,
            localURL: url,
            thumbnailData: thumbnail,
            type: type
        )
    }
    
    // MARK: - Utility Methods
    func deleteAttachment(_ attachment: Attachment) throws {
        try fileManager.removeItem(at: attachment.localURL)
        
        // Also delete thumbnail if it exists
        let thumbnailsDir = documentsDirectory.appendingPathComponent("Thumbnails")
        let thumbnailURL = thumbnailsDir.appendingPathComponent("\(attachment.id.uuidString).jpg")
        
        if fileManager.fileExists(atPath: thumbnailURL.path) {
            try fileManager.removeItem(at: thumbnailURL)
        }
    }
    
    func getAttachmentSize() -> String {
        let attachmentsDir = documentsDirectory.appendingPathComponent("Attachments")
        
        guard let enumerator = fileManager.enumerator(at: attachmentsDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 MB"
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - File Import Errors
enum FileImportError: LocalizedError {
    case fileNotFound
    case fileTooLarge
    case unsupportedFileType
    case pdfProcessingFailed
    case imageProcessingFailed
    case textExtractionFailed
    case copyFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .fileTooLarge:
            return "File is too large (max 50MB)"
        case .unsupportedFileType:
            return "Unsupported file type"
        case .pdfProcessingFailed:
            return "Failed to process PDF"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .textExtractionFailed:
            return "Failed to extract text"
        case .copyFailed:
            return "Failed to copy file"
        }
    }
}

// MARK: - UIImage Extension for FileImportManager
private extension UIImage {
    func resizedForImport(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

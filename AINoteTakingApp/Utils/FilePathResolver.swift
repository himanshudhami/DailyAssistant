//
//  FilePathResolver.swift
//  AINoteTakingApp
//
//  Utility for resolving file paths that may have changed due to iOS sandbox container changes
//

import Foundation

class FilePathResolver {
    static let shared = FilePathResolver()
    
    private init() {}
    
    /// Resolves a potentially outdated file URL to the current container path
    /// - Parameter url: The stored file URL (may be from previous app launch)
    /// - Returns: The current valid file URL, or nil if file doesn't exist
    func resolveFileURL(_ url: URL) -> URL? {
        // First, check if the original path still works
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        
        // If original path doesn't work, try to find file in current container
        let fileName = url.lastPathComponent
        let relativePath = getRelativePath(from: url)
        
        // Get current documents directory
        guard let currentDocumentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Reconstruct the path in current container
        let resolvedURL = currentDocumentsURL.appendingPathComponent(relativePath)
        
        if FileManager.default.fileExists(atPath: resolvedURL.path) {
            print("📁 Resolved path: \(url.path) -> \(resolvedURL.path)")
            return resolvedURL
        }
        
        // If that doesn't work, try common attachment locations
        let possiblePaths = [
            currentDocumentsURL.appendingPathComponent("Attachments/\(fileName)"),
            currentDocumentsURL.appendingPathComponent("Images/\(fileName)"),
            currentDocumentsURL.appendingPathComponent("Audio/\(fileName)"),
            currentDocumentsURL.appendingPathComponent("Documents/\(fileName)")
        ]
        
        for possiblePath in possiblePaths {
            if FileManager.default.fileExists(atPath: possiblePath.path) {
                print("📁 Found file at alternative path: \(possiblePath.path)")
                return possiblePath
            }
        }
        
        print("❌ Could not resolve file path for: \(fileName)")
        return nil
    }
    
    /// Updates an attachment's URL to the current resolved path
    /// - Parameter attachment: The attachment to update
    /// - Returns: Updated attachment with resolved path, or nil if file not found
    func resolveAttachment(_ attachment: Attachment) -> Attachment? {
        guard let resolvedURL = resolveFileURL(attachment.localURL) else {
            return nil
        }
        
        // If the URL is different, create updated attachment
        if resolvedURL != attachment.localURL {
            var updatedAttachment = attachment
            updatedAttachment.localURL = resolvedURL
            return updatedAttachment
        }
        
        return attachment
    }
    
    /// Creates a file URL that's more resilient to container path changes
    /// - Parameters:
    ///   - fileName: The filename
    ///   - subdirectory: The subdirectory within Documents (e.g., "Attachments")
    /// - Returns: The file URL in current container
    static func createResistantFileURL(fileName: String, subdirectory: String = "Attachments") -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let subdirectoryURL = documentsURL.appendingPathComponent(subdirectory)
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: subdirectoryURL, withIntermediateDirectories: true)
        
        return subdirectoryURL.appendingPathComponent(fileName)
    }
    
    // MARK: - Private Helpers
    
    /// Extracts relative path from Documents directory
    private func getRelativePath(from url: URL) -> String {
        let pathComponents = url.pathComponents
        
        // Find "Documents" in the path
        if let documentsIndex = pathComponents.firstIndex(of: "Documents") {
            let relativeComponents = Array(pathComponents.suffix(from: documentsIndex + 1))
            return relativeComponents.joined(separator: "/")
        }
        
        // Fallback: assume it's in Attachments
        return "Attachments/\(url.lastPathComponent)"
    }
    
    /// Migrates all attachments in Core Data to use current container paths
    func migrateAttachmentPaths() {
        // This would update all attachments in Core Data with resolved paths
        // Implementation depends on your Core Data setup
        print("📁 Starting attachment path migration...")
        
        // Get all notes with attachments from DataManager
        let dataManager = DataManager.shared
        let allNotes = dataManager.fetchAllNotes()
        
        var migratedCount = 0
        var notFoundCount = 0
        
        for note in allNotes {
            var needsUpdate = false
            var updatedAttachments: [Attachment] = []
            
            for attachment in note.attachments {
                if let resolvedAttachment = resolveAttachment(attachment) {
                    updatedAttachments.append(resolvedAttachment)
                    if resolvedAttachment.localURL != attachment.localURL {
                        needsUpdate = true
                        migratedCount += 1
                    }
                } else {
                    print("⚠️ File not found for attachment: \(attachment.fileName)")
                    notFoundCount += 1
                    // Keep the attachment but mark it as problematic
                    updatedAttachments.append(attachment)
                }
            }
            
            if needsUpdate {
                // Update the note with resolved attachment paths
                var updatedNote = note
                updatedNote.attachments = updatedAttachments
                dataManager.updateNote(updatedNote)
            }
        }
        
        print("📁 Migration complete: \(migratedCount) paths updated, \(notFoundCount) files not found")
    }
}
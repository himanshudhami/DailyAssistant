//
//  CameraProcessingService.swift
//  AINoteTakingApp
//
//  Service for processing camera-captured images.
//  Handles OCR, location capture, and note creation with attachments.
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import UIKit

// MARK: - Camera Processing Result
struct CameraProcessingResult {
    let note: Note
    let success: Bool
    let error: Error?
}

// MARK: - Camera Processing Service
@MainActor
class CameraProcessingService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    
    // MARK: - Dependencies
    private let dataManager: DataManager
    private let locationService: LocationService
    private let ocrService: OCRService
    private let attachmentService: AttachmentService
    
    // MARK: - Initialization
    init(
        dataManager: DataManager = DataManager.shared,
        locationService: LocationService? = nil,
        ocrService: OCRService? = nil,
        attachmentService: AttachmentService? = nil
    ) {
        self.dataManager = dataManager
        self.locationService = locationService ?? LocationService()
        self.ocrService = ocrService ?? OCRService()
        self.attachmentService = attachmentService ?? AttachmentService.shared
    }
    
    // MARK: - Public Methods
    
    /// Processes a camera-captured image and creates a note with attachment
    /// - Parameters:
    ///   - image: The captured image
    ///   - folderId: Optional folder ID to create the note in
    /// - Returns: Processing result with created note or error
    func processCameraImage(_ image: UIImage, folderId: UUID? = nil) async -> CameraProcessingResult {
        isProcessing = true
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            processingProgress = 0.0
        }
        
        do {
            // Step 1: Request location permission and get location (10% progress)
            processingProgress = 0.1
            print("📍 Requesting location permission...")
            let permissionGranted = await locationService.requestLocationPermission()
            print("📍 Location permission granted: \(permissionGranted)")

            let location = await locationService.getCurrentLocationSafely()
            if let location = location {
                print("📍 Location captured successfully: \(location.latitude), \(location.longitude)")
            } else {
                print("⚠️ No location captured - using test coordinates for debugging")
                // For testing purposes, add some test coordinates if location is unavailable
                // This helps verify the UI works when location data is present
                // Remove this in production or when location services are working
            }
            
            // Step 2: Perform OCR (40% progress)
            processingProgress = 0.4
            let ocrResult = await ocrService.performOCR(on: image)
            print("📝 OCR completed with \(ocrResult.rawText.count) characters")
            
            // Step 3: Create image attachment (70% progress)
            processingProgress = 0.7
            let attachment = try await attachmentService.createImageAttachment(from: image)
            print("📎 Attachment created: \(attachment.fileName)")
            
            // Step 4: Create note with attachment (90% progress)
            processingProgress = 0.9
            let note = createCameraNote(
                ocrText: ocrResult.rawText.isEmpty ? nil : ocrResult.rawText,
                location: location,
                attachment: attachment,
                folderId: folderId
            )

            // Step 5: Complete processing (100% progress)
            processingProgress = 1.0

            print("✅ Camera note created successfully with attachment")
            return CameraProcessingResult(note: note, success: true, error: nil)
            
        } catch {
            print("❌ Failed to process camera image: \(error)")
            return CameraProcessingResult(note: Note(), success: false, error: error)
        }
    }
    
    // MARK: - Private Methods
    
    /// Creates a camera note with the processed data
    /// - Parameters:
    ///   - ocrText: Extracted text from OCR
    ///   - location: Location coordinates
    ///   - attachment: Created image attachment
    ///   - folderId: Optional folder ID
    /// - Returns: Created note
    private func createCameraNote(
        ocrText: String?,
        location: LocationCoordinate?,
        attachment: Attachment,
        folderId: UUID?
    ) -> Note {
        
        // Generate title based on OCR content or use default
        let title = generateNoteTitle(from: ocrText)
        
        // Create content with OCR text if available
        let content = ocrText ?? ""
        
        // Create the note
        print("🏗️ Creating camera note with location: lat=\(location?.latitude ?? -999), lng=\(location?.longitude ?? -999)")
        var createdNote = dataManager.createCameraNote(
            image: nil, // We don't need to pass the image since we have the attachment
            ocrText: ocrText,
            latitude: location?.latitude,
            longitude: location?.longitude,
            folderId: folderId
        )

        // Add the attachment to the note
        createdNote.attachments = [attachment]
        dataManager.updateNote(createdNote)

        print("✅ Camera note created with ID: \(createdNote.id), lat=\(createdNote.latitude ?? -999), lng=\(createdNote.longitude ?? -999), attachments=\(createdNote.attachments.count)")
        return createdNote
    }
    
    /// Generates a meaningful title from OCR text - ALWAYS includes timestamp for camera photos
    /// - Parameter ocrText: The extracted text
    /// - Returns: Generated title with timestamp
    private func generateNoteTitle(from ocrText: String?) -> String {
        let dateString = formatCurrentDate()

        guard let ocrText = ocrText, !ocrText.isEmpty else {
            return "Camera Photo - \(dateString)"
        }

        // Take first line as title but include timestamp
        let lines = ocrText.components(separatedBy: .newlines)
        let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if firstLine.isEmpty {
            return "Camera Photo - \(dateString)"
        }

        // Limit OCR text length to leave room for timestamp
        let maxOCRLength = 30
        let ocrTitle = firstLine.count > maxOCRLength ?
            String(firstLine.prefix(maxOCRLength)) + "..." : firstLine

        return "\(ocrTitle) - \(dateString)"
    }
    
    /// Formats current date for note titles
    /// - Returns: Formatted date string
    private func formatCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - DataManager Extension for Camera Notes
extension DataManager {
    /// Creates a camera note with image metadata
    /// - Parameters:
    ///   - image: The captured image (optional, used for metadata)
    ///   - ocrText: Extracted text from OCR
    ///   - latitude: Location latitude
    ///   - longitude: Location longitude
    ///   - attachment: Image attachment to include with the note
    ///   - folderId: Optional folder ID
    /// - Returns: Created note
    func createCameraNote(
        image: UIImage?,
        ocrText: String?,
        latitude: Double?,
        longitude: Double?,
        attachment: Attachment? = nil,
        folderId: UUID?
    ) -> Note {
        
        // Generate title with date and time - ALWAYS include timestamp for camera photos
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())

        let title: String
        if let ocrText = ocrText, !ocrText.isEmpty {
            // If OCR found text, use first line as title but still include timestamp
            let firstLine = ocrText.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !firstLine.isEmpty {
                // Limit OCR text length to leave room for timestamp
                let maxOCRLength = 30
                let ocrTitle = firstLine.count > maxOCRLength ?
                    String(firstLine.prefix(maxOCRLength)) + "..." : firstLine
                title = "\(ocrTitle) - \(dateString)"
            } else {
                title = "Camera Photo - \(dateString)"
            }
        } else {
            // No OCR text, use default camera photo title with timestamp
            title = "Camera Photo - \(dateString)"
        }
        
        // Create note
        let note = Note(
            title: title,
            content: ocrText ?? "",
            folderId: folderId,
            ocrText: ocrText,
            latitude: latitude,
            longitude: longitude
        )
        
        // Save to database
        let noteEntity = NoteEntity(context: context)
        note.updateEntity(noteEntity, context: context)
        save()
        
        // Update folder note count if needed
        if let folderId = folderId {
            updateFolderNoteCount(folderId)
        }
        
        return note
    }
}

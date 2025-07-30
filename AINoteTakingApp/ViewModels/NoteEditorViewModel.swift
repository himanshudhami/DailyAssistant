//
//  NoteEditorViewModel.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import UIKit
import CoreData
import Combine

// MARK: - Image Import Errors
enum ImageImportError: LocalizedError {
    case invalidImageData
    case saveFailed
    case directoryCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Unable to process image data"
        case .saveFailed:
            return "Failed to save image to disk"
        case .directoryCreationFailed:
            return "Failed to create attachments directory"
        }
    }
}

@MainActor
class NoteEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var title = ""
    @Published var content = ""
    @Published var tags: [String] = []
    @Published var selectedCategory: Category?
    @Published var attachments: [Attachment] = []
    @Published var actionItems: [ActionItem] = []
    @Published var audioURL: URL?
    @Published var transcript: String?
    @Published var aiSummary: String?
    @Published var keyPoints: [String] = []
    @Published var ocrText: String?
    @Published var latitude: Double?
    @Published var longitude: Double?

    @Published var isProcessing = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    var isNewNote: Bool {
        return originalNote == nil
    }
    
    var hasContent: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               audioURL != nil ||
               !attachments.isEmpty
    }
    
    var hasChanges: Bool {
        guard let originalNote = originalNote else { return hasContent }

        return title != originalNote.title ||
               content != originalNote.content ||
               tags != originalNote.tags ||
               selectedCategory?.id != originalNote.category?.id ||
               attachments.count != originalNote.attachments.count ||
               audioURL != originalNote.audioURL ||
               transcript != originalNote.transcript ||
               ocrText != originalNote.ocrText ||
               latitude != originalNote.latitude ||
               longitude != originalNote.longitude
    }
    
    // MARK: - Private Properties
    private let originalNote: Note?
    private let currentFolder: Folder?
    private let dataManager = DataManager.shared
    private let aiProcessor = AIProcessor()
    private let fileImportManager = FileImportManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(note: Note? = nil, currentFolder: Folder? = nil) {
        self.originalNote = note
        self.currentFolder = currentFolder
        
        if let note = note {
            loadNoteData(note)
        }
        
        setupAutoSave()
    }
    
    private func loadNoteData(_ note: Note) {
        title = note.title
        content = note.content
        tags = note.tags
        selectedCategory = note.category
        attachments = note.attachments
        actionItems = note.actionItems
        audioURL = note.audioURL
        transcript = note.transcript
        aiSummary = note.aiSummary
        keyPoints = note.keyPoints
        ocrText = note.ocrText
        latitude = note.latitude
        longitude = note.longitude
    }
    
    private func setupAutoSave() {
        // Disabled auto-save to prevent duplicates
        // Users must manually save notes using the save button
    }
    
    // MARK: - Save Operations
    func saveNote() async {
        guard hasContent else { return }
        
        await MainActor.run {
            self.isSaving = true
            self.errorMessage = nil
        }
        
        let noteToSave = createNoteFromCurrentData()
        
        if originalNote != nil {
            // Update existing note - this properly saves attachments via updateEntity
            dataManager.updateNote(noteToSave)
        } else {
            // Create new note - use createNoteFromData to save all properties including attachments
            let _ = dataManager.createNoteFromData(noteToSave)
        }
        
        await MainActor.run {
            self.isSaving = false
        }
    }
    
    private func autoSave() async {
        guard hasChanges && hasContent && !isSaving else { return }
        
        let noteToSave = createNoteFromCurrentData()
        
        if originalNote != nil {
            dataManager.updateNote(noteToSave)
        } else {
            let _ = dataManager.createNoteFromData(noteToSave)
        }
    }
    
    private func createNoteFromCurrentData() -> Note {
        let noteId = originalNote?.id ?? UUID()
        let createdDate = originalNote?.createdDate ?? Date()
        
        return Note(
            id: noteId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            audioURL: audioURL,
            attachments: attachments,
            tags: tags,
            category: selectedCategory,
            folderId: originalNote?.folderId ?? currentFolder?.id,
            createdDate: createdDate,
            modifiedDate: Date(),
            aiSummary: aiSummary,
            keyPoints: keyPoints,
            actionItems: actionItems,
            transcript: transcript,
            ocrText: ocrText,
            latitude: latitude,
            longitude: longitude
        )
    }
    
    
    // MARK: - AI Processing
    func processWithAI() async {
        guard hasContent else { return }
        
        isProcessing = true
        errorMessage = nil
        
        let fullContent = content + " " + (transcript ?? "")
        let processedContent = await aiProcessor.processContent(fullContent)
        
        await MainActor.run {
            self.applyAIProcessing(processedContent)
            self.isProcessing = false
        }
    }
    
    func applyAIProcessing(_ processedContent: ProcessedContent) {
        // Apply AI suggestions
        if aiSummary?.isEmpty ?? true {
            aiSummary = processedContent.summary
        }
        
        if keyPoints.isEmpty {
            keyPoints = processedContent.keyPoints
        }
        
        // Merge action items (avoid duplicates)
        let newActionItems = processedContent.actionItems.filter { newItem in
            !actionItems.contains { existingItem in
                existingItem.title.lowercased() == newItem.title.lowercased()
            }
        }
        actionItems.append(contentsOf: newActionItems)
        
        // Merge tags (avoid duplicates)
        let newTags = processedContent.suggestedTags.filter { !tags.contains($0) }
        tags.append(contentsOf: newTags)
        
        // Suggest category if none selected
        if selectedCategory == nil {
            selectedCategory = processedContent.suggestedCategory
        }
    }
    
    // MARK: - File Import
    func handleFileImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            isProcessing = true
            
            do {
                let importResult = await fileImportManager.importFile(from: url)
                
                await MainActor.run {
                    if importResult.success, let attachment = importResult.attachment {
                        self.attachments.append(attachment)
                        
                        // Add extracted text to OCR field and content if available
                        if let extractedText = importResult.extractedText, !extractedText.isEmpty {
                            // Store in dedicated OCR field for searching
                            if let existingOcrText = self.ocrText, !existingOcrText.isEmpty {
                                self.ocrText = existingOcrText + "\n\n--- From \(attachment.fileName) ---\n" + extractedText
                            } else {
                                self.ocrText = "--- From \(attachment.fileName) ---\n" + extractedText
                            }
                            
                            // Also add to content for display
                            if !self.content.isEmpty {
                                self.content += "\n\n"
                            }
                            self.content += "--- Imported from \(attachment.fileName) ---\n"
                            self.content += extractedText
                        }
                    } else if let error = importResult.error {
                        self.errorMessage = error
                    }
                    
                    self.isProcessing = false
                }
            }
            
        case .failure(let error):
            await MainActor.run {
                self.errorMessage = "File import failed: \(error.localizedDescription)"
            }
        }
    }
    
    func handleImageImport(_ image: UIImage) async {
        isProcessing = true
        
        do {
            // Ensure image data is available
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw ImageImportError.invalidImageData
            }
            
            // Create attachments directory if it doesn't exist
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let attachmentsDir = documentsDir.appendingPathComponent("Attachments")
            
            if !FileManager.default.fileExists(atPath: attachmentsDir.path) {
                try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
            }
            
            // Generate unique filename and save image
            let fileName = "\(UUID().uuidString).jpg"
            let imageURL = attachmentsDir.appendingPathComponent(fileName)
            try imageData.write(to: imageURL)
            
            // Verify file was saved successfully
            guard FileManager.default.fileExists(atPath: imageURL.path) else {
                throw ImageImportError.saveFailed
            }
            
            // Create thumbnail
            let thumbnailData = image.resizedForEditor(to: CGSize(width: 200, height: 200)).jpegData(compressionQuality: 0.7)
            
            // Create attachment
            let attachment = Attachment(
                fileName: fileName,
                fileExtension: "jpg",
                mimeType: "image/jpeg",
                fileSize: Int64(imageData.count),
                localURL: imageURL,
                thumbnailData: thumbnailData,
                type: .image
            )
            
            // Perform OCR (optional, don't fail if OCR fails)
            var extractedText = ""
            do {
                extractedText = try await fileImportManager.performOCR(on: imageURL)
            } catch {
                print("OCR failed, continuing without text extraction: \(error)")
            }
            
            await MainActor.run {
                self.attachments.append(attachment)
                
                // Add extracted text to OCR field and content if available
                if !extractedText.isEmpty {
                    // Store in dedicated OCR field for searching
                    if let existingOcrText = self.ocrText, !existingOcrText.isEmpty {
                        self.ocrText = existingOcrText + "\n\n--- Text from image ---\n" + extractedText
                    } else {
                        self.ocrText = "--- Text from image ---\n" + extractedText
                    }
                    
                    // Also add to content for display
                    if !self.content.isEmpty {
                        self.content += "\n\n"
                    }
                    self.content += "--- Text from image ---\n"
                    self.content += extractedText
                }
                
                self.isProcessing = false
                print("✅ Image saved successfully at: \(imageURL.path)")
                print("✅ Attachments count: \(self.attachments.count)")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Image import failed: \(error.localizedDescription)"
                self.isProcessing = false
                print("❌ Image import failed: \(error)")
            }
        }
    }
    
    // MARK: - Attachment Management
    func removeAttachment(_ attachment: Attachment) {
        attachments.removeAll { $0.id == attachment.id }
        
        // Delete file from disk
        do {
            try fileImportManager.deleteAttachment(attachment)
        } catch {
            errorMessage = "Failed to delete attachment file: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Action Item Management
    func addActionItem(_ title: String, priority: Priority = .medium) {
        let actionItem = ActionItem(title: title, priority: priority)
        actionItems.append(actionItem)
    }
    
    func removeActionItem(_ actionItem: ActionItem) {
        actionItems.removeAll { $0.id == actionItem.id }
    }
    
    func toggleActionItemCompletion(_ actionItem: ActionItem) {
        if let index = actionItems.firstIndex(where: { $0.id == actionItem.id }) {
            actionItems[index].completed.toggle()
        }
    }
    
    // MARK: - Tag Management
    func addTag(_ tag: String) {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
        }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    // MARK: - Validation
    func validateNote() -> [String] {
        var errors: [String] = []
        
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           audioURL == nil &&
           attachments.isEmpty {
            errors.append("Note must have at least a title, content, audio, or attachments")
        }
        
        if title.count > 200 {
            errors.append("Title must be less than 200 characters")
        }
        
        if content.count > 50000 {
            errors.append("Content must be less than 50,000 characters")
        }
        
        if tags.count > 20 {
            errors.append("Maximum 20 tags allowed")
        }
        
        return errors
    }
    
    // MARK: - Cleanup
    func discardChanges() {
        if let originalNote = originalNote {
            loadNoteData(originalNote)
        } else {
            // Clear all fields for new note
            title = ""
            content = ""
            tags = []
            selectedCategory = nil
            attachments = []
            actionItems = []
            audioURL = nil
            transcript = nil
            aiSummary = nil
            keyPoints = []
            ocrText = nil
            latitude = nil
            longitude = nil
        }
    }
}

// MARK: - UIImage Extension for NoteEditorViewModel
private extension UIImage {
    func resizedForEditor(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

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
               !attachments.isEmpty // This now includes audio files too
    }
    
    var hasChanges: Bool {
        guard let originalNote = originalNote else { return hasContent }

        return title != originalNote.title ||
               content != originalNote.content ||
               tags != originalNote.tags ||
               selectedCategory?.id != originalNote.category?.id ||
               attachments.count != originalNote.attachments.count ||
               transcript != originalNote.transcript ||
               ocrText != originalNote.ocrText ||
               latitude != originalNote.latitude ||
               longitude != originalNote.longitude
        // Note: Removed audioURL check since we now use attachments for all files
    }
    
    // MARK: - Private Properties
    private var originalNote: Note? // Made mutable to update after first save
    private let currentFolder: Folder?
    private let dataManager = DataManager.shared
    private let networkService = NetworkService.shared
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
    
    deinit {
        // Clean up all subscriptions to prevent memory leaks
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
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
        guard hasContent && !isSaving else { return }
        
        isSaving = true
        errorMessage = nil
        
        let noteToSave = createNoteFromCurrentData()
        
        print("💾 Starting save for note: \(noteToSave.title) (Local ID: \(noteToSave.id))")
        print("💾 Is existing note: \(originalNote != nil)")
        
        do {
            // Save locally first (immediate save)
            if originalNote != nil {
                // Update existing note
                dataManager.updateNote(noteToSave)
                print("💾 Updated local note")
            } else {
                // Create new note
                let _ = dataManager.createNoteFromData(noteToSave)
                print("💾 Created new local note")
            }
            
            // Save to backend (only if authenticated)
            var backendNote: Note? = nil
            if networkService.isAuthenticated {
                print("💾 Starting backend save...")
                backendNote = try await saveToBackend(noteToSave)
                
                // Upload attachments after note is created/updated using backend note ID
                if !noteToSave.attachments.isEmpty, let backendNote = backendNote {
                    try await uploadAttachments(for: backendNote, originalAttachments: noteToSave.attachments)
                }
                
                // Update local note with backend info and mark as synced
                if let backendNote = backendNote {
                    await updateLocalNoteWithBackendInfo(backendNote)
                }
            }
            
            // Update originalNote after first successful save to prevent treating subsequent saves as new notes
            if originalNote == nil {
                originalNote = noteToSave
                print("📝 Set originalNote after first save: \(noteToSave.id)")
            }
            
            print("✅ Note saved successfully - Local: ✓ Backend: \(networkService.isAuthenticated ? "✓" : "⚠️ Offline")")
            
        } catch {
            errorMessage = "Failed to save note: \(error.localizedDescription)"
            print("❌ Note save failed: \(error)")
        }
        
        isSaving = false
    }
    
    private func saveToBackend(_ note: Note) async throws -> Note {
        return try await withCheckedThrowingContinuation { continuation in
            
            // Prepare note for backend (handle local-only data)
            let backendNote = prepareNoteForBackend(note)
            
            // For existing notes, check if already synced. For new notes, always create.
            let noteToCheck = originalNote ?? note
            let isExistingNote = originalNote != nil
            let isAlreadySynced = isNoteSyncedToBackend(noteToCheck)
            
            print("📊 Save decision: isExisting=\(isExistingNote), isAlreadySynced=\(isAlreadySynced)")
            
            // Create a single-use cancellable for this operation
            var saveCancellable: AnyCancellable?
            
            if isExistingNote && isAlreadySynced {
                // Update existing note that exists on backend
                let backendId = getBackendNoteId(noteToCheck)
                print("🔄 Updating existing backend note: \(backendNote.title) (Backend ID: \(backendId))")
                saveCancellable = networkService.notes.updateNote(
                    backendId,
                    title: backendNote.title,
                    content: backendNote.content,
                    tags: backendNote.tags,
                    folderId: backendNote.folderId,
                    categoryId: nil // Skip category for now until properly synced
                )
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            print("❌ Backend update failed, will try creating as new note instead")
                            // If update fails, try creating as new note (fallback for local-only notes)
                            self.createNoteOnBackend(backendNote, continuation: continuation)
                        }
                        saveCancellable = nil // Clean up reference
                    },
                    receiveValue: { updatedNote in
                        print("✅ Note updated on backend: \(updatedNote.title) (ID: \(updatedNote.id))")
                        // Mark as synced immediately after successful update
                        self.markNoteAsSynced(noteToCheck)
                        continuation.resume(returning: updatedNote)
                        saveCancellable = nil // Clean up reference
                    }
                )
            } else {
                // Create new note (either truly new or local-only existing note)
                print("➕ Creating new note on backend: \(backendNote.title)")
                createNoteOnBackend(backendNote, continuation: continuation)
            }
        }
    }
    
    private func createNoteOnBackend(_ note: Note, continuation: CheckedContinuation<Note, Error>) {
        // Create a single-use cancellable for this operation
        var createCancellable: AnyCancellable?
        createCancellable = networkService.notes.createNote(note)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ Backend creation error: \(error)")
                        continuation.resume(throwing: error)
                    }
                    createCancellable = nil // Clean up reference
                },
                receiveValue: { createdNote in
                    print("✅ Note created on backend: \(createdNote.title) (ID: \(createdNote.id))")
                    // Mark this note as synced for future reference
                    self.markNoteAsSynced(createdNote)
                    continuation.resume(returning: createdNote)
                    createCancellable = nil // Clean up reference
                }
            )
    }
    
    private func isNoteSyncedToBackend(_ note: Note) -> Bool {
        // Check if this note has been synced to backend before
        let syncKey = "synced_note_\(note.id)"
        let hasSyncFlag = UserDefaults.standard.bool(forKey: syncKey)
        
        // Also check if we have a backend ID mapping for this note
        let mappingKey = "backend_id_\(note.id)"
        let hasMapping = UserDefaults.standard.string(forKey: mappingKey) != nil
        
        let isSynced = hasSyncFlag || hasMapping
        print("🔍 Sync check for note \(note.id): syncFlag=\(hasSyncFlag), hasMapping=\(hasMapping), result=\(isSynced)")
        
        return isSynced
    }
    
    private func markNoteAsSynced(_ note: Note) {
        let key = "synced_note_\(note.id)"
        UserDefaults.standard.set(true, forKey: key)
    }
    
    private func getBackendNoteId(_ localNote: Note) -> UUID {
        // First check if we have a stored mapping for this local note
        let mappingKey = "backend_id_\(localNote.id)"
        if let backendIdString = UserDefaults.standard.string(forKey: mappingKey),
           let backendId = UUID(uuidString: backendIdString) {
            return backendId
        }
        
        // If no mapping exists, use the local ID (for notes that were updated directly)
        return localNote.id
    }
    
    private func updateLocalNoteWithBackendInfo(_ backendNote: Note) async {
        await MainActor.run {
            // If this was a new note creation, the backend note will have a different ID
            // We need to track this mapping for future updates
            if let originalNote = self.originalNote {
                // This was an update - mark the original note as synced
                self.markNoteAsSynced(originalNote)
            } else {
                // This was a new note creation - the backend assigned a new ID
                print("📝 New note created: Local ID \(self.createNoteFromCurrentData().id) → Backend ID \(backendNote.id)")
                
                // Store the mapping between local ID and backend ID for future reference
                let localNoteId = self.createNoteFromCurrentData().id
                let backendId = backendNote.id
                
                // Mark as synced using backend ID
                self.markNoteAsSynced(backendNote)
                
                // Also store mapping for future updates
                let mappingKey = "backend_id_\(localNoteId)"
                UserDefaults.standard.set(backendId.uuidString, forKey: mappingKey)
                
                print("✅ Note sync mapping stored: \(localNoteId) → \(backendId)")
            }
        }
    }
    
    private func prepareNoteForBackend(_ note: Note) -> Note {
        // Create a copy of the note without local-only data that might cause validation errors
        var backendNote = note
        
        // For now, don't send category_id until we implement proper category sync
        // This prevents "category not found" errors
        backendNote.category = nil
        
        // Also skip folder_id if it's local-only (we'll implement folder sync later)
        // For now, just send nil to avoid validation errors
        backendNote.folderId = nil
        
        // Remove attachments from the initial note creation
        // We'll upload them separately after note is created
        backendNote.attachments = []
        backendNote.actionItems = []
        
        // Don't send legacy audioURL field (use attachments instead)
        backendNote.audioURL = nil
        
        print("📤 Sending to backend: title='\(backendNote.title)', content=\(backendNote.content.count) chars")
        
        return backendNote
    }
    
    private func uploadAttachments(for backendNote: Note, originalAttachments: [Attachment]) async throws {
        print("📎 Uploading \(originalAttachments.count) attachments for backend note: \(backendNote.title) (ID: \(backendNote.id))")
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploads = originalAttachments.compactMap { attachment -> AnyPublisher<Attachment, NetworkError>? in
                print("📎 Preparing to upload: \(attachment.fileName)")
                
                // Use FilePathResolver to get the current valid path
                guard let resolvedURL = FilePathResolver.shared.resolveFileURL(attachment.localURL) else {
                    print("❌ Could not resolve file path for: \(attachment.fileName)")
                    return Fail<Attachment, NetworkError>(error: NetworkError.noData)
                        .eraseToAnyPublisher()
                }
                
                print("📎 Resolved URL: \(resolvedURL)")
                let mimeType = mimeType(for: resolvedURL)
                
                return networkService.attachments.uploadAttachment(
                    for: backendNote.id,
                    fileURL: resolvedURL,
                    mimeType: mimeType
                )
            }
            
            // Create a single-use cancellable for this upload operation
            var uploadCancellable: AnyCancellable?
            uploadCancellable = Publishers.MergeMany(uploads)
                .collect()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            print("✅ All attachments uploaded successfully")
                            continuation.resume()
                        case .failure(let error):
                            print("❌ Attachment upload failed: \(error)")
                            continuation.resume(throwing: error)
                        }
                        uploadCancellable = nil // Clean up reference
                    },
                    receiveValue: { uploadedAttachments in
                        print("✅ Uploaded \(uploadedAttachments.count) attachments")
                    }
                )
        }
    }
    
    // MARK: - Audio Recording Handler
    
    func handleAudioRecording(audioURL: URL, transcript: String?) async {
        isProcessing = true
        
        do {
            // Get file info
            let fileSize = try audioURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            let fileName = audioURL.lastPathComponent
            let fileExtension = audioURL.pathExtension
            
            print("🎵 Processing audio recording: \(fileName) (\(fileSize) bytes)")
            
            // Create audio attachment
            let audioAttachment = Attachment(
                fileName: fileName,
                fileExtension: fileExtension,
                mimeType: mimeType(for: audioURL),
                fileSize: Int64(fileSize),
                localURL: audioURL,
                thumbnailData: nil,
                type: .audio
            )
            
            await MainActor.run {
                // Add to attachments (supporting multiple audio files)
                self.attachments.append(audioAttachment)
                
                // Set transcript if provided
                if let transcript = transcript, !transcript.isEmpty {
                    if let existingTranscript = self.transcript, !existingTranscript.isEmpty {
                        self.transcript = existingTranscript + "\n\n--- Audio transcription ---\n" + transcript
                    } else {
                        self.transcript = "--- Audio transcription ---\n" + transcript
                    }
                }
                
                self.isProcessing = false
                print("✅ Audio attachment added: \(fileName)")
            }
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.errorMessage = "Failed to process audio recording: \(error.localizedDescription)"
                print("❌ Audio processing failed: \(error)")
            }
        }
    }
    
    private func mimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic", "heif":
            return "image/heic"
        case "pdf":
            return "application/pdf"
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/m4a"
        case "wav":
            return "audio/wav"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "txt":
            return "text/plain"
        default:
            return "application/octet-stream"
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
            audioURL: nil, // Legacy field - now audio files are in attachments array
            attachments: attachments, // This now includes both images AND audio files
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
            
            // Generate unique filename and get resistant file URL
            let fileName = "\(UUID().uuidString).jpg"
            guard let imageURL = FilePathResolver.createResistantFileURL(fileName: fileName, subdirectory: "Attachments") else {
                throw ImageImportError.directoryCreationFailed
            }
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

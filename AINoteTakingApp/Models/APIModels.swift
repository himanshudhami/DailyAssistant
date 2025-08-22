//
//  APIModels.swift
//  AINoteTakingApp
//
//  API models that match the backend Go models exactly
//  Created by AI Assistant on 2025-01-29.
//

import Foundation

// MARK: - Authentication Models

struct UserCreateRequest: Codable {
    let email: String
    let username: String
    let password: String
    let firstName: String
    let lastName: String
    
    enum CodingKeys: String, CodingKey {
        case email, username, password
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct UserLoginRequest: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let user: UserResponse
    let token: String
}

// MARK: - User Models

struct UserResponse: Codable, Identifiable {
    let id: UUID
    let email: String
    let username: String
    let firstName: String
    let lastName: String
    let isActive: Bool
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, email, username
        case firstName = "first_name"
        case lastName = "last_name"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Note Models

struct APINote: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let content: String
    let audioURL: String?
    let tags: [String]
    let categoryId: UUID?
    let folderId: UUID?
    let createdAt: String
    let updatedAt: String
    let aiSummary: String?
    let keyPoints: [String]
    let transcript: String?
    let ocrText: String?
    let latitude: Double?
    let longitude: Double?
    let attachments: [APIAttachment]?
    let actionItems: [APIActionItem]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, tags, latitude, longitude, attachments
        case userId = "user_id"
        case audioURL = "audio_url"
        case categoryId = "category_id" 
        case folderId = "folder_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case aiSummary = "ai_summary"
        case keyPoints = "key_points"
        case transcript, ocrText = "ocr_text"
        case actionItems = "action_items"
    }
}

struct NoteCreateRequest: Codable {
    let title: String
    let content: String
    let audioURL: String?
    let tags: [String]
    let categoryId: UUID?
    let folderId: UUID?
    let aiSummary: String?
    let keyPoints: [String]
    let transcript: String?
    let ocrText: String?
    let latitude: Double?
    let longitude: Double?
    let attachments: [AttachmentCreateRequest]?
    let actionItems: [ActionItemCreateRequest]?
    
    enum CodingKeys: String, CodingKey {
        case title, content, tags, latitude, longitude, attachments
        case audioURL = "audio_url"
        case categoryId = "category_id"
        case folderId = "folder_id"
        case aiSummary = "ai_summary"
        case keyPoints = "key_points"
        case transcript, ocrText = "ocr_text"
        case actionItems = "action_items"
    }
}

// MARK: - Folder Models
// Note: FolderSentiment is defined in Note.swift

struct APIFolder: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let parentFolderId: UUID?
    let createdAt: String
    let updatedAt: String
    let sortOrder: Int
    let sentiment: FolderSentiment
    let noteCount: Int
    let childFolders: [APIFolder]?
    let notes: [APINote]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, sentiment, notes
        case userId = "user_id"
        case parentFolderId = "parent_folder_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case sortOrder = "sort_order"
        case noteCount = "note_count"
        case childFolders = "child_folders"
    }
}

struct FolderCreateRequest: Codable {
    let name: String
    let parentFolderId: UUID?
    let sortOrder: Int
    let sentiment: FolderSentiment
    
    enum CodingKeys: String, CodingKey {
        case name, sentiment
        case parentFolderId = "parent_folder_id"
        case sortOrder = "sort_order"
    }
}

// MARK: - Attachment Models
// Note: AttachmentType is defined in Note.swift

struct APIAttachment: Codable, Identifiable {
    let id: UUID
    let noteId: UUID
    let fileName: String
    let fileExtension: String
    let mimeType: String
    let fileSize: Int64
    let localURL: String
    let thumbnailData: Data?
    let type: AttachmentType
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, type
        case noteId = "note_id"
        case fileName = "file_name"
        case fileExtension = "file_extension"
        case mimeType = "mime_type"
        case fileSize = "file_size"
        case localURL = "local_url"
        case thumbnailData = "thumbnail_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AttachmentCreateRequest: Codable {
    let fileName: String
    let fileExtension: String
    let mimeType: String
    let fileSize: Int64
    let localURL: String
    let thumbnailData: Data?
    let type: AttachmentType
    
    enum CodingKeys: String, CodingKey {
        case type
        case fileName = "file_name"
        case fileExtension = "file_extension"
        case mimeType = "mime_type"
        case fileSize = "file_size"
        case localURL = "local_url"
        case thumbnailData = "thumbnail_data"
    }
}

// MARK: - Action Item Models

struct APIActionItem: Codable, Identifiable {
    let id: UUID
    let noteId: UUID
    let content: String
    let isCompleted: Bool
    let dueDate: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, content
        case noteId = "note_id"
        case isCompleted = "is_completed"
        case dueDate = "due_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ActionItemCreateRequest: Codable {
    let content: String
    let isCompleted: Bool
    let dueDate: String?
    
    enum CodingKeys: String, CodingKey {
        case content
        case isCompleted = "is_completed"
        case dueDate = "due_date"
    }
}

// MARK: - Model Converters

extension Note {
    // Convert local Note to API create request
    func toCreateRequest() -> NoteCreateRequest {
        return NoteCreateRequest(
            title: title,
            content: content,
            audioURL: audioURL?.absoluteString,
            tags: tags,
            categoryId: category?.id,
            folderId: folderId,
            aiSummary: aiSummary,
            keyPoints: keyPoints,
            transcript: transcript,
            ocrText: ocrText,
            latitude: latitude,
            longitude: longitude,
            attachments: attachments.map { $0.toCreateRequest() },
            actionItems: actionItems.map { $0.toCreateRequest() }
        )
    }
    
    // Create local Note from API response
    static func from(_ apiNote: APINote) -> Note {
        let dateFormatter = ISO8601DateFormatter()
        
        return Note(
            id: apiNote.id,
            title: apiNote.title,
            content: apiNote.content,
            audioURL: apiNote.audioURL.flatMap { URL(string: $0) },
            attachments: apiNote.attachments?.compactMap { Attachment.from($0) } ?? [],
            tags: apiNote.tags,
            category: nil, // Will need to fetch separately or include in API response
            folderId: apiNote.folderId,
            createdDate: dateFormatter.date(from: apiNote.createdAt) ?? Date(),
            modifiedDate: dateFormatter.date(from: apiNote.updatedAt) ?? Date(),
            aiSummary: apiNote.aiSummary,
            keyPoints: apiNote.keyPoints,
            actionItems: apiNote.actionItems?.compactMap { ActionItem.from($0) } ?? [],
            transcript: apiNote.transcript,
            ocrText: apiNote.ocrText,
            latitude: apiNote.latitude,
            longitude: apiNote.longitude
        )
    }
}

extension Folder {
    // Convert local Folder to API create request
    func toCreateRequest() -> FolderCreateRequest {
        return FolderCreateRequest(
            name: name,
            parentFolderId: parentFolderId,
            sortOrder: sortOrder,
            sentiment: sentiment
        )
    }
    
    // Create local Folder from API response
    static func from(_ apiFolder: APIFolder) -> Folder {
        let dateFormatter = ISO8601DateFormatter()
        
        return Folder(
            id: apiFolder.id,
            name: apiFolder.name,
            parentFolderId: apiFolder.parentFolderId,
            createdDate: dateFormatter.date(from: apiFolder.createdAt) ?? Date(),
            modifiedDate: dateFormatter.date(from: apiFolder.updatedAt) ?? Date(),
            sortOrder: apiFolder.sortOrder,
            sentiment: apiFolder.sentiment,
            noteCount: apiFolder.noteCount
        )
    }
}

extension Attachment {
    // Convert local Attachment to API create request
    func toCreateRequest() -> AttachmentCreateRequest {
        return AttachmentCreateRequest(
            fileName: fileName,
            fileExtension: fileExtension,
            mimeType: mimeType,
            fileSize: fileSize,
            localURL: localURL.absoluteString,
            thumbnailData: thumbnailData,
            type: type
        )
    }
    
    // Create local Attachment from API response
    static func from(_ apiAttachment: APIAttachment) -> Attachment? {
        let dateFormatter = ISO8601DateFormatter()
        
        guard let url = URL(string: apiAttachment.localURL) else { return nil }
        
        return Attachment(
            id: apiAttachment.id,
            fileName: apiAttachment.fileName,
            fileExtension: apiAttachment.fileExtension,
            mimeType: apiAttachment.mimeType,
            fileSize: apiAttachment.fileSize,
            localURL: url,
            thumbnailData: apiAttachment.thumbnailData,
            type: apiAttachment.type,
            createdDate: dateFormatter.date(from: apiAttachment.createdAt) ?? Date()
        )
    }
}

extension ActionItem {
    // Convert local ActionItem to API create request
    func toCreateRequest() -> ActionItemCreateRequest {
        let dateFormatter = ISO8601DateFormatter()
        
        return ActionItemCreateRequest(
            content: title,
            isCompleted: completed,
            dueDate: dueDate.map { dateFormatter.string(from: $0) }
        )
    }
    
    // Create local ActionItem from API response
    static func from(_ apiItem: APIActionItem) -> ActionItem? {
        let dateFormatter = ISO8601DateFormatter()
        
        return ActionItem(
            id: apiItem.id,
            title: apiItem.content,
            completed: apiItem.isCompleted,
            priority: .medium, // Default as API doesn't have priority
            dueDate: apiItem.dueDate.flatMap { dateFormatter.date(from: $0) },
            createdDate: dateFormatter.date(from: apiItem.createdAt) ?? Date()
        )
    }
}
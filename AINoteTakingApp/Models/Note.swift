//
//  Note.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import CoreData

// MARK: - Note Model
struct Note: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var audioURL: URL?
    var attachments: [Attachment]
    var tags: [String]
    var category: Category?
    var createdDate: Date
    var modifiedDate: Date
    var aiSummary: String?
    var keyPoints: [String]
    var actionItems: [ActionItem]
    var transcript: String?
    
    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        audioURL: URL? = nil,
        attachments: [Attachment] = [],
        tags: [String] = [],
        category: Category? = nil,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        aiSummary: String? = nil,
        keyPoints: [String] = [],
        actionItems: [ActionItem] = [],
        transcript: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.audioURL = audioURL
        self.attachments = attachments
        self.tags = tags
        self.category = category
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.aiSummary = aiSummary
        self.keyPoints = keyPoints
        self.actionItems = actionItems
        self.transcript = transcript
    }
}

// MARK: - Category Model
struct Category: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var color: String
    var sortOrder: Int
    var createdDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        color: String = "#007AFF",
        sortOrder: Int = 0,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.createdDate = createdDate
    }
}

// MARK: - Attachment Model
struct Attachment: Codable, Identifiable, Hashable {
    let id: UUID
    var fileName: String
    var fileExtension: String
    var mimeType: String
    var fileSize: Int64
    var localURL: URL
    var thumbnailData: Data?
    var type: AttachmentType
    var createdDate: Date
    
    init(
        id: UUID = UUID(),
        fileName: String,
        fileExtension: String,
        mimeType: String,
        fileSize: Int64,
        localURL: URL,
        thumbnailData: Data? = nil,
        type: AttachmentType,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.localURL = localURL
        self.thumbnailData = thumbnailData
        self.type = type
        self.createdDate = createdDate
    }
}

// MARK: - AttachmentType Enum
enum AttachmentType: String, Codable, CaseIterable {
    case image = "image"
    case pdf = "pdf"
    case document = "document"
    case audio = "audio"
    case video = "video"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .image: return "Image"
        case .pdf: return "PDF"
        case .document: return "Document"
        case .audio: return "Audio"
        case .video: return "Video"
        case .other: return "Other"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .document: return "doc.text"
        case .audio: return "waveform"
        case .video: return "video"
        case .other: return "paperclip"
        }
    }
}

// MARK: - ActionItem Model
struct ActionItem: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var completed: Bool
    var priority: Priority
    var dueDate: Date?
    var createdDate: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        completed: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.completed = completed
        self.priority = priority
        self.dueDate = dueDate
        self.createdDate = createdDate
    }
}

// MARK: - Priority Enum
enum Priority: Int, Codable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#34C759"
        case .medium: return "#FF9500"
        case .high: return "#FF3B30"
        case .urgent: return "#AF52DE"
        }
    }
}

// MARK: - Core Data Extensions
extension Note {
    init(from entity: NoteEntity) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.content = entity.content ?? ""
        self.audioURL = entity.audioURL
        self.attachments = entity.attachments?.compactMap { attachment in
            guard let attachmentEntity = attachment as? AttachmentEntity else { return nil }
            return Attachment(from: attachmentEntity)
        } ?? []
        self.tags = entity.tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
        self.category = entity.category.map { Category(from: $0) }
        self.createdDate = entity.createdDate ?? Date()
        self.modifiedDate = entity.modifiedDate ?? Date()
        self.aiSummary = entity.aiSummary
        self.keyPoints = entity.keyPoints?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        self.actionItems = entity.actionItems?.compactMap { actionItem in
            guard let actionItemEntity = actionItem as? ActionItemEntity else { return nil }
            return ActionItem(from: actionItemEntity)
        } ?? []
        self.transcript = entity.transcript
    }
    
    func updateEntity(_ entity: NoteEntity) {
        entity.id = self.id
        entity.title = self.title
        entity.content = self.content
        entity.audioURL = self.audioURL
        entity.tags = self.tags.joined(separator: ",")
        entity.createdDate = self.createdDate
        entity.modifiedDate = self.modifiedDate
        entity.aiSummary = self.aiSummary
        entity.keyPoints = self.keyPoints.joined(separator: "\n")
        entity.transcript = self.transcript
    }
}

extension Category {
    init(from entity: CategoryEntity) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.color = entity.color ?? "#007AFF"
        self.sortOrder = Int(entity.sortOrder)
        self.createdDate = entity.createdDate ?? Date()
    }
    
    func updateEntity(_ entity: CategoryEntity) {
        entity.id = self.id
        entity.name = self.name
        entity.color = self.color
        entity.sortOrder = Int16(self.sortOrder)
        entity.createdDate = self.createdDate
    }
}

extension Attachment {
    init(from entity: AttachmentEntity) {
        self.id = entity.id ?? UUID()
        self.fileName = entity.fileName ?? ""
        self.fileExtension = entity.fileExtension ?? ""
        self.mimeType = entity.mimeType ?? ""
        self.fileSize = entity.fileSize
        self.localURL = entity.localURL ?? URL(fileURLWithPath: "")
        self.thumbnailData = entity.thumbnailData
        self.type = AttachmentType(rawValue: entity.type ?? "other") ?? .other
        self.createdDate = entity.createdDate ?? Date()
    }
    
    func updateEntity(_ entity: AttachmentEntity) {
        entity.id = self.id
        entity.fileName = self.fileName
        entity.fileExtension = self.fileExtension
        entity.mimeType = self.mimeType
        entity.fileSize = self.fileSize
        entity.localURL = self.localURL
        entity.thumbnailData = self.thumbnailData
        entity.type = self.type.rawValue
        entity.createdDate = self.createdDate
    }
}

extension ActionItem {
    init(from entity: ActionItemEntity) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.completed = entity.completed
        self.priority = Priority(rawValue: Int(entity.priority)) ?? .medium
        self.dueDate = entity.dueDate
        self.createdDate = entity.createdDate ?? Date()
    }
    
    func updateEntity(_ entity: ActionItemEntity) {
        entity.id = self.id
        entity.title = self.title
        entity.completed = self.completed
        entity.priority = Int16(self.priority.rawValue)
        entity.dueDate = self.dueDate
        entity.createdDate = self.createdDate
    }
}

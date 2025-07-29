//
//  Note.swift
//  AINoteTakingApp
//
//  Core data models for the note-taking application with hierarchical organization.
//  Defines Note, Folder, Category, Attachment, and ActionItem structures.
//  Includes Core Data extensions for SQLite database integration.
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import CoreData

// MARK: - Folder Model
struct Folder: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var parentFolderId: UUID?
    var createdDate: Date
    var modifiedDate: Date
    var sortOrder: Int
    var sentiment: FolderSentiment
    var noteCount: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        parentFolderId: UUID? = nil,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        sortOrder: Int = 0,
        sentiment: FolderSentiment = .neutral,
        noteCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.parentFolderId = parentFolderId
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.sortOrder = sortOrder
        self.sentiment = sentiment
        self.noteCount = noteCount
    }
    
    var gradientColors: [String] {
        return sentiment.gradientColors
    }
}

// MARK: - Folder Sentiment Enum
enum FolderSentiment: String, Codable, CaseIterable {
    case veryPositive = "very_positive"
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
    case veryNegative = "very_negative"
    case mixed = "mixed"
    
    var displayName: String {
        switch self {
        case .veryPositive: return "Very Positive"
        case .positive: return "Positive"
        case .neutral: return "Neutral"
        case .negative: return "Negative"
        case .veryNegative: return "Very Negative"
        case .mixed: return "Mixed"
        }
    }
    
    var gradientColors: [String] {
        switch self {
        case .veryPositive:
            return ["#FFD700", "#FFA500", "#FF6B6B"] // Gold to Orange to Light Red
        case .positive:
            return ["#98FB98", "#87CEEB", "#DDA0DD"] // Light Green to Sky Blue to Plum
        case .neutral:
            return ["#F0F8FF", "#E6E6FA", "#D3D3D3"] // Alice Blue to Lavender to Light Gray
        case .negative:
            return ["#B0C4DE", "#778899", "#696969"] // Light Steel Blue to Light Slate Gray to Dim Gray
        case .veryNegative:
            return ["#8B0000", "#A0522D", "#2F4F4F"] // Dark Red to Saddle Brown to Dark Slate Gray
        case .mixed:
            return ["#FF69B4", "#9370DB", "#4169E1"] // Hot Pink to Medium Purple to Royal Blue
        }
    }
    
    var emoji: String {
        switch self {
        case .veryPositive: return "🌟"
        case .positive: return "😊"
        case .neutral: return "📁"
        case .negative: return "😔"
        case .veryNegative: return "😰"
        case .mixed: return "🎭"
        }
    }
}

// MARK: - Note Model
struct Note: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var audioURL: URL?
    var attachments: [Attachment]
    var tags: [String]
    var category: Category?
    var folderId: UUID?
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
        folderId: UUID? = nil,
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
        self.folderId = folderId
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
extension Folder {
    init(from entity: FolderEntity) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.parentFolderId = entity.parentFolder?.id
        self.createdDate = entity.createdDate ?? Date()
        self.modifiedDate = entity.modifiedDate ?? Date()
        self.sortOrder = Int(entity.sortOrder)
        self.sentiment = FolderSentiment(rawValue: entity.sentiment ?? "neutral") ?? .neutral
        self.noteCount = Int(entity.noteCount)
    }
    
    func updateEntity(_ entity: FolderEntity, context: NSManagedObjectContext) {
        entity.id = self.id
        entity.name = self.name
        entity.createdDate = self.createdDate
        entity.modifiedDate = self.modifiedDate
        entity.sortOrder = Int32(self.sortOrder)
        entity.sentiment = self.sentiment.rawValue
        entity.noteCount = Int32(self.noteCount)
        
        if let parentId = self.parentFolderId {
            let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", parentId as CVarArg)
            entity.parentFolder = try? context.fetch(request).first
        } else {
            entity.parentFolder = nil
        }
    }
}

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
        self.folderId = entity.folder?.id
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
    
    func updateEntity(_ entity: NoteEntity, context: NSManagedObjectContext) {
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
        
        if let folderId = self.folderId {
            let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
            entity.folder = try? context.fetch(request).first
        } else {
            entity.folder = nil
        }
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

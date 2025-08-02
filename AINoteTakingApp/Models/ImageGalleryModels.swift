//
//  ImageGalleryModels.swift
//  AINoteTakingApp
//
//  Enhanced models for image gallery functionality with metadata support.
//  Provides comprehensive image information and search context.
//
//  Created by AI Assistant on 2025-08-01.
//

import Foundation
import SwiftUI
import Vision

// MARK: - Image Search Result Types
struct EnhancedImageSearchResult {
    let note: Note
    let attachment: Attachment
    let relevanceScore: Float
    let matchType: ImageSearchMatchType
    let matchedContent: String
    let searchContext: ImageSearchContext
}

enum ImageSearchMatchType {
    case objectDetection
    case ocrText
    case visualFeatures
    case semanticContent
    case filename
    case noteContent
}

struct ImageSearchContext {
    let detectedObjects: [String]
    let ocrText: String?
    let dominantColors: [UIColor]
    let imageDescription: String?
    let confidence: Float
}

// MARK: - Enhanced Gallery Image Item
struct EnhancedGalleryImageItem: Identifiable, Hashable {
    let id = UUID()
    let attachment: Attachment
    let note: Note
    let thumbnail: UIImage?
    let searchContext: ImageSearchContext?
    let matchInfo: ImageMatchInfo?
    
    init(attachment: Attachment, note: Note, searchContext: ImageSearchContext? = nil, matchInfo: ImageMatchInfo? = nil) {
        self.attachment = attachment
        self.note = note
        self.searchContext = searchContext
        self.matchInfo = matchInfo
        self.thumbnail = Self.loadThumbnail(from: attachment)
    }
    
    init(from searchResult: EnhancedImageSearchResult) {
        self.attachment = searchResult.attachment
        self.note = searchResult.note
        self.searchContext = searchResult.searchContext
        self.matchInfo = ImageMatchInfo(
            matchType: searchResult.matchType,
            relevanceScore: searchResult.relevanceScore,
            matchedContent: searchResult.matchedContent
        )
        self.thumbnail = Self.loadThumbnail(from: searchResult.attachment)
    }
    
    private static func loadThumbnail(from attachment: Attachment) -> UIImage? {
        if let thumbnailData = attachment.thumbnailData {
            return UIImage(data: thumbnailData)
        }
        
        if let image = UIImage(contentsOfFile: attachment.localURL.path) {
            return image.thumbnail(size: CGSize(width: 200, height: 200))
        }
        
        return nil
    }
    
    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(attachment.id)
    }
    
    static func == (lhs: EnhancedGalleryImageItem, rhs: EnhancedGalleryImageItem) -> Bool {
        return lhs.attachment.id == rhs.attachment.id
    }
}

// MARK: - Image Match Information
struct ImageMatchInfo {
    let matchType: ImageSearchMatchType
    let relevanceScore: Float
    let matchedContent: String
    
    var displayText: String {
        switch matchType {
        case .objectDetection:
            return "Objects: \(matchedContent)"
        case .ocrText:
            return "Text: \(matchedContent)"
        case .visualFeatures:
            return "Visual: \(matchedContent)"
        case .semanticContent:
            return "Scene: \(matchedContent)"
        case .filename:
            return "File: \(matchedContent)"
        case .noteContent:
            return "Note: \(matchedContent)"
        }
    }
    
    var badgeColor: Color {
        switch matchType {
        case .objectDetection:
            return .blue
        case .ocrText:
            return .green
        case .visualFeatures:
            return .purple
        case .semanticContent:
            return .orange
        case .filename:
            return .gray
        case .noteContent:
            return .red
        }
    }
    
    var iconName: String {
        switch matchType {
        case .objectDetection:
            return "eye.fill"
        case .ocrText:
            return "text.viewfinder"
        case .visualFeatures:
            return "camera.filters"
        case .semanticContent:
            return "brain.head.profile"
        case .filename:
            return "doc.text"
        case .noteContent:
            return "note.text"
        }
    }
}

// MARK: - UIImage Thumbnail Extension
extension UIImage {
    func thumbnail(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
//
//  ImageMetadataSearchService.swift
//  AINoteTakingApp
//
//  Enhanced image metadata search service integrating object detection, OCR, and content analysis.
//  Provides comprehensive image search capabilities across visual content and metadata.
//  Follows SRP by focusing on image-specific search functionality.
//
//  Created by AI Assistant on 2025-08-01.
//

import Foundation
import Vision
import UIKit
import CoreML
import NaturalLanguage

// Note: EnhancedImageSearchResult, ImageSearchMatchType, and ImageSearchContext 
// are now defined in Models/ImageGalleryModels.swift for better organization

// MARK: - Image Metadata Search Service
@MainActor
class ImageMetadataSearchService: ObservableObject {
    
    // MARK: - Dependencies
    private let imageSearchManager = ImageSearchManager()
    private let dataManager = DataManager.shared
    
    // MARK: - Private Properties
    private var processedImagesCache: [UUID: ImageSearchContext] = [:]
    private let processingQueue = DispatchQueue(label: "image.metadata.processing", qos: .userInitiated)
    
    // Vision Requests
    private var ocrRequest: VNRecognizeTextRequest
    private var objectRecognitionRequest: VNClassifyImageRequest
    private var sceneClassificationRequest: VNClassifyImageRequest
    
    // MARK: - Initialization
    init() {
        self.ocrRequest = VNRecognizeTextRequest()
        self.objectRecognitionRequest = VNClassifyImageRequest()
        self.sceneClassificationRequest = VNClassifyImageRequest()
        setupVisionRequests()
    }
    
    // MARK: - Public Methods
    
    /// Comprehensive image search across all metadata types
    func searchImages(query: String, in notes: [Note]? = nil) async -> [EnhancedImageSearchResult] {
        let searchNotes = notes ?? dataManager.fetchAllNotes()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedQuery.isEmpty else { return [] }
        
        return await withTaskGroup(of: [EnhancedImageSearchResult].self, returning: [EnhancedImageSearchResult].self) { group in
            
            // Object detection search
            group.addTask {
                await self.searchByObjectDetection(query: trimmedQuery, notes: searchNotes)
            }
            
            // OCR text search
            group.addTask {
                await self.searchByOCRText(query: trimmedQuery, notes: searchNotes)
            }
            
            // Filename search
            group.addTask {
                await self.searchByFilename(query: trimmedQuery, notes: searchNotes)
            }
            
            // Note content search (for images in matching notes)
            group.addTask {
                await self.searchByNoteContent(query: trimmedQuery, notes: searchNotes)
            }
            
            // Scene classification search
            group.addTask {
                await self.searchBySceneClassification(query: trimmedQuery, notes: searchNotes)
            }
            
            var allResults: [EnhancedImageSearchResult] = []
            for await results in group {
                allResults.append(contentsOf: results)
            }
            
            return deduplicateAndRankResults(allResults)
        }
    }
    
    /// Pre-process and cache image metadata for faster searches
    func indexImages(in notes: [Note]) async {
        await withTaskGroup(of: Void.self) { group in
            for note in notes {
                for attachment in note.attachments where attachment.type == .image {
                    if processedImagesCache[attachment.id] == nil {
                        group.addTask {
                            await self.processImageMetadata(attachment: attachment, note: note)
                        }
                    }
                }
            }
        }
    }
    
    /// Get search context for a specific image
    func getImageContext(_ attachmentId: UUID) -> ImageSearchContext? {
        return processedImagesCache[attachmentId]
    }
}

// MARK: - Private Search Methods
private extension ImageMetadataSearchService {
    
    func searchByObjectDetection(query: String, notes: [Note]) async -> [EnhancedImageSearchResult] {
        var results: [EnhancedImageSearchResult] = []
        
        for note in notes {
            for attachment in note.attachments where attachment.type == .image {
                let context = await getOrCreateImageContext(attachment: attachment, note: note)
                
                let matchingObjects = context.detectedObjects.filter { object in
                    object.lowercased().contains(query) ||
                    query.contains(object.lowercased()) ||
                    calculateStringSimilarity(query, object.lowercased()) > 0.7
                }
                
                if !matchingObjects.isEmpty {
                    let score = calculateObjectMatchScore(matchingObjects, context.detectedObjects, query)
                    results.append(EnhancedImageSearchResult(
                        note: note,
                        attachment: attachment,
                        relevanceScore: score,
                        matchType: .objectDetection,
                        matchedContent: matchingObjects.joined(separator: ", "),
                        searchContext: context
                    ))
                }
            }
        }
        
        return results
    }
    
    func searchByOCRText(query: String, notes: [Note]) async -> [EnhancedImageSearchResult] {
        var results: [EnhancedImageSearchResult] = []
        
        for note in notes {
            for attachment in note.attachments where attachment.type == .image {
                let context = await getOrCreateImageContext(attachment: attachment, note: note)
                
                if let ocrText = context.ocrText,
                   ocrText.lowercased().contains(query) {
                    let score = calculateTextMatchScore(query, ocrText)
                    results.append(EnhancedImageSearchResult(
                        note: note,
                        attachment: attachment,
                        relevanceScore: score,
                        matchType: .ocrText,
                        matchedContent: extractMatchedTextSnippet(query, from: ocrText),
                        searchContext: context
                    ))
                }
            }
        }
        
        return results
    }
    
    func searchByFilename(query: String, notes: [Note]) async -> [EnhancedImageSearchResult] {
        var results: [EnhancedImageSearchResult] = []
        
        for note in notes {
            for attachment in note.attachments where attachment.type == .image {
                let filename = attachment.fileName.lowercased()
                if filename.contains(query) {
                    let context = await getOrCreateImageContext(attachment: attachment, note: note)
                    let score = calculateFilenameMatchScore(query, filename)
                    
                    results.append(EnhancedImageSearchResult(
                        note: note,
                        attachment: attachment,
                        relevanceScore: score,
                        matchType: .filename,
                        matchedContent: attachment.fileName,
                        searchContext: context
                    ))
                }
            }
        }
        
        return results
    }
    
    func searchByNoteContent(query: String, notes: [Note]) async -> [EnhancedImageSearchResult] {
        var results: [EnhancedImageSearchResult] = []
        
        let matchingNotes = notes.filter { note in
            note.title.lowercased().contains(query) ||
            note.content.lowercased().contains(query) ||
            note.tags.contains { $0.lowercased().contains(query) } ||
            note.aiSummary?.lowercased().contains(query) == true ||
            note.keyPoints.contains { $0.lowercased().contains(query) }
        }
        
        for note in matchingNotes {
            for attachment in note.attachments where attachment.type == .image {
                let context = await getOrCreateImageContext(attachment: attachment, note: note)
                let score = calculateNoteContentMatchScore(query, note)
                
                results.append(EnhancedImageSearchResult(
                    note: note,
                    attachment: attachment,
                    relevanceScore: score * 0.8, // Lower weight for note content matches
                    matchType: .noteContent,
                    matchedContent: extractNoteContentSnippet(query, from: note),
                    searchContext: context
                ))
            }
        }
        
        return results
    }
    
    func searchBySceneClassification(query: String, notes: [Note]) async -> [EnhancedImageSearchResult] {
        var results: [EnhancedImageSearchResult] = []
        
        for note in notes {
            for attachment in note.attachments where attachment.type == .image {
                let context = await getOrCreateImageContext(attachment: attachment, note: note)
                
                if let description = context.imageDescription,
                   description.lowercased().contains(query) {
                    let score = calculateDescriptionMatchScore(query, description)
                    results.append(EnhancedImageSearchResult(
                        note: note,
                        attachment: attachment,
                        relevanceScore: score,
                        matchType: .semanticContent,
                        matchedContent: description,
                        searchContext: context
                    ))
                }
            }
        }
        
        return results
    }
}

// MARK: - Image Processing Methods
private extension ImageMetadataSearchService {
    
    func getOrCreateImageContext(attachment: Attachment, note: Note) async -> ImageSearchContext {
        if let cachedContext = processedImagesCache[attachment.id] {
            return cachedContext
        }
        
        await processImageMetadata(attachment: attachment, note: note)
        return processedImagesCache[attachment.id] ?? createEmptyContext()
    }
    
    func processImageMetadata(attachment: Attachment, note: Note) async {
        guard let image = await loadImage(from: attachment) else { return }
        
        let context = await withCheckedContinuation { (continuation: CheckedContinuation<ImageSearchContext, Never>) in
            processingQueue.async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: self.createEmptyContext())
                    return
                }
                
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                var detectedObjects: [String] = []
                var ocrText: String?
                var imageDescription: String?
                var dominantColors: [UIColor] = []
                
                // Object Recognition
                do {
                    try requestHandler.perform([self.objectRecognitionRequest])
                    if let results = self.objectRecognitionRequest.results {
                        detectedObjects = results.compactMap { observation in
                            guard observation.confidence > 0.3 else { return nil }
                            return observation.identifier
                        }
                    }
                } catch {
                    print("Object recognition failed: \(error)")
                }
                
                // OCR Text Recognition
                do {
                    try requestHandler.perform([self.ocrRequest])
                    if let results = self.ocrRequest.results {
                        let recognizedStrings = results.compactMap { observation in
                            observation.topCandidates(1).first?.string
                        }
                        ocrText = recognizedStrings.joined(separator: " ")
                    }
                } catch {
                    print("OCR failed: \(error)")
                }
                
                // Scene Classification
                do {
                    try requestHandler.perform([self.sceneClassificationRequest])
                    if let results = self.sceneClassificationRequest.results?.first {
                        imageDescription = results.identifier
                    }
                } catch {
                    print("Scene classification failed: \(error)")
                }
                
                // Extract dominant colors
                dominantColors = self.extractDominantColors(from: image)
                
                let context = ImageSearchContext(
                    detectedObjects: detectedObjects,
                    ocrText: ocrText,
                    dominantColors: dominantColors,
                    imageDescription: imageDescription,
                    confidence: 0.8
                )
                
                continuation.resume(returning: context)
            }
        }
        
        await MainActor.run {
            processedImagesCache[attachment.id] = context
        }
    }
    
    func setupVisionRequests() {
        // Configure OCR request
        ocrRequest.recognitionLevel = .accurate
        ocrRequest.usesLanguageCorrection = true
        
        // Configure object recognition
        objectRecognitionRequest.usesCPUOnly = false
        
        // Configure scene classification
        sceneClassificationRequest.usesCPUOnly = false
    }
    
    func loadImage(from attachment: Attachment) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            processingQueue.async {
                let image = UIImage(contentsOfFile: attachment.localURL.path)
                continuation.resume(returning: image)
            }
        }
    }
    
    func createEmptyContext() -> ImageSearchContext {
        return ImageSearchContext(
            detectedObjects: [],
            ocrText: nil,
            dominantColors: [],
            imageDescription: nil,
            confidence: 0.0
        )
    }
    
    func extractDominantColors(from image: UIImage, maxColors: Int = 3) -> [UIColor] {
        guard let cgImage = image.cgImage else { return [] }
        
        let width = cgImage.width
        let height = cgImage.height
        let sampleSize = min(50, min(width, height))
        
        guard let context = CGContext(
            data: nil,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        
        guard let data = context.data else { return [] }
        let pixels = data.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)
        
        var colorCounts: [String: Int] = [:]
        
        for i in stride(from: 0, to: sampleSize * sampleSize * 4, by: 16) {
            let r = pixels[i]
            let g = pixels[i + 1]
            let b = pixels[i + 2]
            
            let quantizedR = (r / 64) * 64
            let quantizedG = (g / 64) * 64
            let quantizedB = (b / 64) * 64
            
            let colorKey = "\(quantizedR)-\(quantizedG)-\(quantizedB)"
            colorCounts[colorKey, default: 0] += 1
        }
        
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        
        return sortedColors.prefix(maxColors).compactMap { colorKey, _ in
            let components = colorKey.split(separator: "-").compactMap { Int($0) }
            guard components.count == 3 else { return nil }
            
            return UIColor(
                red: CGFloat(components[0]) / 255.0,
                green: CGFloat(components[1]) / 255.0,
                blue: CGFloat(components[2]) / 255.0,
                alpha: 1.0
            )
        }
    }
}

// MARK: - Scoring and Ranking Methods
private extension ImageMetadataSearchService {
    
    func deduplicateAndRankResults(_ results: [EnhancedImageSearchResult]) -> [EnhancedImageSearchResult] {
        var uniqueResults: [UUID: EnhancedImageSearchResult] = [:]
        
        for result in results {
            let key = result.attachment.id
            if let existing = uniqueResults[key] {
                // Keep the result with higher score or combine match types
                if result.relevanceScore > existing.relevanceScore {
                    uniqueResults[key] = result
                }
            } else {
                uniqueResults[key] = result
            }
        }
        
        return Array(uniqueResults.values).sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    func calculateObjectMatchScore(_ matchingObjects: [String], _ allObjects: [String], _ query: String) -> Float {
        let exactMatches = matchingObjects.filter { $0.lowercased() == query }.count
        let partialMatches = matchingObjects.count - exactMatches
        
        let exactScore = Float(exactMatches) * 1.0
        let partialScore = Float(partialMatches) * 0.7
        let totalObjects = Float(max(allObjects.count, 1))
        
        return min((exactScore + partialScore) / totalObjects, 1.0)
    }
    
    func calculateTextMatchScore(_ query: String, _ text: String) -> Float {
        let queryWords = query.components(separatedBy: .whitespacesAndNewlines)
        let textWords = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        let matches = queryWords.filter { word in
            textWords.contains { $0.contains(word) }
        }
        
        return Float(matches.count) / Float(max(queryWords.count, 1))
    }
    
    func calculateFilenameMatchScore(_ query: String, _ filename: String) -> Float {
        if filename == query { return 1.0 }
        if filename.hasPrefix(query) { return 0.9 }
        if filename.contains(query) { return 0.8 }
        return calculateStringSimilarity(query, filename)
    }
    
    func calculateNoteContentMatchScore(_ query: String, _ note: Note) -> Float {
        var score: Float = 0.0
        let queryLower = query.lowercased()
        
        if note.title.lowercased().contains(queryLower) { score += 0.3 }
        if note.content.lowercased().contains(queryLower) { score += 0.2 }
        if note.tags.contains(where: { $0.lowercased().contains(queryLower) }) { score += 0.2 }
        if note.aiSummary?.lowercased().contains(queryLower) == true { score += 0.2 }
        if note.keyPoints.contains(where: { $0.lowercased().contains(queryLower) }) { score += 0.1 }
        
        return min(score, 1.0)
    }
    
    func calculateDescriptionMatchScore(_ query: String, _ description: String) -> Float {
        return calculateStringSimilarity(query, description.lowercased())
    }
    
    func calculateStringSimilarity(_ str1: String, _ str2: String) -> Float {
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        guard maxLength > 0 else { return 1.0 }
        return 1.0 - Float(distance) / Float(maxLength)
    }
    
    func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let str1Count = str1Array.count
        let str2Count = str2Array.count
        
        if str1Count == 0 { return str2Count }
        if str2Count == 0 { return str1Count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)
        
        for i in 0...str1Count { matrix[i][0] = i }
        for j in 0...str2Count { matrix[0][j] = j }
        
        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[str1Count][str2Count]
    }
    
    func extractMatchedTextSnippet(_ query: String, from text: String, context: Int = 20) -> String {
        let lowercasedText = text.lowercased()
        let queryLower = query.lowercased()
        
        guard let range = lowercasedText.range(of: queryLower) else {
            return String(text.prefix(50))
        }
        
        let startIndex = text.index(range.lowerBound, offsetBy: -context, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: context, limitedBy: text.endIndex) ?? text.endIndex
        
        return String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func extractNoteContentSnippet(_ query: String, from note: Note) -> String {
        let queryLower = query.lowercased()
        
        if note.title.lowercased().contains(queryLower) {
            return note.title
        }
        
        if note.content.lowercased().contains(queryLower) {
            return extractMatchedTextSnippet(query, from: note.content)
        }
        
        if let summary = note.aiSummary, summary.lowercased().contains(queryLower) {
            return extractMatchedTextSnippet(query, from: summary)
        }
        
        return String(note.content.prefix(50))
    }
}
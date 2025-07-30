//
//  SemanticSearchService.swift
//  AINoteTakingApp
//
//  Semantic search service using Core ML embeddings for intelligent note discovery.
//  Handles text embeddings, similarity calculations, and ranking algorithms.
//  Follows SRP by focusing solely on semantic search functionality.
//
//  Created by AI Assistant on 2025-01-30.
//

import Foundation
import NaturalLanguage
import CoreML
import UIKit

// MARK: - Search Result Types
struct SearchResult {
    let note: Note
    let relevanceScore: Float
    let searchType: SearchType
    let matchedContent: String
    let matchedField: SearchField
}

enum SearchType {
    case exactMatch
    case semanticSimilarity
    case partialMatch
    case imageContent
    case attachmentMetadata
}

enum SearchField {
    case title
    case content
    case transcript
    case aiSummary
    case tags
    case imageOCR
    case attachmentName
    case keyPoints
}

// MARK: - Semantic Search Service
@MainActor
class SemanticSearchService: ObservableObject {
    
    // MARK: - Private Properties
    private let dataManager = DataManager.shared
    private var embeddingModel: NLEmbedding?
    private var noteEmbeddings: [UUID: [Float]] = [:]
    private let embeddingQueue = DispatchQueue(label: "embedding.queue", qos: .userInitiated)
    private let imageSearchManager = ImageSearchManager()
    private let imageMetadataIndex = ImageMetadataIndex()
    
    // MARK: - Initialization
    init() {
        setupEmbeddingModel()
    }
    
    // MARK: - Public Methods
    
    /// Performs comprehensive search across all note content including images
    func searchNotes(query: String, folder: Folder? = nil) async -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let notes = folder != nil ? dataManager.fetchNotes(in: folder) : dataManager.fetchAllNotes()
        guard !notes.isEmpty else { return [] }
        
        return await withTaskGroup(of: [SearchResult].self, returning: [SearchResult].self) { group in
            // Exact text matches (highest priority)
            group.addTask {
                await self.performExactSearch(query: query, notes: notes)
            }
            
            // Semantic similarity search
            group.addTask {
                await self.performSemanticSearch(query: query, notes: notes)
            }
            
            // Advanced image search via Vision and metadata
            group.addTask {
                await self.performAdvancedImageSearch(query: query, notes: notes)
            }
            
            // Attachment metadata search
            group.addTask {
                await self.performAttachmentSearch(query: query, notes: notes)
            }
            
            var allResults: [SearchResult] = []
            for await results in group {
                allResults.append(contentsOf: results)
            }
            
            return rankAndDeduplicateResults(allResults)
        }
    }
    
    /// Updates embeddings for a specific note and indexes its images
    func updateNoteEmbedding(for note: Note) async {
        let content = extractSearchableContent(from: note)
        guard !content.isEmpty else { return }
        
        await withCheckedContinuation { continuation in
            embeddingQueue.async {
                if let embedding = self.generateEmbedding(for: content) {
                    DispatchQueue.main.async {
                        self.noteEmbeddings[note.id] = embedding
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }
        }
        
        // Index images in this note
        for attachment in note.attachments where attachment.type == .image {
            await imageSearchManager.indexImage(attachment, from: note)
        }
    }
    
    /// Batch update embeddings for multiple notes
    func updateAllNoteEmbeddings() async {
        let notes = dataManager.fetchAllNotes()
        
        await withTaskGroup(of: Void.self) { group in
            for note in notes {
                group.addTask {
                    await self.updateNoteEmbedding(for: note)
                }
            }
        }
    }
}

// MARK: - Private Search Methods
private extension SemanticSearchService {
    
    func performExactSearch(query: String, notes: [Note]) async -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        var results: [SearchResult] = []
        
        for note in notes {
            // Title exact match (highest relevance)
            if note.title.lowercased().contains(lowercasedQuery) {
                results.append(SearchResult(
                    note: note,
                    relevanceScore: 1.0,
                    searchType: .exactMatch,
                    matchedContent: note.title,
                    matchedField: .title
                ))
            }
            
            // Content exact match
            if note.content.lowercased().contains(lowercasedQuery) {
                let matchedSnippet = extractSnippet(from: note.content, query: query)
                results.append(SearchResult(
                    note: note,
                    relevanceScore: 0.9,
                    searchType: .exactMatch,
                    matchedContent: matchedSnippet,
                    matchedField: .content
                ))
            }
            
            // Tags exact match
            if note.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                let matchedTags = note.tags.filter { $0.lowercased().contains(lowercasedQuery) }
                results.append(SearchResult(
                    note: note,
                    relevanceScore: 0.85,
                    searchType: .exactMatch,
                    matchedContent: matchedTags.joined(separator: ", "),
                    matchedField: .tags
                ))
            }
            
            // Transcript exact match
            if let transcript = note.transcript, transcript.lowercased().contains(lowercasedQuery) {
                let matchedSnippet = extractSnippet(from: transcript, query: query)
                results.append(SearchResult(
                    note: note,
                    relevanceScore: 0.8,
                    searchType: .exactMatch,
                    matchedContent: matchedSnippet,
                    matchedField: .transcript
                ))
            }
            
            // AI Summary exact match
            if let aiSummary = note.aiSummary, aiSummary.lowercased().contains(lowercasedQuery) {
                let matchedSnippet = extractSnippet(from: aiSummary, query: query)
                results.append(SearchResult(
                    note: note,
                    relevanceScore: 0.75,
                    searchType: .exactMatch,
                    matchedContent: matchedSnippet,
                    matchedField: .aiSummary
                ))
            }
            
            // OCR Text exact match
            if let ocrText = note.ocrText, ocrText.lowercased().contains(lowercasedQuery) {
                let matchedSnippet = extractSnippet(from: ocrText, query: query)
                results.append(SearchResult(
                    note: note,
                    relevanceScore: 0.85,
                    searchType: .exactMatch,
                    matchedContent: matchedSnippet,
                    matchedField: .imageOCR
                ))
            }
        }
        
        return results
    }
    
    func performSemanticSearch(query: String, notes: [Note]) async -> [SearchResult] {
        guard let embeddingModel = embeddingModel else { return [] }
        
        return await withCheckedContinuation { continuation in
            embeddingQueue.async {
                guard let queryEmbedding = self.generateEmbedding(for: query) else {
                    continuation.resume(returning: [])
                    return
                }
                
                var results: [SearchResult] = []
                
                for note in notes {
                    let noteEmbedding: [Float]
                    
                    if let cached = self.noteEmbeddings[note.id] {
                        noteEmbedding = cached
                    } else {
                        let content = self.extractSearchableContent(from: note)
                        guard let embedding = self.generateEmbedding(for: content) else { continue }
                        noteEmbedding = embedding
                        
                        DispatchQueue.main.async {
                            self.noteEmbeddings[note.id] = embedding
                        }
                    }
                    
                    let similarity = self.cosineSimilarity(queryEmbedding, noteEmbedding)
                    
                    // Only include results with meaningful similarity (above threshold)
                    if similarity > 0.3 {
                        let snippet = self.extractSnippet(from: note.content, query: query, maxLength: 120)
                        results.append(SearchResult(
                            note: note,
                            relevanceScore: similarity,
                            searchType: .semanticSimilarity,
                            matchedContent: snippet,
                            matchedField: .content
                        ))
                    }
                }
                
                continuation.resume(returning: results)
            }
        }
    }
    
    func performAdvancedImageSearch(query: String, notes: [Note]) async -> [SearchResult] {
        var results: [SearchResult] = []
        let lowercasedQuery = query.lowercased()
        
        // 1. Fast metadata-based search
        let metadataResults = await performMetadataImageSearch(query: lowercasedQuery, notes: notes)
        results.append(contentsOf: metadataResults)
        
        // 2. Visual similarity search (if query contains visual terms)
        if containsVisualTerms(lowercasedQuery) {
            let visualResults = await performVisualSimilaritySearch(query: lowercasedQuery, notes: notes)
            results.append(contentsOf: visualResults)
        }
        
        // 3. Object detection search
        let objectResults = await performObjectDetectionSearch(query: lowercasedQuery, notes: notes)
        results.append(contentsOf: objectResults)
        
        // 4. Color-based search
        if let color = extractColorFromQuery(lowercasedQuery) {
            let colorResults = await performColorBasedSearch(color: color, notes: notes)
            results.append(contentsOf: colorResults)
        }
        
        return results
    }
    
    func performMetadataImageSearch(query: String, notes: [Note]) async -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Fast filename search using index
        let filenameMatches = imageMetadataIndex.findImagesByFilename(query)
        for attachmentId in filenameMatches {
            if let (note, attachment) = findNoteAndAttachment(attachmentId: attachmentId, in: notes) {
                results.append(SearchResult(
                    note: note,
                    relevanceScore: 0.8,
                    searchType: .imageContent,
                    matchedContent: "Image: \(attachment.fileName)",
                    matchedField: .attachmentName
                ))
            }
        }
        
        // Fast object search using index
        let objectMatches = imageMetadataIndex.findImagesByObject(query)
        for attachmentId in objectMatches {
            if let (note, attachment) = findNoteAndAttachment(attachmentId: attachmentId, in: notes) {
                results.append(SearchResult(
                    note: note,
                    relevanceScore: 0.75,
                    searchType: .imageContent,
                    matchedContent: "Contains: \(query)",
                    matchedField: .imageOCR
                ))
            }
        }
        
        return results
    }
    
    func performVisualSimilaritySearch(query: String, notes: [Note]) async -> [SearchResult] {
        // This would require having a reference image to compare against
        // For text queries describing visual content, we rely on object detection
        return []
    }
    
    func performObjectDetectionSearch(query: String, notes: [Note]) async -> [SearchResult] {
        let similarityResults = await imageSearchManager.searchImagesByObject(query, in: notes)
        
        return similarityResults.map { result in
            SearchResult(
                note: result.note,
                relevanceScore: result.similarityScore,
                searchType: .imageContent,
                matchedContent: result.attachment.fileName,
                matchedField: .imageOCR
            )
        }
    }
    
    func performColorBasedSearch(color: UIColor, notes: [Note]) async -> [SearchResult] {
        let colorResults = await imageSearchManager.searchImagesByColor([color], in: notes)
        
        return colorResults.map { result in
            SearchResult(
                note: result.note,
                relevanceScore: result.similarityScore,
                searchType: .imageContent,
                matchedContent: "Similar colors in \(result.attachment.fileName)",
                matchedField: .imageOCR
            )
        }
    }
    
    func performAttachmentSearch(query: String, notes: [Note]) async -> [SearchResult] {
        var results: [SearchResult] = []
        let lowercasedQuery = query.lowercased()
        
        for note in notes {
            for attachment in note.attachments {
                // Search attachment filenames and extensions
                if attachment.fileName.lowercased().contains(lowercasedQuery) ||
                   attachment.fileExtension.lowercased().contains(lowercasedQuery) ||
                   attachment.mimeType.lowercased().contains(lowercasedQuery) {
                    
                    results.append(SearchResult(
                        note: note,
                        relevanceScore: 0.6,
                        searchType: .attachmentMetadata,
                        matchedContent: "Attachment: \(attachment.fileName).\(attachment.fileExtension)",
                        matchedField: .attachmentName
                    ))
                }
            }
        }
        
        return results
    }
}

// MARK: - Private Helper Methods
private extension SemanticSearchService {
    
    func setupEmbeddingModel() {
        embeddingQueue.async {
            if let model = NLEmbedding.sentenceEmbedding(for: .english) {
                DispatchQueue.main.async {
                    self.embeddingModel = model
                }
            }
        }
    }
    
    func generateEmbedding(for text: String) -> [Float]? {
        guard let embeddingModel = embeddingModel else { return nil }
        
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return nil }
        
        guard let doubleVector = embeddingModel.vector(for: cleanedText) else { return nil }
        return doubleVector.map { Float($0) }
    }
    
    func extractSearchableContent(from note: Note) -> String {
        var content = [note.title, note.content]
        
        if let transcript = note.transcript {
            content.append(transcript)
        }
        
        if let aiSummary = note.aiSummary {
            content.append(aiSummary)
        }
        
        if let ocrText = note.ocrText {
            content.append(ocrText)
        }
        
        if !note.keyPoints.isEmpty {
            content.append(note.keyPoints.joined(separator: " "))
        }
        
        content.append(note.tags.joined(separator: " "))
        
        return content.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func extractSnippet(from text: String, query: String, maxLength: Int = 150) -> String {
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()
        
        if let range = lowercasedText.range(of: lowercasedQuery) {
            let startIndex = max(text.startIndex, text.index(range.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex)
            let endIndex = min(text.endIndex, text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex)
            
            let snippet = String(text[startIndex..<endIndex])
            return snippet.count > maxLength ? String(snippet.prefix(maxLength)) + "..." : snippet
        }
        
        // If no direct match, return beginning of text
        return text.count > maxLength ? String(text.prefix(maxLength)) + "..." : text
    }
    
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    func rankAndDeduplicateResults(_ results: [SearchResult]) -> [SearchResult] {
        // Group by note ID to avoid duplicates
        let grouped = Dictionary(grouping: results) { $0.note.id }
        
        // For each note, take the highest scoring result
        let deduplicated = grouped.compactMap { _, noteResults -> SearchResult? in
            return noteResults.max { $0.relevanceScore < $1.relevanceScore }
        }
        
        // Sort by relevance score (highest first)
        return deduplicated.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    // MARK: - Advanced Image Search Helper Methods
    
    func containsVisualTerms(_ query: String) -> Bool {
        let visualKeywords = [
            "photo", "image", "picture", "visual", "graphic", "illustration",
            "screenshot", "diagram", "chart", "graph", "drawing", "sketch",
            "color", "red", "blue", "green", "yellow", "orange", "purple", "pink", "black", "white", "brown", "gray",
            "bright", "dark", "light", "colorful", "vibrant", "pale", "bold",
            "landscape", "portrait", "face", "person", "people", "building", "architecture",
            "car", "vehicle", "animal", "dog", "cat", "bird", "tree", "flower", "nature",
            "food", "meal", "document", "text", "handwriting", "signature",
            "logo", "brand", "sign", "symbol", "icon", "badge", "artwork", "design"
        ]
        
        let lowercasedQuery = query.lowercased()
        return visualKeywords.contains { lowercasedQuery.contains($0) }
    }
    
    func extractColorFromQuery(_ query: String) -> UIColor? {
        let colorMappings: [String: UIColor] = [
            "red": .systemRed,
            "blue": .systemBlue,
            "green": .systemGreen,
            "yellow": .systemYellow,
            "orange": .systemOrange,
            "purple": .systemPurple,
            "pink": .systemPink,
            "brown": .systemBrown,
            "gray": .systemGray,
            "grey": .systemGray,
            "black": .black,
            "white": .white
        ]
        
        let lowercasedQuery = query.lowercased()
        
        for (colorName, color) in colorMappings {
            if lowercasedQuery.contains(colorName) {
                return color
            }
        }
        
        return nil
    }
    
    func findNoteAndAttachment(attachmentId: UUID, in notes: [Note]) -> (Note, Attachment)? {
        for note in notes {
            for attachment in note.attachments {
                if attachment.id == attachmentId {
                    return (note, attachment)
                }
            }
        }
        return nil
    }
}
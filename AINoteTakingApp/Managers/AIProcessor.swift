//
//  AIProcessor.swift
//  AINoteTakingApp
//
//  AI content analysis and processing service
//  OCR functionality moved to separate OCRService following SRP
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import NaturalLanguage

// MARK: - AI Processing Results
struct ProcessedContent {
    let summary: String
    let keyPoints: [String]
    let actionItems: [ActionItem]
    let suggestedTags: [String]
    let suggestedCategory: Category?
    let sentiment: String
}

struct RelatedNotesResult {
    let notes: [Note]
    let similarity: Double
}

// MARK: - AI Processor
@MainActor
class AIProcessor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let nlProcessor = NLLanguageRecognizer()
    private let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass, .nameType, .sentimentScore])
    
    // MARK: - Configuration
    private struct AIConfig {
        static let maxSummaryLength = 200
        static let maxKeyPoints = 5
        static let maxActionItems = 10
        static let maxSuggestedTags = 5
        static let similarityThreshold = 0.3
    }
    
    // MARK: - Content Processing Methods
    func processContent(_ text: String) async -> ProcessedContent {
        isProcessing = true
        processingProgress = 0
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0
            }
        }
        
        // Step 1: Generate summary
        await updateProgress(0.2)
        let summary = await summarizeContent(text)
        
        // Step 2: Extract key points
        await updateProgress(0.4)
        let keyPoints = await extractKeyPoints(text)
        
        // Step 3: Extract action items
        await updateProgress(0.6)
        let actionItems = await extractActionItems(text)
        
        // Step 4: Suggest tags
        await updateProgress(0.8)
        let suggestedTags = await suggestTags(text)
        
        // Step 5: Categorize content
        await updateProgress(0.9)
        let suggestedCategory = await categorizeContent(text)
        
        // Step 6: Analyze sentiment
        await updateProgress(1.0)
        let sentiment = await analyzeSentiment(text)
        
        return ProcessedContent(
            summary: summary,
            keyPoints: keyPoints,
            actionItems: actionItems,
            suggestedTags: suggestedTags,
            suggestedCategory: suggestedCategory,
            sentiment: sentiment
        )
    }
    
    func summarizeContent(_ text: String) async -> String {
        guard !text.isEmpty else { return "" }
        
        let sentences = extractSentences(from: text)
        guard sentences.count > 1 else { return text }
        
        let scoredSentences = scoreSentences(sentences, in: text)
        let topSentences = Array(scoredSentences.prefix(3))
        let summary = topSentences.map { $0.sentence }.joined(separator: " ")
        
        return summary.count > AIConfig.maxSummaryLength 
            ? String(summary.prefix(AIConfig.maxSummaryLength)) + "..."
            : summary
    }
    
    func extractKeyPoints(_ text: String) async -> [String] {
        guard !text.isEmpty else { return [] }
        
        let sentences = extractSentences(from: text)
        var keyPoints: [String] = []
        
        let keyIndicators = ["important", "key", "main", "primary", "essential", "critical", "note that", "remember"]
        
        for sentence in sentences {
            let lowercased = sentence.lowercased()
            if keyIndicators.contains(where: { lowercased.contains($0) }) {
                keyPoints.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        if keyPoints.isEmpty {
            let scoredSentences = scoreSentences(sentences, in: text)
            keyPoints = Array(scoredSentences.prefix(AIConfig.maxKeyPoints)).map { $0.sentence }
        }
        
        return Array(keyPoints.prefix(AIConfig.maxKeyPoints))
    }
    
    func extractActionItems(_ text: String) async -> [ActionItem] {
        guard !text.isEmpty else { return [] }
        
        let sentences = extractSentences(from: text)
        var actionItems: [ActionItem] = []
        
        let actionIndicators = ["todo", "to do", "need to", "should", "must", "action", "task", "follow up", "call", "email", "schedule", "book", "buy", "complete", "finish"]
        
        for sentence in sentences {
            let lowercased = sentence.lowercased()
            if actionIndicators.contains(where: { lowercased.contains($0) }) {
                let priority = determinePriority(from: sentence)
                let actionItem = ActionItem(
                    title: sentence.trimmingCharacters(in: .whitespacesAndNewlines),
                    priority: priority
                )
                actionItems.append(actionItem)
            }
        }
        
        return Array(actionItems.prefix(AIConfig.maxActionItems))
    }
    
    func suggestTags(_ content: String) async -> [String] {
        guard !content.isEmpty else { return [] }

        tagger.string = content
        var tags: Set<String> = []

        let range = content.startIndex..<content.endIndex
        tagger.enumerateTags(in: range,
                           unit: .word,
                           scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                let substring = String(content[tokenRange])
                switch tag {
                case .personalName, .placeName, .organizationName:
                    tags.insert(substring.lowercased())
                default:
                    break
                }
            }
            return true
        }

        let keywords = extractKeywords(from: content)
        tags.formUnion(keywords)

        return Array(tags.prefix(AIConfig.maxSuggestedTags))
    }
    
    func categorizeContent(_ text: String) async -> Category? {
        guard !text.isEmpty else { return nil }
        
        let lowercased = text.lowercased()
        
        if lowercased.contains("meeting") || lowercased.contains("call") || lowercased.contains("discussion") {
            return Category(name: "Meetings", color: "#FF9500")
        } else if lowercased.contains("idea") || lowercased.contains("brainstorm") || lowercased.contains("concept") {
            return Category(name: "Ideas", color: "#AF52DE")
        } else if lowercased.contains("task") || lowercased.contains("todo") || lowercased.contains("action") {
            return Category(name: "Tasks", color: "#FF3B30")
        } else if lowercased.contains("research") || lowercased.contains("study") || lowercased.contains("learn") {
            return Category(name: "Research", color: "#007AFF")
        } else if lowercased.contains("personal") || lowercased.contains("diary") || lowercased.contains("journal") {
            return Category(name: "Personal", color: "#34C759")
        }
        
        return Category(name: "General", color: "#8E8E93")
    }
    
    func analyzeSentiment(_ text: String) async -> String {
        guard !text.isEmpty else { return "neutral" }

        tagger.string = text
        var sentimentScore: Double = 0
        var sentimentCount = 0

        let range = text.startIndex..<text.endIndex
        tagger.enumerateTags(in: range,
                           unit: .sentence,
                           scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                sentimentScore += score
                sentimentCount += 1
            }
            return true
        }

        if sentimentCount > 0 {
            let averageScore = sentimentScore / Double(sentimentCount)
            if averageScore > 0.1 {
                return "positive"
            } else if averageScore < -0.1 {
                return "negative"
            }
        }

        return "neutral"
    }
    
    // MARK: - Note Relationship Methods
    func findRelatedNotes(_ note: Note, in notes: [Note]) async -> [RelatedNotesResult] {
        guard !note.content.isEmpty else { return [] }
        
        var relatedNotes: [RelatedNotesResult] = []
        
        for otherNote in notes {
            guard otherNote.id != note.id, !otherNote.content.isEmpty else { continue }
            
            let similarity = calculateSimilarity(between: note.content, and: otherNote.content)
            
            if similarity > AIConfig.similarityThreshold {
                relatedNotes.append(RelatedNotesResult(notes: [otherNote], similarity: similarity))
            }
        }
        
        return relatedNotes.sorted { $0.similarity > $1.similarity }
    }
    
    // MARK: - Folder Sentiment Analysis
    func analyzeFolderSentiment(for notes: [Note]) async -> FolderSentiment {
        guard !notes.isEmpty else { return .neutral }
        
        var totalSentimentScore: Double = 0
        var sentimentCounts: [String: Int] = [:]
        var validAnalyses = 0
        
        for note in notes {
            let content = "\(note.title) \(note.content)"
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            
            let sentiment = await analyzeSentiment(content)
            sentimentCounts[sentiment, default: 0] += 1
            
            switch sentiment {
            case "positive":
                totalSentimentScore += 1.0
            case "negative":
                totalSentimentScore -= 1.0
            default:
                totalSentimentScore += 0.0
            }
            
            validAnalyses += 1
        }
        
        guard validAnalyses > 0 else { return .neutral }
        
        let averageScore = totalSentimentScore / Double(validAnalyses)
        let positiveCount = sentimentCounts["positive"] ?? 0
        let negativeCount = sentimentCounts["negative"] ?? 0
        let neutralCount = sentimentCounts["neutral"] ?? 0
        
        let dominantSentiment = max(positiveCount, negativeCount, neutralCount)
        let mixedThreshold = validAnalyses / 3
        
        if positiveCount > 0 && negativeCount > 0 && dominantSentiment < mixedThreshold * 2 {
            return .mixed
        } else if averageScore >= 0.6 {
            return .veryPositive
        } else if averageScore >= 0.2 {
            return .positive
        } else if averageScore <= -0.6 {
            return .veryNegative
        } else if averageScore <= -0.2 {
            return .negative
        } else {
            return .neutral
        }
    }
    
    func updateFolderSentiment(_ folder: inout Folder, with notes: [Note]) async {
        let folderNotes = notes.filter { $0.folderId == folder.id }
        folder.sentiment = await analyzeFolderSentiment(for: folderNotes)
        folder.noteCount = folderNotes.count
        folder.modifiedDate = Date()
    }
}

// MARK: - Private Helper Methods
private extension AIProcessor {
    
    func updateProgress(_ progress: Double) async {
        await MainActor.run {
            processingProgress = progress
        }
    }
    
    func extractSentences(from text: String) -> [String] {
        var sentences: [String] = []

        text.enumerateSubstrings(in: text.startIndex..<text.endIndex,
                               options: [.bySentences, .localized]) { substring, _, _, _ in
            if let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines),
               !sentence.isEmpty {
                sentences.append(sentence)
            }
        }

        return sentences
    }
    
    func scoreSentences(_ sentences: [String], in text: String) -> [(sentence: String, score: Double)] {
        let keywords = extractKeywords(from: text)
        
        return sentences.map { sentence in
            var score = 0.0
            let lowercased = sentence.lowercased()
            
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    score += 1.0
                }
            }
            
            if sentence.range(of: "\\d+", options: .regularExpression) != nil {
                score += 0.5
            }
            
            let wordCount = sentence.components(separatedBy: .whitespaces).count
            if wordCount < 5 || wordCount > 30 {
                score *= 0.5
            }
            
            return (sentence: sentence, score: score)
        }.sorted { $0.score > $1.score }
    }
    
    func extractKeywords(from text: String) -> Set<String> {
        var keywords: Set<String> = []

        tagger.string = text
        let range = text.startIndex..<text.endIndex
        tagger.enumerateTags(in: range,
                           unit: .word,
                           scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag, tag == .noun || tag == .verb {
                let word = String(text[tokenRange]).lowercased()
                if word.count > 3 {
                    keywords.insert(word)
                }
            }
            return true
        }

        return keywords
    }
    
    func determinePriority(from text: String) -> Priority {
        let lowercased = text.lowercased()
        
        if lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("immediately") {
            return .urgent
        } else if lowercased.contains("important") || lowercased.contains("priority") || lowercased.contains("critical") {
            return .high
        } else if lowercased.contains("when possible") || lowercased.contains("eventually") || lowercased.contains("someday") {
            return .low
        }
        
        return .medium
    }
    
    func calculateSimilarity(between text1: String, and text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
    }
}
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
import CoreML

// MARK: - AI Processing Results
struct ProcessedContent {
    let summary: String
    let keyPoints: [String]
    let actionItems: [ActionItem]
    let suggestedTags: [String]
    let suggestedCategory: Category?
    let sentiment: String
    let sentimentConfidence: Double
    let categoryConfidence: Double
}

struct RelatedNotesResult {
    let notes: [Note]
    let similarity: Double
}

// MARK: - ML Results  
// Note: ExtractedEntities moved to StructuredTextModels.swift

struct MLSentimentResult {
    let sentiment: String
    let confidence: Double
    let rawScore: Double
}

struct MLCategoryResult {
    let category: String
    let confidence: Double
    let alternatives: [(String, Double)]
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
    private let coreMLProcessor = CoreMLTextProcessor()
    private let entityExtractor = MLEntityExtractor()
    
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
        
        // Step 1: Check if this looks like structured content (business card, etc.)
        await updateProgress(0.1)
        let structuredExtractor = StructuredTextExtractor()
        let quickStructuredData = await structuredExtractor.extractStructuredData(
            from: text,
            textBlocks: [],
            image: nil,
            options: .businessCard // Quick check for business cards
        )
        
        // If we detected structured content, use the enhanced processing
        if structuredContentDetected(structuredData: quickStructuredData) {
            print("🎯 Structured content detected - using enhanced processing")
            return await processStructuredContent(quickStructuredData, originalText: text)
        }
        
        // Otherwise, use traditional processing
        print("📄 Using traditional text processing")
        
        // Step 2: Generate summary (improved with structure awareness)
        await updateProgress(0.2)
        let summary = await summarizeContent(text)
        
        // Step 3: Extract key points (improved)
        await updateProgress(0.4)
        let rawKeyPoints = await extractKeyPoints(text)
        
        // Step 4: Remove duplicate content between summary and key points
        let keyPoints = removeDuplicateContent(summary: summary, keyPoints: rawKeyPoints)
        
        // Step 5: Extract action items (improved)
        await updateProgress(0.6)
        let actionItems = await extractActionItems(text)
        
        // Step 6: Suggest tags (improved)
        await updateProgress(0.8)
        let suggestedTags = await suggestTags(text)
        
        // Step 7: Analyze sentiment with confidence
        await updateProgress(1.0)
        let sentimentResult = await analyzeSentimentWithConfidence(text)
        let categoryResult = await categorizeContentWithConfidence(text)

        return ProcessedContent(
            summary: summary,
            keyPoints: keyPoints,
            actionItems: actionItems,
            suggestedTags: suggestedTags,
            suggestedCategory: categoryResult.category,
            sentiment: sentimentResult.sentiment,
            sentimentConfidence: sentimentResult.confidence,
            categoryConfidence: categoryResult.confidence
        )
    }
    
    private func structuredContentDetected(structuredData: StructuredTextData) -> Bool {
        // Check if we found meaningful structured content
        return structuredData.businessCard != nil || 
               structuredData.contactInfo?.phoneNumbers.isEmpty == false ||
               structuredData.contactInfo?.emailAddresses.isEmpty == false ||
               structuredData.documentType != .generic
    }
    
    // MARK: - Enhanced Processing with Structured Data
    func processStructuredContent(_ structuredData: StructuredTextData, originalText: String) async -> ProcessedContent {
        isProcessing = true
        processingProgress = 0
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0
            }
        }
        
        let structuredExtractor = StructuredTextExtractor()
        
        // Step 1: Generate intelligent summary based on document type
        await updateProgress(0.2)
        let summary = structuredExtractor.generateSmartSummary(from: structuredData, originalText: originalText)
        
        // Step 2: Extract structured key points
        await updateProgress(0.4)
        let keyPoints = await extractStructuredKeyPoints(structuredData, originalText: originalText)
        
        // Step 3: Generate smart action items
        await updateProgress(0.6)
        let actionItems = structuredExtractor.generateActionableItems(from: structuredData)
        
        // Step 4: Generate smart tags
        await updateProgress(0.8)
        let suggestedTags = structuredExtractor.generateSmartTags(from: structuredData)
        
        // Step 5: Use document type for category
        await updateProgress(0.9)
        let suggestedCategory = createCategoryFromDocumentType(structuredData.documentType)
        
        // Step 6: Analyze sentiment
        await updateProgress(1.0)
        let sentimentResult = await analyzeSentimentWithConfidence(originalText)
        
        return ProcessedContent(
            summary: summary,
            keyPoints: keyPoints,
            actionItems: actionItems,
            suggestedTags: suggestedTags,
            suggestedCategory: suggestedCategory,
            sentiment: sentimentResult.sentiment,
            sentimentConfidence: sentimentResult.confidence,
            categoryConfidence: Double(structuredData.processingConfidence)
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

        // Use ML entity extraction for better tag suggestions
        let entities = await entityExtractor.extractEntitiesWithML(content)
        var tags: Set<String> = []

        // Add named entities as tags
        tags.formUnion(entities.people.map { $0.lowercased() })
        tags.formUnion(entities.places.map { $0.lowercased() })
        tags.formUnion(entities.organizations.map { $0.lowercased() })

        // Add products (important nouns equivalent)
        tags.formUnion(entities.products)

        // Add semantic keywords using traditional method as fallback
        let keywords = extractKeywords(from: content)
        tags.formUnion(keywords)

        return Array(tags.prefix(AIConfig.maxSuggestedTags))
    }
    
    func categorizeContent(_ text: String) async -> Category? {
        let result = await coreMLProcessor.classifyCategory(text)
        return createCategory(from: result.category)
    }
    
    // MARK: - Structured Data Processing Helpers
    private func extractStructuredKeyPoints(_ structuredData: StructuredTextData, originalText: String) async -> [String] {
        var keyPoints: [String] = []
        
        switch structuredData.documentType {
        case .businessCard:
            if let businessCard = structuredData.businessCard {
                if let name = businessCard.name {
                    keyPoints.append("Contact: \(name.fullName)")
                }
                if let company = businessCard.company {
                    keyPoints.append("Company: \(company)")
                }
                if !businessCard.contactInfo.phoneNumbers.isEmpty {
                    keyPoints.append("Phone available")
                }
                if !businessCard.contactInfo.emailAddresses.isEmpty {
                    keyPoints.append("Email available")
                }
            }
            
        case .notice:
            if let layout = structuredData.documentLayout {
                if !layout.sections.isEmpty {
                    keyPoints.append(contentsOf: layout.sections.prefix(3).map { "• \($0.title)" })
                }
                if !layout.bulletPoints.isEmpty {
                    keyPoints.append(contentsOf: layout.bulletPoints.prefix(3).map { "• \($0.text)" })
                }
            }
            if let contactInfo = structuredData.contactInfo {
                if !contactInfo.phoneNumbers.isEmpty {
                    keyPoints.append("Contact information provided")
                }
            }
            
        case .form:
            keyPoints.append("Form requires completion")
            if let layout = structuredData.documentLayout {
                keyPoints.append("Contains \(layout.sections.count) sections")
            }
            
        case .receipt:
            if let entities = structuredData.extractedEntities {
                if !entities.currencies.isEmpty {
                    let amounts = entities.currencies.compactMap { $0.amount }
                    if let total = amounts.max() {
                        keyPoints.append("Total amount: \(total)")
                    }
                }
                if !entities.dates.isEmpty {
                    keyPoints.append("Transaction date recorded")
                }
            }
            
        default:
            // Fallback to traditional extraction
            keyPoints = await extractKeyPoints(originalText)
        }
        
        // Ensure we have at least some key points
        if keyPoints.isEmpty {
            keyPoints = await extractKeyPoints(originalText)
        }
        
        return Array(keyPoints.prefix(AIConfig.maxKeyPoints))
    }
    
    private func createCategoryFromDocumentType(_ documentType: DocumentType) -> Category {
        switch documentType {
        case .businessCard:
            return Category(name: "Contacts", color: "#34C759")
        case .notice:
            return Category(name: "Announcements", color: "#FF9500")
        case .form:
            return Category(name: "Forms", color: "#007AFF")
        case .receipt:
            return Category(name: "Receipts", color: "#FF3B30")
        case .letter:
            return Category(name: "Correspondence", color: "#AF52DE")
        case .flyer:
            return Category(name: "Events", color: "#FF2D92")
        case .menu:
            return Category(name: "Menus", color: "#32ADE6")
        case .generic:
            return Category(name: "Documents", color: "#8E8E93")
        }
    }

    func categorizeContentWithConfidence(_ text: String) async -> (category: Category?, confidence: Double) {
        let result = await coreMLProcessor.classifyCategory(text)
        let category = createCategory(from: result.category)
        return (category, result.confidence)
    }
    
    func analyzeSentiment(_ text: String) async -> String {
        let result = await coreMLProcessor.analyzeSentimentWithML(text)
        return result.sentiment
    }

    func analyzeSentimentWithConfidence(_ text: String) async -> (sentiment: String, confidence: Double) {
        let result = await coreMLProcessor.analyzeSentimentWithML(text)
        return (result.sentiment, result.confidence)
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
        // Try semantic similarity first (more accurate)
        let semanticSimilarity = coreMLProcessor.calculateSemanticSimilarity(text1, text2)

        if semanticSimilarity > 0 {
            return semanticSimilarity
        }

        // Fallback to word-based similarity
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))

        let intersection = words1.intersection(words2)
        let union = words1.union(words2)

        return union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
    }

    func removeDuplicateContent(summary: String, keyPoints: [String]) -> [String] {
        guard !summary.isEmpty && !keyPoints.isEmpty else { return keyPoints }
        
        let summaryWords = Set(summary.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 })
        
        return keyPoints.filter { keyPoint in
            let keyPointWords = Set(keyPoint.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 })
                
            let intersection = summaryWords.intersection(keyPointWords)
            let similarity = Double(intersection.count) / Double(max(summaryWords.count, keyPointWords.count))
            
            // If similarity is over 80%, consider it a duplicate
            return similarity < 0.8
        }
    }
    
    func createCategory(from categoryName: String) -> Category {
        switch categoryName.lowercased() {
        case "meeting", "meetings":
            return Category(name: "Meetings", color: "#FF9500")
        case "research":
            return Category(name: "Research", color: "#007AFF")
        case "personal":
            return Category(name: "Personal", color: "#34C759")
        case "tasks", "task":
            return Category(name: "Tasks", color: "#FF3B30")
        case "ideas", "idea":
            return Category(name: "Ideas", color: "#AF52DE")
        default:
            return Category(name: "General", color: "#8E8E93")
        }
    }
}

// MARK: - Core ML Text Processor
class CoreMLTextProcessor {

    // MARK: - Private Properties
    private var sentimentModel: NLModel?
    private var categoryModel: NLModel?
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    // MARK: - Initialization
    init() {
        setupModels()
    }

    private func setupModels() {
        // Initialize Apple's built-in sentiment model
        setupSentimentModel()

        // Initialize custom category model (will fallback to rule-based if not available)
        setupCategoryModel()
    }

    private func setupSentimentModel() {
        // Try to use Apple's built-in sentiment model
        if let mlModel = createSentimentModel(),
           let model = try? NLModel(mlModel: mlModel) {
            self.sentimentModel = model
        }
    }

    private func setupCategoryModel() {
        // Try to load custom category model, fallback to rule-based
        if let modelURL = Bundle.main.url(forResource: "NoteCategoryClassifier", withExtension: "mlmodelc"),
           let mlModel = try? MLModel(contentsOf: modelURL),
           let nlModel = try? NLModel(mlModel: mlModel) {
            self.categoryModel = nlModel
        }
    }

    // MARK: - Public Methods
    func analyzeSentimentWithML(_ text: String) async -> MLSentimentResult {
        guard !text.isEmpty else {
            return MLSentimentResult(sentiment: "neutral", confidence: 0.0, rawScore: 0.0)
        }

        if let model = sentimentModel {
            return await performMLSentimentAnalysis(text, model: model)
        } else {
            return await fallbackSentimentAnalysis(text)
        }
    }

    func classifyCategory(_ text: String) async -> MLCategoryResult {
        guard !text.isEmpty else {
            return MLCategoryResult(category: "general", confidence: 0.0, alternatives: [])
        }

        if let model = categoryModel {
            return await performMLCategoryClassification(text, model: model)
        } else {
            return await fallbackCategoryClassification(text)
        }
    }

    func generateSemanticEmbedding(_ text: String) -> [Double]? {
        return embedding?.vector(for: text)
    }

    func calculateSemanticSimilarity(_ text1: String, _ text2: String) -> Double {
        guard let embedding1 = generateSemanticEmbedding(text1),
              let embedding2 = generateSemanticEmbedding(text2) else {
            return 0.0
        }

        return cosineSimilarity(embedding1, embedding2)
    }

    // MARK: - Private ML Methods
    private func performMLSentimentAnalysis(_ text: String, model: NLModel) async -> MLSentimentResult {
        let prediction = model.predictedLabel(for: text)
        let hypotheses = model.predictedLabelHypotheses(for: text, maximumCount: 3)

        let confidence = hypotheses.values.max() ?? 0.0
        let sentiment = prediction ?? "neutral"

        // Calculate raw score for more nuanced analysis
        let rawScore = calculateRawSentimentScore(from: hypotheses)

        return MLSentimentResult(
            sentiment: sentiment,
            confidence: confidence,
            rawScore: rawScore
        )
    }

    private func performMLCategoryClassification(_ text: String, model: NLModel) async -> MLCategoryResult {
        let prediction = model.predictedLabel(for: text)
        let hypotheses = model.predictedLabelHypotheses(for: text, maximumCount: 5)

        let confidence = hypotheses.values.max() ?? 0.0
        let category = prediction ?? "general"

        // Get alternative categories
        let sortedHypotheses = hypotheses.sorted { $0.value > $1.value }
        let alternatives = Array(sortedHypotheses.dropFirst().prefix(3)).map { ($0.key, $0.value) }

        return MLCategoryResult(
            category: category,
            confidence: confidence,
            alternatives: alternatives
        )
    }

    private func fallbackSentimentAnalysis(_ text: String) async -> MLSentimentResult {
        // Enhanced fallback using NLTagger with better scoring
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        var sentimentScore: Double = 0
        var sentimentCount = 0

        let range = text.startIndex..<text.endIndex
        tagger.enumerateTags(in: range, unit: .sentence, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                sentimentScore += score
                sentimentCount += 1
            }
            return true
        }

        let averageScore = sentimentCount > 0 ? sentimentScore / Double(sentimentCount) : 0.0
        let confidence = min(abs(averageScore) * 2, 1.0) // Convert to confidence

        let sentiment: String
        if averageScore > 0.1 {
            sentiment = "positive"
        } else if averageScore < -0.1 {
            sentiment = "negative"
        } else {
            sentiment = "neutral"
        }

        return MLSentimentResult(
            sentiment: sentiment,
            confidence: confidence,
            rawScore: averageScore
        )
    }

    private func fallbackCategoryClassification(_ text: String) async -> MLCategoryResult {
        // Enhanced rule-based classification with confidence scoring
        let lowercased = text.lowercased()
        var categoryScores: [String: Double] = [:]

        // Meeting indicators
        let meetingKeywords = ["meeting", "call", "discussion", "agenda", "attendees", "minutes", "zoom", "teams"]
        categoryScores["meeting"] = calculateKeywordScore(lowercased, keywords: meetingKeywords)

        // Research indicators
        let researchKeywords = ["research", "study", "analysis", "findings", "data", "hypothesis", "methodology"]
        categoryScores["research"] = calculateKeywordScore(lowercased, keywords: researchKeywords)

        // Personal indicators
        let personalKeywords = ["feeling", "think", "believe", "personal", "diary", "journal", "mood"]
        categoryScores["personal"] = calculateKeywordScore(lowercased, keywords: personalKeywords)

        // Task indicators
        let taskKeywords = ["task", "todo", "action", "complete", "finish", "deadline", "priority"]
        categoryScores["tasks"] = calculateKeywordScore(lowercased, keywords: taskKeywords)

        // Ideas indicators
        let ideaKeywords = ["idea", "brainstorm", "concept", "innovation", "creative", "inspiration"]
        categoryScores["ideas"] = calculateKeywordScore(lowercased, keywords: ideaKeywords)

        // Find best match
        let sortedScores = categoryScores.sorted { $0.value > $1.value }
        let bestCategory = sortedScores.first?.key ?? "general"
        let confidence = sortedScores.first?.value ?? 0.0

        // Create alternatives list
        let alternatives = Array(sortedScores.dropFirst().prefix(3)).map { ($0.key, $0.value) }

        return MLCategoryResult(
            category: bestCategory,
            confidence: confidence,
            alternatives: alternatives
        )
    }

    // MARK: - Helper Methods
    private func calculateRawSentimentScore(from hypotheses: [String: Double]) -> Double {
        var score: Double = 0.0

        for (key, value) in hypotheses {
            switch key.lowercased() {
            case "positive":
                score += value
            case "negative":
                score -= value
            default:
                break
            }
        }

        return score
    }

    private func calculateKeywordScore(_ text: String, keywords: [String]) -> Double {
        var score: Double = 0.0
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let totalWords = Double(words.count)

        for keyword in keywords {
            if text.contains(keyword) {
                // Base score for containing the keyword
                score += 0.3

                // Bonus for multiple occurrences
                let occurrences = text.components(separatedBy: keyword).count - 1
                score += Double(occurrences) * 0.1

                // Bonus for keyword density
                score += Double(occurrences) / totalWords
            }
        }

        return min(score, 1.0) // Cap at 1.0
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }

    private func createSentimentModel() -> MLModel? {
        // This would normally load a pre-trained sentiment model
        // For now, we return nil to use the fallback method
        // In a real implementation, you'd load an actual Core ML model here
        return nil
    }
}

// MARK: - ML Entity Extractor
class MLEntityExtractor {
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .lemma])

    func extractEntitiesWithML(_ text: String) async -> ExtractedEntities {
        guard !text.isEmpty else {
            return ExtractedEntities(people: [], places: [], organizations: [], dates: [], currencies: [], products: [], confidence: 0.0)
        }

        tagger.string = text

        var people: [String] = []
        var places: [String] = []
        var organizations: [String] = []
        var actionVerbs: [String] = []
        var importantNouns: [String] = []

        let range = text.startIndex..<text.endIndex

        // Extract named entities
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            let entity = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !entity.isEmpty else { return true }

            switch tag {
            case .personalName:
                if !people.contains(entity) {
                    people.append(entity)
                }
            case .placeName:
                if !places.contains(entity) {
                    places.append(entity)
                }
            case .organizationName:
                if !organizations.contains(entity) {
                    organizations.append(entity)
                }
            default:
                break
            }
            return true
        }

        // Extract action verbs and important nouns
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !word.isEmpty, word.count > 2 else { return true }

            switch tag {
            case .verb:
                if isActionVerb(word) && !actionVerbs.contains(word.lowercased()) {
                    actionVerbs.append(word.lowercased())
                }
            case .noun:
                if isImportantNoun(word, in: text) && !importantNouns.contains(word.lowercased()) {
                    importantNouns.append(word.lowercased())
                }
            default:
                break
            }
            return true
        }

        // Convert to new ExtractedEntities format
        let confidence = calculateEntityConfidence(people: people, places: places, organizations: organizations)
        
        return ExtractedEntities(
            people: people,
            places: places,
            organizations: organizations,
            dates: [], // Dates will be extracted by ContactInfoExtractor
            currencies: [], // Currencies will be extracted by StructuredTextExtractor
            products: Array(importantNouns.prefix(10)), // Use important nouns as products
            confidence: confidence
        )
    }

    private func isActionVerb(_ verb: String) -> Bool {
        let actionVerbs = [
            "call", "email", "text", "contact", "schedule", "book", "buy", "purchase",
            "complete", "finish", "start", "begin", "create", "make", "build", "develop",
            "update", "modify", "change", "review", "check", "verify", "confirm",
            "send", "deliver", "submit", "upload", "download", "install", "setup",
            "meet", "discuss", "talk", "present", "demonstrate", "explain", "teach",
            "research", "study", "analyze", "investigate", "explore", "learn",
            "plan", "organize", "prepare", "arrange", "coordinate", "manage"
        ]
        return actionVerbs.contains(verb.lowercased())
    }

    private func isImportantNoun(_ noun: String, in text: String) -> Bool {
        let word = noun.lowercased()

        // Skip common words
        let commonWords = ["thing", "time", "way", "day", "man", "world", "life", "hand", "part", "child", "eye", "woman", "place", "work", "week", "case", "point", "government", "company"]
        if commonWords.contains(word) {
            return false
        }

        // Check if it appears multiple times (indicates importance)
        let occurrences = text.lowercased().components(separatedBy: word).count - 1
        if occurrences > 1 {
            return true
        }

        // Check if it's capitalized (might be important)
        if noun.first?.isUppercase == true {
            return true
        }

        // Check if it's a domain-specific important noun
        let importantNouns = [
            "project", "task", "goal", "objective", "deadline", "meeting", "presentation",
            "document", "report", "analysis", "research", "study", "data", "information",
            "client", "customer", "user", "team", "member", "manager", "director",
            "budget", "cost", "price", "revenue", "profit", "investment", "funding",
            "strategy", "plan", "approach", "method", "process", "system", "solution",
            "issue", "problem", "challenge", "opportunity", "risk", "threat",
            "decision", "choice", "option", "alternative", "recommendation", "suggestion"
        ]

        return importantNouns.contains(word)
    }
    
    private func calculateEntityConfidence(people: [String], places: [String], organizations: [String]) -> Float {
        let totalEntities = people.count + places.count + organizations.count
        
        if totalEntities == 0 {
            return 0.3 // Low confidence when no entities found
        } else if totalEntities >= 5 {
            return 0.9 // High confidence with many entities
        } else {
            return 0.5 + Float(totalEntities) * 0.1 // Scale with entity count
        }
    }
}
//
//  AIProcessor.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import NaturalLanguage
import CoreML
import Combine
import Vision
import UIKit

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

// MARK: - OCR and Table Processing Results
struct OCRResult {
    let rawText: String
    let detectedTables: [TableData]
    let confidence: Float
}

struct TableData {
    let title: String?
    let headers: [String]
    let rows: [[String]]
    let boundingBox: CGRect
    let confidence: Float
    
    enum OutputFormat {
        case markdown
        case csv
        case json
        case plainText
    }
    
    var formattedText: String {
        return formatAs(.markdown)
    }
    
    func formatAs(_ format: OutputFormat) -> String {
        switch format {
        case .markdown:
            return formatAsMarkdown()
        case .csv:
            return formatAsCSV()
        case .json:
            return formatAsJSON()
        case .plainText:
            return formatAsPlainText()
        }
    }
    
    private func formatAsMarkdown() -> String {
        var result = ""
        
        if let title = title, !title.isEmpty {
            result += "**\(title)**\n\n"
        }
        
        // Create markdown table format
        if !headers.isEmpty {
            result += "| " + headers.joined(separator: " | ") + " |\n"
            result += "|" + String(repeating: "---|", count: headers.count) + "\n"
        }
        
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            result += "| " + paddedRow.joined(separator: " | ") + " |\n"
        }
        
        return result
    }
    
    private func formatAsCSV() -> String {
        var result = ""
        
        if let title = title, !title.isEmpty {
            result += "\"\(title)\"\n"
        }
        
        // Add headers
        if !headers.isEmpty {
            result += headers.map { "\"\($0)\"" }.joined(separator: ",") + "\n"
        }
        
        // Add rows
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            result += paddedRow.map { "\"\($0)\"" }.joined(separator: ",") + "\n"
        }
        
        return result
    }
    
    private func formatAsJSON() -> String {
        var tableDict: [String: Any] = [:]
        
        if let title = title, !title.isEmpty {
            tableDict["title"] = title
        }
        
        tableDict["headers"] = headers
        tableDict["rows"] = rows.map { padRowToMatchHeaders($0) }
        tableDict["confidence"] = confidence
        
        // Convert to structured data
        var tableData: [[String: String]] = []
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            var rowDict: [String: String] = [:]
            
            for (index, header) in headers.enumerated() {
                let value = index < paddedRow.count ? paddedRow[index] : ""
                rowDict[header] = value
            }
            tableData.append(rowDict)
        }
        
        tableDict["data"] = tableData
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: tableDict, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to serialize table data\"}"
        }
    }
    
    private func formatAsPlainText() -> String {
        var result = ""
        
        if let title = title, !title.isEmpty {
            result += "\(title)\n"
            result += String(repeating: "=", count: title.count) + "\n\n"
        }
        
        // Calculate column widths
        let columnWidths = calculateColumnWidths()
        
        // Add headers
        if !headers.isEmpty {
            let headerRow = headers.enumerated().map { index, header in
                let width = index < columnWidths.count ? columnWidths[index] : header.count
                return header.padding(toLength: width, withPad: " ", startingAt: 0)
            }.joined(separator: " | ")
            
            result += headerRow + "\n"
            result += String(repeating: "-", count: headerRow.count) + "\n"
        }
        
        // Add rows
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            let formattedRow = paddedRow.enumerated().map { index, cell in
                let width = index < columnWidths.count ? columnWidths[index] : cell.count
                return cell.padding(toLength: width, withPad: " ", startingAt: 0)
            }.joined(separator: " | ")
            
            result += formattedRow + "\n"
        }
        
        return result
    }
    
    private func padRowToMatchHeaders(_ row: [String]) -> [String] {
        var paddedRow = row
        while paddedRow.count < headers.count {
            paddedRow.append("")
        }
        return Array(paddedRow.prefix(headers.count))
    }
    
    private func calculateColumnWidths() -> [Int] {
        var widths = headers.map { $0.count }
        
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            for (index, cell) in paddedRow.enumerated() {
                if index < widths.count {
                    widths[index] = max(widths[index], cell.count)
                }
            }
        }
        
        return widths
    }
    
    var isValid: Bool {
        return !headers.isEmpty && !rows.isEmpty && confidence > 0.3
    }
    
    var rowCount: Int {
        return rows.count
    }
    
    var columnCount: Int {
        return headers.count
    }
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
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private struct AIConfig {
        static let maxSummaryLength = 200
        static let maxKeyPoints = 5
        static let maxActionItems = 10
        static let maxSuggestedTags = 5  // Restricted to max 5 tags
        static let similarityThreshold = 0.3
    }
    
    // MARK: - Initialization
    init() {
        setupNaturalLanguageProcessing()
    }
    
    private func setupNaturalLanguageProcessing() {
        // Language will be set when processing content
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
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            processingProgress = progress
        }
    }
    
    // MARK: - Individual Processing Methods
    func summarizeContent(_ text: String) async -> String {
        guard !text.isEmpty else { return "" }
        
        // Use NaturalLanguage framework for basic summarization
        let sentences = extractSentences(from: text)
        guard sentences.count > 1 else { return text }
        
        // Score sentences based on keyword frequency and position
        let scoredSentences = scoreSentences(sentences, in: text)
        
        // Select top sentences for summary
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
        
        // Look for sentences with key indicators
        let keyIndicators = ["important", "key", "main", "primary", "essential", "critical", "note that", "remember"]
        
        for sentence in sentences {
            let lowercased = sentence.lowercased()
            if keyIndicators.contains(where: { lowercased.contains($0) }) {
                keyPoints.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        // If no key indicators found, use sentence scoring
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
        
        // Look for action-oriented sentences
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

        // Extract named entities
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

        // Extract important keywords
        let keywords = extractKeywords(from: content)
        tags.formUnion(keywords)

        return Array(tags.prefix(AIConfig.maxSuggestedTags))
    }
    
    func categorizeContent(_ text: String) async -> Category? {
        guard !text.isEmpty else { return nil }
        
        let lowercased = text.lowercased()
        
        // Simple rule-based categorization
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
    
    // MARK: - Helper Methods
    private func extractSentences(from text: String) -> [String] {
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
    
    private func scoreSentences(_ sentences: [String], in text: String) -> [(sentence: String, score: Double)] {
        let keywords = extractKeywords(from: text)
        
        return sentences.map { sentence in
            var score = 0.0
            let lowercased = sentence.lowercased()
            
            // Score based on keyword frequency
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    score += 1.0
                }
            }
            
            // Boost score for sentences with numbers or dates
            if sentence.range(of: "\\d+", options: .regularExpression) != nil {
                score += 0.5
            }
            
            // Penalize very short or very long sentences
            let wordCount = sentence.components(separatedBy: .whitespaces).count
            if wordCount < 5 || wordCount > 30 {
                score *= 0.5
            }
            
            return (sentence: sentence, score: score)
        }.sorted { $0.score > $1.score }
    }
    
    private func extractKeywords(from text: String) -> Set<String> {
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
    
    private func determinePriority(from text: String) -> Priority {
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
    
    private func calculateSimilarity(between text1: String, and text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
    }
    
    // MARK: - OCR and Table Processing Methods
    func performOCR(on image: UIImage) async -> OCRResult {
        isProcessing = true
        processingProgress = 0
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0
            }
        }
        
        guard let cgImage = image.cgImage else {
            return OCRResult(rawText: "", detectedTables: [], confidence: 0.0)
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                Task { @MainActor in
                    self.processingProgress = 0.5
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(rawText: "", detectedTables: [], confidence: 0.0))
                    return
                }
                
                Task {
                    let result = await self.processOCRObservations(observations, imageSize: image.size)
                    await MainActor.run {
                        self.processingProgress = 1.0
                    }
                    continuation.resume(returning: result)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func processOCRObservations(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) async -> OCRResult {
        var rawText = ""
        var textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)] = []
        
        // Extract all text with positions
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let text = topCandidate.string
            let boundingBox = observation.boundingBox
            let confidence = topCandidate.confidence
            
            rawText += text + "\n"
            textBlocks.append((text: text, boundingBox: boundingBox, confidence: confidence))
        }
        
        // Detect tables from text blocks
        let detectedTables = await detectTables(from: textBlocks, imageSize: imageSize)
        
        let averageConfidence = textBlocks.isEmpty ? 0.0 : textBlocks.map { $0.confidence }.reduce(0, +) / Float(textBlocks.count)
        
        return OCRResult(
            rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedTables: detectedTables,
            confidence: averageConfidence
        )
    }
    
    private func detectTables(from textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)], imageSize: CGSize) async -> [TableData] {
        var tables: [TableData] = []
        
        // Group text blocks by vertical position to identify potential rows
        let sortedBlocks = textBlocks.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        var processedBlocks = Set<Int>()
        
        for (index, block) in sortedBlocks.enumerated() {
            if processedBlocks.contains(index) { continue }
            
            // Find blocks that could form a table row (similar Y position)
            var rowBlocks: [(text: String, boundingBox: CGRect, confidence: Float)] = [block]
            let rowY = block.boundingBox.minY
            let rowTolerance: CGFloat = 0.02 // 2% tolerance
            
            for (otherIndex, otherBlock) in sortedBlocks.enumerated() {
                if otherIndex == index || processedBlocks.contains(otherIndex) { continue }
                
                if abs(otherBlock.boundingBox.minY - rowY) <= rowTolerance {
                    rowBlocks.append(otherBlock)
                    processedBlocks.insert(otherIndex)
                }
            }
            
            // If we found multiple blocks in a row, check if it could be part of a table
            if rowBlocks.count >= 2 {
                processedBlocks.insert(index)
                
                // Sort blocks by X position for proper column order
                rowBlocks.sort { $0.boundingBox.minX < $1.boundingBox.minX }
                
                // Look for additional rows below this one
                var tableRows: [[String]] = [rowBlocks.map { $0.text }]
                var tableBoundingBox = rowBlocks.reduce(rowBlocks[0].boundingBox) { result, block in
                    result.union(block.boundingBox)
                }
                
                // Search for additional rows
                let columnCount = rowBlocks.count
                let columnPositions = rowBlocks.map { $0.boundingBox.minX }
                
                for (searchIndex, searchBlock) in sortedBlocks.enumerated() {
                    if processedBlocks.contains(searchIndex) { continue }
                    
                    // Check if this block could start a new row below the current table
                    if searchBlock.boundingBox.minY < (rowY - 0.05) { // 5% below current row
                        var newRowBlocks: [(text: String, boundingBox: CGRect)] = []
                        
                        // Try to find blocks for each column position
                        for columnX in columnPositions {
                            let columnTolerance: CGFloat = 0.03
                            
                            if let matchingBlock = sortedBlocks.first(where: { otherBlock in
                                !processedBlocks.contains(sortedBlocks.firstIndex(where: { $0.boundingBox == otherBlock.boundingBox }) ?? -1) &&
                                abs(otherBlock.boundingBox.minX - columnX) <= columnTolerance &&
                                abs(otherBlock.boundingBox.minY - searchBlock.boundingBox.minY) <= rowTolerance
                            }) {
                                newRowBlocks.append((text: matchingBlock.text, boundingBox: matchingBlock.boundingBox))
                            }
                        }
                        
                        // If we found blocks for most columns, add this as a table row
                        if newRowBlocks.count >= max(2, columnCount - 1) {
                            newRowBlocks.sort { $0.boundingBox.minX < $1.boundingBox.minX }
                            
                            // Pad row to match column count
                            var rowData = newRowBlocks.map { $0.text }
                            while rowData.count < columnCount {
                                rowData.append("")
                            }
                            
                            tableRows.append(Array(rowData.prefix(columnCount)))
                            
                            // Update table bounding box
                            for block in newRowBlocks {
                                tableBoundingBox = tableBoundingBox.union(block.boundingBox)
                            }
                            
                            // Mark these blocks as processed
                            for block in newRowBlocks {
                                if let blockIndex = sortedBlocks.firstIndex(where: { $0.boundingBox == block.boundingBox }) {
                                    processedBlocks.insert(blockIndex)
                                }
                            }
                        }
                    }
                }
                
                // Create table if we have at least 2 rows
                if tableRows.count >= 2 {
                    let headers = tableRows[0]
                    let dataRows = Array(tableRows[1...])
                    
                    let averageConfidence = rowBlocks.map { $0.confidence }.reduce(0, +) / Float(rowBlocks.count)
                    
                    let rawTable = TableData(
                        title: detectTableTitle(near: tableBoundingBox, in: textBlocks),
                        headers: headers,
                        rows: dataRows,
                        boundingBox: tableBoundingBox,
                        confidence: averageConfidence
                    )
                    
                    // Validate and correct the table
                    let correctedTable = validateAndCorrectTable(rawTable)
                    
                    // Only add valid tables
                    if correctedTable.isValid {
                        tables.append(correctedTable)
                    }
                }
            }
        }
        
        return tables
    }
    
    private func detectTableTitle(near tableBoundingBox: CGRect, in textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> String? {
        let titleSearchArea = CGRect(
            x: tableBoundingBox.minX - 0.1,
            y: tableBoundingBox.maxY,
            width: tableBoundingBox.width + 0.2,
            height: 0.1
        )
        
        let potentialTitles = textBlocks.filter { block in
            titleSearchArea.intersects(block.boundingBox) &&
            !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        return potentialTitles.sorted { $0.boundingBox.minY > $1.boundingBox.minY }.first?.text
    }
    
    // MARK: - Table Validation and Correction
    func validateAndCorrectTable(_ table: TableData) -> TableData {
        var correctedHeaders = validateHeaders(table.headers)
        var correctedRows = validateRows(table.rows, expectedColumnCount: correctedHeaders.count)
        
        // Clean and normalize text
        correctedHeaders = correctedHeaders.map { cleanText($0) }
        correctedRows = correctedRows.map { row in
            row.map { cleanText($0) }
        }
        
        // Remove completely empty rows
        correctedRows = correctedRows.filter { row in
            !row.allSatisfy { $0.isEmpty }
        }
        
        // Merge split cells if detected
        correctedRows = mergeSplitCells(correctedRows)
        
        return TableData(
            title: table.title?.trimmingCharacters(in: .whitespacesAndNewlines),
            headers: correctedHeaders,
            rows: correctedRows,
            boundingBox: table.boundingBox,
            confidence: calculateCorrectedConfidence(originalConfidence: table.confidence, headers: correctedHeaders, rows: correctedRows)
        )
    }
    
    private func validateHeaders(_ headers: [String]) -> [String] {
        var validatedHeaders = headers
        
        // Remove empty headers at the end
        while validatedHeaders.last?.isEmpty == true {
            validatedHeaders.removeLast()
        }
        
        // Fill empty headers with generic names
        for (index, header) in validatedHeaders.enumerated() {
            if header.isEmpty {
                validatedHeaders[index] = "Column \(index + 1)"
            }
        }
        
        // Ensure minimum 2 columns for a valid table
        if validatedHeaders.count < 2 {
            while validatedHeaders.count < 2 {
                validatedHeaders.append("Column \(validatedHeaders.count + 1)")
            }
        }
        
        return validatedHeaders
    }
    
    private func validateRows(_ rows: [[String]], expectedColumnCount: Int) -> [[String]] {
        return rows.map { row in
            var validatedRow = row
            
            // Pad row to match expected column count
            while validatedRow.count < expectedColumnCount {
                validatedRow.append("")
            }
            
            // Trim row if it exceeds expected column count
            if validatedRow.count > expectedColumnCount {
                validatedRow = Array(validatedRow.prefix(expectedColumnCount))
            }
            
            return validatedRow
        }
    }
    
    private func cleanText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[\\x00-\\x1F\\x7F]", with: "", options: .regularExpression) // Remove control characters
    }
    
    private func mergeSplitCells(_ rows: [[String]]) -> [[String]] {
        guard !rows.isEmpty else { return rows }
        
        var mergedRows: [[String]] = []
        var i = 0
        
        while i < rows.count {
            let currentRow = rows[i]
            
            // Check if this row might be a continuation of the previous row
            if i > 0 && shouldMergeWithPreviousRow(currentRow, previousRow: rows[i-1]) {
                // Merge with the last row in mergedRows
                if !mergedRows.isEmpty {
                    let lastIndex = mergedRows.count - 1
                    mergedRows[lastIndex] = mergeRows(mergedRows[lastIndex], currentRow)
                }
            } else {
                mergedRows.append(currentRow)
            }
            
            i += 1
        }
        
        return mergedRows
    }
    
    private func shouldMergeWithPreviousRow(_ currentRow: [String], previousRow: [String]) -> Bool {
        // Check if current row has significantly fewer non-empty cells
        let currentNonEmpty = currentRow.filter { !$0.isEmpty }.count
        let previousNonEmpty = previousRow.filter { !$0.isEmpty }.count
        
        // If current row has very few cells and previous row has more, likely a split
        if currentNonEmpty > 0 && currentNonEmpty < previousNonEmpty / 2 {
            return true
        }
        
        // Check if current row starts with what looks like continuation text
        let firstNonEmpty = currentRow.first { !$0.isEmpty }
        if let text = firstNonEmpty {
            let startsWithLowercase = text.first?.isLowercase == true
            let hasNoPunctuation = !text.contains(".") && !text.contains("!") && !text.contains("?")
            return startsWithLowercase && hasNoPunctuation && text.count < 30
        }
        
        return false
    }
    
    private func mergeRows(_ row1: [String], _ row2: [String]) -> [String] {
        let maxCount = max(row1.count, row2.count)
        var merged: [String] = []
        
        for i in 0..<maxCount {
            let cell1 = i < row1.count ? row1[i] : ""
            let cell2 = i < row2.count ? row2[i] : ""
            
            if cell1.isEmpty {
                merged.append(cell2)
            } else if cell2.isEmpty {
                merged.append(cell1)
            } else {
                merged.append(cell1 + " " + cell2)
            }
        }
        
        return merged
    }
    
    private func calculateCorrectedConfidence(originalConfidence: Float, headers: [String], rows: [[String]]) -> Float {
        var confidence = originalConfidence
        
        // Reduce confidence for tables with many empty cells
        let totalCells = headers.count * (rows.count + 1) // +1 for header row
        let emptyCells = headers.filter { $0.isEmpty }.count + 
                        rows.flatMap { $0 }.filter { $0.isEmpty }.count
        
        let emptyRatio = Float(emptyCells) / Float(totalCells)
        confidence *= (1.0 - emptyRatio * 0.5) // Reduce by up to 50% based on empty cells
        
        // Boost confidence for well-structured tables
        if rows.count >= 3 && headers.count >= 2 {
            confidence *= 1.1 // 10% boost for substantial tables
        }
        
        return min(max(confidence, 0.0), 1.0) // Clamp between 0 and 1
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
            
            // Convert sentiment to numerical score
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
        
        // Determine overall folder sentiment
        let dominantSentiment = max(positiveCount, negativeCount, neutralCount)
        let mixedThreshold = validAnalyses / 3 // If no sentiment dominates by more than 1/3
        
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

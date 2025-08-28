//
//  DocumentLayoutAnalyzer.swift
//  AINoteTakingApp
//
//  Analyzes document structure and layout from OCR text blocks
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import Vision
import NaturalLanguage
import CoreGraphics

class DocumentLayoutAnalyzer {
    
    // MARK: - Private Properties
    private let nlTagger: NLTagger
    
    // MARK: - Layout Patterns
    private struct LayoutPatterns {
        static let bulletPatterns = ["•", "◦", "▪", "▫", "‣", "-", "*", "·"]
        static let numberPatterns = [
            #"^\d+\."#,  // 1. 2. 3.
            #"^\d+\)"#,  // 1) 2) 3)
            #"^[a-z]\."#, // a. b. c.
            #"^[A-Z]\."#, // A. B. C.
            #"^[ivx]+\."#, // i. ii. iii.
            #"^[IVX]+\."# // I. II. III.
        ]
        
        static let headingIndicators = [
            "title", "heading", "section", "chapter", "part", "summary",
            "introduction", "conclusion", "overview", "details", "information"
        ]
        
        // REMOVED: documentTypeKeywords - no longer used since we don't classify document types here
    }
    
    // MARK: - Initialization
    init() {
        self.nlTagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass])
    }
    
    // MARK: - Public Methods
    func analyzeDocumentLayout(from textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)], imageSize: CGSize) -> DocumentLayout {
        
        // Sort text blocks by position (top to bottom, left to right)
        let sortedBlocks = sortTextBlocks(textBlocks)
        
        // Detect document title
        let title = detectTitle(from: sortedBlocks)
        
        // Extract sections
        let sections = extractSections(from: sortedBlocks)
        
        // Extract bullet points
        let bulletPoints = extractBulletPoints(from: sortedBlocks)
        
        // Extract numbered lists
        let numberedLists = extractNumberedLists(from: sortedBlocks)
        
        // Extract simple tables
        let tables = extractSimpleTables(from: sortedBlocks, imageSize: imageSize)
        
        // Determine if document is well-structured
        let isStructured = determineStructure(
            title: title,
            sections: sections,
            bulletPoints: bulletPoints,
            numberedLists: numberedLists,
            tables: tables
        )
        
        // Calculate confidence
        let confidence = calculateLayoutConfidence(
            textBlocks: textBlocks,
            isStructured: isStructured
        )
        
        return DocumentLayout(
            title: title,
            sections: sections,
            bulletPoints: bulletPoints,
            numberedLists: numberedLists,
            tables: tables,
            isStructured: isStructured,
            confidence: confidence
        )
    }
    
    // REMOVED: classifyDocumentType - now handled by DocumentClassifier (image-based)
    // DocumentLayoutAnalyzer now focuses only on layout analysis
    
    // MARK: - Private Analysis Methods
    private func sortTextBlocks(_ textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> [(text: String, boundingBox: CGRect, confidence: Float)] {
        return textBlocks.sorted { block1, block2 in
            // Primary sort: top to bottom (higher Y values first in iOS coordinate system)
            if abs(block1.boundingBox.minY - block2.boundingBox.minY) > 0.02 {
                return block1.boundingBox.minY > block2.boundingBox.minY
            }
            // Secondary sort: left to right
            return block1.boundingBox.minX < block2.boundingBox.minX
        }
    }
    
    private func detectTitle(from textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> String? {
        guard !textBlocks.isEmpty else { return nil }
        
        // Check the first few text blocks for title characteristics
        for block in textBlocks.prefix(3) {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Title characteristics
            let isCentered = block.boundingBox.midX > 0.3 && block.boundingBox.midX < 0.7
            let isShort = text.components(separatedBy: .whitespaces).count <= 10
            let isNotContactInfo = !text.contains("@") && !text.contains("phone")
            let hasCapitalWords = text.components(separatedBy: .whitespaces)
                .filter { word in
                    word.first?.isUppercase == true
                }.count >= text.components(separatedBy: .whitespaces).count / 2
            
            if isCentered && isShort && isNotContactInfo && hasCapitalWords {
                return text
            }
            
            // Check for title-like formatting
            if text.allSatisfy({ $0.isUppercase || $0.isWhitespace || $0.isPunctuation }) && isShort {
                return text
            }
        }
        
        // Fallback: use the first non-trivial text block
        let candidateTitle = textBlocks.first?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let title = candidateTitle,
           title.count > 3 && title.count < 100 && !title.contains("@") {
            return title
        }
        
        return nil
    }
    
    private func extractSections(from textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> [DocumentSection] {
        var sections: [DocumentSection] = []
        var currentSection: DocumentSection?
        
        for block in textBlocks {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if this looks like a section header
            if isSectionHeader(text) {
                // Save the previous section if it exists
                if let section = currentSection {
                    sections.append(section)
                }
                
                // Start a new section
                currentSection = DocumentSection(
                    title: text,
                    content: "",
                    level: determineSectionLevel(text),
                    boundingBox: block.boundingBox
                )
            } else if let section = currentSection {
                // Add content to the current section
                var updatedContent = section.content
                if !updatedContent.isEmpty {
                    updatedContent += " "
                }
                updatedContent += text
                
                // Create new section with updated content
                currentSection = DocumentSection(
                    title: section.title,
                    content: updatedContent,
                    level: section.level,
                    boundingBox: section.boundingBox
                )
            }
        }
        
        // Add the last section
        if let section = currentSection {
            sections.append(section)
        }
        
        return sections
    }
    
    private func isSectionHeader(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        
        // Check for heading indicators
        for indicator in LayoutPatterns.headingIndicators {
            if lowercaseText.contains(indicator) {
                return true
            }
        }
        
        // Check for formatting patterns typical of headers
        let words = text.components(separatedBy: .whitespaces)
        
        // All caps and short
        if text.allSatisfy({ $0.isUppercase || $0.isWhitespace || $0.isPunctuation }) && words.count <= 5 {
            return true
        }
        
        // Title case and reasonable length
        let titleCaseWords = words.filter { word in
            word.first?.isUppercase == true && word.dropFirst().allSatisfy { $0.isLowercase }
        }
        
        if titleCaseWords.count >= words.count / 2 && words.count <= 8 {
            return true
        }
        
        // Ends with colon (often indicates a section)
        if text.hasSuffix(":") && words.count <= 6 {
            return true
        }
        
        return false
    }
    
    private func determineSectionLevel(_ text: String) -> Int {
        let lowercaseText = text.lowercased()
        
        // Level 1: Main headings
        if lowercaseText.contains("title") || lowercaseText.contains("main") ||
           text.allSatisfy({ $0.isUppercase || $0.isWhitespace || $0.isPunctuation }) {
            return 1
        }
        
        // Level 2: Section headings
        if lowercaseText.contains("section") || lowercaseText.contains("part") {
            return 2
        }
        
        // Level 3: Subsections
        return 3
    }
    
    private func extractBulletPoints(from textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> [BulletPoint] {
        var bulletPoints: [BulletPoint] = []
        
        for block in textBlocks {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if text starts with a bullet pattern
            for bullet in LayoutPatterns.bulletPatterns {
                if text.hasPrefix(bullet) {
                    let content = String(text.dropFirst(bullet.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !content.isEmpty {
                        let bulletPoint = BulletPoint(
                            text: content,
                            level: determineBulletLevel(block.boundingBox),
                            boundingBox: block.boundingBox
                        )
                        bulletPoints.append(bulletPoint)
                        break
                    }
                }
            }
        }
        
        return bulletPoints
    }
    
    private func determineBulletLevel(_ boundingBox: CGRect) -> Int {
        // Determine bullet level based on indentation
        let leftMargin = boundingBox.minX
        
        if leftMargin < 0.1 {
            return 1 // No indentation
        } else if leftMargin < 0.2 {
            return 2 // First level indentation
        } else {
            return 3 // Further indentation
        }
    }
    
    private func extractNumberedLists(from textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> [NumberedList] {
        var numberedLists: [NumberedList] = []
        var currentList: [NumberedItem] = []
        var expectedNumber = 1
        
        for block in textBlocks {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var foundNumber = false
            for pattern in LayoutPatterns.numberPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.count)) {
                    
                    let numberPart = (text as NSString).substring(with: match.range)
                    let content = String(text.dropFirst(match.range.length)).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !content.isEmpty {
                        let item = NumberedItem(
                            number: expectedNumber,
                            text: content,
                            boundingBox: block.boundingBox
                        )
                        currentList.append(item)
                        expectedNumber += 1
                        foundNumber = true
                        break
                    }
                }
            }
            
            // If we didn't find a numbered item and we have a current list, finalize it
            if !foundNumber && !currentList.isEmpty {
                let numberedList = NumberedList(
                    items: currentList,
                    startNumber: 1
                )
                numberedLists.append(numberedList)
                currentList = []
                expectedNumber = 1
            }
        }
        
        // Add the last list if it exists
        if !currentList.isEmpty {
            let numberedList = NumberedList(
                items: currentList,
                startNumber: 1
            )
            numberedLists.append(numberedList)
        }
        
        return numberedLists
    }
    
    private func extractSimpleTables(from textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)], imageSize: CGSize) -> [SimpleTable] {
        // Group text blocks that could form table rows
        var tables: [SimpleTable] = []
        
        // Find rows with similar Y positions
        let tolerance: CGFloat = 0.02
        var rowGroups: [[(text: String, boundingBox: CGRect, confidence: Float)]] = []
        var processedIndices = Set<Int>()
        
        for (index, block) in textBlocks.enumerated() {
            if processedIndices.contains(index) { continue }
            
            var rowBlocks = [block]
            let rowY = block.boundingBox.minY
            
            // Find other blocks at similar Y position
            for (otherIndex, otherBlock) in textBlocks.enumerated() {
                if otherIndex != index && !processedIndices.contains(otherIndex) {
                    if abs(otherBlock.boundingBox.minY - rowY) <= tolerance {
                        rowBlocks.append(otherBlock)
                        processedIndices.insert(otherIndex)
                    }
                }
            }
            
            if rowBlocks.count >= 2 {
                // Sort by X position
                rowBlocks.sort { $0.boundingBox.minX < $1.boundingBox.minX }
                rowGroups.append(rowBlocks)
                processedIndices.insert(index)
            }
        }
        
        // Convert row groups to tables
        if rowGroups.count >= 2 {
            let rows = rowGroups.map { rowBlocks in
                rowBlocks.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            
            // Determine if first row is header (check for consistent column count)
            let columnCounts = rows.map { $0.count }
            let hasConsistentColumns = Set(columnCounts).count == 1
            
            if hasConsistentColumns {
                let boundingBox = rowGroups.flatMap { $0 }.reduce(rowGroups[0][0].boundingBox) { result, block in
                    result.union(block.boundingBox)
                }
                
                let table = SimpleTable(
                    rows: rows,
                    hasHeader: true, // Assume first row is header
                    boundingBox: boundingBox
                )
                tables.append(table)
            }
        }
        
        return tables
    }
    
    private func determineStructure(
        title: String?,
        sections: [DocumentSection],
        bulletPoints: [BulletPoint],
        numberedLists: [NumberedList],
        tables: [SimpleTable]
    ) -> Bool {
        var structureScore = 0
        
        if title != nil { structureScore += 1 }
        if sections.count >= 2 { structureScore += 2 }
        if !bulletPoints.isEmpty { structureScore += 1 }
        if !numberedLists.isEmpty { structureScore += 1 }
        if !tables.isEmpty { structureScore += 2 }
        
        return structureScore >= 3
    }
    
    private func calculateLayoutConfidence(
        textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)],
        isStructured: Bool
    ) -> Float {
        var confidence: Float = 0.6 // Base confidence
        
        // Boost for structure
        if isStructured {
            confidence += 0.3
        }
        
        // Average OCR confidence
        let averageOCRConfidence = textBlocks.isEmpty ? 0.0 :
            textBlocks.map { $0.confidence }.reduce(0, +) / Float(textBlocks.count)
        confidence = (confidence + averageOCRConfidence) / 2
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Document Type Classification Helpers
    private func hasContactInfo(_ text: String) -> Bool {
        // Use ContactInfoExtractor for more accurate detection
        let contactExtractor = ContactInfoExtractor()
        let contactInfo = contactExtractor.extractContactInfo(from: text)
        
        let hasContact = !contactInfo.phoneNumbers.isEmpty || !contactInfo.emailAddresses.isEmpty
        print("📋 hasContactInfo: phones=\(contactInfo.phoneNumbers.count), emails=\(contactInfo.emailAddresses.count), hasContact=\(hasContact)")
        
        return hasContact
    }
    
    // REMOVED: hasPersonNames - no longer needed since we don't classify business cards here
    
    // REMOVED: parsePersonNameFromLine - no longer needed since we don't classify business cards here
    
    private func hasFormFields(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        let formIndicators = ["name:", "date:", "signature:", "check", "□", "☐", "fill", "complete"]
        
        for indicator in formIndicators {
            if lowercaseText.contains(indicator) {
                return true
            }
        }
        
        return false
    }
    
    // REMOVED: Price/receipt/menu detection methods - no longer used after simplification
}

// MARK: - DocumentType Extension
extension DocumentType {
    init?(rawValue: String) {
        switch rawValue {
        case "notice": self = .notice
        case "form": self = .form
        case "letter": self = .letter
        case "flyer": self = .flyer
        case "menu": self = .menu
        case "receipt": self = .receipt
        default: return nil
        }
    }
}
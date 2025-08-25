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
        
        static let documentTypeKeywords = [
            "notice": ["notice", "announcement", "alert", "warning", "attention"],
            "form": ["form", "application", "questionnaire", "survey", "registration"],
            "letter": ["dear", "sincerely", "regards", "yours", "letter"],
            "flyer": ["event", "join", "register", "rsvp", "admission"],
            "menu": ["menu", "appetizer", "entree", "dessert", "beverage", "price"],
            "receipt": ["receipt", "total", "subtotal", "tax", "payment", "change"]
        ]
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
    
    func classifyDocumentType(from text: String) -> DocumentType {
        print("📋 DocumentLayoutAnalyzer: Classifying document type for text: '\(text.prefix(100))...'")
        
        let lowercaseText = text.lowercased()
        var scores: [DocumentType: Int] = [:]
        
        // Initialize scores
        for docType in [DocumentType.notice, .form, .letter, .flyer, .menu, .receipt] {
            scores[docType] = 0
        }
        
        // Score based on keywords
        for (docType, keywords) in LayoutPatterns.documentTypeKeywords {
            let documentType = DocumentType(rawValue: docType) ?? .generic
            
            for keyword in keywords {
                if lowercaseText.contains(keyword) {
                    scores[documentType, default: 0] += 1
                }
            }
        }
        
        // Additional pattern-based scoring
        
        // Business card patterns
        let contactInfo = hasContactInfo(text)
        let hasPersonName = hasPersonNames(text)
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        
        print("📋 Business card check: contactInfo=\(contactInfo), hasPersonName=\(hasPersonName), wordCount=\(wordCount)")
        
        if contactInfo && hasPersonName && wordCount < 100 {
            print("📋 DocumentLayoutAnalyzer: Classified as BUSINESS CARD")
            return .businessCard
        }
        
        // Form patterns
        if hasFormFields(text) {
            scores[.form, default: 0] += 3
        }
        
        // Receipt patterns
        if hasPricePatterns(text) && hasReceiptKeywords(text) {
            scores[.receipt, default: 0] += 3
        }
        
        // Menu patterns
        if hasMenuStructure(text) {
            scores[.menu, default: 0] += 3
        }
        
        // Find the highest scoring document type
        let bestMatch = scores.max(by: { $0.value < $1.value })
        
        print("📋 DocumentLayoutAnalyzer: Final scores: \(scores)")
        print("📋 DocumentLayoutAnalyzer: Best match: \(bestMatch?.key.rawValue ?? "none") with score \(bestMatch?.value ?? 0)")
        
        if let (docType, score) = bestMatch, score >= 2 {
            print("📋 DocumentLayoutAnalyzer: Classified as \(docType.rawValue.uppercased())")
            return docType
        }
        
        print("📋 DocumentLayoutAnalyzer: Classified as GENERIC")
        return .generic
    }
    
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
    
    private func hasPersonNames(_ text: String) -> Bool {
        print("📋 hasPersonNames: Checking text for person names...")
        
        // Use the same robust name detection logic as BusinessCardProcessor
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        print("📋 hasPersonNames: Processing \(lines.count) lines")
        
        // Check last 3 lines for potential names (same strategy as BusinessCardProcessor)
        for (index, line) in lines.suffix(3).enumerated() {
            print("📋 hasPersonNames: Checking suffix line \(index): '\(line)'")
            if let name = parsePersonNameFromLine(line) {
                print("📋 hasPersonNames: Found name '\(name.fullName)' in suffix")
                return true
            }
        }
        
        // Check first 5 lines too (like BusinessCardProcessor Strategy 1)
        for (index, line) in lines.prefix(5).enumerated() {
            print("📋 hasPersonNames: Checking prefix line \(index): '\(line)'")
            if let name = parsePersonNameFromLine(line) {
                print("📋 hasPersonNames: Found name '\(name.fullName)' in prefix")
                return true
            }
        }
        
        print("📋 hasPersonNames: No names found with custom logic, trying NLTagger...")
        
        // Fallback: try NLTagger
        nlTagger.string = text
        let range = text.startIndex..<text.endIndex
        
        var hasNames = false
        nlTagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, _ in
            if tag == .personalName {
                hasNames = true
                return false
            }
            return true
        }
        
        print("📋 hasPersonNames: NLTagger result: \(hasNames)")
        return hasNames
    }
    
    private func parsePersonNameFromLine(_ line: String) -> PersonName? {
        print("📋 parsePersonNameFromLine: '\(line)'")
        
        let words = line.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        print("📋   Words: \(words), count: \(words.count)")
        
        guard words.count >= 2, words.count <= 4 else { 
            print("📋   SKIP: Word count not in range 2-4")
            return nil 
        }
        
        // Check if words look like names (capitalized, alphabetic)
        let nameWords = words.filter { word in
            guard let firstChar = word.first else { return false }
            let isCapitalizedLetter = firstChar.isLetter && firstChar.isUppercase
            let isAlphabetic = word.allSatisfy { $0.isLetter || $0 == "'" || $0 == "-" || $0 == "." }
            print("📋     Word '\(word)': firstChar=\(firstChar), isCapitalizedLetter=\(isCapitalizedLetter), isAlphabetic=\(isAlphabetic)")
            return isCapitalizedLetter && isAlphabetic && word.count >= 2
        }
        
        print("📋   Name words found: \(nameWords), count: \(nameWords.count)")
        
        guard nameWords.count >= 2 else { 
            print("📋   SKIP: Not enough name words")
            return nil 
        }
        
        // Create PersonName
        if nameWords.count == 2 {
            return PersonName(
                fullName: "\(nameWords[0]) \(nameWords[1])",
                firstName: nameWords[0],
                lastName: nameWords[1],
                prefix: nil,
                suffix: nil
            )
        } else if nameWords.count >= 3 {
            let fullName = nameWords.joined(separator: " ")
            return PersonName(
                fullName: fullName,
                firstName: nameWords[0],
                lastName: nameWords.last!,
                prefix: nil,
                suffix: nil
            )
        }
        
        return nil
    }
    
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
    
    private func hasPricePatterns(_ text: String) -> Bool {
        // Look for currency patterns
        let currencyPattern = #"\$\d+\.?\d*|\d+\.?\d*\s*(USD|usd|\$)"#
        return text.range(of: currencyPattern, options: .regularExpression) != nil
    }
    
    private func hasReceiptKeywords(_ text: String) -> Bool {
        let receiptKeywords = ["total", "subtotal", "tax", "receipt", "change", "payment"]
        let lowercaseText = text.lowercased()
        
        return receiptKeywords.contains { lowercaseText.contains($0) }
    }
    
    private func hasMenuStructure(_ text: String) -> Bool {
        let menuKeywords = ["appetizer", "entree", "dessert", "beverage", "menu", "special"]
        let lowercaseText = text.lowercased()
        
        let menuWordCount = menuKeywords.filter { lowercaseText.contains($0) }.count
        let hasPrices = hasPricePatterns(text)
        
        return menuWordCount >= 2 && hasPrices
    }
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
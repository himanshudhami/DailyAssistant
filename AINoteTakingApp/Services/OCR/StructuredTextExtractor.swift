//
//  StructuredTextExtractor.swift
//  AINoteTakingApp
//
//  Main coordinator for structured text extraction from OCR
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import UIKit
import Vision
import NaturalLanguage

@MainActor
class StructuredTextExtractor: ObservableObject {
    
    // MARK: - Private Properties
    private let contactExtractor: ContactInfoExtractor
    private let businessCardProcessor: BusinessCardProcessor
    private let documentAnalyzer: DocumentLayoutAnalyzer
    private let nlTagger: NLTagger
    
    // MARK: - Initialization
    init() {
        self.contactExtractor = ContactInfoExtractor()
        self.businessCardProcessor = BusinessCardProcessor()
        self.documentAnalyzer = DocumentLayoutAnalyzer()
        self.nlTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    }
    
    // MARK: - Public Methods
    func extractStructuredData(
        from text: String,
        textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)] = [],
        image: UIImage? = nil,
        options: StructuredExtractionOptions = .comprehensive
    ) async -> StructuredTextData {
        
        // Classify document type first
        let documentType = options.classifyDocumentType ? 
            documentAnalyzer.classifyDocumentType(from: text) : .generic
        
        // Extract data based on options and document type
        var contactInfo: ContactInfo?
        var businessCard: BusinessCardData?
        var documentLayout: DocumentLayout?
        var extractedEntities: ExtractedEntities?
        
        // Extract contact information
        if options.extractContactInfo {
            contactInfo = contactExtractor.extractContactInfo(from: text)
            print("📞 ContactInfo extracted: phones=\(contactInfo?.phoneNumbers.count ?? 0), emails=\(contactInfo?.emailAddresses.count ?? 0)")
        }
        
        // Detect business card
        if options.detectBusinessCard || documentType == .businessCard {
            businessCard = businessCardProcessor.detectBusinessCard(from: text, image: image)
            if let bc = businessCard {
                print("💼 BusinessCard detected: name=\(bc.name?.fullName ?? "nil"), company=\(bc.company ?? "nil")")
            } else {
                print("💼 No BusinessCard detected from BusinessCardProcessor")
            }
        }
        
        // Analyze document layout
        if options.analyzeLayout {
            let imageSize = image?.size ?? CGSize(width: 1, height: 1)
            documentLayout = documentAnalyzer.analyzeDocumentLayout(
                from: textBlocks,
                imageSize: imageSize
            )
        }
        
        // Extract entities
        if options.extractEntities {
            extractedEntities = await extractEntities(from: text)
        }
        
        // Calculate overall confidence
        let processingConfidence = calculateOverallConfidence(
            contactInfo: contactInfo,
            businessCard: businessCard,
            documentLayout: documentLayout,
            extractedEntities: extractedEntities,
            textBlocks: textBlocks
        )
        
        // Create preliminary structured data for generating summary and actions
        let preliminaryData = StructuredTextData(
            contactInfo: contactInfo,
            businessCard: businessCard,
            documentLayout: documentLayout,
            extractedEntities: extractedEntities,
            documentType: documentType,
            processingConfidence: processingConfidence,
            summary: nil,
            actionItems: [],
            tags: []
        )
        
        // Generate computed properties
        let summary = generateSmartSummary(from: preliminaryData, originalText: text)
        let actionItems = generateActionableItems(from: preliminaryData)
        let tags = generateSmartTags(from: preliminaryData)
        
        return StructuredTextData(
            contactInfo: contactInfo,
            businessCard: businessCard,
            documentLayout: documentLayout,
            extractedEntities: extractedEntities,
            documentType: documentType,
            processingConfidence: processingConfidence,
            summary: summary,
            actionItems: actionItems.map { $0.title },
            tags: tags
        )
    }
    
    func generateSmartSummary(from structuredData: StructuredTextData, originalText: String) -> String {
        print("📝 generateSmartSummary: DocumentType = \(structuredData.documentType)")
        print("📝 generateSmartSummary: BusinessCard = \(structuredData.businessCard?.name?.fullName ?? "nil")")
        
        var summaryParts: [String] = []
        
        switch structuredData.documentType {
        case .businessCard:
            if let businessCard = structuredData.businessCard {
                let summary = generateBusinessCardSummary(businessCard)
                print("📝 Generated business card summary: '\(summary)'")
                summaryParts.append(summary)
            } else {
                print("📝 ERROR: Document type is businessCard but businessCard data is nil!")
            }
            
        case .notice:
            summaryParts.append(generateNoticeSummary(structuredData, originalText: originalText))
            
        case .form:
            summaryParts.append(generateFormSummary(structuredData, originalText: originalText))
            
        case .receipt:
            summaryParts.append(generateReceiptSummary(structuredData, originalText: originalText))
            
        case .letter:
            summaryParts.append(generateLetterSummary(structuredData, originalText: originalText))
            
        case .flyer:
            summaryParts.append(generateFlyerSummary(structuredData, originalText: originalText))
            
        case .menu:
            summaryParts.append(generateMenuSummary(structuredData, originalText: originalText))
            
        default:
            summaryParts.append(generateGenericSummary(structuredData, originalText: originalText))
        }
        
        return summaryParts.joined(separator: "\n\n")
    }
    
    func generateActionableItems(from structuredData: StructuredTextData) -> [ActionItem] {
        var actionItems: [ActionItem] = []
        
        switch structuredData.documentType {
        case .businessCard:
            if let businessCard = structuredData.businessCard {
                actionItems.append(contentsOf: generateBusinessCardActions(businessCard))
            }
            
        case .notice:
            actionItems.append(contentsOf: generateNoticeActions(structuredData))
            
        case .form:
            actionItems.append(contentsOf: generateFormActions(structuredData))
            
        case .receipt:
            actionItems.append(contentsOf: generateReceiptActions(structuredData))
            
        default:
            actionItems.append(contentsOf: generateGenericActions(structuredData))
        }
        
        return actionItems
    }
    
    func generateSmartTags(from structuredData: StructuredTextData) -> [String] {
        var tags = Set<String>()
        
        // Add document type tag
        tags.insert(structuredData.documentType.rawValue)
        
        // Add entity-based tags
        if let entities = structuredData.extractedEntities {
            tags.formUnion(entities.people.map { $0.lowercased() })
            tags.formUnion(entities.places.map { $0.lowercased() })
            tags.formUnion(entities.organizations.map { $0.lowercased() })
        }
        
        // Add contact-based tags
        if let contactInfo = structuredData.contactInfo {
            if !contactInfo.phoneNumbers.isEmpty {
                tags.insert("phone")
            }
            if !contactInfo.emailAddresses.isEmpty {
                tags.insert("email")
            }
            if !contactInfo.addresses.isEmpty {
                tags.insert("address")
            }
        }
        
        // Add document-specific tags
        switch structuredData.documentType {
        case .businessCard:
            tags.insert("networking")
            tags.insert("contact")
            if let businessCard = structuredData.businessCard,
               let company = businessCard.company {
                tags.insert(company.lowercased())
            }
            
        case .notice:
            tags.insert("announcement")
            tags.insert("information")
            
        case .form:
            tags.insert("document")
            tags.insert("paperwork")
            
        case .receipt:
            tags.insert("expense")
            tags.insert("purchase")
            
        case .letter:
            tags.insert("correspondence")
            
        case .flyer:
            tags.insert("event")
            tags.insert("promotion")
            
        case .menu:
            tags.insert("restaurant")
            tags.insert("food")
            
        default:
            tags.insert("document")
        }
        
        return Array(tags.prefix(8)) // Limit to 8 tags
    }
    
    // MARK: - Private Entity Extraction
    private func extractEntities(from text: String) async -> ExtractedEntities {
        nlTagger.string = text
        
        var people: [String] = []
        var places: [String] = []
        var organizations: [String] = []
        var dates: [DateData] = []
        var currencies: [CurrencyData] = []
        var products: [String] = []
        
        let range = text.startIndex..<text.endIndex
        
        // Extract named entities
        nlTagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            let entity = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            
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
        
        // Extract dates using ContactInfoExtractor
        let contactInfo = contactExtractor.extractContactInfo(from: text)
        dates = contactInfo.dates
        
        // Extract currencies
        currencies = extractCurrencies(from: text)
        
        // Extract potential products (simple heuristic)
        products = extractProducts(from: text)
        
        let confidence = calculateEntityConfidence(
            people: people,
            places: places,
            organizations: organizations
        )
        
        return ExtractedEntities(
            people: people,
            places: places,
            organizations: organizations,
            dates: dates,
            currencies: currencies,
            products: products,
            confidence: confidence
        )
    }
    
    private func extractCurrencies(from text: String) -> [CurrencyData] {
        var currencies: [CurrencyData] = []
        
        // Currency patterns
        let patterns = [
            (#"\$(\d+(?:\.\d{2})?)"#, "USD"),
            (#"(\d+(?:\.\d{2})?)\s*USD"#, "USD"),
            (#"€(\d+(?:\.\d{2})?)"#, "EUR"),
            (#"£(\d+(?:\.\d{2})?)"#, "GBP")
        ]
        
        for (pattern, currencyCode) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    let fullMatch = (text as NSString).substring(with: match.range)
                    let amountRange = match.range(at: 1)
                    let amountString = (text as NSString).substring(with: amountRange)
                    
                    if let amount = Decimal(string: amountString) {
                        let currency = CurrencyData(
                            raw: fullMatch,
                            amount: amount,
                            currency: currencyCode,
                            confidence: 0.9
                        )
                        currencies.append(currency)
                    }
                }
            }
        }
        
        return currencies
    }
    
    private func extractProducts(from text: String) -> [String] {
        // Simple product extraction - could be enhanced with ML
        let productIndicators = ["buy", "purchase", "item", "product", "service"]
        var products: [String] = []
        
        let sentences = text.components(separatedBy: .punctuationCharacters)
        
        for sentence in sentences {
            let lowercased = sentence.lowercased()
            for indicator in productIndicators {
                if lowercased.contains(indicator) {
                    // Extract potential product names (simple heuristic)
                    let words = sentence.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                    
                    for (index, word) in words.enumerated() {
                        if word.lowercased() == indicator && index + 1 < words.count {
                            let potentialProduct = words[index + 1]
                            if potentialProduct.count > 2 && !products.contains(potentialProduct) {
                                products.append(potentialProduct)
                            }
                        }
                    }
                }
            }
        }
        
        return Array(products.prefix(10)) // Limit results
    }
    
    // MARK: - Summary Generation Methods
    private func generateBusinessCardSummary(_ businessCard: BusinessCardData) -> String {
        var parts: [String] = []
        
        if let name = businessCard.name {
            parts.append("Contact: \(name.fullName)")
        }
        
        if let title = businessCard.title {
            parts.append("Title: \(title)")
        }
        
        if let company = businessCard.company {
            parts.append("Company: \(company)")
        }
        
        if !businessCard.contactInfo.phoneNumbers.isEmpty {
            let phone = businessCard.contactInfo.phoneNumbers.first!.formatted
            parts.append("Phone: \(phone)")
        }
        
        if !businessCard.contactInfo.emailAddresses.isEmpty {
            let email = businessCard.contactInfo.emailAddresses.first!.address
            parts.append("Email: \(email)")
        }
        
        return "Business Card - " + parts.joined(separator: " | ")
    }
    
    private func generateNoticeSummary(_ structuredData: StructuredTextData, originalText: String) -> String {
        var summary = "Notice"
        
        if let layout = structuredData.documentLayout,
           let title = layout.title {
            summary += " - \(title)"
        }
        
        if let contactInfo = structuredData.contactInfo,
           !contactInfo.phoneNumbers.isEmpty {
            summary += " | Contact: \(contactInfo.phoneNumbers.first!.formatted)"
        }
        
        return summary
    }
    
    private func generateFormSummary(_ structuredData: StructuredTextData, originalText: String) -> String {
        var summary = "Form"
        
        if let layout = structuredData.documentLayout,
           let title = layout.title {
            summary += " - \(title)"
        }
        
        summary += " | Requires completion"
        return summary
    }
    
    private func generateReceiptSummary(_ structuredData: StructuredTextData, originalText: String) -> String {
        var summary = "Receipt"
        
        if let entities = structuredData.extractedEntities,
           !entities.currencies.isEmpty {
            let total = entities.currencies.max(by: { $0.amount ?? 0 < $1.amount ?? 0 })
            if let totalAmount = total {
                summary += " - Total: \(totalAmount.raw)"
            }
        }
        
        return summary
    }
    
    private func generateLetterSummary(_ structuredData: StructuredTextData, originalText: String) -> String {
        return "Letter" + (structuredData.documentLayout?.title.map { " - \($0)" } ?? "")
    }
    
    private func generateFlyerSummary(_ structuredData: StructuredTextData, originalText: String) -> String {
        return "Event Flyer" + (structuredData.documentLayout?.title.map { " - \($0)" } ?? "")
    }
    
    private func generateMenuSummary(_ structuredData: StructuredTextData, originalText: String) -> String {
        return "Menu" + (structuredData.documentLayout?.title.map { " - \($0)" } ?? "")
    }
    
    private func generateGenericSummary(_ structuredData: StructuredTextData, originalText: String) -> String {
        return "Document" + (structuredData.documentLayout?.title.map { " - \($0)" } ?? "")
    }
    
    // MARK: - Action Item Generation
    private func generateBusinessCardActions(_ businessCard: BusinessCardData) -> [ActionItem] {
        var actions: [ActionItem] = []
        
        actions.append(ActionItem(
            title: "Add contact to CRM",
            priority: .medium
        ))
        
        if !businessCard.contactInfo.emailAddresses.isEmpty {
            actions.append(ActionItem(
                title: "Send follow-up email",
                priority: .low
            ))
        }
        
        return actions
    }
    
    private func generateNoticeActions(_ structuredData: StructuredTextData) -> [ActionItem] {
        var actions: [ActionItem] = []
        
        actions.append(ActionItem(
            title: "Review notice details",
            priority: .medium
        ))
        
        if let contactInfo = structuredData.contactInfo,
           !contactInfo.phoneNumbers.isEmpty {
            actions.append(ActionItem(
                title: "Call for more information",
                priority: .low
            ))
        }
        
        return actions
    }
    
    private func generateFormActions(_ structuredData: StructuredTextData) -> [ActionItem] {
        return [
            ActionItem(title: "Complete form", priority: .high),
            ActionItem(title: "Submit completed form", priority: .medium)
        ]
    }
    
    private func generateReceiptActions(_ structuredData: StructuredTextData) -> [ActionItem] {
        return [
            ActionItem(title: "File receipt for expense tracking", priority: .low),
            ActionItem(title: "Update budget records", priority: .low)
        ]
    }
    
    private func generateGenericActions(_ structuredData: StructuredTextData) -> [ActionItem] {
        return [
            ActionItem(title: "Review document", priority: .low)
        ]
    }
    
    // MARK: - Helper Methods
    private func calculateOverallConfidence(
        contactInfo: ContactInfo?,
        businessCard: BusinessCardData?,
        documentLayout: DocumentLayout?,
        extractedEntities: ExtractedEntities?,
        textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]
    ) -> Float {
        var confidence: Float = 0.0
        var componentCount = 0
        
        // Average OCR confidence
        if !textBlocks.isEmpty {
            let ocrConfidence = textBlocks.map { $0.confidence }.reduce(0, +) / Float(textBlocks.count)
            confidence += ocrConfidence
            componentCount += 1
        }
        
        // Business card confidence
        if let bc = businessCard {
            confidence += bc.confidence
            componentCount += 1
        }
        
        // Document layout confidence
        if let layout = documentLayout {
            confidence += layout.confidence
            componentCount += 1
        }
        
        // Entity extraction confidence
        if let entities = extractedEntities {
            confidence += entities.confidence
            componentCount += 1
        }
        
        return componentCount > 0 ? confidence / Float(componentCount) : 0.5
    }
    
    private func calculateEntityConfidence(
        people: [String],
        places: [String],
        organizations: [String]
    ) -> Float {
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

// MARK: - DocumentType Extension
extension DocumentType {
    var rawValue: String {
        switch self {
        case .businessCard: return "business_card"
        case .notice: return "notice"
        case .form: return "form"
        case .receipt: return "receipt"
        case .letter: return "letter"
        case .flyer: return "flyer"
        case .menu: return "menu"
        case .generic: return "generic"
        }
    }
}
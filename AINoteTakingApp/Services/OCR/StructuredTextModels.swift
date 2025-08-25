//
//  StructuredTextModels.swift
//  AINoteTakingApp
//
//  Data models for structured text extraction from OCR
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import CoreGraphics

// MARK: - Main Structured Data Container
struct StructuredTextData {
    let contactInfo: ContactInfo?
    let businessCard: BusinessCardData?
    let documentLayout: DocumentLayout?
    let extractedEntities: ExtractedEntities?
    let documentType: DocumentType
    let processingConfidence: Float
    
    // Computed properties for UI
    let summary: String?
    let actionItems: [String]
    let tags: [String]
    
    // Convenience properties
    var confidence: Float { processingConfidence }
}

// MARK: - Contact Information
struct ContactInfo {
    let phoneNumbers: [PhoneNumber]
    let emailAddresses: [EmailAddress]
    let addresses: [Address]
    let urls: [URLData]
    let dates: [DateData]
    
    var isEmpty: Bool {
        phoneNumbers.isEmpty && emailAddresses.isEmpty && 
        addresses.isEmpty && urls.isEmpty && dates.isEmpty
    }
}

struct PhoneNumber {
    let raw: String
    let formatted: String
    let type: PhoneType
    let confidence: Float
    
    enum PhoneType {
        case mobile
        case landline
        case toll_free
        case international
        case unknown
    }
}

struct EmailAddress {
    let address: String
    let domain: String
    let isValid: Bool
    let confidence: Float
}

struct Address {
    let raw: String
    let street: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let country: String?
    let confidence: Float
}

struct URLData {
    let url: String
    let displayText: String?
    let isValid: Bool
    let confidence: Float
}

struct DateData {
    let raw: String
    let parsed: Date?
    let format: String?
    let confidence: Float
}

// MARK: - Business Card Data
struct BusinessCardData {
    let name: PersonName?
    let title: String?
    let company: String?
    let contactInfo: ContactInfo
    let socialMedia: [SocialMediaInfo]
    let confidence: Float
    
    var isComplete: Bool {
        name != nil && (title != nil || company != nil) && 
        (!contactInfo.phoneNumbers.isEmpty || !contactInfo.emailAddresses.isEmpty)
    }
}

struct PersonName {
    let fullName: String
    let firstName: String?
    let lastName: String?
    let prefix: String? // Dr., Mr., etc.
    let suffix: String? // Jr., PhD, etc.
}

struct SocialMediaInfo {
    let platform: SocialPlatform
    let handle: String
    let url: String?
    
    enum SocialPlatform {
        case linkedin
        case twitter
        case facebook
        case instagram
        case other(String)
    }
}

// MARK: - Document Layout
struct DocumentLayout {
    let title: String?
    let sections: [DocumentSection]
    let bulletPoints: [BulletPoint]
    let numberedLists: [NumberedList]
    let tables: [SimpleTable]
    let isStructured: Bool
    let confidence: Float
}

struct DocumentSection {
    let title: String
    let content: String
    let level: Int // 1 = main heading, 2 = subheading, etc.
    let boundingBox: CGRect
}

struct BulletPoint {
    let text: String
    let level: Int
    let boundingBox: CGRect
}

struct NumberedList {
    let items: [NumberedItem]
    let startNumber: Int
}

struct NumberedItem {
    let number: Int
    let text: String
    let boundingBox: CGRect
}

struct SimpleTable {
    let rows: [[String]]
    let hasHeader: Bool
    let boundingBox: CGRect
}

// MARK: - Extracted Entities
struct ExtractedEntities {
    let people: [String]
    let places: [String]
    let organizations: [String]
    let dates: [DateData]
    let currencies: [CurrencyData]
    let products: [String]
    let confidence: Float
}

struct CurrencyData {
    let raw: String
    let amount: Decimal?
    let currency: String
    let confidence: Float
}

// MARK: - Document Type Classification
enum DocumentType {
    case businessCard
    case notice
    case form
    case receipt
    case letter
    case flyer
    case menu
    case generic
    
    var processingHints: [String] {
        switch self {
        case .businessCard:
            return ["name", "title", "company", "contact", "email", "phone"]
        case .notice:
            return ["announcement", "date", "contact", "location", "time"]
        case .form:
            return ["field", "label", "value", "checkbox", "signature"]
        case .receipt:
            return ["item", "price", "total", "date", "tax", "payment"]
        case .letter:
            return ["date", "address", "signature", "subject", "dear"]
        case .flyer:
            return ["event", "date", "location", "contact", "price"]
        case .menu:
            return ["item", "price", "description", "category"]
        case .generic:
            return []
        }
    }
    
    var expectedElements: [String] {
        switch self {
        case .businessCard:
            return ["name", "contact_info"]
        case .notice:
            return ["title", "content", "contact"]
        case .form:
            return ["fields", "labels"]
        case .receipt:
            return ["items", "total"]
        case .letter:
            return ["header", "body", "signature"]
        case .flyer:
            return ["title", "details", "contact"]
        case .menu:
            return ["categories", "items", "prices"]
        case .generic:
            return ["content"]
        }
    }
}

// MARK: - Processing Options
struct StructuredExtractionOptions {
    let extractContactInfo: Bool
    let detectBusinessCard: Bool
    let analyzeLayout: Bool
    let extractEntities: Bool
    let classifyDocumentType: Bool
    
    static let businessCard = StructuredExtractionOptions(
        extractContactInfo: true,
        detectBusinessCard: true,
        analyzeLayout: false,
        extractEntities: false,
        classifyDocumentType: true
    )
    
    static let notice = StructuredExtractionOptions(
        extractContactInfo: true,
        detectBusinessCard: false,
        analyzeLayout: true,
        extractEntities: true,
        classifyDocumentType: true
    )
    
    static let comprehensive = StructuredExtractionOptions(
        extractContactInfo: true,
        detectBusinessCard: true,
        analyzeLayout: true,
        extractEntities: true,
        classifyDocumentType: true
    )
    
    static let minimal = StructuredExtractionOptions(
        extractContactInfo: true,
        detectBusinessCard: false,
        analyzeLayout: false,
        extractEntities: false,
        classifyDocumentType: true
    )
}
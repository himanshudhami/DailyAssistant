//
//  BusinessCardTester.swift
//  AINoteTakingApp
//
//  Test and debug business card processing
//
//  Created by AI Assistant on 2025-08-24.
//

import Foundation
import UIKit

class BusinessCardTester {
    
    private let ocrService = OCRService()
    private let businessCardProcessor = BusinessCardProcessor()
    
    func testBusinessCardProcessing(with image: UIImage) async {
        print("🔍 Testing Business Card Processing...")
        
        // Step 1: Perform OCR with business card optimization
        let ocrResult = await ocrService.performBusinessCardOCR(on: image)
        
        print("📄 Raw OCR Text:")
        print("================")
        print(ocrResult.rawText)
        print("================")
        print("OCR Confidence: \(ocrResult.confidence)")
        
        // Step 2: Test business card detection
        let businessCardData = businessCardProcessor.detectBusinessCard(from: ocrResult.rawText, image: image)
        
        if let businessCard = businessCardData {
            print("✅ Business Card Detected!")
            print("Name: \(businessCard.name?.fullName ?? "Not found")")
            print("Title: \(businessCard.title ?? "Not found")")
            print("Company: \(businessCard.company ?? "Not found")")
            print("Phone Numbers: \(businessCard.contactInfo.phoneNumbers.map { $0.formatted })")
            print("Emails: \(businessCard.contactInfo.emailAddresses.map { $0.address })")
            print("Confidence: \(businessCard.confidence)")
            
            // Generate CRM data
            let crmData = businessCardProcessor.generateCRMData(from: businessCard)
            print("📊 CRM Data Generated:")
            for (key, value) in crmData {
                print("  \(key): \(value)")
            }
            
        } else {
            print("❌ Business Card Not Detected")
            print("Running diagnostics...")
            
            // Diagnostic tests
            runDiagnostics(with: ocrResult.rawText)
        }
        
        // Test structured data processing
        if let structuredData = ocrResult.structuredData {
            print("📋 Structured Data:")
            print("Document Type: \(structuredData.documentType)")
            print("Processing Confidence: \(structuredData.processingConfidence)")
            
            if let contactInfo = structuredData.contactInfo {
                print("Contact Info Found:")
                print("  Phones: \(contactInfo.phoneNumbers.count)")
                print("  Emails: \(contactInfo.emailAddresses.count)")
                print("  Addresses: \(contactInfo.addresses.count)")
            }
        }
    }
    
    private func runDiagnostics(with text: String) {
        print("🔧 Running Diagnostics...")
        
        // Test 1: Check if text contains obvious name patterns
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        print("Lines found: \(lines.count)")
        
        for (index, line) in lines.enumerated() {
            if !line.isEmpty {
                print("Line \(index + 1): '\(line)'")
                
                // Check for name patterns
                if line.range(of: #"[A-Z][a-z]+ [A-Z][a-z]+"#, options: .regularExpression) != nil {
                    print("  ↳ Potential name pattern detected")
                }
                
                // Check for all caps (common on business cards)
                if line.allSatisfy({ $0.isUppercase || $0.isWhitespace }) && line.count > 3 {
                    print("  ↳ All caps text (might be name): '\(line)'")
                }
            }
        }
        
        // Test 2: Check contact information detection
        let contactExtractor = ContactInfoExtractor()
        let contactInfo = contactExtractor.extractContactInfo(from: text)
        
        print("Contact Detection Results:")
        print("  Phone numbers: \(contactInfo.phoneNumbers.count)")
        print("  Email addresses: \(contactInfo.emailAddresses.count)")
        
        // Test 3: Check business card scoring
        let processor = BusinessCardProcessor()
        let isLikelyBusinessCard = processor.isLikelyBusinessCard(text)
        print("Business Card Likelihood: \(isLikelyBusinessCard)")
    }
}

// Make isLikelyBusinessCard public for testing
extension BusinessCardProcessor {
    func isLikelyBusinessCard(_ text: String) -> Bool {
        // Copy the private method logic here for testing
        let lowercaseText = text.lowercased()
        var score = 0
        
        let contactExtractor = ContactInfoExtractor()
        let contactInfo = contactExtractor.extractContactInfo(from: text)
        
        if contactInfo.phoneNumbers.isEmpty && contactInfo.emailAddresses.isEmpty {
            return false
        }
        
        if !contactInfo.phoneNumbers.isEmpty { score += 2 }
        if !contactInfo.emailAddresses.isEmpty { score += 2 }
        if !contactInfo.addresses.isEmpty { score += 1 }
        if !contactInfo.urls.isEmpty { score += 1 }
        
        // Check for business titles
        let titles = ["ceo", "president", "director", "manager", "vp", "vice president",
                     "senior", "lead", "head", "chief", "founder", "partner"]
        for title in titles {
            if lowercaseText.contains(title) {
                score += 1
                break
            }
        }
        
        // Check for company indicators
        let indicators = ["inc", "llc", "corp", "corporation", "company", "co.", "ltd",
                         "limited", "group", "associates", "partners", "solutions"]
        for indicator in indicators {
            if lowercaseText.contains(indicator) {
                score += 1
                break
            }
        }
        
        if extractPersonName(from: text) != nil {
            score += 2
        }
        
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        if wordCount >= 10 && wordCount <= 100 {
            score += 1
        }
        
        print("Business Card Score: \(score) (need ≥5)")
        return score >= 5
    }
}
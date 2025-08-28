//
//  BusinessCardProcessor.swift
//  AINoteTakingApp
//
//  Specialized processor for business card detection and data extraction
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import NaturalLanguage
import Vision
import UIKit

class BusinessCardProcessor {
    
    // MARK: - Private Properties
    private let contactExtractor: ContactInfoExtractor
    private let nlTagger: NLTagger
    
    // MARK: - Business Card Patterns
    private struct BusinessCardPatterns {
        static let titles = [
            "ceo", "president", "director", "manager", "vp", "vice president",
            "senior", "lead", "head", "chief", "founder", "partner",
            "consultant", "specialist", "analyst", "engineer", "developer",
            "designer", "architect", "coordinator", "supervisor", "executive"
        ]
        
        static let companyIndicators = [
            "inc", "llc", "corp", "corporation", "company", "co.", "ltd",
            "limited", "group", "associates", "partners", "solutions",
            "services", "systems", "technologies", "tech", "consulting"
        ]
        
        static let socialPlatforms = [
            "linkedin.com": SocialMediaInfo.SocialPlatform.linkedin,
            "twitter.com": SocialMediaInfo.SocialPlatform.twitter,
            "facebook.com": SocialMediaInfo.SocialPlatform.facebook,
            "instagram.com": SocialMediaInfo.SocialPlatform.instagram
        ]
    }
    
    // MARK: - Initialization
    init() {
        self.contactExtractor = ContactInfoExtractor()
        self.nlTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    }
    
    // MARK: - Public Methods
    func detectBusinessCard(from text: String, image: UIImage? = nil) -> BusinessCardData? {
        print("🔍 BusinessCardProcessor: Analyzing text: '\(text.prefix(100))...'")
        
        // First, check if this looks like a business card
        guard isLikelyBusinessCard(text) else { 
            print("❌ BusinessCardProcessor: Not a business card")
            return nil 
        }
        
        print("✅ BusinessCardProcessor: Business card detected")
        
        // Extract all information in ONE pass (avoid redundant extraction)
        let contactInfo = contactExtractor.extractContactInfo(from: text)
        let name = extractPersonName(from: text)
        let title = extractTitle(from: text, personName: name?.fullName)
        let company = extractCompany(from: text, personName: name?.fullName, title: title)
        let socialMedia = extractSocialMedia(from: text)
        
        // Single log for all extracted data
        print("📇 Extracted: name=\(name?.fullName ?? "nil"), title=\(title ?? "nil"), company=\(company ?? "nil"), phones=\(contactInfo.phoneNumbers.count), emails=\(contactInfo.emailAddresses.count)")
        
        // Calculate overall confidence
        let confidence = calculateBusinessCardConfidence(
            name: name,
            title: title,
            company: company,
            contactInfo: contactInfo
        )
        
        return BusinessCardData(
            name: name,
            title: title,
            company: company,
            contactInfo: contactInfo,
            socialMedia: socialMedia,
            confidence: confidence
        )
    }
    
    func generateCRMData(from businessCard: BusinessCardData) -> [String: Any] {
        var crmData: [String: Any] = [:]
        
        // Basic contact information
        if let name = businessCard.name {
            crmData["first_name"] = name.firstName ?? ""
            crmData["last_name"] = name.lastName ?? ""
            crmData["full_name"] = name.fullName
            crmData["prefix"] = name.prefix
            crmData["suffix"] = name.suffix
        }
        
        crmData["title"] = businessCard.title ?? ""
        crmData["company"] = businessCard.company ?? ""
        
        // Contact details
        if !businessCard.contactInfo.phoneNumbers.isEmpty {
            crmData["phone"] = businessCard.contactInfo.phoneNumbers.first?.formatted ?? ""
            crmData["phone_numbers"] = businessCard.contactInfo.phoneNumbers.map { phone in
                [
                    "number": phone.formatted,
                    "type": phone.type.rawValue,
                    "confidence": phone.confidence
                ]
            }
        }
        
        if !businessCard.contactInfo.emailAddresses.isEmpty {
            crmData["email"] = businessCard.contactInfo.emailAddresses.first?.address ?? ""
            crmData["emails"] = businessCard.contactInfo.emailAddresses.map { email in
                [
                    "address": email.address,
                    "domain": email.domain,
                    "is_valid": email.isValid,
                    "confidence": email.confidence
                ]
            }
        }
        
        if !businessCard.contactInfo.addresses.isEmpty {
            let address = businessCard.contactInfo.addresses.first!
            crmData["address"] = address.raw
            crmData["street"] = address.street
            crmData["city"] = address.city
            crmData["state"] = address.state
            crmData["zip_code"] = address.zipCode
            crmData["country"] = address.country
        }
        
        // Social media
        if !businessCard.socialMedia.isEmpty {
            crmData["social_media"] = businessCard.socialMedia.map { social in
                [
                    "platform": social.platform,
                    "handle": social.handle,
                    "url": social.url
                ]
            }
            
            // Extract specific platforms for easy CRM integration
            for social in businessCard.socialMedia {
                switch social.platform {
                case .linkedin:
                    crmData["linkedin"] = social.url ?? social.handle
                case .twitter:
                    crmData["twitter"] = social.handle
                case .facebook:
                    crmData["facebook"] = social.url ?? social.handle
                default:
                    break
                }
            }
        }
        
        // Metadata
        crmData["source"] = "business_card_scan"
        crmData["confidence"] = businessCard.confidence
        crmData["created_date"] = ISO8601DateFormatter().string(from: Date())
        
        return crmData
    }
    
    // MARK: - Private Detection Methods
    private func isLikelyBusinessCard(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        var score = 0
        var requiredElements = 0
        
        // Check for typical business card elements
        let contactInfo = contactExtractor.extractContactInfo(from: text)
        
        // STRICT: Must have BOTH email AND phone (or multiple contact methods)
        let hasEmail = !contactInfo.emailAddresses.isEmpty
        let hasPhone = !contactInfo.phoneNumbers.isEmpty
        let hasAddress = !contactInfo.addresses.isEmpty
        
        // Require at least 2 contact methods
        let contactMethodCount = (hasEmail ? 1 : 0) + (hasPhone ? 1 : 0) + (hasAddress ? 1 : 0)
        if contactMethodCount < 2 {
            return false  // Not enough contact info for a business card
        }
        
        // Score based on elements present
        if hasPhone { 
            score += 2 
            requiredElements += 1
        }
        if hasEmail { 
            score += 2 
            requiredElements += 1
        }
        if hasAddress { score += 1 }
        if !contactInfo.urls.isEmpty { score += 1 }
        
        // Check for business titles (more strict)
        var hasTitle = false
        for title in BusinessCardPatterns.titles {
            if lowercaseText.contains(title) {
                // Make sure it's not part of another word
                let pattern = "\\b\(title)\\b"
                if lowercaseText.range(of: pattern, options: .regularExpression) != nil {
                    score += 2
                    hasTitle = true
                    break
                }
            }
        }
        
        // Check for company indicators (more strict)
        var hasCompany = false
        for indicator in BusinessCardPatterns.companyIndicators {
            if lowercaseText.contains(indicator) {
                let pattern = "\\b\(indicator)\\b"
                if lowercaseText.range(of: pattern, options: .regularExpression) != nil {
                    score += 2
                    hasCompany = true
                    break
                }
            }
        }
        
        // Check for person names (REQUIRED for business card)
        let personName = extractPersonName(from: text)
        if personName != nil {
            score += 3
            requiredElements += 1
        } else {
            // No name = not a business card
            return false
        }
        
        // Business cards typically have concise text (stricter range)
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        if wordCount >= 15 && wordCount <= 80 {
            score += 1
        } else if wordCount > 100 {
            // Too much text for a business card
            return false
        }
        
        // Check text structure - business cards have short lines
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        if lines.count >= 3 && lines.count <= 15 {
            score += 1
        }
        
        // STRICT REQUIREMENTS:
        // 1. Must have a person's name
        // 2. Must have at least 2 contact methods
        // 3. Must have either title OR company
        // 4. Score must be >= 10 (raised from 5)
        
        let hasBusinessContext = hasTitle || hasCompany
        
        print("🎯 Business card scoring:")
        print("   - Name found: \(personName != nil)")
        print("   - Contact methods: \(contactMethodCount)")
        print("   - Has title/company: \(hasBusinessContext)")
        print("   - Word count: \(wordCount)")
        print("   - Total score: \(score) (need ≥10)")
        
        return requiredElements >= 3 && hasBusinessContext && score >= 10
    }
    
    private func extractPersonName(from text: String) -> PersonName? {
        let lines = text.components(separatedBy: .newlines)
        
        // First try NL tagger for names
        nlTagger.string = text
        
        var personNames: [String] = []
        let range = text.startIndex..<text.endIndex
        
        nlTagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag == .personalName {
                let name = String(text[tokenRange])
                personNames.append(name)
            }
            return true
        }
        
        // Join consecutive person name tokens
        if !personNames.isEmpty {
            let fullName = personNames.joined(separator: " ")
            return parsePersonName(fullName)
        }
        
        // Enhanced fallback: look for name patterns with better cleaning
        let cleanedText = cleanAndNormalizeText(text)
        let cleanedLines = cleanedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Try multiple strategies for finding names (removed verbose logging)
        
        // Strategy 0: Business cards often have the name prominently at the END
        for line in cleanedLines.suffix(3).reversed() { // Check last 3 lines, start from end
            if let name = parsePersonNameFromLine(line) {
                return name
            }
        }
        
        // Strategy 1: Look for typical name patterns at the beginning
        for line in cleanedLines.prefix(5) { // Check first 5 lines
            if let name = parsePersonNameFromLine(line) {
                return name
            }
        }
        
        // Strategy 2: Look for capitalized words that could be names
        for line in cleanedLines {
            if let name = findCapitalizedNameInLine(line) {
                return name
            }
        }
        
        // Strategy 3: Use regex patterns for common name formats
        if let name = extractNameWithRegex(from: cleanedText) {
            return name
        }
        return nil
    }
    
    private func parsePersonName(_ fullName: String) -> PersonName {
        let components = fullName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        var prefix: String?
        var firstName: String?
        var lastName: String?
        var suffix: String?
        
        let prefixes = ["dr", "dr.", "mr", "mr.", "mrs", "mrs.", "ms", "ms."]
        let suffixes = ["jr", "jr.", "sr", "sr.", "ii", "iii", "phd", "md", "esq"]
        
        var workingComponents = components
        
        // Extract prefix
        if let first = workingComponents.first,
           prefixes.contains(first.lowercased()) {
            prefix = first
            workingComponents.removeFirst()
        }
        
        // Extract suffix
        if let last = workingComponents.last,
           suffixes.contains(last.lowercased()) {
            suffix = last
            workingComponents.removeLast()
        }
        
        // Assign first and last names
        if workingComponents.count >= 2 {
            firstName = workingComponents.first
            lastName = workingComponents.dropFirst().joined(separator: " ")
        } else if workingComponents.count == 1 {
            firstName = workingComponents.first
        }
        
        return PersonName(
            fullName: fullName,
            firstName: firstName,
            lastName: lastName,
            prefix: prefix,
            suffix: suffix
        )
    }
    
    private func parsePersonNameFromLine(_ line: String) -> PersonName? {
        // Skip lines that are obviously not names
        let lowercaseLine = line.lowercased()
        
        if lowercaseLine.contains("@") || // email
           lowercaseLine.contains("www") || // website
           lowercaseLine.contains(".com") || // domain
           lowercaseLine.contains("phone") || // phone label
           BusinessCardPatterns.companyIndicators.contains(where: { lowercaseLine.contains($0) }) {
            return nil
        }
        
        // Look for name-like patterns
        let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        if words.count >= 2 && words.count <= 4 {
            // Check if words look like names (capitalized, alphabetic)
            let nameWords = words.filter { word in
                let firstChar = word.first
                return firstChar?.isLetter == true && firstChar?.isUppercase == true
            }
            
            if nameWords.count >= 2 {
                return parsePersonName(nameWords.joined(separator: " "))
            }
        }
        
        return nil
    }
    
    private func extractTitle(from text: String, personName: String?) -> String? {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Look for title near the person's name
        for (index, line) in lines.enumerated() {
            let lowercaseLine = line.lowercased()
            
            // Check if this line contains the person's name
            let containsName = personName?.components(separatedBy: " ").allSatisfy { namePart in
                lowercaseLine.contains(namePart.lowercased())
            } ?? false
            
            if containsName {
                // Check the next few lines for a title
                for nextIndex in (index + 1)..<min(lines.count, index + 3) {
                    let candidateLine = lines[nextIndex]
                    if let title = extractTitleFromLine(candidateLine) {
                        return title
                    }
                }
            } else {
                // Check if this line itself is a title
                if let title = extractTitleFromLine(line) {
                    return title
                }
            }
        }
        
        return nil
    }
    
    private func extractTitleFromLine(_ line: String) -> String? {
        let lowercaseLine = line.lowercased()
        
        // Skip lines that are obviously not titles
        if lowercaseLine.contains("@") || lowercaseLine.contains("www") ||
           lowercaseLine.contains(".com") || lowercaseLine.contains("phone") {
            return nil
        }
        
        // Check for title keywords
        for titleKeyword in BusinessCardPatterns.titles {
            if lowercaseLine.contains(titleKeyword) {
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Check for common title patterns
        if lowercaseLine.range(of: #"\b(senior|lead|head|chief|principal)\s+\w+"#, options: .regularExpression) != nil ||
           lowercaseLine.range(of: #"\w+\s+(manager|director|officer|specialist)"#, options: .regularExpression) != nil {
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func extractCompany(from text: String, personName: String?, title: String?) -> String? {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            
            // Skip lines that are obviously not company names
            if lowercaseLine.contains("@") || lowercaseLine.contains("phone") ||
               lowercaseLine.contains("mobile") || lowercaseLine.contains("cell") {
                continue
            }
            
            // Skip if this is the person's name or title
            if let name = personName,
               name.lowercased().components(separatedBy: " ").allSatisfy({ lowercaseLine.contains($0) }) {
                continue
            }
            
            if let jobTitle = title, lowercaseLine == jobTitle.lowercased() {
                continue
            }
            
            // Check for company indicators
            for indicator in BusinessCardPatterns.companyIndicators {
                if lowercaseLine.contains(indicator) {
                    return line.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Fallback: look for the longest line that's not obviously contact info
        let candidateLines = lines.filter { line in
            let lowercaseLine = line.lowercased()
            return !lowercaseLine.contains("@") &&
                   !lowercaseLine.contains("phone") &&
                   !lowercaseLine.contains("www") &&
                   line.count > 3
        }
        
        return candidateLines.max(by: { $0.count < $1.count })
    }
    
    private func extractSocialMedia(from text: String) -> [SocialMediaInfo] {
        var socialMedia: [SocialMediaInfo] = []
        
        for (domain, platform) in BusinessCardPatterns.socialPlatforms {
            if text.lowercased().contains(domain) {
                // Extract the social media information
                let pattern = #"\b\w*"# + NSRegularExpression.escapedPattern(for: domain) + #"/?\S*"#
                
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))
                    
                    for match in matches {
                        let matchedText = (text as NSString).substring(with: match.range)
                        let handle = extractHandle(from: matchedText, platform: platform)
                        let url = matchedText.hasPrefix("http") ? matchedText : "https://\(matchedText)"
                        
                        let socialInfo = SocialMediaInfo(
                            platform: platform,
                            handle: handle,
                            url: url
                        )
                        
                        socialMedia.append(socialInfo)
                    }
                }
            }
        }
        
        return socialMedia
    }
    
    private func extractHandle(from url: String, platform: SocialMediaInfo.SocialPlatform) -> String {
        // Extract username/handle from social media URL
        let components = url.components(separatedBy: "/")
        
        switch platform {
        case .linkedin:
            if let inIndex = components.firstIndex(of: "in"), inIndex + 1 < components.count {
                return components[inIndex + 1]
            }
        case .twitter:
            return components.last?.replacingOccurrences(of: "@", with: "") ?? ""
        case .facebook, .instagram:
            return components.last ?? ""
        case .other:
            return components.last ?? ""
        }
        
        return components.last ?? ""
    }
    
    private func calculateBusinessCardConfidence(
        name: PersonName?,
        title: String?,
        company: String?,
        contactInfo: ContactInfo
    ) -> Float {
        var confidence: Float = 0.0
        
        // Name presence and quality
        if let personName = name {
            confidence += 0.3
            if personName.firstName != nil && personName.lastName != nil {
                confidence += 0.1
            }
        }
        
        // Title presence
        if title != nil {
            confidence += 0.2
        }
        
        // Company presence
        if company != nil {
            confidence += 0.2
        }
        
        // Contact information quality
        if !contactInfo.phoneNumbers.isEmpty {
            confidence += 0.1
            confidence += Float(contactInfo.phoneNumbers.count) * 0.05 // Bonus for multiple phones
        }
        
        if !contactInfo.emailAddresses.isEmpty {
            confidence += 0.1
            confidence += Float(contactInfo.emailAddresses.count) * 0.05 // Bonus for multiple emails
        }
        
        if !contactInfo.addresses.isEmpty {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Enhanced Name Detection Helpers
    private func cleanAndNormalizeText(_ text: String) -> String {
        // Normalize line breaks but PRESERVE line structure for business cards
        let normalized = text
            .replacingOccurrences(of: "\\r\\n|\\r", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\\n+", with: "\n", options: .regularExpression)
            // Only clean excessive spaces WITHIN lines, not across lines
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func findCapitalizedNameInLine(_ line: String) -> PersonName? {
        let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Skip lines with obvious non-name content
        let lowercaseLine = line.lowercased()
        if lowercaseLine.contains("@") || lowercaseLine.contains(".com") || 
           lowercaseLine.contains("phone") || lowercaseLine.contains("tel") ||
           lowercaseLine.contains("www") || lowercaseLine.contains("http") {
            return nil
        }
        
        // Look for 2-4 capitalized words that could be a name
        if words.count >= 2 && words.count <= 4 {
            let capitalizedWords = words.filter { word in
                // Check if word starts with capital and contains mostly letters
                guard let firstChar = word.first else { return false }
                let hasGoodFormat = firstChar.isUppercase && 
                                  word.allSatisfy { $0.isLetter || $0 == "." || $0 == "'" }
                let isReasonableLength = word.count >= 2 && word.count <= 20
                
                return hasGoodFormat && isReasonableLength
            }
            
            // If most words are capitalized, likely a name
            if capitalizedWords.count >= 2 && capitalizedWords.count >= words.count - 1 {
                let fullName = capitalizedWords.joined(separator: " ")
                return parsePersonName(fullName)
            }
        }
        
        return nil
    }
    
    private func extractNameWithRegex(from text: String) -> PersonName? {
        // Common patterns for names on business cards
        let patterns = [
            #"^([A-Z][a-z]+ [A-Z][a-z]+)$"#,  // FirstName LastName
            #"^([A-Z][a-z]+ [A-Z]\. [A-Z][a-z]+)$"#,  // FirstName M. LastName
            #"^([A-Z][a-z]+, [A-Z][a-z]+)$"#,  // LastName, FirstName
            #"([A-Z][A-Z]+ [A-Z][A-Z]+)"#,     // FIRSTNAME LASTNAME (all caps)
            #"([A-Z][a-z]+ [A-Z][a-z]+ [A-Z][a-z]+)"# // FirstName MiddleName LastName
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    let matchedText = (text as NSString).substring(with: match.range)
                    
                    // Validate it's not obviously something else
                    if !isObviouslyNotName(matchedText) {
                        return parsePersonName(matchedText)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func isObviouslyNotName(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Skip if it contains obvious non-name indicators
        let nonNameIndicators = ["phone", "tel", "email", "www", ".com", "@", 
                               "solutions", "service", "company", "inc", "llc"]
        
        return nonNameIndicators.contains { lowercased.contains($0) }
    }
}

// MARK: - PhoneNumber.PhoneType Extension
extension PhoneNumber.PhoneType {
    var rawValue: String {
        switch self {
        case .mobile: return "mobile"
        case .landline: return "landline"
        case .toll_free: return "toll_free"
        case .international: return "international"
        case .unknown: return "unknown"
        }
    }
}
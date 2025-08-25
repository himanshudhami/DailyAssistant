//
//  ContactInfoExtractor.swift
//  AINoteTakingApp
//
//  Extracts structured contact information from OCR text using iOS NSDataDetector
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import Contacts
import UIKit

class ContactInfoExtractor {
    
    // MARK: - Private Properties
    private let dataDetector: NSDataDetector
    private let phoneNumberRegex: NSRegularExpression
    private let emailRegex: NSRegularExpression
    
    // MARK: - Initialization
    init() {
        // Initialize NSDataDetector with common types
        self.dataDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.address.rawValue | NSTextCheckingResult.CheckingType.date.rawValue)
        
        // Enhanced phone number regex
        self.phoneNumberRegex = try! NSRegularExpression(
            pattern: #"(\+?1?[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})(?:\s?(?:ext|x|extension)[-.\s]?(\d+))?"#,
            options: [.caseInsensitive]
        )
        
        // Enhanced email regex
        self.emailRegex = try! NSRegularExpression(
            pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            options: [.caseInsensitive]
        )
    }
    
    // MARK: - Public Methods
    func extractContactInfo(from text: String) -> ContactInfo {
        let phoneNumbers = extractPhoneNumbers(from: text)
        let emailAddresses = extractEmailAddresses(from: text)
        let addresses = extractAddresses(from: text)
        let urls = extractURLs(from: text)
        let dates = extractDates(from: text)
        
        return ContactInfo(
            phoneNumbers: phoneNumbers,
            emailAddresses: emailAddresses,
            addresses: addresses,
            urls: urls,
            dates: dates
        )
    }
    
    // MARK: - Phone Number Extraction
    private func extractPhoneNumbers(from text: String) -> [PhoneNumber] {
        var phoneNumbers: [PhoneNumber] = []
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        
        print("📱 ContactInfoExtractor: Searching for phone numbers in: '\(text)'")
        
        // Use NSDataDetector for phone numbers
        let matches = dataDetector.matches(in: text, options: [], range: range)
        print("📱 NSDataDetector found \(matches.count) matches")
        
        for match in matches {
            if match.resultType == .phoneNumber,
               let phoneNumber = match.phoneNumber {
                print("📱 NSDataDetector phone: \(phoneNumber)")
                let phone = processPhoneNumber(phoneNumber, in: text, range: match.range)
                phoneNumbers.append(phone)
            }
        }
        
        // Also try custom regex for additional patterns
        let customMatches = phoneNumberRegex.matches(in: text, options: [], range: range)
        print("📱 Custom regex found \(customMatches.count) matches")
        for match in customMatches {
            let matchedText = nsText.substring(with: match.range)
            print("📱 Custom regex phone: \(matchedText)")
            if !phoneNumbers.contains(where: { $0.raw.contains(matchedText) }) {
                let phone = processPhoneNumber(matchedText, in: text, range: match.range)
                phoneNumbers.append(phone)
            }
        }
        
        print("📱 ContactInfoExtractor: Final phone numbers found: \(phoneNumbers.count)")
        for phone in phoneNumbers {
            print("📱 - \(phone.formatted)")
        }
        
        return phoneNumbers
    }
    
    private func processPhoneNumber(_ phoneNumber: String, in text: String, range: NSRange) -> PhoneNumber {
        let cleaned = phoneNumber.replacingOccurrences(of: #"[^\d+]"#, with: "", options: .regularExpression)
        let formatted = formatPhoneNumber(cleaned)
        let type = classifyPhoneNumber(cleaned)
        let confidence = calculatePhoneConfidence(phoneNumber, in: text)
        
        return PhoneNumber(
            raw: phoneNumber,
            formatted: formatted,
            type: type,
            confidence: confidence
        )
    }
    
    private func formatPhoneNumber(_ cleaned: String) -> String {
        // US phone number formatting
        if cleaned.hasPrefix("+1") {
            let digits = String(cleaned.dropFirst(2))
            if digits.count == 10 {
                return "+1 (\(String(digits.prefix(3)))) \(String(digits.dropFirst(3).prefix(3)))-\(String(digits.suffix(4)))"
            }
        } else if cleaned.hasPrefix("1") && cleaned.count == 11 {
            let digits = String(cleaned.dropFirst())
            return "+1 (\(String(digits.prefix(3)))) \(String(digits.dropFirst(3).prefix(3)))-\(String(digits.suffix(4)))"
        } else if cleaned.count == 10 {
            return "(\(String(cleaned.prefix(3)))) \(String(cleaned.dropFirst(3).prefix(3)))-\(String(cleaned.suffix(4)))"
        }
        
        return cleaned
    }
    
    private func classifyPhoneNumber(_ cleaned: String) -> PhoneNumber.PhoneType {
        if cleaned.hasPrefix("+") {
            return .international
        } else if cleaned.hasPrefix("1800") || cleaned.hasPrefix("1888") || cleaned.hasPrefix("1877") {
            return .toll_free
        } else if cleaned.count == 10 || (cleaned.count == 11 && cleaned.hasPrefix("1")) {
            // Could be mobile or landline - would need more context
            return .unknown
        }
        return .unknown
    }
    
    private func calculatePhoneConfidence(_ phoneNumber: String, in text: String) -> Float {
        var confidence: Float = 0.7 // Base confidence
        
        // Check for context clues
        let context = getContext(for: phoneNumber, in: text, radius: 20)
        let lowercaseContext = context.lowercased()
        
        if lowercaseContext.contains("phone") || lowercaseContext.contains("tel") || 
           lowercaseContext.contains("mobile") || lowercaseContext.contains("cell") {
            confidence += 0.2
        }
        
        // Check format quality
        if phoneNumber.contains("(") && phoneNumber.contains(")") && phoneNumber.contains("-") {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Email Extraction
    private func extractEmailAddresses(from text: String) -> [EmailAddress] {
        var emailAddresses: [EmailAddress] = []
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        
        print("📧 ContactInfoExtractor: Searching for emails in: '\(text)'")
        
        // Use NSDataDetector
        let matches = dataDetector.matches(in: text, options: [], range: range)
        print("📧 NSDataDetector found \(matches.count) matches")
        
        for match in matches {
            if match.resultType == .link,
               let url = match.url,
               url.scheme == "mailto" {
                print("📧 NSDataDetector email: \(url.absoluteString)")
                let email = processEmailAddress(url.absoluteString.replacingOccurrences(of: "mailto:", with: ""), in: text)
                emailAddresses.append(email)
            }
        }
        
        // Also use custom regex
        let customMatches = emailRegex.matches(in: text, options: [], range: range)
        print("📧 Custom regex found \(customMatches.count) matches")
        for match in customMatches {
            let matchedText = nsText.substring(with: match.range)
            print("📧 Custom regex email: \(matchedText)")
            if !emailAddresses.contains(where: { $0.address == matchedText }) {
                let email = processEmailAddress(matchedText, in: text)
                emailAddresses.append(email)
            }
        }
        
        print("📧 ContactInfoExtractor: Final emails found: \(emailAddresses.count)")
        for email in emailAddresses {
            print("📧 - \(email.address)")
        }
        
        return emailAddresses
    }
    
    private func processEmailAddress(_ email: String, in text: String) -> EmailAddress {
        let domain = String(email.split(separator: "@").last ?? "")
        let isValid = isValidEmail(email)
        let confidence = calculateEmailConfidence(email, in: text)
        
        return EmailAddress(
            address: email.lowercased(),
            domain: domain,
            isValid: isValid,
            confidence: confidence
        )
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return false }
        
        let domain = String(parts[1])
        return domain.contains(".") && domain.count >= 4
    }
    
    private func calculateEmailConfidence(_ email: String, in text: String) -> Float {
        var confidence: Float = 0.8 // Base confidence for email format
        
        let context = getContext(for: email, in: text, radius: 20)
        let lowercaseContext = context.lowercased()
        
        if lowercaseContext.contains("email") || lowercaseContext.contains("e-mail") ||
           lowercaseContext.contains("contact") {
            confidence += 0.1
        }
        
        // Check domain reputation (common domains get higher confidence)
        let domain = String(email.split(separator: "@").last ?? "")
        let commonDomains = ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "icloud.com"]
        if commonDomains.contains(domain.lowercased()) {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Address Extraction
    private func extractAddresses(from text: String) -> [Address] {
        var addresses: [Address] = []
        let range = NSRange(location: 0, length: text.count)
        
        let matches = dataDetector.matches(in: text, options: [], range: range)
        
        for match in matches {
            if match.resultType == .address {
                let nsText = text as NSString
                let addressText = nsText.substring(with: match.range)
                let address = processAddress(addressText, in: text)
                addresses.append(address)
            }
        }
        
        return addresses
    }
    
    private func processAddress(_ addressText: String, in text: String) -> Address {
        let components = parseAddressComponents(addressText)
        let confidence = calculateAddressConfidence(addressText, in: text)
        
        return Address(
            raw: addressText,
            street: components.street,
            city: components.city,
            state: components.state,
            zipCode: components.zipCode,
            country: components.country,
            confidence: confidence
        )
    }
    
    private func parseAddressComponents(_ address: String) -> (street: String?, city: String?, state: String?, zipCode: String?, country: String?) {
        // Simple address parsing - could be enhanced with more sophisticated logic
        let lines = address.components(separatedBy: .newlines)
        
        var street: String?
        var city: String?
        var state: String?
        var zipCode: String?
        var country: String?
        
        if lines.count >= 2 {
            street = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try to parse last line for city, state, zip
            if let lastLine = lines.last {
                let zipPattern = #"\b\d{5}(-\d{4})?\b"#
                let zipRegex = try? NSRegularExpression(pattern: zipPattern)
                let zipRange = NSRange(location: 0, length: lastLine.count)
                
                if let zipMatch = zipRegex?.firstMatch(in: lastLine, range: zipRange) {
                    let nsLastLine = lastLine as NSString
                    zipCode = nsLastLine.substring(with: zipMatch.range)
                    
                    // Remove zip from line to get city/state
                    let remaining = lastLine.replacingOccurrences(of: zipCode!, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let parts = remaining.components(separatedBy: ",")
                    
                    if parts.count >= 2 {
                        city = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        state = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        
        return (street: street, city: city, state: state, zipCode: zipCode, country: country)
    }
    
    private func calculateAddressConfidence(_ address: String, in text: String) -> Float {
        var confidence: Float = 0.6
        
        let context = getContext(for: address, in: text, radius: 30)
        let lowercaseContext = context.lowercased()
        
        if lowercaseContext.contains("address") || lowercaseContext.contains("location") ||
           lowercaseContext.contains("visit") || lowercaseContext.contains("office") {
            confidence += 0.2
        }
        
        // Check for zip code
        if address.range(of: #"\b\d{5}(-\d{4})?\b"#, options: .regularExpression) != nil {
            confidence += 0.2
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - URL Extraction
    private func extractURLs(from text: String) -> [URLData] {
        var urls: [URLData] = []
        let range = NSRange(location: 0, length: text.count)
        
        let matches = dataDetector.matches(in: text, options: [], range: range)
        
        for match in matches {
            if match.resultType == .link,
               let url = match.url,
               url.scheme != "mailto" {
                let nsText = text as NSString
                let urlText = nsText.substring(with: match.range)
                let urlData = processURL(url, displayText: urlText, in: text)
                urls.append(urlData)
            }
        }
        
        return urls
    }
    
    private func processURL(_ url: URL, displayText: String, in text: String) -> URLData {
        let isValid = UIApplication.shared.canOpenURL(url)
        let confidence = calculateURLConfidence(url.absoluteString, in: text)
        
        return URLData(
            url: url.absoluteString,
            displayText: displayText,
            isValid: isValid,
            confidence: confidence
        )
    }
    
    private func calculateURLConfidence(_ url: String, in text: String) -> Float {
        var confidence: Float = 0.8
        
        let context = getContext(for: url, in: text, radius: 20)
        let lowercaseContext = context.lowercased()
        
        if lowercaseContext.contains("website") || lowercaseContext.contains("visit") ||
           lowercaseContext.contains("web") || lowercaseContext.contains("www") {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Date Extraction
    private func extractDates(from text: String) -> [DateData] {
        var dates: [DateData] = []
        let range = NSRange(location: 0, length: text.count)
        
        let matches = dataDetector.matches(in: text, options: [], range: range)
        
        for match in matches {
            if match.resultType == .date,
               let date = match.date {
                let nsText = text as NSString
                let dateText = nsText.substring(with: match.range)
                let dateData = processDate(date, text: dateText, in: text)
                dates.append(dateData)
            }
        }
        
        return dates
    }
    
    private func processDate(_ date: Date, text: String, in fullText: String) -> DateData {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let confidence = calculateDateConfidence(text, in: fullText)
        
        return DateData(
            raw: text,
            parsed: date,
            format: detectDateFormat(text),
            confidence: confidence
        )
    }
    
    private func detectDateFormat(_ dateText: String) -> String? {
        // Common date patterns
        let patterns = [
            (#"\d{1,2}/\d{1,2}/\d{4}"#, "MM/dd/yyyy"),
            (#"\d{4}-\d{2}-\d{2}"#, "yyyy-MM-dd"),
            (#"\w+ \d{1,2}, \d{4}"#, "MMMM dd, yyyy"),
            (#"\d{1,2} \w+ \d{4}"#, "dd MMMM yyyy")
        ]
        
        for (pattern, format) in patterns {
            if dateText.range(of: pattern, options: .regularExpression) != nil {
                return format
            }
        }
        
        return nil
    }
    
    private func calculateDateConfidence(_ dateText: String, in text: String) -> Float {
        var confidence: Float = 0.7
        
        let context = getContext(for: dateText, in: text, radius: 20)
        let lowercaseContext = context.lowercased()
        
        if lowercaseContext.contains("date") || lowercaseContext.contains("when") ||
           lowercaseContext.contains("schedule") || lowercaseContext.contains("due") {
            confidence += 0.2
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Helper Methods
    private func getContext(for target: String, in text: String, radius: Int) -> String {
        guard let range = text.range(of: target) else { return "" }
        
        let startIndex = text.index(range.lowerBound, offsetBy: -min(radius, range.lowerBound.utf16Offset(in: text)), limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: min(radius, text.endIndex.utf16Offset(in: text) - range.upperBound.utf16Offset(in: text)), limitedBy: text.endIndex) ?? text.endIndex
        
        return String(text[startIndex..<endIndex])
    }
}
//
//  SystemIntegrations.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import EventKit
import Intents
import IntentsUI
import Social
import UIKit

// MARK: - Calendar Integration
class CalendarIntegration: ObservableObject {
    private let eventStore = EKEventStore()
    
    @Published var hasCalendarAccess = false
    @Published var upcomingEvents: [EKEvent] = []
    
    init() {
        checkCalendarAccess()
    }
    
    private func checkCalendarAccess() {
        hasCalendarAccess = EKEventStore.authorizationStatus(for: .event) == .authorized
        if hasCalendarAccess {
            loadUpcomingEvents()
        }
    }
    
    func requestCalendarAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, error in
                Task { @MainActor in
                    self.hasCalendarAccess = granted
                    if granted {
                        self.loadUpcomingEvents()
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func loadUpcomingEvents() {
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        upcomingEvents = eventStore.events(matching: predicate)
    }
    
    func createMeetingNote(for event: EKEvent) -> Note {
        let title = "Meeting: \(event.title ?? "Untitled")"
        var content = "Meeting Details:\n"
        content += "Title: \(event.title ?? "N/A")\n"
        content += "Date: \(event.startDate?.formatted() ?? "N/A")\n"
        
        if let location = event.location {
            content += "Location: \(location)\n"
        }
        
        if let notes = event.notes {
            content += "Notes: \(notes)\n"
        }
        
        content += "\nMeeting Notes:\n"
        content += "- \n"
        content += "- \n"
        content += "- \n"
        
        content += "\nAction Items:\n"
        content += "- [ ] \n"
        content += "- [ ] \n"
        
        return Note(
            title: title,
            content: content,
            tags: ["meeting", "calendar"],
            category: Category(name: "Meetings", color: "#FF9500")
        )
    }
    
    func suggestMeetingPreparation(for event: EKEvent) -> [String] {
        var suggestions: [String] = []
        
        suggestions.append("Review agenda and prepare talking points")
        suggestions.append("Gather relevant documents and materials")
        suggestions.append("Check technical setup (camera, microphone)")
        
        if let attendees = event.attendees, attendees.count > 1 {
            suggestions.append("Send reminder to attendees")
        }
        
        if event.location?.contains("zoom") == true || event.location?.contains("teams") == true {
            suggestions.append("Test video conferencing link")
        }
        
        return suggestions
    }
}

// MARK: - Shortcuts Integration
class ShortcutsIntegration: NSObject, ObservableObject {
    
    static let shared = ShortcutsIntegration()
    
    override init() {
        super.init()
        setupShortcuts()
    }
    
    func setupShortcuts() {
        // Donate shortcuts for Siri integration
        donateCreateNoteShortcut()
        donateSearchNotesShortcut()
        donateRecordVoiceNoteShortcut()
    }
    
    private func donateCreateNoteShortcut() {
        let intent = CreateNoteIntent()
        intent.suggestedInvocationPhrase = "Create a new note"
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate create note shortcut: \(error)")
            }
        }
    }
    
    private func donateSearchNotesShortcut() {
        let intent = SearchNotesIntent()
        intent.suggestedInvocationPhrase = "Search my notes"
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate search notes shortcut: \(error)")
            }
        }
    }
    
    private func donateRecordVoiceNoteShortcut() {
        let intent = RecordVoiceNoteIntent()
        intent.suggestedInvocationPhrase = "Record a voice note"
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate record voice note shortcut: \(error)")
            }
        }
    }
}

// MARK: - Share Extension Support
class ShareExtensionHandler: ObservableObject {
    
    func handleSharedContent(_ items: [Any]) async -> Note? {
        for item in items {
            if let url = item as? URL {
                return await handleSharedURL(url)
            } else if let string = item as? String {
                return handleSharedText(string)
            } else if let image = item as? UIImage {
                return await handleSharedImage(image)
            }
        }
        return nil
    }
    
    private func handleSharedText(_ text: String) -> Note {
        return Note(
            title: "Shared Text",
            content: text,
            tags: ["shared", "text"],
            category: Category(name: "Shared", color: "#34C759")
        )
    }
    
    private func handleSharedURL(_ url: URL) async -> Note {
        var content = "Shared URL: \(url.absoluteString)\n\n"
        
        // Try to fetch page title if it's a web URL
        if url.scheme == "http" || url.scheme == "https" {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let html = String(data: data, encoding: .utf8) {
                    if let title = extractTitleFromHTML(html) {
                        content = "Title: \(title)\n" + content
                    }
                }
            } catch {
                print("Failed to fetch URL content: \(error)")
            }
        }
        
        return Note(
            title: "Shared Link",
            content: content,
            tags: ["shared", "link"],
            category: Category(name: "Shared", color: "#34C759")
        )
    }
    
    private func handleSharedImage(_ image: UIImage) async -> Note {
        // Perform OCR on the shared image
        let fileImportManager = await FileImportManager()
        
        // Save image temporarily
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        
        do {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                try imageData.write(to: tempURL)
                
                let extractedText = try await fileImportManager.performOCR(on: tempURL)
                
                var content = "Shared Image\n\n"
                if !extractedText.isEmpty {
                    content += "Extracted Text:\n\(extractedText)"
                }
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                
                return Note(
                    title: "Shared Image",
                    content: content,
                    tags: ["shared", "image"],
                    category: Category(name: "Shared", color: "#34C759")
                )
            }
        } catch {
            print("Failed to process shared image: \(error)")
        }
        
        return Note(
            title: "Shared Image",
            content: "Shared image (text extraction failed)",
            tags: ["shared", "image"],
            category: Category(name: "Shared", color: "#34C759")
        )
    }
    
    private func extractTitleFromHTML(_ html: String) -> String? {
        let titlePattern = "<title>(.*?)</title>"
        let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: html.count)
        
        if let match = regex?.firstMatch(in: html, options: [], range: range) {
            let titleRange = match.range(at: 1)
            if let swiftRange = Range(titleRange, in: html) {
                return String(html[swiftRange])
            }
        }
        
        return nil
    }
}

// MARK: - URL Scheme Handler
class URLSchemeHandler: ObservableObject {
    
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "ainotetaking" else { return false }
        
        switch url.host {
        case "create":
            handleCreateNoteURL(url)
            return true
        case "search":
            handleSearchURL(url)
            return true
        case "record":
            handleRecordURL(url)
            return true
        default:
            return false
        }
    }
    
    private func handleCreateNoteURL(_ url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let title = components?.queryItems?.first(where: { $0.name == "title" })?.value
        let content = components?.queryItems?.first(where: { $0.name == "content" })?.value
        
        // Post notification to create new note
        NotificationCenter.default.post(
            name: AppConstants.Notifications.noteCreated,
            object: nil,
            userInfo: [
                "title": title ?? "",
                "content": content ?? ""
            ]
        )
    }
    
    private func handleSearchURL(_ url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems?.first(where: { $0.name == "q" })?.value
        
        // Post notification to perform search
        NotificationCenter.default.post(
            name: Notification.Name("PerformSearch"),
            object: nil,
            userInfo: ["query": query ?? ""]
        )
    }
    
    private func handleRecordURL(_ url: URL) {
        // Post notification to start voice recording
        NotificationCenter.default.post(
            name: Notification.Name("StartVoiceRecording"),
            object: nil
        )
    }
}

// MARK: - Intent Definitions (These would typically be in a separate Intents extension)

// Create Note Intent
class CreateNoteIntent: INIntent {
    // This would be defined in an Intents extension
}

// Search Notes Intent
class SearchNotesIntent: INIntent {
    // This would be defined in an Intents extension
}

// Record Voice Note Intent
class RecordVoiceNoteIntent: INIntent {
    // This would be defined in an Intents extension
}

// MARK: - System Integration Manager
class SystemIntegrationManager: ObservableObject {
    
    let calendarIntegration = CalendarIntegration()
    let shortcutsIntegration = ShortcutsIntegration.shared
    let shareExtensionHandler = ShareExtensionHandler()
    let urlSchemeHandler = URLSchemeHandler()
    
    init() {
        setupIntegrations()
    }
    
    private func setupIntegrations() {
        // Setup URL scheme handling
        NotificationCenter.default.addObserver(
            forName: UIApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            // App finished launching
        }
        
        // Setup background refresh
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleAppDidEnterBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleAppWillEnterForeground()
        }
    }
    
    private func handleAppDidEnterBackground() {
        // Donate shortcuts when app goes to background
        shortcutsIntegration.setupShortcuts()
    }
    
    private func handleAppWillEnterForeground() {
        // Refresh calendar events when app comes to foreground
        if calendarIntegration.hasCalendarAccess {
            calendarIntegration.loadUpcomingEvents()
        }
    }
    
    func handleIncomingURL(_ url: URL) -> Bool {
        return urlSchemeHandler.handleURL(url)
    }
    
    func handleSharedItems(_ items: [Any]) async -> Note? {
        return await shareExtensionHandler.handleSharedContent(items)
    }
}

//
//  AIAssistantService.swift
//  AINoteTakingApp
//
//  AI Assistant business logic service following SRP (Single Responsibility Principle)
//  Handles AI query processing, note operations, and response generation
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation

// MARK: - AI Action Types
enum AIAction {
    case summarizeAll
    case summarizeNote(Note)
    case findRelated(Note)
    case extractTasks
    case searchNotes(String)
    case categorizeNotes
    case analyzeNote(Note)
    case openNote(Note)
    case createNote(String)
    case editNote(Note)
    case showNotesByTag(String)
    case showNotesByCategory(String)
    case showRecentNotes
    case showNotesByDate(String)
    case deleteNote(Note)
}

// MARK: - AI Context Types
enum AIContext {
    case general
    case noteSpecific(Note)
    case multipleNotes([Note])
    case search(String)
}

// MARK: - AI Assistant Service
@MainActor
class AIAssistantService: ObservableObject {
    
    // MARK: - Private Properties
    private let dataManager = DataManager.shared
    private let aiProcessor = AIProcessor()
    
    // MARK: - Public Methods
    
    func processUserMessage(_ message: String) async -> (String, [AIAction], [Note]) {
        let lowercased = message.lowercased()
        let availableNotes = dataManager.fetchAllNotes()

        // Navigation and direct actions
        if lowercased.contains("open") || lowercased.contains("show me") {
            return await handleOpenNoteRequest(message, notes: availableNotes)
        } else if lowercased.contains("create") || lowercased.contains("new log") || lowercased.contains("add") {
            return await handleCreateNoteRequest(message)
        } else if lowercased.contains("edit") || lowercased.contains("modify") {
            return await handleEditNoteRequest(message, notes: availableNotes)
        } else if lowercased.contains("delete") || lowercased.contains("remove") {
            return await handleDeleteNoteRequest(message, notes: availableNotes)
        } else if lowercased.contains("recent") || lowercased.contains("latest") {
            return await handleRecentNotesRequest(availableNotes)
        } else if lowercased.contains("tag") && (lowercased.contains("show") || lowercased.contains("find")) {
            return await handleTagSearchRequest(message, notes: availableNotes)
        } else if lowercased.contains("category") && (lowercased.contains("show") || lowercased.contains("find")) {
            return await handleCategorySearchRequest(message, notes: availableNotes)
        } else if lowercased.contains("today") || lowercased.contains("yesterday") || lowercased.contains("this week") {
            return await handleDateSearchRequest(message, notes: availableNotes)
        }
        
        // Analysis functionality
        else if lowercased.contains("summarize all") || lowercased.contains("summary of all") {
            return await handleSummarizeAllRequest(availableNotes)
        } else if lowercased.contains("summarize") || lowercased.contains("summary") {
            return await handleSummarizeRequest(message, notes: availableNotes)
        } else if lowercased.contains("find") || lowercased.contains("search") {
            return await handleSearchRequest(message, notes: availableNotes)
        } else if lowercased.contains("action") || lowercased.contains("task") || lowercased.contains("todo") {
            return await handleActionItemsRequest(availableNotes)
        } else if lowercased.contains("organize") || lowercased.contains("categorize") {
            return await handleOrganizeRequest(availableNotes)
        } else if lowercased.contains("related") || lowercased.contains("connection") {
            return await handleRelatedNotesRequest(message, notes: availableNotes)
        } else if lowercased.contains("hello") || lowercased.contains("hi") || lowercased.contains("hey") {
            return await handleGreeting(availableNotes)
        } else if lowercased.contains("help") {
            return await handleHelpRequest(availableNotes)
        } else {
            return await handleIntelligentQuery(message, notes: availableNotes)
        }
    }
    
    func processAction(_ action: AIAction) async -> (String, [AIAction], [Note]) {
        let availableNotes = dataManager.fetchAllNotes()

        switch action {
        case .summarizeAll:
            return await handleSummarizeAllRequest(availableNotes)
        case .summarizeNote(let note):
            return await handleSummarizeRequest("summarize \(note.title)", notes: [note])
        case .findRelated(let note):
            return await handleRelatedNotesRequest("find related to \(note.title)", notes: availableNotes)
        case .extractTasks:
            return await handleActionItemsRequest(availableNotes)
        case .searchNotes(let query):
            return await handleSearchRequest("search \(query)", notes: availableNotes)
        case .categorizeNotes:
            return await handleOrganizeRequest(availableNotes)
        case .analyzeNote(let note):
            return await handleSummarizeRequest("analyze \(note.title)", notes: [note])
        case .openNote(let note):
            return ("Opening '\(note.title.isEmpty ? "Untitled" : note.title)' for you...", [], [note])
        case .createNote(let title):
            return ("Creating a new log titled '\(title)' for you...", [], [])
        case .editNote(let note):
            return ("Opening '\(note.title.isEmpty ? "Untitled" : note.title)' for editing...", [], [note])
        case .showNotesByTag(let tag):
            return await handleTagSearchRequest("show notes with tag \(tag)", notes: availableNotes)
        case .showNotesByCategory(let category):
            return await handleCategorySearchRequest("show notes in category \(category)", notes: availableNotes)
        case .showRecentNotes:
            return await handleRecentNotesRequest(availableNotes)
        case .showNotesByDate(let date):
            return await handleDateSearchRequest("show notes from \(date)", notes: availableNotes)
        case .deleteNote(let note):
            return ("I can help you identify the note to delete, but you'll need to delete it from the main logs view for safety.", [.openNote(note)], [note])
        }
    }
    
    func generateContextualGreeting(noteCount: Int) -> String {
        let baseGreeting = "Hello! I'm your AI assistant. "

        if noteCount == 0 {
            return baseGreeting + "I see you don't have any notes yet. Once you create some notes, I can help you:\n\n• Summarize and analyze content\n• Extract action items and tasks\n• Find related information\n• Organize and categorize notes\n\nStart by creating your first note, then come back to chat with me!"
        } else if noteCount < 5 {
            return baseGreeting + "I can see you have \(noteCount) note\(noteCount == 1 ? "" : "s"). I can help you:\n\n• Summarize your existing notes\n• Extract action items\n• Find connections between notes\n• Suggest better organization\n\nWhat would you like me to help you with?"
        } else {
            return baseGreeting + "I can see you have \(noteCount) notes to work with! I can help you:\n\n• Summarize all or specific notes\n• Find related content across your notes\n• Extract and organize action items\n• Categorize and tag your notes\n• Search through your content\n\nWhat would you like me to analyze today?"
        }
    }
}

// MARK: - Private Request Handlers
private extension AIAssistantService {
    
    func handleSummarizeAllRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't see any notes to summarize. Create some notes first, then I can help you summarize them!", [], [])
        }

        let allContent = notes.map { note in
            "\(note.title.isEmpty ? "Untitled" : note.title): \(note.content)"
        }.joined(separator: "\n\n")

        let summary = await aiProcessor.summarizeContent(allContent)
        let keyPoints = await aiProcessor.extractKeyPoints(allContent)

        var response = "Here's a summary of all your \(notes.count) notes:\n\n**Summary:**\n\(summary)"

        if !keyPoints.isEmpty {
            response += "\n\n**Key Points:**\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n")
        }

        let actions: [AIAction] = [.extractTasks, .categorizeNotes]
        return (response, actions, notes)
    }

    func handleSearchRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't have any notes to search through. Create some notes first!", [], [])
        }

        let searchTerms = extractSearchTerms(from: message)
        let matchingNotes = searchNotes(searchTerms, in: notes)

        if matchingNotes.isEmpty {
            return ("I couldn't find any notes matching '\(searchTerms.joined(separator: ", "))'. Try different keywords or create notes with that content.", [.summarizeAll], [])
        }

        let response = "I found \(matchingNotes.count) note\(matchingNotes.count == 1 ? "" : "s") matching your search:\n\n" +
            matchingNotes.prefix(5).map { note in
                "• **\(note.title.isEmpty ? "Untitled" : note.title)** - \(String(note.content.prefix(100)))\(note.content.count > 100 ? "..." : "")"
            }.joined(separator: "\n")

        let actions: [AIAction] = matchingNotes.count == 1 ? [.analyzeNote(matchingNotes[0])] : [.summarizeAll]
        return (response, actions, Array(matchingNotes.prefix(10)))
    }

    func handleActionItemsRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't have any notes to extract action items from. Create some notes first!", [], [])
        }

        var allActionItems: [ActionItem] = []
        var notesWithTasks: [Note] = []

        for note in notes {
            let content = "\(note.title) \(note.content)"
            let extractedItems = await aiProcessor.extractActionItems(content)
            if !extractedItems.isEmpty {
                allActionItems.append(contentsOf: extractedItems)
                notesWithTasks.append(note)
            }
        }

        if allActionItems.isEmpty {
            return ("I couldn't find any action items in your notes. Try adding tasks with words like 'need to', 'should', 'must', or 'todo'.", [.summarizeAll], [])
        }

        let response = "I found \(allActionItems.count) action item\(allActionItems.count == 1 ? "" : "s") across \(notesWithTasks.count) note\(notesWithTasks.count == 1 ? "" : "s"):\n\n" +
            allActionItems.prefix(10).map { item in
                let priorityIcon = item.priority == .urgent ? "🔴" : item.priority == .high ? "🟡" : "🟢"
                return "\(priorityIcon) \(item.title)"
            }.joined(separator: "\n")

        return (response, [.categorizeNotes], notesWithTasks)
    }

    func handleGreeting(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
        let contextualGreeting = generateContextualGreeting(noteCount: notes.count)
        let actions: [AIAction] = notes.isEmpty ? [] : [.summarizeAll, .extractTasks, .categorizeNotes]
        return (contextualGreeting, actions, [])
    }

    func handleOpenNoteRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        let searchTerms = extractSearchTerms(from: message)
        let matchingNotes = searchNotes(searchTerms, in: notes)
        
        if matchingNotes.isEmpty {
            return ("I couldn't find any logs matching '\(searchTerms.joined(separator: ", "))'. Try different keywords or create a new log.", [.createNote(searchTerms.first ?? "New Log")], [])
        }
        
        if matchingNotes.count == 1 {
            let note = matchingNotes[0]
            return ("Found '\(note.title.isEmpty ? "Untitled" : note.title)'. Tap 'Open' to view it.", [.openNote(note)], [note])
        } else {
            let response = "I found \(matchingNotes.count) logs matching your search:\n\n" +
                matchingNotes.prefix(5).map { note in
                    "• \(note.title.isEmpty ? "Untitled" : note.title)"
                }.joined(separator: "\n")
            
            let actions = Array(matchingNotes.prefix(3)).map { AIAction.openNote($0) }
            return (response, actions, Array(matchingNotes.prefix(5)))
        }
    }
    
    func handleCreateNoteRequest(_ message: String) async -> (String, [AIAction], [Note]) {
        let titleKeywords = ["create", "new", "add", "log", "note", "about", "for"]
        var cleanedMessage = message.lowercased()
        
        for keyword in titleKeywords {
            cleanedMessage = cleanedMessage.replacingOccurrences(of: keyword, with: "")
        }
        
        let title = cleanedMessage.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        let finalTitle = title.isEmpty ? "New Log" : title
        
        return ("I'll create a new log titled '\(finalTitle)' for you.", [.createNote(finalTitle)], [])
    }
    
    func handleEditNoteRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        let searchTerms = extractSearchTerms(from: message)
        let matchingNotes = searchNotes(searchTerms, in: notes)
        
        if matchingNotes.isEmpty {
            return ("I couldn't find any logs to edit matching '\(searchTerms.joined(separator: ", "))'. Try different keywords.", [], [])
        }
        
        if matchingNotes.count == 1 {
            let note = matchingNotes[0]
            return ("Opening '\(note.title.isEmpty ? "Untitled" : note.title)' for editing.", [.editNote(note)], [note])
        } else {
            let response = "Which log would you like to edit?\n\n" +
                matchingNotes.prefix(3).map { note in
                    "• \(note.title.isEmpty ? "Untitled" : note.title)"
                }.joined(separator: "\n")
            
            let actions = Array(matchingNotes.prefix(3)).map { AIAction.editNote($0) }
            return (response, actions, Array(matchingNotes.prefix(3)))
        }
    }
    
    func handleDeleteNoteRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        let searchTerms = extractSearchTerms(from: message)
        let matchingNotes = searchNotes(searchTerms, in: notes)
        
        if matchingNotes.isEmpty {
            return ("I couldn't find any logs matching '\(searchTerms.joined(separator: ", "))' to delete.", [], [])
        }
        
        let response = "⚠️ I found \(matchingNotes.count) log\(matchingNotes.count == 1 ? "" : "s") matching your search. For safety, I can't delete logs directly. I'll show you the log\(matchingNotes.count == 1 ? "" : "s") so you can delete \(matchingNotes.count == 1 ? "it" : "them") manually:\n\n" +
            matchingNotes.prefix(3).map { note in
                "• \(note.title.isEmpty ? "Untitled" : note.title)"
            }.joined(separator: "\n")
        
        let actions = Array(matchingNotes.prefix(3)).map { AIAction.openNote($0) }
        return (response, actions, Array(matchingNotes.prefix(3)))
    }
    
    func handleRecentNotesRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
        let recentNotes = Array(notes.sorted { $0.modifiedDate > $1.modifiedDate }.prefix(5))
        
        if recentNotes.isEmpty {
            return ("You don't have any logs yet. Create your first log to get started!", [.createNote("My First Log")], [])
        }
        
        let response = "Here are your \(recentNotes.count) most recent logs:\n\n" +
            recentNotes.map { note in
                "• \(note.title.isEmpty ? "Untitled" : note.title) (\(formatRelativeDate(note.modifiedDate)))"
            }.joined(separator: "\n")
        
        let actions = Array(recentNotes.prefix(3)).map { AIAction.openNote($0) }
        return (response, actions, recentNotes)
    }
    
    func handleTagSearchRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        let words = message.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let tagKeywordIndex = words.firstIndex { $0.contains("tag") } ?? -1
        
        var searchTag = ""
        if tagKeywordIndex >= 0 && tagKeywordIndex + 1 < words.count {
            searchTag = words[tagKeywordIndex + 1]
        }
        
        let matchingNotes = notes.filter { note in
            note.tags.contains { tag in
                tag.lowercased().contains(searchTag.lowercased())
            }
        }
        
        if matchingNotes.isEmpty {
            return ("I couldn't find any logs with the tag '\(searchTag)'. Available tags: \(getAvailableTags(from: notes).joined(separator: ", "))", [], [])
        }
        
        let response = "Found \(matchingNotes.count) log\(matchingNotes.count == 1 ? "" : "s") tagged with '\(searchTag)':\n\n" +
            matchingNotes.prefix(5).map { note in
                "• \(note.title.isEmpty ? "Untitled" : note.title)"
            }.joined(separator: "\n")
        
        let actions = Array(matchingNotes.prefix(3)).map { AIAction.openNote($0) }
        return (response, actions, Array(matchingNotes.prefix(5)))
    }
    
    func handleCategorySearchRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        let words = message.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let categoryKeywordIndex = words.firstIndex { $0.contains("category") } ?? -1
        
        var searchCategory = ""
        if categoryKeywordIndex >= 0 && categoryKeywordIndex + 1 < words.count {
            searchCategory = words[categoryKeywordIndex + 1]
        }
        
        let matchingNotes = notes.filter { note in
            note.category?.name.lowercased().contains(searchCategory.lowercased()) == true
        }
        
        if matchingNotes.isEmpty {
            return ("I couldn't find any logs in the category '\(searchCategory)'. Available categories: \(getAvailableCategories(from: notes).joined(separator: ", "))", [], [])
        }
        
        let response = "Found \(matchingNotes.count) log\(matchingNotes.count == 1 ? "" : "s") in the '\(searchCategory)' category:\n\n" +
            matchingNotes.prefix(5).map { note in
                "• \(note.title.isEmpty ? "Untitled" : note.title)"
            }.joined(separator: "\n")
        
        let actions = Array(matchingNotes.prefix(3)).map { AIAction.openNote($0) }
        return (response, actions, Array(matchingNotes.prefix(5)))
    }
    
    func handleDateSearchRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        
        let lowercased = message.lowercased()
        var dateFilter: (Date) -> Bool
        var dateDescription: String
        
        if lowercased.contains("today") {
            dateFilter = { Calendar.current.isDate($0, inSameDayAs: Date()) }
            dateDescription = "today"
        } else if lowercased.contains("yesterday") {
            dateFilter = { Calendar.current.isDate($0, inSameDayAs: yesterday) }
            dateDescription = "yesterday"
        } else if lowercased.contains("this week") {
            dateFilter = { $0 >= weekAgo }
            dateDescription = "this week"
        } else {
            dateFilter = { $0 >= weekAgo }
            dateDescription = "recently"
        }
        
        let matchingNotes = notes.filter { dateFilter($0.modifiedDate) }
        
        if matchingNotes.isEmpty {
            return ("I couldn't find any logs from \(dateDescription).", [.showRecentNotes], [])
        }
        
        let response = "Found \(matchingNotes.count) log\(matchingNotes.count == 1 ? "" : "s") from \(dateDescription):\n\n" +
            matchingNotes.prefix(5).map { note in
                "• \(note.title.isEmpty ? "Untitled" : note.title) (\(formatRelativeDate(note.modifiedDate)))"
            }.joined(separator: "\n")
        
        let actions = Array(matchingNotes.prefix(3)).map { AIAction.openNote($0) }
        return (response, actions, Array(matchingNotes.prefix(5)))
    }
    
    func handleSummarizeRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't have any notes to summarize. Create some notes first!", [], [])
        }

        let searchTerms = extractSearchTerms(from: message)
        let relevantNotes = searchTerms.isEmpty ? notes : searchNotes(searchTerms, in: notes)

        if relevantNotes.isEmpty {
            return ("I couldn't find any notes matching those terms to summarize.", [.summarizeAll], [])
        }

        // If multiple notes found, summarize all of them, not just the first
        if relevantNotes.count > 1 {
            let allContent = relevantNotes.map { note in
                "\(note.title.isEmpty ? "Untitled" : note.title): \(note.content)"
            }.joined(separator: "\n\n")
            
            let summary = await aiProcessor.summarizeContent(allContent)
            let keyPoints = await aiProcessor.extractKeyPoints(allContent)
            
            var response = "Here's a summary of \(relevantNotes.count) matching notes:\n\n**Summary:**\n\(summary)"
            
            if !keyPoints.isEmpty {
                response += "\n\n**Key Points:**\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n")
            }
            
            let actions: [AIAction] = [.extractTasks, .categorizeNotes]
            return (response, actions, relevantNotes)
        } else {
            let noteToSummarize = relevantNotes.first!
            let summary = await aiProcessor.summarizeContent(noteToSummarize.content)
            let keyPoints = await aiProcessor.extractKeyPoints(noteToSummarize.content)

            var response = "Here's a summary of '\(noteToSummarize.title.isEmpty ? "Untitled Note" : noteToSummarize.title)':\n\n**Summary:**\n\(summary)"

            if !keyPoints.isEmpty {
                response += "\n\n**Key Points:**\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n")
            }

            let actions: [AIAction] = [.findRelated(noteToSummarize), .extractTasks]
            return (response, actions, [noteToSummarize])
        }
    }

    func handleOrganizeRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't have any notes to organize. Create some notes first!", [], [])
        }

        var categoryMap: [String: [Note]] = [:]

        for note in notes {
            let processed = await aiProcessor.processContent(note.content)
            let categoryName = processed.suggestedCategory?.name ?? "Uncategorized"

            if categoryMap[categoryName] == nil {
                categoryMap[categoryName] = []
            }
            categoryMap[categoryName]?.append(note)
        }

        let response = "I've analyzed your \(notes.count) notes and suggest organizing them into these categories:\n\n" +
            categoryMap.map { category, notesInCategory in
                "**\(category)** (\(notesInCategory.count) note\(notesInCategory.count == 1 ? "" : "s"))"
            }.joined(separator: "\n")

        return (response, [.summarizeAll], notes)
    }

    func handleRelatedNotesRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't have any notes to find relationships between. Create some notes first!", [], [])
        }

        let searchTerms = extractSearchTerms(from: message)
        let relevantNotes = searchTerms.isEmpty ? [notes.first!] : searchNotes(searchTerms, in: notes)

        guard let baseNote = relevantNotes.first else {
            return ("I couldn't find a note to base the relationship search on.", [.summarizeAll], [])
        }

        let relatedResults = await aiProcessor.findRelatedNotes(baseNote, in: notes)
        let relatedNotes = relatedResults.map { $0.notes }.flatMap { $0 }

        if relatedNotes.isEmpty {
            return ("I couldn't find any notes related to '\(baseNote.title.isEmpty ? "that note" : baseNote.title)'.", [.summarizeAll], [baseNote])
        }

        let response = "I found \(relatedNotes.count) note\(relatedNotes.count == 1 ? "" : "s") related to '\(baseNote.title.isEmpty ? "Untitled" : baseNote.title)':\n\n" +
            relatedNotes.prefix(5).map { note in
                "• **\(note.title.isEmpty ? "Untitled" : note.title)**"
            }.joined(separator: "\n")

        return (response, [.summarizeAll], [baseNote] + relatedNotes)
    }

    func handleHelpRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
        let response = "Here's what I can help you with:\n\n🗂️ **Navigation & Access**\n• Open specific logs: 'Open my meeting notes'\n• Create new logs: 'Create a log about project X'\n• Edit existing logs: 'Edit my notes from yesterday'\n• Show recent logs: 'Show me recent logs'\n\n🔍 **Smart Search**\n• Find by content: 'Find logs about meetings'\n• Filter by tags: 'Show logs tagged with work'\n• Filter by category: 'Show all personal logs'\n• Date-based: 'Show logs from today'\n\n📝 **Content Analysis**\n• Summarize logs or all logs\n• Extract key points and action items\n• Analyze specific logs\n\n🏷️ **Organization**\n• Find related logs\n• Suggest categories and tags\n• Smart groupings\n\n**Try natural language:**\n• 'Take me to my project notes'\n• 'What did I write about the meeting?'\n• 'Create a new log for my ideas'\n• 'Show me everything tagged important'"

        let actions: [AIAction] = notes.isEmpty ? [] : [.showRecentNotes, .summarizeAll, .extractTasks]
        return (response, actions, [])
    }
    
    func handleIntelligentQuery(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        let searchTerms = extractSearchTerms(from: message)
        let matchingNotes = searchNotes(searchTerms, in: notes)
        
        if !matchingNotes.isEmpty {
            let response = "I think you're looking for information about '\(searchTerms.joined(separator: ", "))'. I found \(matchingNotes.count) relevant log\(matchingNotes.count == 1 ? "" : "s"):\n\n" +
                matchingNotes.prefix(3).map { note in
                    "• \(note.title.isEmpty ? "Untitled" : note.title) - \(String(note.content.prefix(60)))\(note.content.count > 60 ? "..." : "")"
                }.joined(separator: "\n")
            
            let actions = Array(matchingNotes.prefix(3)).map { AIAction.openNote($0) } + [.summarizeAll]
            return (response, actions, Array(matchingNotes.prefix(5)))
        }
        
        let response = "I understand you're asking about: \"\(message)\"\n\nI can help you with:\n• **Find logs**: 'Show me notes about meetings'\n• **Open specific logs**: 'Open my project notes'\n• **Create new logs**: 'Create a log about today's ideas'\n• **Recent activity**: 'Show me recent logs'\n• **Organization**: 'Show logs tagged with work'\n\nTry being more specific about what you're looking for!"
        
        let actions: [AIAction] = notes.isEmpty ? [.createNote("New Log")] : [.showRecentNotes, .summarizeAll]
        return (response, actions, [])
    }
}

// MARK: - Helper Methods
private extension AIAssistantService {
    
    func extractSearchTerms(from message: String) -> [String] {
        let lowercased = message.lowercased()
        let searchPrefixes = ["find", "search", "look for", "show me"]

        var cleanedMessage = lowercased
        for prefix in searchPrefixes {
            if let range = cleanedMessage.range(of: prefix) {
                cleanedMessage = String(cleanedMessage[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        return cleanedMessage.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count > 2 }
    }

    func searchNotes(_ searchTerms: [String], in notes: [Note]) -> [Note] {
        if searchTerms.isEmpty { return notes }
        
        let query = searchTerms.joined(separator: " ")
        let foundNotes = dataManager.searchAllNotes(query: query)
        
        // If no results from data manager, try local search as fallback
        if foundNotes.isEmpty {
            return notes.filter { note in
                let searchText = query.lowercased()
                return note.title.lowercased().contains(searchText) ||
                       note.content.lowercased().contains(searchText) ||
                       note.tags.contains { $0.lowercased().contains(searchText) } ||
                       note.transcript?.lowercased().contains(searchText) == true ||
                       note.aiSummary?.lowercased().contains(searchText) == true
            }
        }
        
        return foundNotes
    }
    
    func getAvailableTags(from notes: [Note]) -> [String] {
        let allTags = Set(notes.flatMap { $0.tags })
        return Array(allTags).sorted()
    }
    
    func getAvailableCategories(from notes: [Note]) -> [String] {
        let categories = Set(notes.compactMap { $0.category?.name })
        return Array(categories).sorted()
    }
    
    func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
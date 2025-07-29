//
//  AIAssistantView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI
import Speech
import AVFoundation

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
    case duplicateNote(Note)
}

// MARK: - AI Context Types
enum AIContext {
    case general
    case noteSpecific(Note)
    case multipleNotes([Note])
    case search(String)
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let actions: [AIAction]
    let relatedNotes: [Note]

    init(content: String, isUser: Bool, timestamp: Date, actions: [AIAction] = [], relatedNotes: [Note] = []) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.actions = actions
        self.relatedNotes = relatedNotes
    }
}

struct AIAssistantView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @StateObject private var aiProcessor = AIProcessor()
    @EnvironmentObject var notesViewModel: NotesListViewModel
    @State private var currentContext: AIContext = .general
    @State private var selectedNotes: Set<Note> = []
    @State private var showingActionSheet = false
    @State private var pendingAction: AIAction?
    @State private var showingClearAlert = false
    @State private var showingNoteEditor = false
    @State private var selectedNoteForEditing: Note?
    @State private var newNoteTitle = ""
    @State private var showingSpeechPermissionAlert = false
    @State private var showingSpeechUnavailableAlert = false
    @State private var showingRecordingErrorAlert = false
    @State private var recordingError: Error?
    
    // Voice recording state
    @State private var isRecording = false
    @State private var justFinishedRecording = false
    @State private var finalTranscription = ""
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var speechAuthorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatMessageView(message: message, onActionTapped: handleActionTap)
                                    .id(message.id)
                            }
                            
                            if isProcessing {
                                TypingIndicatorView()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
                
                // Input Area - This will stay at bottom
                ChatInputView(
                    inputText: $inputText,
                    isProcessing: isProcessing,
                    isRecording: isRecording,
                    justFinishedRecording: justFinishedRecording,
                    onSend: sendMessage,
                    onVoiceToggle: toggleVoiceRecording
                )
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        showingClearAlert = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                if messages.isEmpty {
                    addWelcomeMessage()
                }
                // Setup speech recognition
                setupSpeechRecognition()
            }
            .alert("Clear Conversation", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearConversation()
                }
            } message: {
                Text("This will clear your entire conversation with the AI assistant. This action cannot be undone.")
            }
            .alert("Speech Recognition Permission", isPresented: $showingSpeechPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable speech recognition in Settings > Privacy & Security > Speech Recognition to use voice input.")
            }
            .alert("Speech Recognition Unavailable", isPresented: $showingSpeechUnavailableAlert) {
                Button("OK") { }
            } message: {
                Text("Speech recognition is not available on this device or language.")
            }
            .alert("Recording Error", isPresented: $showingRecordingErrorAlert) {
                Button("OK") { }
            } message: {
                Text("There was an error with voice recording: \(recordingError?.localizedDescription ?? "Unknown error")")
            }
            .sheet(isPresented: $showingNoteEditor) {
                if let note = selectedNoteForEditing {
                    NoteEditorView(note: note)
                } else {
                    NoteEditorView()
                        .onAppear {
                            // Set the title for new notes if provided
                            if !newNoteTitle.isEmpty {
                                // This would need to be handled in NoteEditorView
                            }
                        }
                }
            }
        }
    }
    
    private func addWelcomeMessage() {
        let dataManager = DataManager.shared
        let noteCount = dataManager.fetchAllNotes().count
        let contextualGreeting = generateContextualGreeting(noteCount: noteCount)

        let welcomeMessage = ChatMessage(
            content: contextualGreeting,
            isUser: false,
            timestamp: Date(),
            actions: [.summarizeAll, .extractTasks, .categorizeNotes]
        )
        messages.append(welcomeMessage)
    }

    private func generateContextualGreeting(noteCount: Int) -> String {
        let baseGreeting = "Hello! I'm your AI assistant. "

        if noteCount == 0 {
            return baseGreeting + "I see you don't have any notes yet. Once you create some notes, I can help you:\n\n• Summarize and analyze content\n• Extract action items and tasks\n• Find related information\n• Organize and categorize notes\n\nStart by creating your first note, then come back to chat with me!"
        } else if noteCount < 5 {
            return baseGreeting + "I can see you have \(noteCount) note\(noteCount == 1 ? "" : "s"). I can help you:\n\n• Summarize your existing notes\n• Extract action items\n• Find connections between notes\n• Suggest better organization\n\nWhat would you like me to help you with?"
        } else {
            return baseGreeting + "I can see you have \(noteCount) notes to work with! I can help you:\n\n• Summarize all or specific notes\n• Find related content across your notes\n• Extract and organize action items\n• Categorize and tag your notes\n• Search through your content\n\nWhat would you like me to analyze today?"
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(
            content: inputText,
            isUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        let messageToProcess = inputText
        inputText = ""
        isProcessing = true
        justFinishedRecording = false // Reset the state
        
        Task {
            let (response, actions, relatedNotes) = await processUserMessage(messageToProcess)

            await MainActor.run {
                let assistantMessage = ChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    actions: actions,
                    relatedNotes: relatedNotes
                )
                messages.append(assistantMessage)
                isProcessing = false
            }
        }
    }
    
    private func sendVoiceMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        print("Creating voice message with text: '\(text)'") // Debug log
        
        let userMessage = ChatMessage(
            content: text,
            isUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        inputText = "" // Clear the input field
        isProcessing = true
        justFinishedRecording = false // Reset the state
        
        print("Message added to conversation, processing...") // Debug log
        
        Task {
            let (response, actions, relatedNotes) = await processUserMessage(text)

            await MainActor.run {
                let assistantMessage = ChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    actions: actions,
                    relatedNotes: relatedNotes
                )
                messages.append(assistantMessage)
                isProcessing = false
                print("AI response added to conversation") // Debug log
            }
        }
    }
    
    private func processUserMessage(_ message: String) async -> (String, [AIAction], [Note]) {
        let lowercased = message.lowercased()
        // Use DataManager to get ALL notes from all folders for AI assistant
        let dataManager = DataManager.shared
        let availableNotes = dataManager.fetchAllNotes() // Get all notes across all folders

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
        
        // Existing functionality
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

    // MARK: - Conversation Management
    private func clearConversation() {
        messages.removeAll()
        currentContext = .general
        selectedNotes.removeAll()

        // Add a small delay to make the clearing feel more intentional
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addWelcomeMessage()
        }
    }

    // MARK: - Action Handling
    private func handleActionTap(_ action: AIAction) {
        Task {
            isProcessing = true
            let (response, newActions, relatedNotes) = await processAction(action)

            await MainActor.run {
                let assistantMessage = ChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    actions: newActions,
                    relatedNotes: relatedNotes
                )
                messages.append(assistantMessage)
                isProcessing = false
            }
        }
    }

    private func processAction(_ action: AIAction) async -> (String, [AIAction], [Note]) {
        let dataManager = DataManager.shared
        let availableNotes = dataManager.fetchAllNotes() // Get all notes across all folders

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
            await MainActor.run {
                selectedNoteForEditing = note
                showingNoteEditor = true
            }
            return ("Opening '\(note.title.isEmpty ? "Untitled" : note.title)' for you...", [], [note])
        case .createNote(let title):
            await MainActor.run {
                newNoteTitle = title
                selectedNoteForEditing = nil
                showingNoteEditor = true
            }
            return ("Creating a new log titled '\(title)' for you...", [], [])
        case .editNote(let note):
            await MainActor.run {
                selectedNoteForEditing = note
                showingNoteEditor = true
            }
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
        case .duplicateNote(let note):
            return ("I found the note you want to duplicate. You can open it and copy its content.", [.openNote(note)], [note])
        }
    }

    // MARK: - AI Request Handlers
    private func handleSummarizeAllRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
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

    private func handleSearchRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't have any notes to search through. Create some notes first!", [], [])
        }

        // Extract search terms from the message
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

    private func handleActionItemsRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
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

    private func handleGreeting(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
        let contextualGreeting = generateContextualGreeting(noteCount: notes.count)
        let actions: [AIAction] = notes.isEmpty ? [] : [.summarizeAll, .extractTasks, .categorizeNotes]
        return (contextualGreeting, actions, [])
    }

    private func handleGeneralQuery(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        let response = "I understand you're asking about: \"\(message)\"\n\nI can help you with:\n• **Summarize** - Get summaries of your notes\n• **Search** - Find specific content\n• **Tasks** - Extract action items\n• **Organize** - Categorize and tag notes\n\nTry asking something like:\n• 'Summarize all my notes'\n• 'Find notes about meetings'\n• 'Extract all tasks'\n• 'Organize my notes'"

        let actions: [AIAction] = notes.isEmpty ? [] : [.summarizeAll, .extractTasks]
        return (response, actions, [])
    }

    // MARK: - Helper Functions
    private func extractSearchTerms(from message: String) -> [String] {
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

    private func searchNotes(_ searchTerms: [String], in notes: [Note]) -> [Note] {
        if searchTerms.isEmpty { return notes }
        
        // Use the enhanced DataManager search method for comprehensive search
        let dataManager = DataManager.shared
        let query = searchTerms.joined(separator: " ")
        return dataManager.searchAllNotes(query: query)
    }

    private func handleSummarizeRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't have any notes to summarize. Create some notes first!", [], [])
        }

        // If user mentions specific terms, try to find relevant notes
        let searchTerms = extractSearchTerms(from: message)
        let relevantNotes = searchTerms.isEmpty ? notes : searchNotes(searchTerms, in: notes)

        if relevantNotes.isEmpty {
            return ("I couldn't find any notes matching those terms to summarize.", [.summarizeAll], [])
        }

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

    private func handleOrganizeRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't have any notes to organize. Create some notes first!", [], [])
        }

        // Analyze notes for categorization suggestions
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

    private func handleRelatedNotesRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        guard !notes.isEmpty else {
            return ("I don't have any notes to find relationships between. Create some notes first!", [], [])
        }

        // Find the most relevant note based on the query
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

    private func handleHelpRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
        let response = "Here's what I can help you with:\n\n🗂️ **Navigation & Access**\n• Open specific logs: 'Open my meeting notes'\n• Create new logs: 'Create a log about project X'\n• Edit existing logs: 'Edit my notes from yesterday'\n• Show recent logs: 'Show me recent logs'\n\n🔍 **Smart Search**\n• Find by content: 'Find logs about meetings'\n• Filter by tags: 'Show logs tagged with work'\n• Filter by category: 'Show all personal logs'\n• Date-based: 'Show logs from today'\n\n📝 **Content Analysis**\n• Summarize logs or all logs\n• Extract key points and action items\n• Analyze specific logs\n\n🏷️ **Organization**\n• Find related logs\n• Suggest categories and tags\n• Smart groupings\n\n**Try natural language:**\n• 'Take me to my project notes'\n• 'What did I write about the meeting?'\n• 'Create a new log for my ideas'\n• 'Show me everything tagged important'"

        let actions: [AIAction] = notes.isEmpty ? [] : [.showRecentNotes, .summarizeAll, .extractTasks]
        return (response, actions, [])
    }
    
    // MARK: - New Enhanced Handlers
    private func handleOpenNoteRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
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
    
    private func handleCreateNoteRequest(_ message: String) async -> (String, [AIAction], [Note]) {
        let titleKeywords = ["create", "new", "add", "log", "note", "about", "for"]
        var cleanedMessage = message.lowercased()
        
        for keyword in titleKeywords {
            cleanedMessage = cleanedMessage.replacingOccurrences(of: keyword, with: "")
        }
        
        let title = cleanedMessage.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        let finalTitle = title.isEmpty ? "New Log" : title
        
        return ("I'll create a new log titled '\(finalTitle)' for you.", [.createNote(finalTitle)], [])
    }
    
    private func handleEditNoteRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
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
    
    private func handleDeleteNoteRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
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
    
    private func handleRecentNotesRequest(_ notes: [Note]) async -> (String, [AIAction], [Note]) {
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
    
    private func handleTagSearchRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
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
    
    private func handleCategorySearchRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
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
    
    private func handleDateSearchRequest(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
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
    
    private func handleIntelligentQuery(_ message: String, notes: [Note]) async -> (String, [AIAction], [Note]) {
        // Try to understand what the user is looking for
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
        
        // If no matches, provide helpful suggestions
        let response = "I understand you're asking about: \"\(message)\"\n\nI can help you with:\n• **Find logs**: 'Show me notes about meetings'\n• **Open specific logs**: 'Open my project notes'\n• **Create new logs**: 'Create a log about today's ideas'\n• **Recent activity**: 'Show me recent logs'\n• **Organization**: 'Show logs tagged with work'\n\nTry being more specific about what you're looking for!"
        
        let actions: [AIAction] = notes.isEmpty ? [.createNote("New Log")] : [.showRecentNotes, .summarizeAll]
        return (response, actions, [])
    }
    
    // MARK: - Helper Methods
    private func getAvailableTags(from notes: [Note]) -> [String] {
        let allTags = Set(notes.flatMap { $0.tags })
        return Array(allTags).sorted()
    }
    
    private func getAvailableCategories(from notes: [Note]) -> [String] {
        let categories = Set(notes.compactMap { $0.category?.name })
        return Array(categories).sorted()
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Speech Recognition Methods
    private func setupSpeechRecognition() {
        speechAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
        
        // Request authorization if needed
        if speechAuthorizationStatus == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.speechAuthorizationStatus = status
                }
            }
        }
    }
    
    private func toggleVoiceRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // Check authorization
        guard speechAuthorizationStatus == .authorized else {
            print("Speech recognition not authorized: \(speechAuthorizationStatus)")
            showSpeechPermissionAlert()
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            showSpeechUnavailableAlert()
            return
        }
        
        do {
            // Cancel previous task
            recognitionTask?.cancel()
            recognitionTask = nil
            
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            let inputNode = audioEngine.inputNode
            
            guard let recognitionRequest = recognitionRequest else {
                fatalError("Unable to create recognition request")
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // Create recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                var isFinal = false
                
                if let result = result {
                    DispatchQueue.main.async {
                        let transcription = result.bestTranscription.formattedString
                        self.inputText = transcription
                        print("Speech recognition result: '\(transcription)'") // Debug log
                        
                        // Store final transcription
                        if result.isFinal {
                            self.finalTranscription = transcription
                            print("Storing final transcription: '\(transcription)'")
                        }
                    }
                    isFinal = result.isFinal
                }
                
                if let error = error {
                    print("Speech recognition error: \(error)")
                    // Don't change recording state here - let stopRecording handle it
                } else if isFinal {
                    print("Speech recognition completed (final result)")
                    // Don't change recording state here - let stopRecording handle it
                }
            }
            
            // Configure input node
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            
        } catch {
            print("Error starting recording: \(error)")
            isRecording = false
            showRecordingErrorAlert(error: error)
        }
    }
    
    private func stopRecording() {
        // Preserve the current text before cleanup
        let currentText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("Current text before cleanup: '\(currentText)'")
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        justFinishedRecording = true
        
        // Use final transcription or current text, whichever is better
        let textToUse = !finalTranscription.isEmpty ? finalTranscription : currentText
        
        // Restore the text after cleanup
        if !textToUse.isEmpty {
            inputText = textToUse
        }
        
        // Auto-send message if there's text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let trimmedText = textToUse.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Attempting to send text: '\(trimmedText)'") // Debug log
            
            if !trimmedText.isEmpty {
                print("Sending message automatically") // Debug log
                self.sendVoiceMessage(trimmedText)
            } else {
                print("No text to send") // Debug log
                // Reset the state if no text to send
                self.justFinishedRecording = false
            }
        }
        
        // Reset final transcription for next recording
        finalTranscription = ""
    }
    
    // MARK: - Error Handling Methods
    private func showSpeechPermissionAlert() {
        showingSpeechPermissionAlert = true
    }
    
    private func showSpeechUnavailableAlert() {
        showingSpeechUnavailableAlert = true
    }
    
    private func showRecordingErrorAlert(error: Error) {
        recordingError = error
        showingRecordingErrorAlert = true
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    let onActionTapped: ((AIAction) -> Void)?

    init(message: ChatMessage, onActionTapped: ((AIAction) -> Void)? = nil) {
        self.message = message
        self.onActionTapped = onActionTapped
    }

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .frame(maxWidth: 280, alignment: .trailing)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                        
                        Text(message.content)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .frame(maxWidth: 280, alignment: .leading)
                    }

                    // Action buttons for AI responses
                    if !message.actions.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(Array(message.actions.prefix(3).enumerated()), id: \.offset) { index, action in
                                Button(action: {
                                    onActionTapped?(action)
                                }) {
                                    Text(actionButtonTitle(for: action))
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.leading, 36)
                        .padding(.top, 4)
                    }

                    Text(message.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                }

                Spacer()
            }
        }
    }

    private func actionButtonTitle(for action: AIAction) -> String {
        switch action {
        case .summarizeAll:
            return "Summarize All"
        case .summarizeNote(_):
            return "Summarize Note"
        case .findRelated(_):
            return "Find Related"
        case .extractTasks:
            return "Extract Tasks"
        case .searchNotes(_):
            return "Search"
        case .categorizeNotes:
            return "Categorize"
        case .analyzeNote(_):
            return "Analyze"
        case .openNote(let note):
            return "Open '\(note.title.isEmpty ? "Untitled" : note.title)'"
        case .createNote(let title):
            return "Create '\(title)'"
        case .editNote(let note):
            return "Edit '\(note.title.isEmpty ? "Untitled" : note.title)'"
        case .showNotesByTag(let tag):
            return "Show #\(tag)"
        case .showNotesByCategory(let category):
            return "Show \(category)"
        case .showRecentNotes:
            return "Show Recent"
        case .showNotesByDate(let date):
            return "Show from \(date)"
        case .deleteNote(let note):
            return "Delete '\(note.title.isEmpty ? "Untitled" : note.title)'"
        case .duplicateNote(let note):
            return "Duplicate '\(note.title.isEmpty ? "Untitled" : note.title)'"
        }
    }
}

struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animationPhase
                            )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                animationPhase = 3
            }
        }
    }
}

struct ChatInputView: View {
    @Binding var inputText: String
    let isProcessing: Bool
    let isRecording: Bool
    let justFinishedRecording: Bool
    let onSend: () -> Void
    let onVoiceToggle: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            // Recording indicator
            if isRecording {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            } else if justFinishedRecording && !inputText.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Voice message ready to send")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            HStack(spacing: 12) {
                // Microphone button
                Button(action: onVoiceToggle) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(isRecording ? .red : .blue)
                        .scaleEffect(isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                }
                .disabled(isProcessing)
                
                TextField(isRecording ? "Listening..." : "Ask me anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($isTextFieldFocused)
                    .disabled(isRecording)
                    .onSubmit {
                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                        .scaleEffect(justFinishedRecording && !inputText.isEmpty ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: justFinishedRecording)
                }
                .disabled(inputText.isEmpty || isProcessing || isRecording)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextFieldFocused = false
                }
                .foregroundColor(.blue)
            }
        }
    }
}

#Preview {
    AIAssistantView()
        .environmentObject(NotesListViewModel())
}

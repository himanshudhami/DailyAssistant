//
//  AIAssistantView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

// MARK: - AI Action Types
enum AIAction {
    case summarizeAll
    case summarizeNote(Note)
    case findRelated(Note)
    case extractTasks
    case searchNotes(String)
    case categorizeNotes
    case analyzeNote(Note)
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
                }
                
                // Input Area
                ChatInputView(
                    inputText: $inputText,
                    isProcessing: isProcessing,
                    onSend: sendMessage
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
                // Load notes when view appears
                notesViewModel.loadNotes()
            }
            .alert("Clear Conversation", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearConversation()
                }
            } message: {
                Text("This will clear your entire conversation with the AI assistant. This action cannot be undone.")
            }
        }
    }
    
    private func addWelcomeMessage() {
        let noteCount = notesViewModel.notes.count
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
    
    private func processUserMessage(_ message: String) async -> (String, [AIAction], [Note]) {
        let lowercased = message.lowercased()
        let availableNotes = notesViewModel.notes

        // Handle different types of requests with real AI functionality
        if lowercased.contains("summarize all") || lowercased.contains("summary of all") {
            return await handleSummarizeAllRequest(availableNotes)
        } else if lowercased.contains("summarize") || lowercased.contains("summary") {
            return await handleSummarizeRequest(message, notes: availableNotes)
        } else if lowercased.contains("find") || lowercased.contains("search") {
            return await handleSearchRequest(message, notes: availableNotes)
        } else if lowercased.contains("action") || lowercased.contains("task") || lowercased.contains("todo") {
            return await handleActionItemsRequest(availableNotes)
        } else if lowercased.contains("organize") || lowercased.contains("category") || lowercased.contains("categorize") {
            return await handleOrganizeRequest(availableNotes)
        } else if lowercased.contains("related") || lowercased.contains("connection") {
            return await handleRelatedNotesRequest(message, notes: availableNotes)
        } else if lowercased.contains("hello") || lowercased.contains("hi") || lowercased.contains("hey") {
            return await handleGreeting(availableNotes)
        } else if lowercased.contains("help") {
            return await handleHelpRequest(availableNotes)
        } else {
            return await handleGeneralQuery(message, notes: availableNotes)
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
        let availableNotes = notesViewModel.notes

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
        return notes.filter { note in
            let searchableContent = "\(note.title) \(note.content) \(note.tags.joined(separator: " "))".lowercased()
            return searchTerms.contains { term in
                searchableContent.contains(term.lowercased())
            }
        }
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
        let response = "Here's what I can help you with:\n\n📝 **Content Analysis**\n• Summarize notes or all notes\n• Extract key points\n• Identify action items\n\n🏷️ **Organization**\n• Suggest categories and tags\n• Find related notes\n• Create smart groupings\n\n🔍 **Search & Discovery**\n• Natural language search\n• Content recommendations\n• Note insights\n\n🎯 **Productivity**\n• Task extraction\n• Priority suggestions\n• Follow-up reminders\n\nJust ask me anything! For example:\n• 'Summarize all my notes'\n• 'Find notes about meetings'\n• 'Extract all tasks'\n• 'Show me related notes'"

        let actions: [AIAction] = notes.isEmpty ? [] : [.summarizeAll, .extractTasks, .categorizeNotes]
        return (response, actions, [])
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
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Ask me anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit {
                        onSend()
                    }
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    AIAssistantView()
        .environmentObject(NotesListViewModel())
}

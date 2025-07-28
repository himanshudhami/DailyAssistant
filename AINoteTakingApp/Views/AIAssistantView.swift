//
//  AIAssistantView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct AIAssistantView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @StateObject private var aiProcessor = AIProcessor()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatMessageView(message: message)
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
            .onAppear {
                if messages.isEmpty {
                    addWelcomeMessage()
                }
            }
        }
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: "Hello! I'm your AI assistant. I can help you with:\n\n• Analyzing and summarizing your notes\n• Finding related content\n• Creating action items\n• Organizing your thoughts\n\nWhat would you like to do today?",
            isUser: false,
            timestamp: Date()
        )
        messages.append(welcomeMessage)
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
            let response = await processUserMessage(messageToProcess)
            
            await MainActor.run {
                let assistantMessage = ChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date()
                )
                messages.append(assistantMessage)
                isProcessing = false
            }
        }
    }
    
    private func processUserMessage(_ message: String) async -> String {
        // Simple AI assistant responses based on keywords
        let lowercased = message.lowercased()
        
        if lowercased.contains("summarize") || lowercased.contains("summary") {
            return "I can help you summarize your notes! To get started, please share the content you'd like me to summarize, or I can analyze your existing notes to find the most important points."
        } else if lowercased.contains("organize") || lowercased.contains("category") {
            return "I can help organize your notes by:\n\n• Suggesting categories based on content\n• Creating tags automatically\n• Grouping related notes together\n\nWould you like me to analyze your current notes and suggest an organization structure?"
        } else if lowercased.contains("action") || lowercased.contains("task") || lowercased.contains("todo") {
            return "I can extract action items from your notes! I look for phrases like:\n\n• 'Need to...'\n• 'Should...'\n• 'Must...'\n• 'Follow up on...'\n• 'Schedule...'\n\nShare some content and I'll identify actionable items for you."
        } else if lowercased.contains("search") || lowercased.contains("find") {
            return "I can help you find notes using natural language! Try asking:\n\n• 'Find notes about meetings'\n• 'Show me notes from last week'\n• 'Find notes with action items'\n• 'Search for notes about projects'\n\nWhat would you like to search for?"
        } else if lowercased.contains("hello") || lowercased.contains("hi") || lowercased.contains("hey") {
            return "Hello! I'm here to help you get the most out of your notes. I can analyze content, suggest improvements, help with organization, and much more. What can I assist you with today?"
        } else if lowercased.contains("help") {
            return "Here's what I can help you with:\n\n📝 **Content Analysis**\n• Summarize long notes\n• Extract key points\n• Identify action items\n\n🏷️ **Organization**\n• Suggest categories and tags\n• Find related notes\n• Create smart groupings\n\n🔍 **Search & Discovery**\n• Natural language search\n• Content recommendations\n• Note insights\n\n🎯 **Productivity**\n• Task extraction\n• Priority suggestions\n• Follow-up reminders\n\nJust ask me anything!"
        } else {
            // For other messages, provide a general helpful response
            return "I understand you're asking about: \"\(message)\"\n\nI'm designed to help with note-taking tasks like summarizing content, organizing notes, extracting action items, and finding information. Could you be more specific about what you'd like me to help you with?\n\nFor example:\n• 'Help me summarize this content...'\n• 'Find notes about...'\n• 'Organize my notes by...'\n• 'Extract tasks from...'"
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct ChatMessageView: View {
    let message: ChatMessage
    
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
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                }
                
                Spacer()
            }
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

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [Note] = []
    @State private var isSearching = false
    @State private var selectedFilters: Set<SearchFilter> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(
                    text: $searchText,
                    isSearching: $isSearching,
                    onSearchChanged: performSearch
                )
                
                // Filters
                SearchFiltersView(selectedFilters: $selectedFilters) {
                    performSearch(searchText)
                }
                
                // Results
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    EmptySearchView()
                } else if !searchResults.isEmpty {
                    SearchResultsList(results: searchResults)
                } else {
                    SearchSuggestionsView(onSuggestionTapped: { suggestion in
                        searchText = suggestion
                        performSearch(suggestion)
                    })
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Simulate search delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Implement actual search logic here
            searchResults = [] // Placeholder
            isSearching = false
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    let onSearchChanged: (String) -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search notes, content, tags...", text: $text)
                    .onSubmit {
                        onSearchChanged(text)
                    }
                    .onChange(of: text) { newValue in
                        onSearchChanged(newValue)
                    }
                
                if !text.isEmpty {
                    Button("Clear") {
                        text = ""
                        onSearchChanged("")
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
    }
}

enum SearchFilter: String, CaseIterable {
    case hasAudio = "Audio"
    case hasAttachments = "Attachments"
    case hasActionItems = "Tasks"
    case recent = "Recent"
    case favorites = "Favorites"
    
    var icon: String {
        switch self {
        case .hasAudio: return "waveform"
        case .hasAttachments: return "paperclip"
        case .hasActionItems: return "checkmark.circle"
        case .recent: return "clock"
        case .favorites: return "heart"
        }
    }
}

struct SearchFiltersView: View {
    @Binding var selectedFilters: Set<SearchFilter>
    let onFiltersChanged: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilters.contains(filter)
                    ) {
                        if selectedFilters.contains(filter) {
                            selectedFilters.remove(filter)
                        } else {
                            selectedFilters.insert(filter)
                        }
                        onFiltersChanged()
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct FilterChip: View {
    let filter: SearchFilter
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search terms or filters")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

struct SearchResultsList: View {
    let results: [Note]
    
    var body: some View {
        List(results) { note in
            SearchResultRow(note: note)
        }
        .listStyle(.plain)
    }
}

struct SearchResultRow: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.headline)
                .lineLimit(1)
            
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(note.modifiedDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if note.audioURL != nil {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if !note.attachments.isEmpty {
                    Image(systemName: "paperclip")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchSuggestionsView: View {
    let onSuggestionTapped: (String) -> Void
    
    private let suggestions = [
        "meeting notes",
        "action items",
        "today",
        "this week",
        "important",
        "project",
        "ideas",
        "tasks"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Suggestions")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSuggestionTapped(suggestion)
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            Text(suggestion)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
    }
}

struct SettingsView: View {
    @EnvironmentObject var securityManager: SecurityManager
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
                // Security Section
                Section("Security & Privacy") {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.blue)
                        Text("App Lock")
                        Spacer()
                        Toggle("", isOn: .constant(securityManager.isAppLockEnabled))
                            .onChange(of: securityManager.isAppLockEnabled) { newValue in
                                if newValue {
                                    securityManager.enableAppLock()
                                } else {
                                    securityManager.disableAppLock()
                                }
                            }
                    }
                    
                    HStack {
                        Image(systemName: securityManager.biometryType == .faceID ? "faceid" : "touchid")
                            .foregroundColor(.green)
                        Text("Biometric Authentication")
                        Spacer()
                        Text(securityManager.getBiometryTypeString())
                            .foregroundColor(.secondary)
                    }
                }
                
                // AI & Processing Section
                Section("AI & Processing") {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        Text("Auto-enhance Notes")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.orange)
                        Text("Real-time Transcription")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                }
                
                // Storage Section
                Section("Storage") {
                    HStack {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                        Text("iCloud Sync")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundColor(.gray)
                        Text("Storage Used")
                        Spacer()
                        Text("2.3 GB")
                            .foregroundColor(.secondary)
                    }
                }
                
                // About Section
                Section("About") {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("About AI Note Taking")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("AI Note Taking")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("An intelligent note-taking app powered by AI to help you capture, organize, and enhance your thoughts.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AIAssistantView()
}

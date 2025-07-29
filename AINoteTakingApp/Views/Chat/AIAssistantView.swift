//
//  AIAssistantView.swift
//  AINoteTakingApp
//
//  AI Assistant interface following SRP and clean architecture
//  Uses service layer for business logic and separate UI components
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI
import Speech
import AVFoundation

struct AIAssistantView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @StateObject private var assistantService = AIAssistantService()
    @StateObject private var speechManager = SpeechRecognitionManager()
    @EnvironmentObject var notesViewModel: NotesListViewModel
    
    // Navigation states
    @State private var showingNoteEditor = false
    @State private var selectedNoteForEditing: Note?
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
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
                
                // Input Area
                ChatInputView(
                    inputText: $inputText,
                    isProcessing: isProcessing,
                    isRecording: speechManager.isRecording,
                    justFinishedRecording: speechManager.justFinishedRecording,
                    onSend: sendMessage,
                    onVoiceToggle: speechManager.toggleVoiceRecording
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
                speechManager.setup()
            }
            .onReceive(speechManager.$recognizedText) { text in
                inputText = text
            }
            .onReceive(speechManager.$shouldAutoSend) { shouldSend in
                if shouldSend && !inputText.isEmpty {
                    sendVoiceMessage(inputText)
                }
            }
            .alert("Clear Conversation", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearConversation()
                }
            } message: {
                Text("This will clear your entire conversation with the AI assistant. This action cannot be undone.")
            }
            .sheet(isPresented: $showingNoteEditor) {
                if let note = selectedNoteForEditing {
                    NoteEditorView(note: note, currentFolder: notesViewModel.currentFolder)
                } else {
                    NoteEditorView(currentFolder: notesViewModel.currentFolder)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func addWelcomeMessage() {
        let dataManager = DataManager.shared
        let noteCount = dataManager.fetchAllNotes().count
        let contextualGreeting = assistantService.generateContextualGreeting(noteCount: noteCount)

        let welcomeMessage = ChatMessage(
            content: contextualGreeting,
            isUser: false,
            timestamp: Date(),
            actions: [.summarizeAll, .extractTasks, .categorizeNotes]
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
        speechManager.justFinishedRecording = false
        
        Task {
            let (response, actions, relatedNotes) = await assistantService.processUserMessage(messageToProcess)

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
        
        let userMessage = ChatMessage(
            content: text,
            isUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        inputText = ""
        isProcessing = true
        speechManager.justFinishedRecording = false
        
        Task {
            let (response, actions, relatedNotes) = await assistantService.processUserMessage(text)

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
    
    private func handleActionTap(_ action: AIAction) {
        Task {
            isProcessing = true
            
            // Handle navigation actions immediately
            switch action {
            case .openNote(let note), .editNote(let note):
                await MainActor.run {
                    selectedNoteForEditing = note
                    showingNoteEditor = true
                    isProcessing = false
                }
                return
            case .createNote(_):
                await MainActor.run {
                    selectedNoteForEditing = nil
                    showingNoteEditor = true
                    isProcessing = false
                }
                return
            default:
                break
            }
            
            let (response, newActions, relatedNotes) = await assistantService.processAction(action)

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
    
    private func clearConversation() {
        messages.removeAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addWelcomeMessage()
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    AIAssistantView()
        .environmentObject(NotesListViewModel())
}
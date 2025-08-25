//
//  VoiceRecorderView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct VoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioManager = AudioManager()
    @StateObject private var aiProcessor = AIProcessor()
    @State private var showingNoteEditor = false
    @State private var recordedNote: Note?
    
    let currentFolder: Folder?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Recording Visualization
                RecordingVisualization(
                    isRecording: audioManager.isRecording,
                    duration: audioManager.recordingDuration
                )
                
                // Transcript Display
                if !audioManager.currentTranscript.isEmpty {
                    TranscriptView(transcript: audioManager.currentTranscript)
                }
                
                Spacer()
                
                // Recording Controls
                RecordingControls(audioManager: audioManager) {
                    handleRecordingComplete()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if audioManager.isRecording {
                            audioManager.stopRecording()
                            // Give a moment for the recording to stop properly
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNoteEditor) {
            if let note = recordedNote {
                NoteEditorView(note: note)
            }
        }
        .alert("Error", isPresented: .constant(audioManager.errorMessage != nil)) {
            Button("OK") {
                audioManager.errorMessage = nil
            }
        } message: {
            if let errorMessage = audioManager.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func handleRecordingComplete() {
        print("🎤 handleRecordingComplete called")

        // Get the current transcript and recording URL immediately
        let currentTranscript = audioManager.currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let recordingURL = audioManager.getRecordingURL()

        print("🎤 Current transcript: '\(currentTranscript)'")
        print("🎤 Recording URL: \(recordingURL?.absoluteString ?? "nil")")
        
        // Clear the recorder after getting the URL
        audioManager.clearRecorder()

        // Always create a note, even if transcript is empty
        // Priority: Use current transcript > transcribe file > create empty note
        if !currentTranscript.isEmpty {
            print("🎤 Using current transcript")
            processTranscriptAndCreateNote(transcript: currentTranscript, audioURL: recordingURL)
        } else if let recordingURL = recordingURL {
            print("🎤 Transcribing audio file")
            Task {
                let transcript = await audioManager.transcribeAudioFile(at: recordingURL)
                let cleanTranscript = transcript?.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🎤 File transcript: '\(cleanTranscript ?? "nil")'")

                await MainActor.run {
                    processTranscriptAndCreateNote(transcript: cleanTranscript, audioURL: recordingURL)
                }
            }
        } else {
            print("🎤 No recording or transcript, creating empty note")
            processTranscriptAndCreateNote(transcript: "Voice recording completed", audioURL: nil)
        }

        // Fallback: If nothing happens within 3 seconds, force create a note
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !self.showingNoteEditor {
                print("🎤 Fallback: Force creating note")
                let fallbackNote = Note(
                    title: "Voice Note \(Date().formatted(date: .omitted, time: .shortened))",
                    content: currentTranscript.isEmpty ? "Voice recording completed" : currentTranscript,
                    audioURL: recordingURL,
                    tags: ["voice", "recording"],
                    category: Category(name: "Voice Notes", color: "#FF6B6B")
                )
                self.recordedNote = fallbackNote
                self.showingNoteEditor = true
            }
        }
    }

    private func processTranscriptAndCreateNote(transcript: String?, audioURL: URL?) {
        print("🎤 processTranscriptAndCreateNote called with transcript: '\(transcript ?? "nil")'")

        Task {
            // Process with AI if transcript is available
            var processedContent: ProcessedContent?
            if let transcript = transcript, !transcript.isEmpty {
                print("🎤 Processing with AI...")
                processedContent = await aiProcessor.processContent(transcript)
                print("🎤 AI processing complete")
            }

            await MainActor.run {
                print("🎤 Creating note...")

                // Determine note title and content
                let finalTranscript = transcript?.isEmpty == false ? transcript! : "Voice recording completed"
                let noteTitle = processedContent?.summary.prefix(50).description ??
                               (audioURL != nil ? "Voice Note \(Date().formatted(date: .omitted, time: .shortened))" : "Voice Note")

                // Save the note to database using DataManager with full voice note metadata
                let dataManager = DataManager.shared
                let savedNote = dataManager.createVoiceNote(
                    title: noteTitle,
                    content: finalTranscript,
                    audioURL: audioURL,
                    transcript: finalTranscript,
                    tags: ["voice", "recording"],
                    category: Category(name: "Voice Notes", color: "#FF6B6B"),
                    folderId: currentFolder?.id,
                    aiSummary: processedContent?.summary,
                    keyPoints: processedContent?.keyPoints ?? [],
                    actionItems: processedContent?.actionItems ?? []
                )

                print("🎤 Note saved to database: '\(savedNote.title)' with content: '\(savedNote.content.prefix(50))...'")
                print("🎤 Note folder ID: \(savedNote.folderId?.uuidString ?? "root")")

                recordedNote = savedNote
                showingNoteEditor = true
                
                // Notify that a new note was created
                NotificationCenter.default.post(name: Notification.Name("NotesDidChange"), object: nil)

                print("🎤 showingNoteEditor set to true")
            }
        }
    }
}

struct RecordingVisualization: View {
    let isRecording: Bool
    let duration: TimeInterval
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Recording Button/Indicator
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animationScale)
                    .animation(
                        isRecording ? 
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                        Animation.default,
                        value: animationScale
                    )
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .onAppear {
                if isRecording {
                    animationScale = 1.2
                }
            }
            .onChange(of: isRecording) { newValue in
                animationScale = newValue ? 1.2 : 1.0
            }
            
            // Duration Display
            Text(formatDuration(duration))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(isRecording ? .red : .primary)
            
            // Status Text
            Text(isRecording ? "Recording..." : "Tap to start recording")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct TranscriptView: View {
    let transcript: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.blue)
                Text("Live Transcript")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            ScrollView {
                Text(transcript)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .frame(maxHeight: 200)
        }
    }
}

struct RecordingControls: View {
    @ObservedObject var audioManager: AudioManager
    let onRecordingComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Main Record/Stop Button
            Button(action: {
                print("🎤 Button tapped, isRecording: \(audioManager.isRecording)")
                if audioManager.isRecording {
                    print("🎤 Stopping recording...")
                    audioManager.stopRecording()
                    // Small delay to ensure recording stops properly before processing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print("🎤 Calling onRecordingComplete...")
                        onRecordingComplete()
                    }
                } else {
                    print("🎤 Starting recording...")
                    audioManager.startRecording()
                }
            }) {
                VStack {
                    Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 80))
                        .foregroundColor(audioManager.isRecording ? .red : .blue)

                    Text(audioManager.isRecording ? "Stop & Save" : "Start Recording")
                        .font(.headline)
                        .foregroundColor(audioManager.isRecording ? .red : .blue)
                }
            }
            .disabled(!audioManager.hasPermission)

            // Recording status
            if audioManager.isRecording {
                Text("Tap to stop and save your note")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        
        // Permission message
        if !audioManager.hasPermission {
            Text("Microphone and speech recognition permissions are required")
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.top)
        }
    }
}

struct AIProcessingView: View {
    let content: String
    let onProcessingComplete: (ProcessedContent) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiProcessor = AIProcessor()
    @State private var processedContent: ProcessedContent?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if aiProcessor.isProcessing {
                    ProcessingView(progress: aiProcessor.processingProgress)
                } else if let processed = processedContent {
                    ProcessedContentView(content: processed) {
                        onProcessingComplete(processed)
                        dismiss()
                    }
                } else {
                    ContentPreview(content: content)
                }
            }
            .padding()
            .navigationTitle("AI Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            processContent()
        }
    }
    
    private func processContent() {
        Task {
            print("🚀 AI Enhancement: Starting enhanced content processing...")
            
            // Use the existing AIProcessor which now supports structured content processing
            let result = await aiProcessor.processContent(content)
            
            await MainActor.run {
                processedContent = result
            }
            
            print("✅ AI Enhancement: Processing complete")
            print("📄 Summary: \(result.summary)")
            print("⚡ Action items: \(result.actionItems.count)")
            print("🏷️ Tags: \(result.suggestedTags.joined(separator: ", "))")
            
            if result.suggestedCategory?.name.lowercased().contains("contact") == true {
                print("🎯 Business card processing detected!")
            }
        }
    }
    
}

struct ProcessingView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // AI Brain Animation
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.1)
                .animation(.easeInOut(duration: 1).repeatForever(), value: UUID())
            
            Text("AI is processing your content...")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(maxWidth: 200)
            
            Text("\(Int(progress * 100))% complete")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct ProcessedContentView: View {
    let content: ProcessedContent
    let onApply: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary
                if !content.summary.isEmpty {
                    ProcessedSection(
                        title: "Summary",
                        icon: "text.alignleft",
                        color: .blue
                    ) {
                        Text(content.summary)
                    }
                }
                
                // Key Points
                if !content.keyPoints.isEmpty {
                    ProcessedSection(
                        title: "Key Points",
                        icon: "key.fill",
                        color: .orange
                    ) {
                        ForEach(content.keyPoints, id: \.self) { point in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(point)
                                Spacer()
                            }
                        }
                    }
                }
                
                // Action Items
                if !content.actionItems.isEmpty {
                    ProcessedSection(
                        title: "Action Items",
                        icon: "checkmark.circle",
                        color: .green
                    ) {
                        ForEach(content.actionItems) { item in
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                                Text(item.title)
                                Spacer()
                                Circle()
                                    .fill(Color(hex: item.priority.color))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                
                // Suggested Tags
                if !content.suggestedTags.isEmpty {
                    ProcessedSection(
                        title: "Suggested Tags",
                        icon: "tag",
                        color: .purple
                    ) {
                        FlowLayout(spacing: 8) {
                            ForEach(content.suggestedTags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Apply Button
                Button("Apply AI Enhancements") {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.top)
            }
        }
    }
}

struct ProcessedSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct ContentPreview: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content to Process")
                .font(.headline)
            
            ScrollView {
                Text(content)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 300)
            
            Button("Start AI Processing") {
                // Processing will start automatically
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        
        init(onImageSelected: @escaping (UIImage) -> Void) {
            self.onImageSelected = onImageSelected
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    VoiceRecorderView(currentFolder: nil)
}

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

        // Fallback: If nothing happens within 3 seconds, dismiss the view
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.recordedNote == nil {
                print("🎤 Fallback: No note created after 3 seconds, dismissing")
                self.dismiss()
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
                
                // Notify that a new note was created
                NotificationCenter.default.post(name: Notification.Name("NotesDidChange"), object: nil)
                
                print("🎤 Note saved successfully, dismissing voice recorder")
                
                // Dismiss the voice recorder view instead of showing note editor
                dismiss()
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

// AI Processing views have been moved to AIProcessingView.swift for better separation of concerns

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

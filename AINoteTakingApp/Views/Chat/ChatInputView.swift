//
//  ChatInputView.swift
//  AINoteTakingApp
//
//  Chat input component with voice recording support
//  Extracted from AIAssistantView for better separation of concerns
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI

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
    ChatInputView(
        inputText: .constant(""),
        isProcessing: false,
        isRecording: false,
        justFinishedRecording: false,
        onSend: {},
        onVoiceToggle: {}
    )
}
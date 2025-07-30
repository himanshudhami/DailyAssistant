//
//  ChatMessageView.swift
//  AINoteTakingApp
//
//  Individual chat message view component
//  Extracted from AIAssistantView for better separation of concerns
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
    let onActionTapped: ((AIAction) -> Void)?
    @State private var isExpanded = false

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

                        VStack(alignment: .leading, spacing: 8) {
                            // Message content with expand/collapse functionality
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isExpanded ? message.content : String(message.content.prefix(200)))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(16)
                                    .frame(maxWidth: 280, alignment: .leading)

                                // Show expand/collapse button if content is long
                                if message.content.count > 200 {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isExpanded.toggle()
                                        }
                                    }) {
                                        Text(isExpanded ? "Show less" : "Show more")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                    }
                                }
                            }

                            // Related notes section
                            if !message.relatedNotes.isEmpty {
                                RelatedNotesView(
                                    notes: message.relatedNotes,
                                    onNoteTapped: { note in
                                        onActionTapped?(.openNote(note))
                                    }
                                )
                            }
                        }
                    }

                    // Action buttons for AI responses
                    if !message.actions.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(Array(message.actions.prefix(3).enumerated()), id: \.offset) { index, action in
                                Button(action: {
                                    onActionTapped?(action)
                                }) {
                                    Text(action.buttonTitle)
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
}

#Preview {
    VStack(spacing: 16) {
        ChatMessageView(
            message: ChatMessage(
                content: "Hello! How can I help you today?",
                isUser: false,
                timestamp: Date(),
                actions: [.summarizeAll, .extractTasks]
            )
        )
        
        ChatMessageView(
            message: ChatMessage(
                content: "Can you summarize my notes?",
                isUser: true,
                timestamp: Date()
            )
        )
    }
    .padding()
}

// MARK: - Related Notes View
struct RelatedNotesView: View {
    let notes: [Note]
    let onNoteTapped: (Note) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related Notes:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            LazyVStack(spacing: 6) {
                ForEach(notes.prefix(5), id: \.id) { note in
                    RelatedNoteCard(note: note, onTapped: {
                        onNoteTapped(note)
                    })
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Related Note Card
struct RelatedNoteCard: View {
    let note: Note
    let onTapped: () -> Void

    var body: some View {
        Button(action: onTapped) {
            HStack(spacing: 8) {
                // Note icon
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 2) {
                    // Note title
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Note preview
                    Text(note.content.isEmpty ? "No content" : note.content)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
            .frame(maxWidth: 260)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
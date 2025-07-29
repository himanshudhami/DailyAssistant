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
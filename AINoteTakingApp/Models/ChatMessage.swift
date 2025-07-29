//
//  ChatMessage.swift
//  AINoteTakingApp
//
//  Chat message model and utilities for AI Assistant
//  Separated from main AI Assistant view for better organization
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation

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

// MARK: - Action Button Utilities
extension AIAction {
    var buttonTitle: String {
        switch self {
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
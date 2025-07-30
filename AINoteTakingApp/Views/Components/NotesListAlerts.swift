//
//  NotesListAlerts.swift
//  AINoteTakingApp
//
//  Alert components for the notes list view.
//  Handles delete confirmations and folder management alerts.
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI

// MARK: - Notes List Alerts Container
struct NotesListAlerts: ViewModifier {
    // Alert states
    @Binding var showingDeleteAlert: Bool
    @Binding var noteToDelete: Note?
    @Binding var folderToDelete: Folder?
    @Binding var folderToRename: Folder?
    @Binding var newFolderName: String
    
    // Actions
    let onDeleteNote: (Note) -> Void
    let onDeleteFolder: (Folder, Bool) -> Void
    let onRenameFolder: (Folder, String) -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Delete Note", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    noteToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let note = noteToDelete {
                        onDeleteNote(note)
                    }
                    noteToDelete = nil
                }
            } message: {
                if let note = noteToDelete {
                    Text("Are you sure you want to delete \"\(note.title.isEmpty ? "Untitled" : note.title)\"? This action cannot be undone.")
                }
            }
            .alert("Delete Folder", isPresented: Binding<Bool>(
                get: { folderToDelete != nil },
                set: { if !$0 { folderToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    folderToDelete = nil
                }
                Button("Move Contents Up", role: .cancel) {
                    if let folder = folderToDelete {
                        onDeleteFolder(folder, false)
                    }
                    folderToDelete = nil
                }
                Button("Delete Everything", role: .destructive) {
                    if let folder = folderToDelete {
                        onDeleteFolder(folder, true)
                    }
                    folderToDelete = nil
                }
            } message: {
                if let folder = folderToDelete {
                    Text("Choose how to handle \"\(folder.name)\":\n• Move Contents Up: Move all notes and subfolders to parent\n• Delete Everything: Permanently delete folder and all contents")
                }
            }
            .alert("Rename Folder", isPresented: Binding<Bool>(
                get: { folderToRename != nil },
                set: { if !$0 { folderToRename = nil; newFolderName = "" } }
            )) {
                TextField("Folder Name", text: $newFolderName)
                Button("Cancel", role: .cancel) {
                    folderToRename = nil
                    newFolderName = ""
                }
                Button("Rename") {
                    if let folder = folderToRename, !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onRenameFolder(folder, newFolderName.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    folderToRename = nil
                    newFolderName = ""
                }
            } message: {
                Text("Enter a new name for the folder.")
            }
    }
}

// MARK: - Individual Alert Components

// MARK: - Delete Note Alert
struct DeleteNoteAlert: ViewModifier {
    @Binding var isPresented: Bool
    let note: Note?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Delete Note", isPresented: $isPresented) {
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Delete", role: .destructive, action: onConfirm)
            } message: {
                if let note = note {
                    Text("Are you sure you want to delete \"\(note.displayTitle)\"? This action cannot be undone.")
                }
            }
    }
}

// MARK: - Delete Folder Alert
struct DeleteFolderAlert: ViewModifier {
    @Binding var isPresented: Bool
    let folder: Folder?
    let onMoveContentsUp: () -> Void
    let onDeleteEverything: () -> Void
    let onCancel: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Delete Folder", isPresented: $isPresented) {
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Move Contents Up", role: .cancel, action: onMoveContentsUp)
                Button("Delete Everything", role: .destructive, action: onDeleteEverything)
            } message: {
                if let folder = folder {
                    Text("Choose how to handle \"\(folder.name)\":\n• Move Contents Up: Move all notes and subfolders to parent\n• Delete Everything: Permanently delete folder and all contents")
                }
            }
    }
}

// MARK: - Rename Folder Alert
struct RenameFolderAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var folderName: String
    let folder: Folder?
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Rename Folder", isPresented: $isPresented) {
                TextField("Folder Name", text: $folderName)
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Rename") {
                    let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        onConfirm(trimmedName)
                    }
                }
            } message: {
                Text("Enter a new name for the folder.")
            }
    }
}

// MARK: - Alert Actions Protocol
protocol NotesListAlertActions {
    func deleteNote(_ note: Note)
    func deleteFolder(_ folder: Folder, cascadeDelete: Bool)
    func renameFolder(_ folder: Folder, newName: String)
}

// MARK: - Alert State Manager
@MainActor
class NotesListAlertState: ObservableObject {
    // Delete note alert
    @Published var showingDeleteAlert = false
    @Published var noteToDelete: Note?
    
    // Delete folder alert
    @Published var folderToDelete: Folder?
    
    // Rename folder alert
    @Published var folderToRename: Folder?
    @Published var newFolderName = ""
    
    // MARK: - Public Methods
    
    func confirmDeleteNote(_ note: Note) {
        noteToDelete = note
        showingDeleteAlert = true
    }
    
    func confirmDeleteFolder(_ folder: Folder) {
        folderToDelete = folder
    }
    
    func confirmRenameFolder(_ folder: Folder) {
        folderToRename = folder
        newFolderName = folder.name
    }
    
    func clearAllAlerts() {
        showingDeleteAlert = false
        noteToDelete = nil
        folderToDelete = nil
        folderToRename = nil
        newFolderName = ""
    }
}

// MARK: - View Extensions
extension View {
    func notesListAlerts(
        alertState: NotesListAlertState,
        actions: NotesListAlertActions
    ) -> some View {
        self.modifier(
            NotesListAlerts(
                showingDeleteAlert: Binding(
                    get: { alertState.showingDeleteAlert },
                    set: { alertState.showingDeleteAlert = $0 }
                ),
                noteToDelete: Binding(
                    get: { alertState.noteToDelete },
                    set: { alertState.noteToDelete = $0 }
                ),
                folderToDelete: Binding(
                    get: { alertState.folderToDelete },
                    set: { alertState.folderToDelete = $0 }
                ),
                folderToRename: Binding(
                    get: { alertState.folderToRename },
                    set: { alertState.folderToRename = $0 }
                ),
                newFolderName: Binding(
                    get: { alertState.newFolderName },
                    set: { alertState.newFolderName = $0 }
                ),
                onDeleteNote: actions.deleteNote,
                onDeleteFolder: actions.deleteFolder,
                onRenameFolder: actions.renameFolder
            )
        )
    }
    
    func deleteNoteAlert(
        isPresented: Binding<Bool>,
        note: Note?,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(
            DeleteNoteAlert(
                isPresented: isPresented,
                note: note,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
    }
    
    func deleteFolderAlert(
        isPresented: Binding<Bool>,
        folder: Folder?,
        onMoveContentsUp: @escaping () -> Void,
        onDeleteEverything: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(
            DeleteFolderAlert(
                isPresented: isPresented,
                folder: folder,
                onMoveContentsUp: onMoveContentsUp,
                onDeleteEverything: onDeleteEverything,
                onCancel: onCancel
            )
        )
    }
    
    func renameFolderAlert(
        isPresented: Binding<Bool>,
        folderName: Binding<String>,
        folder: Folder?,
        onConfirm: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(
            RenameFolderAlert(
                isPresented: isPresented,
                folderName: folderName,
                folder: folder,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
    }
}

// MARK: - Note Extension for Display
extension Note {
    var displayTitle: String {
        return title.isEmpty ? "Untitled" : title
    }
}

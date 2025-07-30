//
//  NotesListToolbar.swift
//  AINoteTakingApp
//
//  Toolbar component for the notes list view.
//  Provides quick access to voice recording, camera, and note creation.
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI

// MARK: - Notes List Toolbar
struct NotesListToolbar: View {
    @Environment(\.appTheme) private var theme
    
    // Bindings for sheet presentation
    @Binding var showingVoiceRecorder: Bool
    @Binding var showingCamera: Bool
    @Binding var showingNoteEditor: Bool
    
    // View model and state
    @ObservedObject var viewModel: NotesListViewModel
    let isProcessingCamera: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Voice Recording Button
            VoiceRecordingButton(
                action: { showingVoiceRecorder = true }
            )
            
            // Camera Button
            CameraButton(
                action: { showingCamera = true },
                isDisabled: isProcessingCamera
            )
            
            // Add Note Menu
            AddNoteMenu(
                showingNoteEditor: $showingNoteEditor,
                viewModel: viewModel
            )
        }
    }
}

// MARK: - Voice Recording Button
struct VoiceRecordingButton: View {
    let action: () -> Void
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.circle.fill")
                .foregroundColor(theme.error)
                .font(.title)
        }
        .accessibilityLabel("Record voice note")
        .accessibilityHint("Tap to start recording a voice note")
    }
}

// MARK: - Add Note Menu
struct AddNoteMenu: View {
    @Environment(\.appTheme) private var theme
    @Binding var showingNoteEditor: Bool
    @ObservedObject var viewModel: NotesListViewModel
    
    var body: some View {
        Menu {
            // Primary action - New Log
            Button("New Log") {
                showingNoteEditor = true
            }
            
            // Folder-specific creation options
            if !viewModel.folders.isEmpty && viewModel.currentFolder == nil {
                Divider()
                Text("Create in Folder:")
                
                ForEach(viewModel.folders.prefix(5), id: \.id) { folder in
                    Button("📁 \(folder.name)") {
                        viewModel.enterFolder(folder)
                        showingNoteEditor = true
                    }
                }
                
                if viewModel.folders.count > 5 {
                    Button("More folders...") {
                        // Could show a folder picker sheet
                    }
                }
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(theme.primary)
                .font(.title)
        } primaryAction: {
            showingNoteEditor = true
        }
        .accessibilityLabel("Add new note")
        .accessibilityHint("Tap to create a new note, or hold for more options")
    }
}

// MARK: - Toolbar Actions Protocol
protocol NotesListToolbarActions {
    func showVoiceRecorder()
    func showCamera()
    func showNoteEditor()
    func createNoteInFolder(_ folder: Folder)
}

// MARK: - Toolbar Actions Implementation
struct NotesListToolbarActionsImpl: NotesListToolbarActions {
    @Binding var showingVoiceRecorder: Bool
    @Binding var showingCamera: Bool
    @Binding var showingNoteEditor: Bool
    let viewModel: NotesListViewModel
    
    func showVoiceRecorder() {
        showingVoiceRecorder = true
    }
    
    func showCamera() {
        showingCamera = true
    }
    
    func showNoteEditor() {
        showingNoteEditor = true
    }

    @MainActor
    func createNoteInFolder(_ folder: Folder) {
        viewModel.enterFolder(folder)
        showingNoteEditor = true
    }
}

// MARK: - Toolbar Configuration
struct NotesListToolbarConfiguration {
    let showVoiceButton: Bool
    let showCameraButton: Bool
    let showAddButton: Bool
    let showFolderOptions: Bool
    
    static let `default` = NotesListToolbarConfiguration(
        showVoiceButton: true,
        showCameraButton: true,
        showAddButton: true,
        showFolderOptions: true
    )
    
    static let minimal = NotesListToolbarConfiguration(
        showVoiceButton: false,
        showCameraButton: false,
        showAddButton: true,
        showFolderOptions: false
    )
}

// MARK: - Configurable Toolbar
struct ConfigurableNotesListToolbar: View {
    @Environment(\.appTheme) private var theme
    
    let configuration: NotesListToolbarConfiguration
    let actions: NotesListToolbarActions
    let viewModel: NotesListViewModel
    let isProcessingCamera: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            if configuration.showVoiceButton {
                VoiceRecordingButton(action: actions.showVoiceRecorder)
            }
            
            if configuration.showCameraButton {
                CameraButton(
                    action: actions.showCamera,
                    isDisabled: isProcessingCamera
                )
            }
            
            if configuration.showAddButton {
                if configuration.showFolderOptions {
                    AddNoteMenu(
                        showingNoteEditor: .constant(false), // This would need proper binding
                        viewModel: viewModel
                    )
                } else {
                    Button(action: actions.showNoteEditor) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(theme.primary)
                            .font(.title)
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NotesListToolbar(
            showingVoiceRecorder: .constant(false),
            showingCamera: .constant(false),
            showingNoteEditor: .constant(false),
            viewModel: NotesListViewModel(),
            isProcessingCamera: false
        )
        
        HStack {
            VoiceRecordingButton(action: {})
            CameraButton(action: {}, isDisabled: false)
            CameraButton(action: {}, isDisabled: true)
        }
    }
    .padding()
}

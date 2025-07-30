//
//  NotesListView.swift
//  AINoteTakingApp
//
//  Main view for displaying and managing notes with hierarchical folder organization.
//  Supports search, filtering, categorization, and multiple view modes (list/grid).
//  Integrates with SQLite database through Core Data for persistent storage.
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI
import CoreData
import UIKit
import CoreLocation

struct NotesListView: View {
    @Environment(\.appTheme) private var theme
    @StateObject private var viewModel = NotesListViewModel()
    
    // Search and filter states
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var sortOption: NoteSortOption = .modifiedDate
    @State private var viewMode: ViewMode = .list
    
    // Sheet and navigation states
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    @State private var showingVoiceRecorder = false
    @State private var showingCreateFolder = false
    @State private var showingCamera = false
    @State private var isProcessingCameraNote = false
    
    // Alert states
    @State private var showingDeleteAlert = false
    @State private var noteToDelete: Note?
    @State private var folderToDelete: Folder?
    @State private var folderToRename: Folder?
    @State private var newFolderName = ""
    
    private var currentFolders: [Folder] {
        return viewModel.folders.filter { $0.parentFolderId == viewModel.currentFolder?.id }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                breadcrumbSection
                mainContentSection
            }
            .navigationTitle(viewModel.currentFolder?.name ?? "MyLogs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarContent
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search logs...")
        .onChange(of: searchText) { newValue in
            viewModel.searchNotes(with: newValue)
        }
        .onChange(of: selectedCategory) { newValue in
            viewModel.filterByCategory(newValue)
        }
        .onChange(of: sortOption) { newValue in
            viewModel.sortNotes(by: newValue)
        }
        .onChange(of: viewModel.currentFolder) { _ in
            viewModel.loadNotes()
        }
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(note: selectedNote, currentFolder: viewModel.currentFolder)
        }
        .onChange(of: showingNoteEditor) { isShowing in
            if !isShowing {
                selectedNote = nil
            }
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecorderView(currentFolder: viewModel.currentFolder)
        }
        .sheet(isPresented: $showingCreateFolder) {
            CreateFolderSheet { folderName in
                viewModel.createFolder(name: folderName)
            }
        }
        .sheet(isPresented: $showingCamera) {
            SimpleCameraView { image in
                Task { @MainActor in
                    isProcessingCameraNote = true

                    // Create services
                    let locationService = SimpleLocationService()
                    let ocrService = OCRService()

                    // Get location
                    let location = await locationService.getCurrentLocationSafely()
                    print("📍 Location captured: \(location?.latitude ?? 0), \(location?.longitude ?? 0)")

                    // Perform OCR
                    let ocrResult = await ocrService.performOCR(on: image)

                    // Create note with image attachment
                    let dataManager = DataManager.shared
                    let currentFolderId = viewModel.currentFolder?.id

                    // Create the note first
                    let note = dataManager.createCameraNote(
                        image: image,
                        ocrText: ocrResult.rawText.isEmpty ? nil : ocrResult.rawText,
                        latitude: location?.latitude,
                        longitude: location?.longitude,
                        folderId: currentFolderId
                    )

                    // Create and save image attachment
                    do {
                        // Get documents directory
                        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let attachmentsDir = documentsDirectory.appendingPathComponent("Attachments")

                        // Create directory if needed
                        try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

                        // Convert image to JPEG data
                        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                            throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
                        }

                        // Generate unique filename and save image
                        let fileName = "\(UUID().uuidString).jpg"
                        let imageURL = attachmentsDir.appendingPathComponent(fileName)
                        try imageData.write(to: imageURL)

                        // Create thumbnail
                        let thumbnailData = image.resizedForEditor(to: CGSize(width: 200, height: 200)).jpegData(compressionQuality: 0.7)

                        // Create attachment
                        let attachment = Attachment(
                            fileName: fileName,
                            fileExtension: "jpg",
                            mimeType: "image/jpeg",
                            fileSize: Int64(imageData.count),
                            localURL: imageURL,
                            thumbnailData: thumbnailData,
                            type: .image
                        )

                        var updatedNote = note
                        updatedNote.attachments = [attachment]
                        _ = dataManager.updateNote(updatedNote)

                        // Refresh the view
                        viewModel.loadNotes()

                        isProcessingCameraNote = false
                    } catch {
                        print("❌ Failed to create image attachment: \(error)")
                        isProcessingCameraNote = false
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadNotes()
            viewModel.loadFolders()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NotesDidChange"))) { _ in
            viewModel.refresh()
        }
        .alert("Delete Note", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.deleteNote(note)
                    }
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
                    viewModel.deleteFolder(folder, cascadeDelete: false)
                }
                folderToDelete = nil
            }
            Button("Delete Everything", role: .destructive) {
                if let folder = folderToDelete {
                    viewModel.deleteFolder(folder, cascadeDelete: true)
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
                    var updatedFolder = folder
                    updatedFolder.name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let index = viewModel.folders.firstIndex(where: { $0.id == folder.id }) {
                        viewModel.folders[index] = updatedFolder
                    }
                }
                folderToRename = nil
                newFolderName = ""
            }
        } message: {
            Text("Enter a new name for the folder.")
        }
    }

    // MARK: - Helper Methods
    private func confirmDelete(_ note: Note) {
        noteToDelete = note
        showingDeleteAlert = true
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private var breadcrumbSection: some View {
        if !viewModel.folderHierarchy.isEmpty || viewModel.currentFolder != nil {
            VStack(spacing: 0) {
                BreadcrumbView(
                    hierarchy: viewModel.folderHierarchy,
                    onNavigate: { folder in
                        viewModel.enterFolder(folder)
                    },
                    onNavigateToRoot: {
                        viewModel.currentFolder = nil
                        viewModel.loadFolders()
                        viewModel.loadNotes()
                    }
                )
                
                quickFolderSwitcher
            }
        }
    }
    
    @ViewBuilder
    private var quickFolderSwitcher: some View {
        if !viewModel.folders.isEmpty && viewModel.currentFolder == nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.folders.prefix(10), id: \.id) { folder in
                        folderChip(folder)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 32)
        }
    }
    
    @ViewBuilder
    private func folderChip(_ folder: Folder) -> some View {
        Button(action: {
            viewModel.enterFolder(folder)
        }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(folderGradient(folder))
                    .frame(width: 12, height: 12)
                
                Text(folder.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func folderGradient(_ folder: Folder) -> LinearGradient {
        LinearGradient(
            colors: folder.gradientColors.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    @ViewBuilder
    private var mainContentSection: some View {
        TopControlsBar(
            searchText: $searchText,
            selectedCategory: $selectedCategory,
            sortOption: $sortOption,
            viewMode: $viewMode,
            categories: viewModel.categories,
            onCreateFolder: { showingCreateFolder = true }
        )
        
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            if viewModel.filteredNotes.isEmpty && currentFolders.isEmpty {
                EmptyStateView(
                    showingNoteEditor: $showingNoteEditor,
                    showingVoiceRecorder: $showingVoiceRecorder,
                    showingCamera: $showingCamera,
                    isProcessingCameraNote: $isProcessingCameraNote
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NotesContentView(
                    notes: viewModel.filteredNotes,
                    folders: currentFolders,
                    viewMode: viewMode,
                    selectedNote: $selectedNote,
                    showingNoteEditor: $showingNoteEditor,
                    onDeleteNote: confirmDelete,
                    onFolderRename: { folder in
                        folderToRename = folder
                        newFolderName = folder.name
                    },
                    onFolderDelete: { folder in
                        folderToDelete = folder
                    }
                )
                .environmentObject(viewModel)
            }
        }
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        HStack(spacing: 16) {
            Button(action: { showingVoiceRecorder = true }) {
                Image(systemName: "mic.circle.fill")
                    .foregroundColor(theme.error)
                    .font(.title)
            }

            Button(action: { showingCamera = true }) {
                Image(systemName: "camera.circle.fill")
                    .foregroundColor(theme.accent)
                    .font(.title)
            }
            .disabled(isProcessingCameraNote)

            Menu {
                Button("New Log") {
                    showingNoteEditor = true
                }

                if !viewModel.folders.isEmpty && viewModel.currentFolder == nil {
                    Divider()
                    Text("Create in Folder:")
                    ForEach(viewModel.folders.prefix(5), id: \.id) { folder in
                        Button("📁 \(folder.name)") {
                            viewModel.enterFolder(folder)
                            showingNoteEditor = true
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
        }
    }
}

// MARK: - Top Controls Bar
struct TopControlsBar: View {
    @Environment(\.appTheme) private var theme
    @Binding var searchText: String
    @Binding var selectedCategory: Category?
    @Binding var sortOption: NoteSortOption
    @Binding var viewMode: ViewMode
    let categories: [Category]
    let onCreateFolder: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            // First row: Category and Sort
            HStack {
                CategoryFilterButton(
                    selectedCategory: $selectedCategory,
                    categories: categories
                )
                
                Spacer()
                
                SortOptionsButton(sortOption: $sortOption)
                
                if let onCreateFolder = onCreateFolder {
                    Button(action: onCreateFolder) {
                        Image(systemName: "folder.badge.plus")
                            .font(.caption)
                            .foregroundColor(theme.primary)
                    }
                }
                
                ViewModeButton(viewMode: $viewMode)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(theme.background)
    }
}

// MARK: - Filter Components
struct CategoryFilterButton: View {
    @Environment(\.appTheme) private var theme
    @Binding var selectedCategory: Category?
    let categories: [Category]
    
    var body: some View {
        Menu {
            Button("All Categories") {
                selectedCategory = nil
            }
            
            Divider()
            
            ForEach(categories) { category in
                Button(category.name) {
                    selectedCategory = category
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.caption)
                Text(selectedCategory?.name ?? "All")
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.sectionBackground)
            .cornerRadius(8)
        }
    }
}

struct SortOptionsButton: View {
    @Environment(\.appTheme) private var theme
    @Binding var sortOption: NoteSortOption
    
    var body: some View {
        Menu {
            ForEach(NoteSortOption.allCases, id: \.self) { option in
                Button(option.rawValue) {
                    sortOption = option
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                Text(sortOption.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.sectionBackground)
            .cornerRadius(8)
        }
    }
}

struct ViewModeButton: View {
    @Environment(\.appTheme) private var theme
    @Binding var viewMode: ViewMode
    
    var body: some View {
        Button(action: {
            viewMode = viewMode == .grid ? .list : .grid
        }) {
            Image(systemName: viewMode.systemImageName)
                .font(.caption)
                .foregroundColor(theme.textPrimary)
                .padding(8)
                .background(theme.sectionBackground)
                .cornerRadius(8)
        }
    }
}

// MARK: - Notes Content View
struct NotesContentView: View {
    let notes: [Note]
    let folders: [Folder]
    let viewMode: ViewMode
    @Binding var selectedNote: Note?
    @Binding var showingNoteEditor: Bool
    let onDeleteNote: (Note) -> Void
    let onFolderRename: (Folder) -> Void
    let onFolderDelete: (Folder) -> Void
    @EnvironmentObject var viewModel: NotesListViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Folders Section
                if !folders.isEmpty {
                    FoldersSection(
                        folders: folders,
                        viewMode: viewMode,
                        onFolderTap: { folder in
                            viewModel.enterFolder(folder)
                        },
                        onFolderRename: onFolderRename,
                        onFolderDelete: onFolderDelete
                    )
                }
                
                // Notes Section
                switch viewMode {
                case .grid:
                    NotesGridView(
                        notes: notes,
                        selectedNote: $selectedNote,
                        showingNoteEditor: $showingNoteEditor,
                        onDeleteNote: onDeleteNote
                    )
                    .environmentObject(viewModel)
                case .list:
                    NotesListContentView(
                        notes: notes,
                        selectedNote: $selectedNote,
                        showingNoteEditor: $showingNoteEditor,
                        onDeleteNote: onDeleteNote
                    )
                    .environmentObject(viewModel)
                }
            }
        }
    }
}

// MARK: - Grid View
struct NotesGridView: View {
    let notes: [Note]
    @Binding var selectedNote: Note?
    @Binding var showingNoteEditor: Bool
    let onDeleteNote: (Note) -> Void
    @EnvironmentObject var viewModel: NotesListViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(notes) { note in
                UniformNoteCard(note: note, viewModel: viewModel)
                    .onTapGesture {
                        DispatchQueue.main.async {
                            selectedNote = note
                            showingNoteEditor = true
                        }
                    }
                    .contextMenu {
                        Button("Edit") {
                            selectedNote = note
                            showingNoteEditor = true
                        }
                        
                        if !viewModel.folders.isEmpty {
                            Menu("Move to Folder") {
                                Button("Root") {
                                    viewModel.moveNoteToFolder(note, folder: nil)
                                }
                                
                                ForEach(viewModel.folders, id: \.id) { folder in
                                    Button(folder.name) {
                                        viewModel.moveNoteToFolder(note, folder: folder)
                                    }
                                }
                            }
                        }

                        Button("Delete", role: .destructive) {
                            onDeleteNote(note)
                        }
                    }
            }
        }
        .padding()
    }
}

// MARK: - List View
struct NotesListContentView: View {
    let notes: [Note]
    @Binding var selectedNote: Note?
    @Binding var showingNoteEditor: Bool
    let onDeleteNote: (Note) -> Void
    @EnvironmentObject var viewModel: NotesListViewModel

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(notes) { note in
                NoteListRow(note: note, viewModel: viewModel)
                    .onTapGesture {
                        DispatchQueue.main.async {
                            selectedNote = note
                            showingNoteEditor = true
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !viewModel.folders.isEmpty {
                            Menu {
                                Button("Root") {
                                    viewModel.moveNoteToFolder(note, folder: nil)
                                }
                                
                                ForEach(viewModel.folders, id: \.id) { folder in
                                    Button(folder.name) {
                                        viewModel.moveNoteToFolder(note, folder: folder)
                                    }
                                }
                            } label: {
                                Label("Move", systemImage: "folder")
                            }
                            .tint(.blue)
                        }
                        
                        Button("Delete", role: .destructive) {
                            onDeleteNote(note)
                        }
                    }
            }
        }
        .padding()
    }
}

// MARK: - Uniform Note Card (Grid)
struct UniformNoteCard: View {
    @Environment(\.appTheme) private var theme
    let note: Note
    @ObservedObject var viewModel: NotesListViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                NoteCardHeader(note: note)
                
                Spacer()
                
                // Folder indicator
                if let folderId = note.folderId,
                   let folder = viewModel.folders.first(where: { $0.id == folderId }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                        Text(folder.name)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }
            }
            
            // Title (flexible height)
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Content preview (flexible height)
            Text(note.content.isEmpty ? "No content" : note.content)
                .font(.body)
                .lineLimit(2)
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 4)
            
            // Bottom info
            NoteCardFooter(note: note)
        }
        .padding(10)
        .frame(minHeight: 160, maxHeight: 200) // Flexible height with constraints
        .background(theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Note List Row
struct NoteListRow: View {
    @Environment(\.appTheme) private var theme
    let note: Note
    @ObservedObject var viewModel: NotesListViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Left content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(theme.textPrimary)
                    
                    Spacer()
                    
                    Text(note.modifiedDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundColor(theme.textSecondary)
                }
                
                HStack {
                    if let category = note.category {
                        CategoryTag(category: category)
                    }
                    
                    if !note.tags.isEmpty {
                        Text("#\(note.tags.prefix(2).joined(separator: " #"))")
                            .font(.caption)
                            .foregroundColor(theme.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    
                    // Folder indicator
                    if let folderId = note.folderId,
                       let folder = viewModel.folders.first(where: { $0.id == folderId }) {
                        HStack(spacing: 2) {
                            Image(systemName: "folder.fill")
                                .font(.caption2)
                            Text(folder.name)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    NoteIndicators(note: note)
                }
            }
        }
        .padding(12)
        .background(theme.cardBackground)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Reusable Components
struct NoteCardHeader: View {
    @Environment(\.appTheme) private var theme
    let note: Note
    
    var body: some View {
        HStack {
            if let category = note.category {
                CategoryTag(category: category)
            }
            
            Text(note.modifiedDate.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
    }
}

struct NoteCardFooter: View {
    @Environment(\.appTheme) private var theme
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Tags (max 2 for cards to prevent overflow)
            if !note.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(note.tags.prefix(2), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(theme.primary.opacity(0.1))
                            .foregroundColor(theme.primary)
                            .cornerRadius(3)
                    }
                    
                    if note.tags.count > 2 {
                        Text("+\(note.tags.count - 2)")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                    
                    Spacer()
                }
            }
            
            // Indicators
            NoteIndicators(note: note)
        }
    }
}

struct CategoryTag: View {
    @Environment(\.appTheme) private var theme
    let category: Category
    
    var body: some View {
        Text(category.name)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: category.color).opacity(0.2))
            .foregroundColor(Color(hex: category.color))
            .cornerRadius(6)
    }
}

struct NoteIndicators: View {
    @Environment(\.appTheme) private var theme
    let note: Note
    
    var body: some View {
        HStack(spacing: 4) {
            if note.audioURL != nil {
                HStack(spacing: 2) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundColor(theme.warning)
                    Text("Audio")
                        .font(.caption2)
                        .foregroundColor(theme.warning)
                }
            }
            
            if !note.attachments.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "paperclip")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                    Text("\(note.attachments.count)")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                }
            }
            
            if !note.actionItems.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption2)
                        .foregroundColor(theme.success)
                    Text("\(note.actionItems.count)")
                        .font(.caption2)
                        .foregroundColor(theme.success)
                }
            }

            if note.latitude != nil && note.longitude != nil {
                HStack(spacing: 2) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Location")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            if note.aiSummary != nil {
                HStack(spacing: 2) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundColor(theme.primary)
                    Text("AI")
                        .font(.caption2)
                        .foregroundColor(theme.primary)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Breadcrumb View
struct BreadcrumbView: View {
    let hierarchy: [Folder]
    let onNavigate: (Folder) -> Void
    let onNavigateToRoot: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("Home") {
                    onNavigateToRoot()
                }
                .foregroundColor(.blue)
                .font(.caption)
                
                ForEach(hierarchy, id: \.id) { folder in
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Button(folder.name) {
                            onNavigate(folder)
                        }
                        .foregroundColor(.blue)
                        .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color(.systemGray6), Color(.systemGray5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(minHeight: 40)
    }
}

// MARK: - Folders Section
struct FoldersSection: View {
    let folders: [Folder]
    let viewMode: ViewMode
    let onFolderTap: (Folder) -> Void
    let onFolderRename: (Folder) -> Void
    let onFolderDelete: (Folder) -> Void
    
    var body: some View {
        if !folders.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Folders")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                
                if viewMode == .grid {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(folders, id: \.id) { folder in
                            FolderGridView(
                                folder: folder,
                                onTap: { onFolderTap(folder) },
                                onRename: { onFolderRename(folder) },
                                onDelete: { onFolderDelete(folder) }
                            )
                        }
                    }
                    .padding(.horizontal)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(folders, id: \.id) { folder in
                            FolderRowView(
                                folder: folder,
                                onTap: { onFolderTap(folder) },
                                onRename: { onFolderRename(folder) },
                                onDelete: { onFolderDelete(folder) }
                            )
                        }
                    }
                }
            }
            .padding(.bottom)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @Environment(\.appTheme) private var theme
    @Binding var showingNoteEditor: Bool
    @Binding var showingVoiceRecorder: Bool
    @Binding var showingCamera: Bool
    @Binding var isProcessingCameraNote: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Welcome message
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 60))
                    .foregroundColor(theme.textSecondary)
                
                Text("Welcome to MyLogs")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
                
                Text("Start capturing your thoughts and ideas")
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Large action buttons
            HStack(spacing: 30) {
                // Voice Recording Button
                Button(action: {
                    showingVoiceRecorder = true
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(theme.error.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Image(systemName: "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(theme.error)
                        }

                        Text("Voice Note")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Camera Note Button
                Button(action: {
                    showingCamera = true
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(theme.accent.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(theme.accent)
                        }

                        Text("Camera Note")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .disabled(isProcessingCameraNote)
                .buttonStyle(PlainButtonStyle())

                // Text Note Button
                Button(action: {
                    showingNoteEditor = true
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(theme.primary.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Image(systemName: "plus")
                                .font(.system(size: 40))
                                .fontWeight(.medium)
                                .foregroundColor(theme.primary)
                        }

                        Text("New Note")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }



    private func createImageAttachment(from image: UIImage, for note: Note) async throws -> Attachment {
        // Get documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let attachmentsDir = documentsDirectory.appendingPathComponent("Attachments")

        // Create directory if needed
        try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }

        // Generate unique filename and save image
        let fileName = "\(UUID().uuidString).jpg"
        let imageURL = attachmentsDir.appendingPathComponent(fileName)
        try imageData.write(to: imageURL)

        // Create thumbnail
        let thumbnailData = image.resizedForEditor(to: CGSize(width: 200, height: 200)).jpegData(compressionQuality: 0.7)

        // Create attachment
        return Attachment(
            fileName: fileName,
            fileExtension: "jpg",
            mimeType: "image/jpeg",
            fileSize: Int64(imageData.count),
            localURL: imageURL,
            thumbnailData: thumbnailData,
            type: .image
        )
    }


}

// MARK: - Simple Location Service
class SimpleLocationService: NSObject, ObservableObject, @unchecked Sendable {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<(latitude: Double, longitude: Double)?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func getCurrentLocationSafely() async -> (latitude: Double, longitude: Double)? {
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services not enabled")
            return nil
        }

        let authStatus = locationManager.authorizationStatus
        print("📍 Location authorization status: \(authStatus.rawValue)")

        // Request permission if not determined
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Wait a bit for permission to be processed
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        let finalStatus = locationManager.authorizationStatus
        guard finalStatus == .authorizedWhenInUse || finalStatus == .authorizedAlways else {
            print("❌ Location permission denied. Status: \(finalStatus.rawValue)")
            return nil
        }

        print("✅ Location permission granted, requesting location...")

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()

            // Set up timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                if self?.locationContinuation != nil {
                    print("⏰ Location request timed out")
                    self?.locationContinuation?.resume(returning: nil)
                    self?.locationContinuation = nil
                }
            }
        }
    }
}

extension SimpleLocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, let continuation = locationContinuation else {
            print("❌ No location or continuation available")
            return
        }

        locationContinuation = nil
        let coordinates = (latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        print("✅ Location received: \(coordinates.latitude), \(coordinates.longitude)")
        continuation.resume(returning: coordinates)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error)")

        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("📍 Location authorization changed to: \(manager.authorizationStatus.rawValue)")
    }
}

// MARK: - Simple Camera View
struct SimpleCameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SimpleCameraView

        init(_ parent: SimpleCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - UIImage Extension for NotesListView
private extension UIImage {
    func resizedForEditor(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    NotesListView()
        .environmentObject(NotesListViewModel())
}
//
//  NotesListView.swift
//  AINoteTakingApp
//
//  Main view for displaying and managing notes with hierarchical folder organization.
//  Refactored to follow clean architecture and Single Responsibility Principle.
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI

struct NotesListView: View {
    @Environment(\.appTheme) private var theme
    @StateObject private var viewModel = NotesListViewModel()
    @StateObject private var cameraViewModel: CameraProcessingViewModel
    @StateObject private var alertState = NotesListAlertState()

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

    // Initialize camera view model with notes list view model
    init() {
        let notesVM = NotesListViewModel()
        self._viewModel = StateObject(wrappedValue: notesVM)
        self._cameraViewModel = StateObject(wrappedValue: CameraProcessingViewModel(notesListViewModel: notesVM))
        self._alertState = StateObject(wrappedValue: NotesListAlertState())
    }

    private var currentFolders: [Folder] {
        return viewModel.folders.filter { $0.parentFolderId == viewModel.currentFolder?.id }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                NotesListBreadcrumb(viewModel: viewModel)
                mainContentSection
            }
            .navigationTitle(viewModel.currentFolder?.name ?? "MyLogs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NotesListToolbar(
                        showingVoiceRecorder: $showingVoiceRecorder,
                        showingCamera: $cameraViewModel.showingCamera,
                        showingNoteEditor: $showingNoteEditor,
                        viewModel: viewModel,
                        isProcessingCamera: cameraViewModel.isProcessing
                    )
                }
            })
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
        .sheet(isPresented: $cameraViewModel.showingCamera) {
            CameraViewWithProcessing(cameraViewModel: cameraViewModel)
        }
        .onAppear {
            viewModel.loadNotes()
            viewModel.loadFolders()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NotesDidChange"))) { _ in
            viewModel.refresh()
        }
        .notesListAlerts(
            alertState: alertState,
            actions: NotesListAlertActionsImpl(viewModel: viewModel)
        )
    }

    // MARK: - Helper Methods
    private func confirmDelete(_ note: Note) {
        alertState.confirmDeleteNote(note)
    }

    private func confirmDeleteFolder(_ folder: Folder) {
        alertState.confirmDeleteFolder(folder)
    }

    private func confirmRenameFolder(_ folder: Folder) {
        alertState.confirmRenameFolder(folder)
    }

    // MARK: - Helper Views
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
                    showingCamera: $cameraViewModel.showingCamera,
                    isProcessingCameraNote: $cameraViewModel.isProcessing
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
                    onFolderRename: confirmRenameFolder,
                    onFolderDelete: confirmDeleteFolder
                )
                .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Alert Actions Implementation
struct NotesListAlertActionsImpl: NotesListAlertActions {
    let viewModel: NotesListViewModel

    @MainActor
    func deleteNote(_ note: Note) {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.deleteNote(note)
        }
    }

    @MainActor
    func deleteFolder(_ folder: Folder, cascadeDelete: Bool) {
        viewModel.deleteFolder(folder, cascadeDelete: cascadeDelete)
    }

    @MainActor
    func renameFolder(_ folder: Folder, newName: String) {
        var updatedFolder = folder
        updatedFolder.name = newName
        if let index = viewModel.folders.firstIndex(where: { $0.id == folder.id }) {
            viewModel.folders[index] = updatedFolder
        }
    }
}

#Preview {
    NotesListView()
        .environmentObject(NotesListViewModel())
}

// MARK: - Camera View with Processing (Temporary location)
struct CameraViewWithProcessing: View {
    @ObservedObject var cameraViewModel: CameraProcessingViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            // Camera interface
            CameraView { image in
                cameraViewModel.processCapturedImage(image)
            }

            // Processing overlay
            if cameraViewModel.isProcessing {
                ProcessingOverlay(progress: cameraViewModel.processingProgress)
            }
        }
        .alert("Camera Error", isPresented: .constant(cameraViewModel.hasError)) {
            Button("OK") {
                cameraViewModel.clearError()
            }
        } message: {
            if let errorMessage = cameraViewModel.errorMessage {
                Text(errorMessage)
            }
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
                
                HStack(spacing: AppConstants.Spacing.sm) {
                    // Cloud indicator for server save status
                    if note.isSavedOnServer {
                        Image(systemName: AppConstants.Icons.saved)
                            .font(TypographyScale.caption)
                            .foregroundColor(theme.success)
                    }
                    
                    // Folder indicator with improved styling
                    if let folderId = note.folderId,
                       let folder = viewModel.folders.first(where: { $0.id == folderId }) {
                        HStack(spacing: AppConstants.Spacing.xs) {
                            Image(systemName: AppConstants.Icons.folder)
                                .font(TypographyScale.caption)
                            Text(folder.name)
                                .font(TypographyScale.caption)
                        }
                        .foregroundColor(theme.labelColor)
                        .padding(.horizontal, AppConstants.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(theme.sectionBackground)
                        .clipShape(Capsule())
                    }
                }
            }
            
            // Title (flexible height) - Updated with new typography
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(TypographyScale.noteTitle)
                .lineLimit(2)
                .foregroundColor(theme.contentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Content preview (flexible height) - Updated with new typography
            Text(note.content.isEmpty ? "No content" : note.content)
                .font(TypographyScale.preview)
                .lineLimit(2)
                .foregroundColor(theme.labelColor)
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
                        .font(TypographyScale.noteTitle)
                        .lineLimit(1)
                        .foregroundColor(theme.contentColor)
                    
                    Spacer()
                    
                    HStack(spacing: AppConstants.Spacing.sm) {
                        // Cloud indicator for server save status
                        if note.isSavedOnServer {
                            Image(systemName: AppConstants.Icons.saved)
                                .font(TypographyScale.caption)
                                .foregroundColor(theme.success)
                        }
                        
                        Text(note.modifiedDate.formatted(date: .abbreviated, time: .shortened))
                            .font(TypographyScale.caption)
                            .foregroundColor(theme.labelColor)
                    }
                }
                
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(TypographyScale.preview)
                        .lineLimit(2)
                        .foregroundColor(theme.labelColor)
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
                .font(TypographyScale.caption)
                .foregroundColor(theme.labelColor)
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
                            .font(TypographyScale.caption)
                            .padding(.horizontal, AppConstants.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(theme.primary.opacity(0.1))
                            .foregroundColor(theme.primary)
                            .cornerRadius(AppConstants.UI.cornerRadius / 3)
                    }
                    
                    if note.tags.count > 2 {
                        Text("+\(note.tags.count - 2)")
                            .font(TypographyScale.caption)
                            .foregroundColor(theme.labelColor)
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
            .font(TypographyScale.caption)
            .fontWeight(.medium)
            .padding(.horizontal, AppConstants.Spacing.sm)
            .padding(.vertical, AppConstants.Spacing.xs)
            .background(Color(hex: category.color).opacity(0.2))
            .foregroundColor(Color(hex: category.color))
            .cornerRadius(AppConstants.UI.cornerRadius / 2)
    }
}

struct NoteIndicators: View {
    @Environment(\.appTheme) private var theme
    let note: Note
    
    var body: some View {
        HStack(spacing: AppConstants.Spacing.xs) {
            // Audio indicator with semantic icon
            if note.audioURL != nil {
                HStack(spacing: 2) {
                    Image(systemName: AppConstants.Icons.microphone)
                        .font(TypographyScale.caption)
                        .foregroundColor(theme.warning)
                    Text("Audio")
                        .font(TypographyScale.caption)
                        .foregroundColor(theme.labelColor)
                }
            }
            
            // Attachment indicator with count
            if !note.attachments.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: AppConstants.Icons.attachment)
                        .font(TypographyScale.caption)
                        .foregroundColor(theme.info)
                    Text("\(note.attachments.count)")
                        .font(TypographyScale.caption)
                        .foregroundColor(theme.labelColor)
                }
            }
            
            // Action items indicator
            if !note.actionItems.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: AppConstants.Icons.actionItem)
                        .font(TypographyScale.caption)
                        .foregroundColor(theme.success)
                    Text("\(note.actionItems.count)")
                        .font(TypographyScale.caption)
                        .foregroundColor(theme.labelColor)
                }
            }
            
            // AI Summary indicator (from feedback - meaningful icon)
            if note.aiSummary != nil {
                HStack(spacing: 2) {
                    Image(systemName: AppConstants.Icons.ai)
                        .font(TypographyScale.caption)
                        .foregroundColor(theme.success)
                    Text("AI")
                        .font(TypographyScale.caption)
                        .foregroundColor(theme.labelColor)
                }
            }

            if let latitude = note.latitude, let longitude = note.longitude {
                Menu {
                    Button("Open in Apple Maps") {
                        openInAppleMaps(latitude: latitude, longitude: longitude)
                    }
                    Button("Open in Google Maps") {
                        openInGoogleMaps(latitude: latitude, longitude: longitude)
                    }
                    Button("Copy Coordinates") {
                        copyCoordinates(latitude: latitude, longitude: longitude)
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(String(format: "%.4f, %.4f", latitude, longitude))
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
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

    // MARK: - Helper Methods
    private func openInAppleMaps(latitude: Double, longitude: Double) {
        let urlString = "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=Note%20Location"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func openInGoogleMaps(latitude: Double, longitude: Double) {
        let urlString = "https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func copyCoordinates(latitude: Double, longitude: Double) {
        let coordinateString = String(format: "%.6f, %.6f", latitude, longitude)
        UIPasteboard.general.string = coordinateString
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
}



#Preview {
    NotesListView()
        .environmentObject(NotesListViewModel())
}
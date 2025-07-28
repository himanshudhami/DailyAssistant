//
//  NotesListView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

// MARK: - View Mode
enum NotesViewMode: CaseIterable {
    case grid
    case list
    
    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Sort Options
enum NoteSortOption: CaseIterable {
    case modifiedDate
    case createdDate
    case title
    
    var displayName: String {
        switch self {
        case .modifiedDate: return "Modified"
        case .createdDate: return "Created"
        case .title: return "Title"
        }
    }
}

// MARK: - Main Notes List View
struct NotesListView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject var viewModel: NotesListViewModel
    @State private var showingNoteEditor = false
    @State private var selectedNote: Note?
    @State private var showingVoiceRecorder = false
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var sortOption: NoteSortOption = .modifiedDate
    @State private var viewMode: NotesViewMode = .grid
    @State private var noteToDelete: Note?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Controls
                TopControlsBar(
                    searchText: $searchText,
                    selectedCategory: $selectedCategory,
                    sortOption: $sortOption,
                    viewMode: $viewMode,
                    categories: viewModel.categories
                )
                
                // Notes Content
                if viewModel.filteredNotes.isEmpty {
                    EmptyNotesView(showingNoteEditor: $showingNoteEditor)
                } else {
                    NotesContentView(
                        notes: viewModel.filteredNotes,
                        viewMode: viewMode,
                        selectedNote: $selectedNote,
                        showingNoteEditor: $showingNoteEditor,
                        onDeleteNote: confirmDelete
                    )
                    .environmentObject(viewModel)
                }
            }
            .navigationTitle("MyLogs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingVoiceRecorder = true }) {
                            Image(systemName: "mic.circle.fill")
                                .foregroundColor(theme.error)
                                .font(.title2)
                        }
                        
                        Button(action: { showingNoteEditor = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(theme.primary)
                                .font(.title2)
                        }
                    }
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
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(note: selectedNote)
        }
        .onChange(of: showingNoteEditor) { isShowing in
            if !isShowing {
                selectedNote = nil
            }
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecorderView()
        }
        .onAppear {
            viewModel.loadNotes()
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
    }

    // MARK: - Helper Methods
    private func confirmDelete(_ note: Note) {
        noteToDelete = note
        showingDeleteAlert = true
    }
}

// MARK: - Top Controls Bar
struct TopControlsBar: View {
    @Environment(\.appTheme) private var theme
    @Binding var searchText: String
    @Binding var selectedCategory: Category?
    @Binding var sortOption: NoteSortOption
    @Binding var viewMode: NotesViewMode
    let categories: [Category]
    
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
                Button(option.displayName) {
                    sortOption = option
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                Text(sortOption.displayName)
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
    @Binding var viewMode: NotesViewMode
    
    var body: some View {
        Button(action: {
            viewMode = viewMode == .grid ? .list : .grid
        }) {
            Image(systemName: viewMode.icon)
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
    let viewMode: NotesViewMode
    @Binding var selectedNote: Note?
    @Binding var showingNoteEditor: Bool
    let onDeleteNote: (Note) -> Void
    @EnvironmentObject var viewModel: NotesListViewModel

    var body: some View {
        ScrollView {
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
                UniformNoteCard(note: note)
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
                NoteListRow(note: note)
                    .onTapGesture {
                        DispatchQueue.main.async {
                            selectedNote = note
                            showingNoteEditor = true
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            NoteCardHeader(note: note)
            
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
            
            Spacer()
            
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

// MARK: - Empty State
struct EmptyNotesView: View {
    @Environment(\.appTheme) private var theme
    @Binding var showingNoteEditor: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "note.text")
                .font(.system(size: 80))
                .foregroundColor(theme.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Logs Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                
                Text("Create your first log or record a voice memo")
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Create Log") {
                showingNoteEditor = true
            }
            .buttonStyle(.borderedProminent)
            .accentColor(theme.primary)
            .padding(.top)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


#Preview {
    NotesListView()
        .environmentObject(NotesListViewModel())
}
//
//  NotesListView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct NotesListView: View {
    @EnvironmentObject var viewModel: NotesListViewModel
    @State private var showingNoteEditor = false
    @State private var selectedNote: Note?
    @State private var showingVoiceRecorder = false
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var sortOption: NoteSortOption = .modifiedDate
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                SearchAndFilterBar(
                    searchText: $searchText,
                    selectedCategory: $selectedCategory,
                    sortOption: $sortOption
                )
                
                // Notes List
                if viewModel.filteredNotes.isEmpty {
                    EmptyNotesView(showingNoteEditor: $showingNoteEditor)
                } else {
                    NotesGrid(
                        notes: viewModel.filteredNotes,
                        selectedNote: $selectedNote,
                        showingNoteEditor: $showingNoteEditor
                    )
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("All Notes") {
                            selectedCategory = nil
                        }
                        
                        Divider()
                        
                        ForEach(viewModel.categories) { category in
                            Button(category.name) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showingVoiceRecorder = true }) {
                            Image(systemName: "mic.circle.fill")
                                .foregroundColor(.red)
                        }
                        
                        Button(action: { showingNoteEditor = true }) {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search notes...")
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
    }
}

struct SearchAndFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedCategory: Category?
    @Binding var sortOption: NoteSortOption
    
    var body: some View {
        HStack {
            // Category Filter
            Menu {
                Button("All Categories") {
                    selectedCategory = nil
                }
                
                // Add category options here
            } label: {
                HStack {
                    Image(systemName: "folder")
                    Text(selectedCategory?.name ?? "All")
                    Image(systemName: "chevron.down")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Sort Options
            Menu {
                Button("Modified Date") {
                    sortOption = .modifiedDate
                }
                Button("Created Date") {
                    sortOption = .createdDate
                }
                Button("Title") {
                    sortOption = .title
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(sortOption.displayName)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct EmptyNotesView: View {
    @Binding var showingNoteEditor: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "note.text")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Notes Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Create your first note by tapping the + button or record a voice note")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Create Note") {
                showingNoteEditor = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
            
            Spacer()
        }
    }
}

struct NotesGrid: View {
    let notes: [Note]
    @Binding var selectedNote: Note?
    @Binding var showingNoteEditor: Bool
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(notes) { note in
                    NoteCard(note: note)
                        .onTapGesture {
                            DispatchQueue.main.async {
                                selectedNote = note
                                showingNoteEditor = true
                            }
                        }
                }
            }
            .padding()
        }
    }
}

struct NoteCard: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with category and date
            HStack {
                if let category = note.category {
                    Text(category.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: category.color).opacity(0.2))
                        .foregroundColor(Color(hex: category.color))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text(note.modifiedDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Title
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            // Content preview
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
            }
            
            // AI Summary if available
            if let aiSummary = note.aiSummary, !aiSummary.isEmpty {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(aiSummary)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
            
            // Tags
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(note.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                        
                        if note.tags.count > 3 {
                            Text("+\(note.tags.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Attachments and audio indicator
            HStack {
                if !note.attachments.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "paperclip")
                            .font(.caption)
                        Text("\(note.attachments.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if note.audioURL != nil {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if !note.actionItems.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption)
                        Text("\(note.actionItems.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    NotesListView()
        .environmentObject(NotesListViewModel())
}

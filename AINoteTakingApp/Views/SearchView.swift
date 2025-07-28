//
//  SearchView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [Note] = []
    @State private var isSearching = false
    @State private var selectedFilters: Set<SearchFilter> = []
    @EnvironmentObject var notesViewModel: NotesListViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(
                    text: $searchText,
                    isSearching: $isSearching,
                    onSearchChanged: performSearch
                )
                
                // Filters
                SearchFiltersView(selectedFilters: $selectedFilters) {
                    performSearch(searchText)
                }
                
                // Results
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    EmptySearchView()
                } else if !searchResults.isEmpty {
                    SearchResultsList(results: searchResults)
                } else {
                    SearchSuggestionsView(onSuggestionTapped: { suggestion in
                        searchText = suggestion
                        performSearch(suggestion)
                    })
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Perform actual search through notes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let lowercasedQuery = query.lowercased()
            searchResults = notesViewModel.notes.filter { note in
                note.title.lowercased().contains(lowercasedQuery) ||
                note.content.lowercased().contains(lowercasedQuery) ||
                note.tags.contains { $0.lowercased().contains(lowercasedQuery) }
            }
            isSearching = false
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    let onSearchChanged: (String) -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search logs, content, tags...", text: $text)
                    .onSubmit {
                        onSearchChanged(text)
                    }
                    .onChange(of: text) { newValue in
                        onSearchChanged(newValue)
                    }
                
                if !text.isEmpty {
                    Button("Clear") {
                        text = ""
                        onSearchChanged("")
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
    }
}

enum SearchFilter: String, CaseIterable {
    case hasAudio = "Audio"
    case hasAttachments = "Attachments"
    case hasActionItems = "Tasks"
    case recent = "Recent"
    case favorites = "Favorites"
    
    var icon: String {
        switch self {
        case .hasAudio: return "waveform"
        case .hasAttachments: return "paperclip"
        case .hasActionItems: return "checkmark.circle"
        case .recent: return "clock"
        case .favorites: return "heart"
        }
    }
}

struct SearchFiltersView: View {
    @Binding var selectedFilters: Set<SearchFilter>
    let onFiltersChanged: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilters.contains(filter)
                    ) {
                        if selectedFilters.contains(filter) {
                            selectedFilters.remove(filter)
                        } else {
                            selectedFilters.insert(filter)
                        }
                        onFiltersChanged()
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct FilterChip: View {
    let filter: SearchFilter
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search terms or filters")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

struct SearchResultsList: View {
    let results: [Note]
    
    var body: some View {
        List(results) { note in
            SearchResultRow(note: note)
        }
        .listStyle(.plain)
    }
}

struct SearchResultRow: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.headline)
                .lineLimit(1)
            
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(note.modifiedDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if note.audioURL != nil {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if !note.attachments.isEmpty {
                    Image(systemName: "paperclip")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchSuggestionsView: View {
    let onSuggestionTapped: (String) -> Void
    
    private let suggestions = [
        "meeting notes",
        "action items",
        "today",
        "this week",
        "important",
        "project",
        "ideas",
        "tasks"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Suggestions")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSuggestionTapped(suggestion)
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            Text(suggestion)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
    }
}

#Preview {
    SearchView()
        .environmentObject(NotesListViewModel())
}

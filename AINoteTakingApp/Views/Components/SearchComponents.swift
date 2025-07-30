//
//  SearchComponents.swift
//  AINoteTakingApp
//
//  Search-related UI components following SRP principle.
//  Separated from main SearchView to reduce file size and improve maintainability.
//  Handles search bar, filters, results display, and user interactions.
//
//  Created by AI Assistant on 2025-01-30.
//

import SwiftUI

// MARK: - Enhanced Search Bar with Keyboard Dismissal
struct EnhancedSearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    @FocusState private var isTextFieldFocused: Bool
    let onSearchChanged: (String) -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search notes, images, content...", text: $text)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        onSearchChanged(text)
                        dismissKeyboard()
                    }
                    .onChange(of: text) { newValue in
                        onSearchChanged(newValue)
                    }
                
                if !text.isEmpty {
                    Button("Clear") {
                        text = ""
                        onClear()
                        dismissKeyboard()
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isTextFieldFocused {
                Button("Done") {
                    dismissKeyboard()
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
            }
        }
    }
    
    private func dismissKeyboard() {
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Search Filters View
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
                
                if !selectedFilters.isEmpty {
                    Button("Clear All") {
                        selectedFilters.removeAll()
                        onFiltersChanged()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Filter Chip
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
        .buttonStyle(.plain)
    }
}

// MARK: - Search Results List
struct SearchResultsList: View {
    let results: [SearchResult]
    let onNoteSelected: (Note) -> Void
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(results, id: \.note.id) { result in
                SearchResultCard(result: result, onTap: {
                    onNoteSelected(result.note)
                })
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Enhanced Search Result Card
struct SearchResultCard: View {
    @Environment(\.appTheme) private var theme
    let result: SearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with title and relevance
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.note.title.isEmpty ? "Untitled" : result.note.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            SearchTypeIndicator(searchType: result.searchType)
                            RelevanceIndicator(score: result.relevanceScore)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(theme.textSecondary)
                        .font(.caption)
                }
                
                // Matched content snippet
                if !result.matchedContent.isEmpty {
                    Text(result.matchedContent)
                        .font(.body)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Note metadata
                HStack {
                    Text(result.note.modifiedDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                    
                    Spacer()
                    
                    NoteMetadataIcons(note: result.note)
                }
            }
            .padding()
            .background(theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Type Indicator
struct SearchTypeIndicator: View {
    let searchType: SearchType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(displayName)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(4)
    }
    
    private var icon: String {
        switch searchType {
        case .exactMatch: return "text.magnifyingglass"
        case .semanticSimilarity: return "brain.head.profile"
        case .partialMatch: return "text.word.spacing"
        case .imageContent: return "photo"
        case .attachmentMetadata: return "paperclip"
        }
    }
    
    private var displayName: String {
        switch searchType {
        case .exactMatch: return "Exact"
        case .semanticSimilarity: return "Similar"
        case .partialMatch: return "Partial"
        case .imageContent: return "Image"
        case .attachmentMetadata: return "File"
        }
    }
    
    private var backgroundColor: Color {
        switch searchType {
        case .exactMatch: return .green.opacity(0.2)
        case .semanticSimilarity: return .blue.opacity(0.2)
        case .partialMatch: return .orange.opacity(0.2)
        case .imageContent: return .purple.opacity(0.2)
        case .attachmentMetadata: return .gray.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch searchType {
        case .exactMatch: return .green
        case .semanticSimilarity: return .blue
        case .partialMatch: return .orange
        case .imageContent: return .purple
        case .attachmentMetadata: return .gray
        }
    }
}

// MARK: - Relevance Indicator
struct RelevanceIndicator: View {
    let score: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < Int(score * 5) ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - Note Metadata Icons
struct NoteMetadataIcons: View {
    @Environment(\.appTheme) private var theme
    let note: Note
    
    var body: some View {
        HStack(spacing: 8) {
            if note.audioURL != nil {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if !note.attachments.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "paperclip")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(note.attachments.count)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            if note.attachments.contains(where: { $0.type == .image }) {
                HStack(spacing: 2) {
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("\(note.attachments.filter { $0.type == .image }.count)")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }

            if note.latitude != nil && note.longitude != nil {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            if !note.actionItems.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("\(note.actionItems.count)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

// MARK: - Recent Searches View
struct RecentSearchesView: View {
    let recentSearches: [String]
    let onSearchSelected: (String) -> Void
    let onSearchRemoved: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                
                Spacer()
                
                if !recentSearches.isEmpty {
                    Button("Clear All") {
                        recentSearches.forEach(onSearchRemoved)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            if recentSearches.isEmpty {
                Text("No recent searches")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentSearches, id: \.self) { search in
                        RecentSearchRow(
                            searchText: search,
                            onTap: { onSearchSelected(search) },
                            onRemove: { onSearchRemoved(search) }
                        )
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Recent Search Row
struct RecentSearchRow: View {
    let searchText: String
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                    Text(searchText)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty Search View
struct EmptySearchView: View {
    let hasActiveSearch: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: hasActiveSearch ? "magnifyingglass" : "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(hasActiveSearch ? "No Results Found" : "Start Searching")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(hasActiveSearch ? 
                "Try different keywords, check filters, or search in images" :
                "Search through your notes, images, attachments, and more"
            )
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}
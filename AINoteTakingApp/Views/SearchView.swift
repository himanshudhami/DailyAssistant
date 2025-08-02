//
//  SearchView.swift
//  AINoteTakingApp
//
//  Enhanced search view with semantic search, image search, and proper keyboard handling.
//  Integrates with SemanticSearchService for intelligent note discovery.
//  Follows clean architecture with proper separation of concerns.
//
//  Created by AI Assistant on 2024-01-01.
//  Enhanced on 2025-01-30.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNote: Note?
    @State private var showingNoteEditor = false
    @State private var showingImageGallery = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Search Bar with keyboard dismissal
                EnhancedSearchBar(
                    text: $viewModel.searchText,
                    isSearching: $viewModel.isSearching,
                    onSearchChanged: { _ in
                        // Search is handled automatically by viewModel debouncing
                    },
                    onClear: {
                        viewModel.clearSearch()
                    }
                )
                
                // Search Filters
                SearchFiltersView(selectedFilters: $viewModel.selectedFilters) {
                    // Filters are applied automatically through computed property
                }
                
                // Main Content
                ScrollView {
                    if viewModel.isSearching {
                        SearchingIndicator()
                    } else if viewModel.hasActiveSearch {
                        if viewModel.hasResults {
                            SearchResultsList(
                                results: viewModel.filteredResults,
                                onNoteSelected: handleNoteSelection
                            )
                        } else {
                            EmptySearchView(hasActiveSearch: true)
                        }
                    } else {
                        SearchHomeContent(
                            recentSearches: viewModel.recentSearches,
                            onSearchSelected: viewModel.selectRecentSearch,
                            onSearchRemoved: viewModel.removeRecentSearch,
                            onSuggestionTapped: { suggestion in
                                viewModel.searchText = suggestion
                            },
                            onImageGalleryTapped: {
                                showingImageGallery = true
                            }
                        )
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingImageGallery = true
                    }) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedNote) { note in
            NoteEditorView(note: note)
        }
        .sheet(isPresented: $showingImageGallery) {
            ImageGalleryView()
        }
    }
    
    private func handleNoteSelection(_ note: Note) {
        selectedNote = note
    }
}

// MARK: - Supporting Views
struct SearchingIndicator: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching intelligently...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct SearchHomeContent: View {
    let recentSearches: [String]
    let onSearchSelected: (String) -> Void
    let onSearchRemoved: (String) -> Void
    let onSuggestionTapped: (String) -> Void
    let onImageGalleryTapped: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 32) {
            // Recent Searches
            if !recentSearches.isEmpty {
                RecentSearchesView(
                    recentSearches: recentSearches,
                    onSearchSelected: onSearchSelected,
                    onSearchRemoved: onSearchRemoved
                )
            }
            
            // Search Suggestions
            SearchSuggestionsView(
                onSuggestionTapped: onSuggestionTapped,
                onImageGalleryTapped: onImageGalleryTapped
            )
            
            // Search Tips
            SearchTipsView()
        }
        .padding(.top)
    }
}

// MARK: - Search Tips View
struct SearchTipsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Tips")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                SearchTipRow(
                    icon: "brain.head.profile",
                    color: .blue,
                    title: "Semantic Search",
                    description: "Find notes by meaning, not just keywords"
                )
                
                SearchTipRow(
                    icon: "photo",
                    color: .purple,
                    title: "Image Search",
                    description: "Search for notes containing specific images"
                )
                
                SearchTipRow(
                    icon: "waveform",
                    color: .orange,
                    title: "Audio Content",
                    description: "Find notes with voice recordings"
                )
                
                SearchTipRow(
                    icon: "tag",
                    color: .green,
                    title: "Smart Filters",
                    description: "Use filters to narrow down results"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct SearchTipRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct SearchSuggestionsView: View {
    let onSuggestionTapped: (String) -> Void
    let onImageGalleryTapped: (() -> Void)?
    
    private let suggestions = [
        ("meeting notes", "person.2"),
        ("action items", "checkmark.circle"),
        ("today", "calendar"),
        ("images", "photo"),
        ("project ideas", "lightbulb"),
        ("voice notes", "waveform"),
        ("important", "exclamationmark.circle"),
        ("this week", "clock")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Popular Searches")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(suggestions, id: \.0) { suggestion, icon in
                    Button(action: {
                        onSuggestionTapped(suggestion)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: icon)
                                .foregroundColor(.blue)
                                .font(.callout)
                            Text(suggestion)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            // Image Gallery Quick Access
            if let onImageGalleryTapped = onImageGalleryTapped {
                Button(action: onImageGalleryTapped) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(.purple)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Browse Image Gallery")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("View all images from your notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
}

#Preview {
    SearchView()
}

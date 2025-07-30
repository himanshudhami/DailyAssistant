//
//  SearchViewModel.swift
//  AINoteTakingApp
//
//  Search view model handling search state, results, and UI interactions.
//  Follows SRP by managing only search-related state and business logic.
//  Integrates with SemanticSearchService for intelligent search capabilities.
//
//  Created by AI Assistant on 2025-01-30.
//

import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var searchText = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var selectedFilters: Set<SearchFilter> = []
    @Published var currentFolder: Folder?
    @Published var recentSearches: [String] = []
    
    // MARK: - Computed Properties
    var hasResults: Bool {
        !searchResults.isEmpty
    }
    
    var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var filteredResults: [SearchResult] {
        guard !selectedFilters.isEmpty else { return searchResults }
        
        return searchResults.filter { result in
            let note = result.note
            
            return selectedFilters.allSatisfy { filter in
                switch filter {
                case .hasAudio:
                    return note.audioURL != nil
                case .hasAttachments:
                    return !note.attachments.isEmpty
                case .hasActionItems:
                    return !note.actionItems.isEmpty
                case .recent:
                    return Calendar.current.isDate(note.modifiedDate, inSameDayAs: Date()) ||
                           Calendar.current.isDate(note.modifiedDate, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
                case .favorites:
                    // TODO: Implement favorites functionality
                    return false
                case .hasImages:
                    return note.attachments.contains { $0.type == .image }
                }
            }
        }
    }
    
    // MARK: - Private Properties
    private let semanticSearchService = SemanticSearchService()
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupSearchDebouncing()
        loadRecentSearches()
    }
    
    // MARK: - Public Methods
    
    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            clearResults()
            return
        }
        
        // Cancel previous search
        searchTask?.cancel()
        
        isSearching = true
        
        searchTask = Task {
            do {
                let results = await semanticSearchService.searchNotes(query: query, folder: currentFolder)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                    self.addToRecentSearches(query)
                }
            }
        }
    }
    
    func clearSearch() {
        searchText = ""
        clearResults()
    }
    
    func clearResults() {
        searchResults = []
        isSearching = false
        searchTask?.cancel()
    }
    
    func selectNote(_ note: Note) {
        // This will be handled by the parent view through navigation
        // The view model just tracks the selection
    }
    
    func toggleFilter(_ filter: SearchFilter) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
    }
    
    func clearAllFilters() {
        selectedFilters.removeAll()
    }
    
    func selectRecentSearch(_ query: String) {
        searchText = query
        performSearch()
    }
    
    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        saveRecentSearches()
    }
    
    func setFolder(_ folder: Folder?) {
        currentFolder = folder
        if hasActiveSearch {
            performSearch()
        }
    }
}

// MARK: - Private Methods
private extension SearchViewModel {
    
    func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }
    
    func addToRecentSearches(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // Remove if already exists
        recentSearches.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        
        // Add to beginning
        recentSearches.insert(trimmedQuery, at: 0)
        
        // Keep only last 10 searches
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        saveRecentSearches()
    }
    
    func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: "recent_searches"),
           let searches = try? JSONDecoder().decode([String].self, from: data) {
            recentSearches = searches
        }
    }
    
    func saveRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: "recent_searches")
        }
    }
}

// MARK: - Search Filter Extension
extension SearchFilter {
    static var allCases: [SearchFilter] {
        return [.hasAudio, .hasAttachments, .hasActionItems, .recent, .favorites, .hasImages]
    }
}

enum SearchFilter: String, CaseIterable, Hashable {
    case hasAudio = "Audio"
    case hasAttachments = "Files"
    case hasActionItems = "Tasks"
    case hasImages = "Images"
    case recent = "Recent"
    case favorites = "Favorites"
    
    var icon: String {
        switch self {
        case .hasAudio: return "waveform"
        case .hasAttachments: return "paperclip"
        case .hasActionItems: return "checkmark.circle"
        case .hasImages: return "photo"
        case .recent: return "clock"
        case .favorites: return "heart"
        }
    }
}
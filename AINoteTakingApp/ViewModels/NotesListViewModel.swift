//
//  NotesListViewModel.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import CoreData
import Combine

@MainActor
class NotesListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var notes: [Note] = []
    @Published var filteredNotes: [Note] = []
    @Published var categories: [Category] = []
    @Published var folders: [Folder] = []
    @Published var currentFolder: Folder?
    @Published var folderHierarchy: [Folder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedCategory: Category?
    @Published var sortOption: NoteSortOption = .modifiedDate
    @Published var viewMode: ViewMode = .list
    
    // MARK: - Private Properties
    private let dataManager = DataManager.shared
    private let networkService = NetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadCategories()
        loadFolders()
        loadNotes()
    }
    
    private func setupBindings() {
        // Combine search, category filter, and sort changes
        Publishers.CombineLatest3($searchText, $selectedCategory, $sortOption)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText, category, sortOption in
                self?.applyFiltersAndSort(searchText: searchText, category: category, sortOption: sortOption)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    func loadNotes() {
        isLoading = true
        errorMessage = nil
        
        let fetchedNotes = dataManager.fetchNotes(in: currentFolder)
        self.notes = fetchedNotes
        self.applyFiltersAndSort(
            searchText: self.searchText,
            category: self.selectedCategory,
            sortOption: self.sortOption
        )
        self.isLoading = false
    }
    
    func loadCategories() {
        self.categories = dataManager.fetchCategories()
    }
    
    // MARK: - Filtering and Sorting
    func searchNotes(with searchText: String) {
        self.searchText = searchText
    }
    
    func filterByCategory(_ category: Category?) {
        self.selectedCategory = category
    }
    
    func sortNotes(by option: NoteSortOption) {
        self.sortOption = option
    }
    
    private func applyFiltersAndSort(searchText: String, category: Category?, sortOption: NoteSortOption) {
        var filtered = notes
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (note.aiSummary?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply category filter
        if let category = category {
            filtered = filtered.filter { $0.category?.id == category.id }
        }
        
        // Apply sorting
        switch sortOption {
        case .modifiedDate:
            filtered.sort { $0.modifiedDate > $1.modifiedDate }
        case .createdDate:
            filtered.sort { $0.createdDate > $1.createdDate }
        case .title:
            filtered.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .category:
            filtered.sort { ($0.category?.name ?? "") < ($1.category?.name ?? "") }
        }
        
        filteredNotes = filtered
    }
    
    // MARK: - Note Management
    func deleteNote(_ note: Note) {
        dataManager.deleteNote(note)
        self.notes.removeAll { $0.id == note.id }
        self.applyFiltersAndSort(
            searchText: self.searchText,
            category: self.selectedCategory,
            sortOption: self.sortOption
        )
    }
    
    func updateNote(_ note: Note) {
        dataManager.updateNote(note)
        if let index = self.notes.firstIndex(where: { $0.id == note.id }) {
            self.notes[index] = note
        }
        self.applyFiltersAndSort(
            searchText: self.searchText,
            category: self.selectedCategory,
            sortOption: self.sortOption
        )
    }
    
    
    // MARK: - Category Management
    func createCategory(name: String, color: String) {
        let newCategory = dataManager.createCategory(name: name, color: color)
        self.categories.append(newCategory)
    }
    
    // MARK: - Statistics
    func getNotesCount() -> Int {
        return notes.count
    }
    
    func getNotesCountForCategory(_ category: Category) -> Int {
        return notes.filter { $0.category?.id == category.id }.count
    }
    
    func getRecentNotesCount(days: Int = 7) -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return notes.filter { $0.createdDate >= cutoffDate }.count
    }
    
    func getNotesWithAudioCount() -> Int {
        return notes.filter { $0.audioURL != nil }.count
    }
    
    func getNotesWithAttachmentsCount() -> Int {
        return notes.filter { !$0.attachments.isEmpty }.count
    }
    
    func getActionItemsCount() -> Int {
        return notes.reduce(0) { $0 + $1.actionItems.count }
    }
    
    func getCompletedActionItemsCount() -> Int {
        return notes.reduce(0) { total, note in
            total + note.actionItems.filter { $0.completed }.count
        }
    }
    
    // MARK: - Bulk Operations
    func deleteAllNotes() {
        for note in notes {
            dataManager.deleteNote(note)
        }
        self.notes.removeAll()
        self.filteredNotes.removeAll()
    }
    
    func exportNotes() -> [Note] {
        return notes
    }
    
    // MARK: - Search Suggestions
    func getSearchSuggestions() -> [String] {
        var suggestions: Set<String> = []
        
        // Add popular tags
        let allTags = notes.flatMap { $0.tags }
        let tagCounts = Dictionary(grouping: allTags, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        suggestions.formUnion(Array(tagCounts.prefix(5).map { $0.key }))
        
        // Add category names
        suggestions.formUnion(categories.map { $0.name })
        
        // Add common search terms
        suggestions.formUnion(["today", "yesterday", "this week", "audio", "attachments", "action items"])
        
        return Array(suggestions).sorted()
    }
    
    // MARK: - Folder Management
    func loadFolders() {
        if let currentFolder = currentFolder {
            self.folders = dataManager.fetchFolders(parentFolder: currentFolder)
        } else {
            self.folders = dataManager.fetchFolders()
        }
        updateFolderHierarchy()
    }
    
    func createFolder(name: String, parentFolderId: UUID? = nil) {
        let parentFolder = currentFolder ?? (parentFolderId != nil ? folders.first { $0.id == parentFolderId } : nil)
        let newFolder = dataManager.createFolder(name: name, parentFolder: parentFolder)
        folders.append(newFolder)
        updateFolderHierarchy()
    }
    
    func deleteFolder(_ folder: Folder, cascadeDelete: Bool = true) {
        dataManager.deleteFolder(folder, cascadeDelete: cascadeDelete)
        folders.removeAll { $0.id == folder.id }
        updateFolderHierarchy()
        // Refresh to show updated folder structure
        loadFolders()
        loadNotes()
    }
    
    func enterFolder(_ folder: Folder) {
        currentFolder = folder
        loadFolders()
        loadNotes()
        updateFolderHierarchy()
    }
    
    func navigateToParentFolder() {
        if let current = currentFolder,
           let parentId = current.parentFolderId {
            let allFolders = dataManager.fetchAllFolders()
            currentFolder = allFolders.first { $0.id == parentId }
        } else {
            currentFolder = nil
        }
        loadFolders()
        loadNotes()
        updateFolderHierarchy()
    }
    
    func moveNoteToFolder(_ note: Note, folder: Folder?) {
        var updatedNote = note
        updatedNote.folderId = folder?.id
        updatedNote.modifiedDate = Date()
        updateNote(updatedNote)
    }
    
    private func updateFolderHierarchy() {
        if let currentFolder = currentFolder {
            folderHierarchy = dataManager.getFolderPath(currentFolder)
        } else {
            folderHierarchy = []
        }
    }
    
    // MARK: - Refresh
    func refresh() {
        loadNotes()
        loadCategories()
        loadFolders()
    }
}

// MARK: - Enums
enum NoteSortOption: String, CaseIterable {
    case createdDate = "Created Date"
    case modifiedDate = "Modified Date"
    case title = "Title"
    case category = "Category"
    
    var systemImageName: String {
        switch self {
        case .createdDate: return "calendar.badge.plus"
        case .modifiedDate: return "calendar.badge.clock"
        case .title: return "textformat.abc"
        case .category: return "folder"
        }
    }
}

enum ViewMode: String, CaseIterable {
    case list = "List"
    case grid = "Grid"
    
    var systemImageName: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

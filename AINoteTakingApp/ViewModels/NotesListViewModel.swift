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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedCategory: Category?
    @Published var sortOption: NoteSortOption = .modifiedDate
    
    // MARK: - Private Properties
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadCategories()
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
        
        Task {
            do {
                let fetchedNotes = try await fetchNotesFromCoreData()
                await MainActor.run {
                    self.notes = fetchedNotes
                    self.applyFiltersAndSort(
                        searchText: self.searchText,
                        category: self.selectedCategory,
                        sortOption: self.sortOption
                    )
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load notes: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchNotesFromCoreData() async throws -> [Note] {
        return try await withCheckedThrowingContinuation { continuation in
            let context = persistenceController.container.viewContext
            let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \NoteEntity.modifiedDate, ascending: false)]
            
            do {
                let noteEntities = try context.fetch(request)
                let notes = noteEntities.map { Note(from: $0) }
                continuation.resume(returning: notes)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func loadCategories() {
        Task {
            do {
                let fetchedCategories = try await fetchCategoriesFromCoreData()
                await MainActor.run {
                    self.categories = fetchedCategories
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load categories: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func fetchCategoriesFromCoreData() async throws -> [Category] {
        return try await withCheckedThrowingContinuation { continuation in
            let context = persistenceController.container.viewContext
            let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CategoryEntity.sortOrder, ascending: true)]
            
            do {
                let categoryEntities = try context.fetch(request)
                let categories = categoryEntities.map { Category(from: $0) }
                continuation.resume(returning: categories)
            } catch {
                continuation.resume(throwing: error)
            }
        }
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
        }
        
        filteredNotes = filtered
    }
    
    // MARK: - Note Management
    func deleteNote(_ note: Note) {
        Task {
            do {
                try await deleteNoteFromCoreData(note)
                await MainActor.run {
                    self.notes.removeAll { $0.id == note.id }
                    self.applyFiltersAndSort(
                        searchText: self.searchText,
                        category: self.selectedCategory,
                        sortOption: self.sortOption
                    )
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete note: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteNoteFromCoreData(_ note: Note) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let context = persistenceController.container.viewContext
            let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
            
            do {
                let noteEntities = try context.fetch(request)
                for entity in noteEntities {
                    context.delete(entity)
                }
                try context.save()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func duplicateNote(_ note: Note) {
        let duplicatedNote = Note(
            title: "\(note.title) (Copy)",
            content: note.content,
            tags: note.tags,
            category: note.category,
            aiSummary: note.aiSummary,
            keyPoints: note.keyPoints
        )
        
        Task {
            do {
                try await saveNoteToCoreData(duplicatedNote)
                await MainActor.run {
                    self.notes.append(duplicatedNote)
                    self.applyFiltersAndSort(
                        searchText: self.searchText,
                        category: self.selectedCategory,
                        sortOption: self.sortOption
                    )
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to duplicate note: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveNoteToCoreData(_ note: Note) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let context = persistenceController.container.viewContext
            let noteEntity = NoteEntity(context: context)
            note.updateEntity(noteEntity)
            
            do {
                try context.save()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Category Management
    func createCategory(name: String, color: String) {
        let newCategory = Category(name: name, color: color, sortOrder: categories.count)
        
        Task {
            do {
                try await saveCategoryToCoreData(newCategory)
                await MainActor.run {
                    self.categories.append(newCategory)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to create category: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveCategoryToCoreData(_ category: Category) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let context = persistenceController.container.viewContext
            let categoryEntity = CategoryEntity(context: context)
            category.updateEntity(categoryEntity)
            
            do {
                try context.save()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
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
        Task {
            do {
                try await deleteAllNotesFromCoreData()
                await MainActor.run {
                    self.notes.removeAll()
                    self.filteredNotes.removeAll()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete all notes: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteAllNotesFromCoreData() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let context = persistenceController.container.viewContext
            let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
            
            do {
                let noteEntities = try context.fetch(request)
                for entity in noteEntities {
                    context.delete(entity)
                }
                try context.save()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
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
    
    // MARK: - Refresh
    func refresh() {
        loadNotes()
        loadCategories()
    }
}

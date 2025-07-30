//
//  DataManager.swift
//  AINoteTakingApp
//
//  Core Data manager providing SQLite database operations for hierarchical data.
//  Manages CRUD operations for Notes, Folders, Categories, Attachments, and ActionItems.
//  Implements n-level deep folder organization with automatic relationship management.
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import CoreData

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    // Semantic search service for indexing
    private var semanticSearchService: SemanticSearchService?
    
    // Initialize semantic search service on main actor
    private func getSemanticSearchService() async -> SemanticSearchService {
        if let service = semanticSearchService {
            return service
        }
        
        let service = await MainActor.run {
            SemanticSearchService()
        }
        
        semanticSearchService = service
        return service
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private init() {}
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}

// MARK: - Folder Operations
extension DataManager {
    
    func createFolder(name: String, parentFolder: Folder? = nil) -> Folder {
        let folderEntity = FolderEntity(context: context)
        let folder = Folder(
            name: name,
            parentFolderId: parentFolder?.id,
            sentiment: .neutral,
            noteCount: 0
        )
        
        folder.updateEntity(folderEntity, context: context)
        save()
        
        return folder
    }
    
    func fetchFolders(parentFolder: Folder? = nil) -> [Folder] {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        
        if let parentFolder = parentFolder {
            request.predicate = NSPredicate(format: "parentFolder.id == %@", parentFolder.id as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "parentFolder == nil")
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FolderEntity.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FolderEntity.name, ascending: true)
        ]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { Folder(from: $0) }
        } catch {
            print("Failed to fetch folders: \(error)")
            return []
        }
    }
    
    func fetchAllFolders() -> [Folder] {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FolderEntity.name, ascending: true)
        ]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { Folder(from: $0) }
        } catch {
            print("Failed to fetch all folders: \(error)")
            return []
        }
    }
    
    func updateFolder(_ folder: Folder) {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                folder.updateEntity(entity, context: context)
                save()
            }
        } catch {
            print("Failed to update folder: \(error)")
        }
    }
    
    func deleteFolder(_ folder: Folder, cascadeDelete: Bool = true) {
        if cascadeDelete {
            // First, delete all notes in this folder
            let notesInFolder = fetchNotes(in: folder)
            for note in notesInFolder {
                deleteNote(note)
            }
            
            // Then, delete all subfolders recursively
            let subfolders = fetchFolders(parentFolder: folder)
            for subfolder in subfolders {
                deleteFolder(subfolder, cascadeDelete: true)
            }
        } else {
            // Move contents to parent folder
            let notesInFolder = fetchNotes(in: folder)
            for note in notesInFolder {
                var updatedNote = note
                updatedNote.folderId = folder.parentFolderId
                updateNote(updatedNote)
            }
            
            let subfolders = fetchFolders(parentFolder: folder)
            for subfolder in subfolders {
                var updatedFolder = subfolder
                updatedFolder.parentFolderId = folder.parentFolderId
                updateFolder(updatedFolder)
            }
        }
        
        // Finally, delete the folder itself
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                save()
            }
        } catch {
            print("Failed to delete folder: \(error)")
        }
    }
    
    func updateFolderNoteCount(_ folderId: UUID) {
        let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        folderRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
        
        let noteRequest: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        noteRequest.predicate = NSPredicate(format: "folder.id == %@", folderId as CVarArg)
        
        do {
            if let folderEntity = try context.fetch(folderRequest).first {
                let noteCount = try context.count(for: noteRequest)
                folderEntity.noteCount = Int32(noteCount)
                save()
            }
        } catch {
            print("Failed to update folder note count: \(error)")
        }
    }
    
    func getFolderPath(_ folder: Folder) -> [Folder] {
        var path: [Folder] = [folder]
        var currentFolder = folder
        
        while let parentId = currentFolder.parentFolderId {
            let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", parentId as CVarArg)
            
            do {
                if let parentEntity = try context.fetch(request).first {
                    let parentFolder = Folder(from: parentEntity)
                    path.insert(parentFolder, at: 0)
                    currentFolder = parentFolder
                } else {
                    break
                }
            } catch {
                print("Failed to get folder path: \(error)")
                break
            }
        }
        
        return path
    }
}

// MARK: - Note Operations
extension DataManager {
    
    func createNote(title: String, content: String, folderId: UUID? = nil) -> Note {
        let noteEntity = NoteEntity(context: context)
        let note = Note(
            title: title,
            content: content,
            folderId: folderId
        )
        
        note.updateEntity(noteEntity, context: context)
        save()
        
        if let folderId = folderId {
            updateFolderNoteCount(folderId)
        }
        
        // Index note for search
        Task {
            let searchService = await getSemanticSearchService()
            await searchService.updateNoteEmbedding(for: note)
        }
        
        return note
    }
    
    func createVoiceNote(
        title: String,
        content: String,
        audioURL: URL?,
        transcript: String?,
        tags: [String]? = nil,
        category: Category? = nil,
        folderId: UUID? = nil,
        aiSummary: String? = nil,
        keyPoints: [String]? = nil,
        actionItems: [ActionItem]? = nil
    ) -> Note {
        let noteEntity = NoteEntity(context: context)
        let note = Note(
            title: title,
            content: content,
            audioURL: audioURL,
            tags: tags ?? [],
            category: category,
            folderId: folderId,
            aiSummary: aiSummary,
            keyPoints: keyPoints ?? [],
            actionItems: actionItems ?? [],
            transcript: transcript
        )
        
        note.updateEntity(noteEntity, context: context)
        save()
        
        if let folderId = folderId {
            updateFolderNoteCount(folderId)
        }
        
        // Index note for search
        Task {
            let searchService = await getSemanticSearchService()
            await searchService.updateNoteEmbedding(for: note)
        }
        
        return note
    }
    
    func createNoteFromData(_ note: Note) -> Note {
        let noteEntity = NoteEntity(context: context)
        note.updateEntity(noteEntity, context: context)
        save()
        
        if let folderId = note.folderId {
            updateFolderNoteCount(folderId)
        }
        
        // Index note for search
        Task {
            let searchService = await getSemanticSearchService()
            await searchService.updateNoteEmbedding(for: note)
        }
        
        return note
    }
    
    func fetchNotes(in folder: Folder? = nil) -> [Note] {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        
        if let folder = folder {
            request.predicate = NSPredicate(format: "folder.id == %@", folder.id as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "folder == nil")
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \NoteEntity.modifiedDate, ascending: false)
        ]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { Note(from: $0) }
        } catch {
            print("Failed to fetch notes: \(error)")
            return []
        }
    }
    
    func fetchAllNotes() -> [Note] {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \NoteEntity.modifiedDate, ascending: false)
        ]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { Note(from: $0) }
        } catch {
            print("Failed to fetch all notes: \(error)")
            return []
        }
    }
    
    func updateNote(_ note: Note) {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                let oldFolderId = entity.folder?.id
                note.updateEntity(entity, context: context)
                save()
                
                if let oldFolderId = oldFolderId {
                    updateFolderNoteCount(oldFolderId)
                }
                if let newFolderId = note.folderId {
                    updateFolderNoteCount(newFolderId)
                }
                
                // Re-index note for search
                Task {
                    let searchService = await self.getSemanticSearchService()
                    await searchService.updateNoteEmbedding(for: note)
                }
            }
        } catch {
            print("Failed to update note: \(error)")
        }
    }
    
    func deleteNote(_ note: Note) {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                let folderId = entity.folder?.id
                context.delete(entity)
                save()
                
                if let folderId = folderId {
                    updateFolderNoteCount(folderId)
                }
            }
        } catch {
            print("Failed to delete note: \(error)")
        }
    }
    
    func searchNotes(query: String, limitToFolder folder: Folder? = nil) -> [Note] {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        
        var predicates: [NSPredicate] = [
            NSPredicate(format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@ OR transcript CONTAINS[cd] %@ OR aiSummary CONTAINS[cd] %@ OR keyPoints CONTAINS[cd] %@", 
                       query, query, query, query, query)
        ]
        
        // Add folder restriction if specified
        if let folder = folder {
            predicates.append(NSPredicate(format: "folder.id == %@", folder.id as CVarArg))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \NoteEntity.modifiedDate, ascending: false)
        ]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { Note(from: $0) }
        } catch {
            print("Failed to search notes: \(error)")
            return []
        }
    }
    
    func searchAllNotes(query: String) -> [Note] {
        return searchNotes(query: query, limitToFolder: nil)
    }
}

// MARK: - Category Operations  
extension DataManager {
    
    func createCategory(name: String, color: String) -> Category {
        let categoryEntity = CategoryEntity(context: context)
        let category = Category(name: name, color: color)
        
        category.updateEntity(categoryEntity)
        save()
        
        return category
    }
    
    func fetchCategories() -> [Category] {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CategoryEntity.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \CategoryEntity.name, ascending: true)
        ]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { Category(from: $0) }
        } catch {
            print("Failed to fetch categories: \(error)")
            return []
        }
    }
    
    func updateCategory(_ category: Category) {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", category.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                category.updateEntity(entity)
                save()
            }
        } catch {
            print("Failed to update category: \(error)")
        }
    }
    
    func deleteCategory(_ category: Category) {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", category.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                save()
            }
        } catch {
            print("Failed to delete category: \(error)")
        }
    }
}
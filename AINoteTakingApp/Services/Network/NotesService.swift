//
//  NotesService.swift
//  AINoteTakingApp
//
//  Service for managing notes via backend API
//

import Foundation
import Combine

class NotesService {
    static let shared = NotesService()
    
    private let client: NetworkClient
    
    private init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    // MARK: - CRUD Operations
    
    func createNote(_ note: Note) -> AnyPublisher<Note, NetworkError> {
        let request = note.toCreateRequest()
        
        // Backend returns: {"note": {...}}
        struct NoteResponse: Codable {
            let note: APINote
        }
        
        return client.request(
            "/notes",
            method: .POST,
            body: request,
            responseType: NoteResponse.self
        )
        .map { response in
            print("✅ Backend created note: \(response.note.title)")
            return Note.from(response.note)
        }
        .eraseToAnyPublisher()
    }
    
    func getNotes(
        folderId: UUID? = nil,
        categoryId: UUID? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) -> AnyPublisher<(notes: [Note], total: Int), NetworkError> {
        
        var queryParams = "?limit=\(limit)&offset=\(offset)"
        
        if let folderId = folderId {
            queryParams += "&folder_id=\(folderId)"
        }
        
        if let categoryId = categoryId {
            queryParams += "&category_id=\(categoryId)"
        }
        
        struct NotesResponse: Codable {
            let notes: [APINote]
            let pagination: PaginationInfo
        }
        
        struct PaginationInfo: Codable {
            let total: Int
            let limit: Int
            let offset: Int
        }
        
        return client.request(
            "/notes\(queryParams)",
            method: .GET,
            responseType: NotesResponse.self
        )
        .map { response in
            let notes = response.notes.map { Note.from($0) }
            return (notes: notes, total: response.pagination.total)
        }
        .eraseToAnyPublisher()
    }
    
    func getNote(by id: UUID) -> AnyPublisher<Note, NetworkError> {
        struct NoteResponse: Codable {
            let note: APINote
        }
        
        return client.request(
            "/notes/\(id)",
            method: .GET,
            responseType: NoteResponse.self
        )
        .map { Note.from($0.note) }
        .eraseToAnyPublisher()
    }
    
    func updateNote(
        _ id: UUID,
        title: String? = nil,
        content: String? = nil,
        tags: [String]? = nil,
        folderId: UUID? = nil,
        categoryId: UUID? = nil
    ) -> AnyPublisher<Note, NetworkError> {
        
        struct UpdateRequest: Codable {
            let title: String?
            let content: String?
            let tags: [String]?
            let folderId: UUID?
            let categoryId: UUID?
            
            enum CodingKeys: String, CodingKey {
                case title, content, tags
                case folderId = "folder_id"
                case categoryId = "category_id"
            }
        }
        
        let request = UpdateRequest(
            title: title,
            content: content,
            tags: tags,
            folderId: folderId,
            categoryId: categoryId
        )
        
        // Backend returns: {"note": {...}}
        struct NoteResponse: Codable {
            let note: APINote
        }
        
        return client.request(
            "/notes/\(id)",
            method: .PUT,
            body: request,
            responseType: NoteResponse.self
        )
        .map { response in
            print("✅ Backend updated note: \(response.note.title)")
            return Note.from(response.note)
        }
        .eraseToAnyPublisher()
    }
    
    func deleteNote(_ id: UUID) -> AnyPublisher<Void, NetworkError> {
        return client.request(
            "/notes/\(id)",
            method: .DELETE
        )
    }
    
    func searchNotes(
        query: String,
        limit: Int = 20,
        offset: Int = 0
    ) -> AnyPublisher<(notes: [Note], total: Int), NetworkError> {
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        struct SearchResponse: Codable {
            let notes: [APINote]
            let pagination: PaginationInfo
        }
        
        struct PaginationInfo: Codable {
            let total: Int
            let limit: Int
            let offset: Int
        }
        
        return client.request(
            "/notes/search?q=\(encodedQuery)&limit=\(limit)&offset=\(offset)",
            method: .GET,
            responseType: SearchResponse.self
        )
        .map { response in
            let notes = response.notes.map { Note.from($0) }
            return (notes: notes, total: response.pagination.total)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Batch Operations
    
    func batchCreateNotes(_ notes: [Note]) -> AnyPublisher<[Note], NetworkError> {
        struct BatchRequest: Codable {
            let notes: [NoteCreateRequest]
        }
        
        struct BatchResponse: Codable {
            let notes: [APINote]
            let successful: Int
            let errors: [String]?
        }
        
        let request = BatchRequest(notes: notes.map { $0.toCreateRequest() })
        
        return client.request(
            "/notes/batch",
            method: .POST,
            body: request,
            responseType: BatchResponse.self
        )
        .tryMap { response in
            if let errors = response.errors, !errors.isEmpty {
                print("Batch create had errors: \(errors)")
            }
            return response.notes.map { Note.from($0) }
        }
        .mapError { $0 as? NetworkError ?? NetworkError.networkFailed }
        .eraseToAnyPublisher()
    }
    
    func batchDeleteNotes(_ ids: [UUID]) -> AnyPublisher<Void, NetworkError> {
        struct BatchDeleteRequest: Codable {
            let noteIds: [UUID]
            
            enum CodingKeys: String, CodingKey {
                case noteIds = "note_ids"
            }
        }
        
        let request = BatchDeleteRequest(noteIds: ids)
        
        return client.request(
            "/notes/batch",
            method: .DELETE,
            body: request
        )
    }
}
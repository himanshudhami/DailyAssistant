//
//  FoldersService.swift
//  AINoteTakingApp
//
//  Service for managing folders via backend API
//

import Foundation
import Combine

class FoldersService {
    static let shared = FoldersService()
    
    private let client: NetworkClient
    
    private init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    // MARK: - CRUD Operations
    
    func createFolder(_ folder: Folder) -> AnyPublisher<Folder, NetworkError> {
        let request = folder.toCreateRequest()
        
        struct FolderResponse: Codable {
            let folder: APIFolder
        }
        
        return client.request(
            "/folders",
            method: .POST,
            body: request,
            responseType: FolderResponse.self
        )
        .map { Folder.from($0.folder) }
        .eraseToAnyPublisher()
    }
    
    func getFolders(parentFolderId: UUID? = nil) -> AnyPublisher<[Folder], NetworkError> {
        var endpoint = "/folders"
        if let parentId = parentFolderId {
            endpoint += "?parent_folder_id=\(parentId)"
        }
        
        struct FoldersResponse: Codable {
            let folders: [APIFolder]
        }
        
        return client.request(
            endpoint,
            method: .GET,
            responseType: FoldersResponse.self
        )
        .map { response in
            response.folders.map { Folder.from($0) }
        }
        .eraseToAnyPublisher()
    }
    
    func getFolder(by id: UUID) -> AnyPublisher<Folder, NetworkError> {
        struct FolderResponse: Codable {
            let folder: APIFolder
        }
        
        return client.request(
            "/folders/\(id)",
            method: .GET,
            responseType: FolderResponse.self
        )
        .map { Folder.from($0.folder) }
        .eraseToAnyPublisher()
    }
    
    func updateFolder(
        _ id: UUID,
        name: String? = nil,
        parentFolderId: UUID? = nil,
        sentiment: FolderSentiment? = nil
    ) -> AnyPublisher<Folder, NetworkError> {
        
        struct UpdateRequest: Codable {
            let name: String?
            let parentFolderId: UUID?
            let sentiment: FolderSentiment?
            
            enum CodingKeys: String, CodingKey {
                case name, sentiment
                case parentFolderId = "parent_folder_id"
            }
        }
        
        let request = UpdateRequest(
            name: name,
            parentFolderId: parentFolderId,
            sentiment: sentiment
        )
        
        struct FolderResponse: Codable {
            let folder: APIFolder
        }
        
        return client.request(
            "/folders/\(id)",
            method: .PUT,
            body: request,
            responseType: FolderResponse.self
        )
        .map { Folder.from($0.folder) }
        .eraseToAnyPublisher()
    }
    
    func deleteFolder(_ id: UUID) -> AnyPublisher<Void, NetworkError> {
        return client.request(
            "/folders/\(id)",
            method: .DELETE
        )
    }
    
    // MARK: - Folder Hierarchy
    
    func getFolderHierarchy(for folderId: UUID) -> AnyPublisher<[Folder], NetworkError> {
        // This would ideally be a backend endpoint, but we can build it client-side
        // by recursively fetching parent folders
        
        func fetchParentChain(currentId: UUID, chain: [Folder]) -> AnyPublisher<[Folder], NetworkError> {
            return getFolder(by: currentId)
                .flatMap { folder -> AnyPublisher<[Folder], NetworkError> in
                    var newChain = chain
                    newChain.insert(folder, at: 0)
                    
                    if let parentId = folder.parentFolderId {
                        return fetchParentChain(currentId: parentId, chain: newChain)
                    } else {
                        return Just(newChain)
                            .setFailureType(to: NetworkError.self)
                            .eraseToAnyPublisher()
                    }
                }
                .eraseToAnyPublisher()
        }
        
        return fetchParentChain(currentId: folderId, chain: [])
    }
}
//
//  CategoriesService.swift
//  AINoteTakingApp
//
//  Service for managing categories via backend API
//

import Foundation
import Combine

class CategoriesService {
    static let shared = CategoriesService()
    
    private let client: NetworkClient
    
    private init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    // MARK: - CRUD Operations
    
    func createCategory(name: String, color: String) -> AnyPublisher<Category, NetworkError> {
        struct CreateRequest: Codable {
            let name: String
            let color: String
        }
        
        struct CategoryResponse: Codable {
            let category: APICategory
        }
        
        struct APICategory: Codable {
            let id: UUID
            let name: String
            let color: String
            let sortOrder: Int
            let createdAt: String
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case id, name, color
                case sortOrder = "sort_order"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let request = CreateRequest(name: name, color: color)
        
        return client.request(
            "/categories",
            method: .POST,
            body: request,
            responseType: CategoryResponse.self
        )
        .map { response in
            Category(
                id: response.category.id,
                name: response.category.name,
                color: response.category.color,
                sortOrder: response.category.sortOrder
            )
        }
        .eraseToAnyPublisher()
    }
    
    func getCategories() -> AnyPublisher<[Category], NetworkError> {
        struct CategoriesResponse: Codable {
            let categories: [APICategory]
        }
        
        struct APICategory: Codable {
            let id: UUID
            let name: String
            let color: String
            let sortOrder: Int
            let createdAt: String
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case id, name, color
                case sortOrder = "sort_order"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        return client.request(
            "/categories",
            method: .GET,
            responseType: CategoriesResponse.self
        )
        .map { response in
            response.categories.map { apiCategory in
                Category(
                    id: apiCategory.id,
                    name: apiCategory.name,
                    color: apiCategory.color,
                    sortOrder: apiCategory.sortOrder
                )
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getCategory(by id: UUID) -> AnyPublisher<Category, NetworkError> {
        struct CategoryResponse: Codable {
            let category: APICategory
        }
        
        struct APICategory: Codable {
            let id: UUID
            let name: String
            let color: String
            let sortOrder: Int
            let createdAt: String
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case id, name, color
                case sortOrder = "sort_order"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        return client.request(
            "/categories/\(id)",
            method: .GET,
            responseType: CategoryResponse.self
        )
        .map { response in
            Category(
                id: response.category.id,
                name: response.category.name,
                color: response.category.color,
                sortOrder: response.category.sortOrder
            )
        }
        .eraseToAnyPublisher()
    }
    
    func updateCategory(
        _ id: UUID,
        name: String? = nil,
        color: String? = nil
    ) -> AnyPublisher<Category, NetworkError> {
        
        struct UpdateRequest: Codable {
            let name: String?
            let color: String?
        }
        
        struct CategoryResponse: Codable {
            let category: APICategory
        }
        
        struct APICategory: Codable {
            let id: UUID
            let name: String
            let color: String
            let sortOrder: Int
            let createdAt: String
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case id, name, color
                case sortOrder = "sort_order"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let request = UpdateRequest(name: name, color: color)
        
        return client.request(
            "/categories/\(id)",
            method: .PUT,
            body: request,
            responseType: CategoryResponse.self
        )
        .map { response in
            Category(
                id: response.category.id,
                name: response.category.name,
                color: response.category.color,
                sortOrder: response.category.sortOrder
            )
        }
        .eraseToAnyPublisher()
    }
    
    func deleteCategory(_ id: UUID) -> AnyPublisher<Void, NetworkError> {
        return client.request(
            "/categories/\(id)",
            method: .DELETE
        )
    }
}
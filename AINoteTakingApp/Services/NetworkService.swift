//
//  NetworkService.swift
//  AINoteTakingApp
//
//  Main facade for all network operations
//  Coordinates between different service layers
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import Combine

class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    // Services
    let auth: AuthService
    let notes: NotesService
    let folders: FoldersService
    let categories: CategoriesService
    let attachments: AttachmentsService
    
    // Published state (delegated from AuthService)
    @Published var isAuthenticated = false
    @Published var currentUser: UserResponse?
    
    // Combine
    var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initialize services
        self.auth = AuthService.shared
        self.notes = NotesService.shared
        self.folders = FoldersService.shared
        self.categories = CategoriesService.shared
        self.attachments = AttachmentsService.shared
        
        // Bind authentication state
        auth.$isAuthenticated
            .assign(to: &$isAuthenticated)
        
        auth.$currentUser
            .assign(to: &$currentUser)
    }
    
    // MARK: - Authentication Convenience Methods
    
    func register(_ request: UserCreateRequest) -> AnyPublisher<AuthResponse, NetworkError> {
        return auth.register(request)
    }
    
    func login(_ request: UserLoginRequest) -> AnyPublisher<AuthResponse, NetworkError> {
        return auth.login(request)
    }
    
    func logout() {
        auth.logout()
    }
    
    // MARK: - Sync Operations
    
    /// Syncs local data with backend
    func syncData() -> AnyPublisher<Void, NetworkError> {
        // This will be implemented when we add the sync strategy
        // For now, just fetch latest data
        return Publishers.Zip3(
            folders.getFolders(),
            categories.getCategories(),
            notes.getNotes()
        )
        .map { _, _, _ in () }
        .eraseToAnyPublisher()
    }
    
    /// Check if backend is reachable
    func checkConnectivity() -> AnyPublisher<Bool, Never> {
        let client = NetworkClient.shared
        
        struct HealthResponse: Codable {
            let status: String
        }
        
        return client.request(
            "/health",
            method: .GET,
            responseType: HealthResponse.self
        )
        .map { _ in true }
        .replaceError(with: false)
        .eraseToAnyPublisher()
    }
}
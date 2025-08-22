//
//  AuthService.swift
//  AINoteTakingApp
//
//  Authentication service for user registration and login
//

import Foundation
import Combine

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: UserResponse?
    
    private let client: NetworkClient
    private var cancellables = Set<AnyCancellable>()
    
    private init(client: NetworkClient = .shared) {
        self.client = client
        
        // Check if we have a stored token
        if client.authToken != nil {
            isAuthenticated = true
            // Could fetch user profile here if needed
        }
    }
    
    // MARK: - Public Methods
    
    func register(_ request: UserCreateRequest) -> AnyPublisher<AuthResponse, NetworkError> {
        return client.request(
            "/auth/register",
            method: .POST,
            body: request,
            responseType: AuthResponse.self
        )
        .handleEvents(receiveOutput: { [weak self] response in
            self?.handleAuthSuccess(response)
        })
        .eraseToAnyPublisher()
    }
    
    func login(_ request: UserLoginRequest) -> AnyPublisher<AuthResponse, NetworkError> {
        return client.request(
            "/auth/login",
            method: .POST,
            body: request,
            responseType: AuthResponse.self
        )
        .handleEvents(receiveOutput: { [weak self] response in
            self?.handleAuthSuccess(response)
        })
        .eraseToAnyPublisher()
    }
    
    func logout() {
        client.authToken = nil
        currentUser = nil
        isAuthenticated = false
        
        // Clear any cached data
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
    
    func getProfile() -> AnyPublisher<UserResponse, NetworkError> {
        return client.request(
            "/profile",
            method: .GET,
            body: EmptyBody(),
            responseType: UserResponse.self
        )
        .handleEvents(receiveOutput: { [weak self] user in
            self?.currentUser = user
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func handleAuthSuccess(_ response: AuthResponse) {
        client.authToken = response.token
        currentUser = response.user
        isAuthenticated = true
        
        // Notify app of successful authentication
        NotificationCenter.default.post(name: .userDidLogin, object: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
}
//
//  NetworkClient.swift
//  AINoteTakingApp
//
//  Base network client providing core networking functionality
//  Handles HTTP requests, authentication headers, and error handling
//

import Foundation
import Combine

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Network Client Protocol
protocol NetworkClientProtocol {
    func request<T: Decodable>(_ endpoint: String, method: HTTPMethod, body: Encodable?, responseType: T.Type) -> AnyPublisher<T, NetworkError>
    func request(_ endpoint: String, method: HTTPMethod, body: Encodable?) -> AnyPublisher<Void, NetworkError>
}

// MARK: - Network Client Implementation
class NetworkClient: NetworkClientProtocol {
    static let shared = NetworkClient()
    
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let configuration = AppConfiguration.shared
    
    var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }
    
    init(baseURL: String? = nil, session: URLSession? = nil) {
        // Use provided baseURL or fall back to configuration
        self.baseURL = baseURL ?? AppConfiguration.shared.apiBaseURL
        
        // Validate the URL on initialization
        if !AppConfiguration.shared.validateAPIURL() {
            print("⚠️ Warning: API URL configuration may be invalid")
        }
        
        // Configure URLSession with timeout
        if let customSession = session {
            self.session = customSession
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = AppConfiguration.shared.apiTimeout
            config.timeoutIntervalForResource = AppConfiguration.shared.apiTimeout * 2
            
            // Add security headers
            config.httpAdditionalHeaders = [
                "User-Agent": "AINoteTakingApp/1.0",
                "Accept": "application/json"
            ]
            
            self.session = URLSession(configuration: config)
        }
        
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        // Configure decoder for ISO8601 dates
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        
        // Print configuration in debug mode
        #if DEBUG
        print("🔧 NetworkClient initialized")
        print("   Base URL: \(self.baseURL)")
        print("   Require HTTPS: \(configuration.requireHTTPS)")
        configuration.printConfiguration()
        #endif
    }
    
    // MARK: - Request with Response
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        
        guard let url = URL(string: baseURL + endpoint) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        // Enforce HTTPS if required
        if configuration.requireHTTPS && url.scheme != "https" {
            print("❌ HTTPS required but attempting to use \(url.scheme ?? "unknown")")
            print("   URL: \(url.absoluteString)")
            print("   Environment: \(AppEnvironment.current.rawValue)")
            print("   To allow HTTP for local development:")
            print("   - Your URL should contain 'localhost', '127.0.0.1', '192.168.', or '10.0.'")
            print("   - Or set ALLOW_HTTP=true in environment variables")
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth header if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if provided
        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                return Fail(error: NetworkError.encodingFailed)
                    .eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response in
                try self?.handleResponse(data: data, response: response) ?? data
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { [weak self] error in
                self?.handleError(error) ?? NetworkError.networkFailed
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Request without Response (Void)
    func request(
        _ endpoint: String,
        method: HTTPMethod,
        body: Encodable? = nil
    ) -> AnyPublisher<Void, NetworkError> {
        
        struct EmptyResponse: Decodable {}
        
        return request(endpoint, method: method, body: body, responseType: EmptyResponse.self)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Response Handling
    private func handleResponse(data: Data, response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.networkFailed
        }
        
        #if DEBUG
        print("HTTP Status: \(httpResponse.statusCode) for \(httpResponse.url?.path ?? "")")
        #endif
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 400:
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw NetworkError.validationFailed(errorMessage)
            }
            throw NetworkError.validationFailed("Invalid request")
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.networkFailed
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) -> NetworkError {
        #if DEBUG
        print("Network error: \(error)")
        #endif
        
        if let networkError = error as? NetworkError {
            return networkError
        } else if error is DecodingError {
            return NetworkError.decodingFailed
        } else {
            return NetworkError.networkFailed
        }
    }
}

// MARK: - Empty Body for GET/DELETE requests
struct EmptyBody: Encodable {}
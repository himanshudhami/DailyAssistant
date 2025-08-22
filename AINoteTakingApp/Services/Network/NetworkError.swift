//
//  NetworkError.swift
//  AINoteTakingApp
//
//  Network error types for API communication
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case networkFailed
    case encodingFailed
    case decodingFailed
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case validationFailed(String)
    case noData
    case offline
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkFailed:
            return "Network request failed"
        case .encodingFailed:
            return "Failed to encode request"
        case .decodingFailed:
            return "Failed to decode response"
        case .unauthorized:
            return "Please log in to continue"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error occurred"
        case .validationFailed(let message):
            return message
        case .noData:
            return "No data received"
        case .offline:
            return "No internet connection"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkFailed, .serverError, .offline:
            return true
        default:
            return false
        }
    }
}
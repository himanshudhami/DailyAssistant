//
//  AppConfiguration.swift
//  AINoteTakingApp
//
//  Centralized configuration for API endpoints and environment settings
//  Supports multiple environments (development, staging, production)
//

import Foundation

enum AppEnvironment: String {
    case development = "development"
    case staging = "staging"
    case production = "production"
    
    static var current: AppEnvironment {
        #if DEBUG
        // For debug builds, check for environment override
        if let envString = ProcessInfo.processInfo.environment["APP_ENVIRONMENT"],
           let env = AppEnvironment(rawValue: envString) {
            return env
        }
        return .development
        #else
        // For release builds, default to production
        return .production
        #endif
    }
}

struct AppConfiguration {
    static let shared = AppConfiguration()
    
    private init() {}
    
    // MARK: - API Configuration
    
    var apiBaseURL: String {
        // First check for environment variable override
        if let overrideURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
            return overrideURL
        }
        
        // Otherwise use environment-specific defaults
        switch AppEnvironment.current {
        case .development:
            // For local development, you can use localhost or a dev server
            return "http://192.168.86.26:8080/api/v1"
            
        case .staging:
            return "https://staging-api.mynotes.app/api/v1"
            
        case .production:
            return "https://api.mynotes.app/api/v1"
        }
    }
    
    var apiTimeout: TimeInterval {
        switch AppEnvironment.current {
        case .development:
            return 30.0  // Longer timeout for debugging
        case .staging:
            return 20.0
        case .production:
            return 15.0
        }
    }
    
    // MARK: - Security Configuration
    
    var requireHTTPS: Bool {
        switch AppEnvironment.current {
        case .development:
            // In development, check if we're using a local URL
            if apiBaseURL.contains("localhost") || 
               apiBaseURL.contains("127.0.0.1") || 
               apiBaseURL.contains("192.168.") ||
               apiBaseURL.contains("10.0.") {
                // Allow HTTP for local development servers
                return false
            }
            
            // For non-local dev URLs, allow HTTP if explicitly set
            if let allowHTTP = ProcessInfo.processInfo.environment["ALLOW_HTTP"],
               allowHTTP.lowercased() == "true" {
                return false
            }
            
            // Otherwise require HTTPS even in development
            return true
            
        case .staging, .production:
            // Always require HTTPS in staging and production
            return true
        }
    }
    
    var certificatePinning: Bool {
        switch AppEnvironment.current {
        case .development:
            return false
        case .staging:
            return true
        case .production:
            return true
        }
    }
    
    // MARK: - Feature Flags
    
    var enableDebugLogging: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var enableCrashReporting: Bool {
        switch AppEnvironment.current {
        case .development:
            return false
        case .staging, .production:
            return true
        }
    }
    
    var enableAnalytics: Bool {
        switch AppEnvironment.current {
        case .development:
            return false
        case .staging:
            return false
        case .production:
            return true
        }
    }
    
    // MARK: - Validation
    
    func validateAPIURL() -> Bool {
        guard let url = URL(string: apiBaseURL) else {
            print("❌ Invalid API URL configuration: \(apiBaseURL)")
            return false
        }
        
        if requireHTTPS && url.scheme != "https" {
            print("⚠️ Warning: HTTPS is required but URL uses \(url.scheme ?? "unknown") scheme")
            print("   API URL: \(apiBaseURL)")
            print("   Environment: \(AppEnvironment.current.rawValue)")
            print("   Require HTTPS: \(requireHTTPS)")
            return false
        }
        
        print("✅ API URL validated: \(apiBaseURL)")
        return true
    }
    
    // MARK: - Helper Methods
    
    func printConfiguration() {
        print("📱 App Configuration")
        print("├─ Environment: \(AppEnvironment.current.rawValue)")
        print("├─ API Base URL: \(apiBaseURL)")
        print("├─ Require HTTPS: \(requireHTTPS)")
        print("├─ Certificate Pinning: \(certificatePinning)")
        print("├─ Debug Logging: \(enableDebugLogging)")
        print("├─ Crash Reporting: \(enableCrashReporting)")
        print("└─ Analytics: \(enableAnalytics)")
    }
}

// MARK: - URL Extensions for Safe Construction

extension AppConfiguration {
    func apiURL(for endpoint: String) -> URL? {
        guard validateAPIURL() else { return nil }
        
        let cleanedEndpoint = endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)"
        let fullURLString = apiBaseURL + cleanedEndpoint
        
        return URL(string: fullURLString)
    }
}

//
//  LocationService.swift
//  AINoteTakingApp
//
//  Service for handling location-based functionality
//  Provides simple async methods to get current GPS coordinates
//
//  Created by AI Assistant on 2025-01-30.
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Location Coordinate Model
struct LocationCoordinate {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    
    var isValid: Bool {
        return accuracy <= 100 // Consider location valid if accuracy is within 100 meters
    }
}

// MARK: - Location Service Errors
enum LocationServiceError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case timeout
    case accuracyTooLow
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied"
        case .locationUnavailable:
            return "Location services unavailable"
        case .timeout:
            return "Location request timed out"
        case .accuracyTooLow:
            return "Location accuracy too low"
        }
    }
}

// MARK: - Location Service
@MainActor
class LocationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLocationAvailable = false
    @Published var currentLocation: LocationCoordinate?
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<LocationCoordinate, Error>?
    private let timeout: TimeInterval = 10.0 // 10 seconds timeout
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        checkLocationAvailability()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }
    
    private func checkLocationAvailability() {
        isLocationAvailable = CLLocationManager.locationServicesEnabled() &&
                             locationManager.authorizationStatus == .authorizedWhenInUse
    }
    
    // MARK: - Public Methods
    
    /// Gets the current location with a timeout
    func getCurrentLocation() async throws -> LocationCoordinate {
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationServiceError.locationUnavailable
        }
        
        // Check authorization status
        let authStatus = locationManager.authorizationStatus
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            throw LocationServiceError.permissionDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            
            // Set up timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                if self?.locationContinuation != nil {
                    self?.locationContinuation?.resume(throwing: LocationServiceError.timeout)
                    self?.locationContinuation = nil
                }
            }
            
            // Request location
            locationManager.requestLocation()
        }
    }
    
    /// Gets current location with fallback to nil if unavailable
    func getCurrentLocationSafely() async -> LocationCoordinate? {
        do {
            return try await getCurrentLocation()
        } catch {
            print("⚠️ Failed to get location: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Requests location permission if needed
    func requestLocationPermission() async -> Bool {
        guard CLLocationManager.locationServicesEnabled() else {
            return false
        }
        
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationAvailable = true
            return true
        case .denied, .restricted:
            isLocationAvailable = false
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                // Store continuation to resume when authorization changes
                Task {
                    locationManager.requestWhenInUseAuthorization()
                    // Wait a bit for the authorization to process
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    let newStatus = locationManager.authorizationStatus
                    let granted = newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways
                    await MainActor.run {
                        self.isLocationAvailable = granted
                    }
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            isLocationAvailable = false
            return false
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let coordinate = LocationCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
        
        currentLocation = coordinate
        
        // Resume continuation if waiting
        if let continuation = locationContinuation {
            locationContinuation = nil
            
            if coordinate.isValid {
                continuation.resume(returning: coordinate)
            } else {
                continuation.resume(throwing: LocationServiceError.accuracyTooLow)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error)")
        
        // Resume continuation with error if waiting
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(throwing: LocationServiceError.locationUnavailable)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAvailability()
    }
}

// MARK: - Convenience Extensions
extension LocationCoordinate {
    /// Returns a formatted string representation of the coordinates
    var formattedString: String {
        return String(format: "%.6f, %.6f", latitude, longitude)
    }
    
    /// Returns a human-readable accuracy description
    var accuracyDescription: String {
        if accuracy < 5 {
            return "Excellent"
        } else if accuracy < 20 {
            return "Good"
        } else if accuracy < 100 {
            return "Fair"
        } else {
            return "Poor"
        }
    }
}

//
//  PermissionManager.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import UIKit
import AVFoundation
import Speech
import Photos
import EventKit
import CoreLocation

// MARK: - Permission Types
enum PermissionType: String, CaseIterable {
    case microphone = "Microphone"
    case speechRecognition = "Speech Recognition"
    case camera = "Camera"
    case photoLibrary = "Photo Library"
    case calendar = "Calendar"
    case location = "Location"
    
    var description: String {
        switch self {
        case .microphone:
            return "Record voice notes and audio"
        case .speechRecognition:
            return "Convert speech to text"
        case .camera:
            return "Capture images for notes"
        case .photoLibrary:
            return "Import images from photo library"
        case .calendar:
            return "Create meeting notes and reminders"
        case .location:
            return "Provide location-based note suggestions"
        }
    }
    
    var icon: String {
        switch self {
        case .microphone: return "mic.fill"
        case .speechRecognition: return "waveform"
        case .camera: return "camera.fill"
        case .photoLibrary: return "photo.fill"
        case .calendar: return "calendar"
        case .location: return "location.fill"
        }
    }
}

// MARK: - Permission Status
enum PermissionStatus {
    case notDetermined
    case granted
    case denied
    case restricted
    
    var isGranted: Bool {
        return self == .granted
    }
}

// MARK: - Permission Manager
@MainActor
class PermissionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var speechRecognitionStatus: PermissionStatus = .notDetermined
    @Published var cameraStatus: PermissionStatus = .notDetermined
    @Published var photoLibraryStatus: PermissionStatus = .notDetermined
    @Published var calendarStatus: PermissionStatus = .notDetermined
    @Published var locationStatus: PermissionStatus = .notDetermined
    
    @Published var allPermissionsGranted = false
    @Published var criticalPermissionsGranted = false
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkAllPermissions()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
    }
    
    // MARK: - Permission Checking
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkCameraPermission()
        checkPhotoLibraryPermission()
        checkCalendarPermission()
        checkLocationPermission()
        updatePermissionStates()
    }
    
    private func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            microphoneStatus = .granted
        case .denied:
            microphoneStatus = .denied
        case .undetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .notDetermined
        }
    }
    
    private func checkSpeechRecognitionPermission() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechRecognitionStatus = .granted
        case .denied:
            speechRecognitionStatus = .denied
        case .restricted:
            speechRecognitionStatus = .restricted
        case .notDetermined:
            speechRecognitionStatus = .notDetermined
        @unknown default:
            speechRecognitionStatus = .notDetermined
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraStatus = .granted
        case .denied:
            cameraStatus = .denied
        case .restricted:
            cameraStatus = .restricted
        case .notDetermined:
            cameraStatus = .notDetermined
        @unknown default:
            cameraStatus = .notDetermined
        }
    }
    
    private func checkPhotoLibraryPermission() {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            photoLibraryStatus = .granted
        case .denied:
            photoLibraryStatus = .denied
        case .restricted:
            photoLibraryStatus = .restricted
        case .notDetermined:
            photoLibraryStatus = .notDetermined
        @unknown default:
            photoLibraryStatus = .notDetermined
        }
    }
    
    private func checkCalendarPermission() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            calendarStatus = .granted
        case .denied:
            calendarStatus = .denied
        case .restricted:
            calendarStatus = .restricted
        case .notDetermined:
            calendarStatus = .notDetermined
        @unknown default:
            calendarStatus = .notDetermined
        }
    }
    
    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationStatus = .granted
        case .denied:
            locationStatus = .denied
        case .restricted:
            locationStatus = .restricted
        case .notDetermined:
            locationStatus = .notDetermined
        @unknown default:
            locationStatus = .notDetermined
        }
    }
    
    private func updatePermissionStates() {
        // Critical permissions for core functionality
        criticalPermissionsGranted = microphoneStatus.isGranted && speechRecognitionStatus.isGranted
        
        // All permissions
        allPermissionsGranted = microphoneStatus.isGranted &&
                               speechRecognitionStatus.isGranted &&
                               cameraStatus.isGranted &&
                               photoLibraryStatus.isGranted &&
                               calendarStatus.isGranted &&
                               locationStatus.isGranted
    }
    
    // MARK: - Permission Requesting
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    self.microphoneStatus = granted ? .granted : .denied
                    self.updatePermissionStates()
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    switch status {
                    case .authorized:
                        self.speechRecognitionStatus = .granted
                        continuation.resume(returning: true)
                    case .denied:
                        self.speechRecognitionStatus = .denied
                        continuation.resume(returning: false)
                    case .restricted:
                        self.speechRecognitionStatus = .restricted
                        continuation.resume(returning: false)
                    case .notDetermined:
                        self.speechRecognitionStatus = .notDetermined
                        continuation.resume(returning: false)
                    @unknown default:
                        self.speechRecognitionStatus = .notDetermined
                        continuation.resume(returning: false)
                    }
                    self.updatePermissionStates()
                }
            }
        }
    }
    
    func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.cameraStatus = granted ? .granted : .denied
                    self.updatePermissionStates()
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func requestPhotoLibraryPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                Task { @MainActor in
                    switch status {
                    case .authorized, .limited:
                        self.photoLibraryStatus = .granted
                        continuation.resume(returning: true)
                    case .denied:
                        self.photoLibraryStatus = .denied
                        continuation.resume(returning: false)
                    case .restricted:
                        self.photoLibraryStatus = .restricted
                        continuation.resume(returning: false)
                    case .notDetermined:
                        self.photoLibraryStatus = .notDetermined
                        continuation.resume(returning: false)
                    @unknown default:
                        self.photoLibraryStatus = .notDetermined
                        continuation.resume(returning: false)
                    }
                    self.updatePermissionStates()
                }
            }
        }
    }
    
    func requestCalendarPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            let eventStore = EKEventStore()
            eventStore.requestAccess(to: .event) { granted, error in
                Task { @MainActor in
                    self.calendarStatus = granted ? .granted : .denied
                    self.updatePermissionStates()
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func requestLocationPermission() async -> Bool {
        guard locationStatus == .notDetermined else {
            return locationStatus.isGranted
        }
        
        return await withCheckedContinuation { continuation in
            locationPermissionContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private var locationPermissionContinuation: CheckedContinuation<Bool, Never>?
    
    // MARK: - Batch Permission Requests
    func requestCriticalPermissions() async -> Bool {
        let microphoneGranted = await requestMicrophonePermission()
        let speechGranted = await requestSpeechRecognitionPermission()
        
        return microphoneGranted && speechGranted
    }
    
    func requestAllPermissions() async -> Bool {
        async let microphone = requestMicrophonePermission()
        async let speech = requestSpeechRecognitionPermission()
        async let camera = requestCameraPermission()
        async let photoLibrary = requestPhotoLibraryPermission()
        async let calendar = requestCalendarPermission()
        async let location = requestLocationPermission()
        
        let results = await [microphone, speech, camera, photoLibrary, calendar, location]
        return results.allSatisfy { $0 }
    }
    
    // MARK: - Permission Status Helpers
    func getPermissionStatus(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .microphone: return microphoneStatus
        case .speechRecognition: return speechRecognitionStatus
        case .camera: return cameraStatus
        case .photoLibrary: return photoLibraryStatus
        case .calendar: return calendarStatus
        case .location: return locationStatus
        }
    }
    
    func isPermissionGranted(for type: PermissionType) -> Bool {
        return getPermissionStatus(for: type).isGranted
    }
    
    func getDeniedPermissions() -> [PermissionType] {
        return PermissionType.allCases.filter { type in
            getPermissionStatus(for: type) == .denied
        }
    }
    
    func getNotDeterminedPermissions() -> [PermissionType] {
        return PermissionType.allCases.filter { type in
            getPermissionStatus(for: type) == .notDetermined
        }
    }
    
    // MARK: - Settings Navigation
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Permission Descriptions
    func getPermissionRationale(for type: PermissionType) -> String {
        switch type {
        case .microphone:
            return "AI Note Taking needs microphone access to record voice notes and provide real-time transcription. This enables you to quickly capture thoughts and ideas hands-free."
        case .speechRecognition:
            return "Speech recognition allows the app to convert your voice recordings into searchable text, making your notes more accessible and useful."
        case .camera:
            return "Camera access enables you to capture images and documents directly into your notes, with automatic text extraction using OCR technology."
        case .photoLibrary:
            return "Photo library access allows you to import existing images into your notes and extract text from them using advanced OCR capabilities."
        case .calendar:
            return "Calendar integration helps create context-aware notes for meetings and events, automatically suggesting relevant information and follow-ups."
        case .location:
            return "Location services enable smart note suggestions based on where you are, helping you stay organized and contextually aware."
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension PermissionManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationPermission()
        
        if let continuation = locationPermissionContinuation {
            locationPermissionContinuation = nil
            continuation.resume(returning: locationStatus.isGranted)
        }
    }
}

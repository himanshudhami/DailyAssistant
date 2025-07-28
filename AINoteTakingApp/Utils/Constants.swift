//
//  Constants.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import SwiftUI
import AVFoundation

// MARK: - App Constants
struct AppConstants {
    
    // MARK: - App Information
    struct App {
        static let name = "AI Note Taking"
        static let version = "1.0"
        static let bundleIdentifier = "com.ainotetaking.app"
    }
    
    // MARK: - File Limits
    struct FileLimits {
        static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
        static let maxNoteTitleLength = 200
        static let maxNoteContentLength = 50000
        static let maxTagsPerNote = 20
        static let maxTagLength = 50
        static let maxAttachmentsPerNote = 10
    }
    
    // MARK: - Audio Settings
    struct Audio {
        static let maxRecordingDuration: TimeInterval = 3600 // 1 hour
        static let sampleRate: Double = 44100
        static let audioQuality = AVAudioQuality.high
        static let audioFormat = kAudioFormatMPEG4AAC
    }
    
    // MARK: - AI Processing
    struct AI {
        static let maxSummaryLength = 200
        static let maxKeyPoints = 5
        static let maxActionItems = 10
        static let maxSuggestedTags = 8
        static let processingTimeout: TimeInterval = 30
        static let similarityThreshold = 0.3
    }
    
    // MARK: - Security
    struct Security {
        static let appLockTimeout: TimeInterval = 300 // 5 minutes
        static let maxFailedAttempts = 5
        static let lockoutDuration: TimeInterval = 900 // 15 minutes
        static let encryptionKeySize = 256
    }
    
    // MARK: - UI Constants
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
        static let animationDuration: Double = 0.3
        static let thumbnailSize = CGSize(width: 200, height: 200)
        static let cardSpacing: CGFloat = 16
        static let padding: CGFloat = 16
    }
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color.blue
        static let secondary = Color.gray
        static let accent = Color.blue
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
    }
    
    // MARK: - Fonts
    struct Fonts {
        static let largeTitle = Font.largeTitle
        static let title = Font.title
        static let title2 = Font.title2
        static let title3 = Font.title3
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Icons
    struct Icons {
        static let note = "note.text"
        static let microphone = "mic.fill"
        static let camera = "camera.fill"
        static let attachment = "paperclip"
        static let ai = "brain.head.profile"
        static let search = "magnifyingglass"
        static let settings = "gear"
        static let lock = "lock.fill"
        static let unlock = "lock.open.fill"
        static let play = "play.circle.fill"
        static let pause = "pause.circle.fill"
        static let stop = "stop.circle.fill"
        static let record = "record.circle"
        static let checkmark = "checkmark.circle.fill"
        static let xmark = "xmark.circle.fill"
        static let plus = "plus.circle.fill"
        static let trash = "trash.fill"
        static let share = "square.and.arrow.up"
        static let export = "square.and.arrow.up.on.square"
        static let importIcon = "square.and.arrow.down"
        static let folder = "folder.fill"
        static let tag = "tag.fill"
        static let calendar = "calendar"
        static let location = "location.fill"
        static let cloud = "icloud.fill"
        static let sync = "arrow.triangle.2.circlepath"
    }
    
    // MARK: - UserDefaults Keys
    struct UserDefaultsKeys {
        static let hasCompletedOnboarding = "HasCompletedOnboarding"
        static let appLockEnabled = "AppLockEnabled"
        static let biometricAuthEnabled = "BiometricAuthEnabled"
        static let autoEnhanceEnabled = "AutoEnhanceEnabled"
        static let realtimeTranscriptionEnabled = "RealtimeTranscriptionEnabled"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let lastSyncDate = "LastSyncDate"
        static let failedAuthAttempts = "FailedAuthAttempts"
        static let lockoutEndTime = "LockoutEndTime"
        static let selectedTheme = "SelectedTheme"
        static let notificationSettings = "NotificationSettings"
    }
    
    // MARK: - Notification Names
    struct Notifications {
        static let noteCreated = Notification.Name("NoteCreated")
        static let noteUpdated = Notification.Name("NoteUpdated")
        static let noteDeleted = Notification.Name("NoteDeleted")
        static let categoryCreated = Notification.Name("CategoryCreated")
        static let categoryUpdated = Notification.Name("CategoryUpdated")
        static let categoryDeleted = Notification.Name("CategoryDeleted")
        static let syncCompleted = Notification.Name("SyncCompleted")
        static let syncFailed = Notification.Name("SyncFailed")
        static let authenticationRequired = Notification.Name("AuthenticationRequired")
        static let permissionGranted = Notification.Name("PermissionGranted")
        static let permissionDenied = Notification.Name("PermissionDenied")
    }
    
    // MARK: - File Extensions
    struct FileExtensions {
        static let supportedImages = ["jpg", "jpeg", "png", "heic", "tiff", "gif"]
        static let supportedDocuments = ["pdf", "txt", "rtf", "html", "doc", "docx"]
        static let supportedAudio = ["m4a", "mp3", "wav", "aac"]
        static let supportedVideo = ["mp4", "mov", "avi"]
    }
    
    // MARK: - MIME Types
    struct MIMETypes {
        static let jpeg = "image/jpeg"
        static let png = "image/png"
        static let heic = "image/heic"
        static let pdf = "application/pdf"
        static let plainText = "text/plain"
        static let rtf = "text/rtf"
        static let html = "text/html"
        static let mp4Audio = "audio/mp4"
        static let mp3 = "audio/mpeg"
        static let wav = "audio/wav"
    }
    
    // MARK: - API Endpoints (if using external AI services)
    struct API {
        static let baseURL = "https://api.example.com"
        static let timeout: TimeInterval = 30
        static let maxRetries = 3
        
        struct Endpoints {
            static let summarize = "/ai/summarize"
            static let extractKeyPoints = "/ai/keypoints"
            static let categorize = "/ai/categorize"
            static let generateTags = "/ai/tags"
            static let findSimilar = "/ai/similar"
        }
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let genericError = "An unexpected error occurred. Please try again."
        static let networkError = "Network connection error. Please check your internet connection."
        static let permissionDenied = "Permission denied. Please grant the required permissions in Settings."
        static let fileNotFound = "File not found or has been moved."
        static let fileTooLarge = "File is too large. Maximum size is 50MB."
        static let unsupportedFileType = "Unsupported file type."
        static let saveFailed = "Failed to save. Please try again."
        static let loadFailed = "Failed to load data. Please try again."
        static let authenticationFailed = "Authentication failed. Please try again."
        static let syncFailed = "Sync failed. Please check your internet connection."
        static let aiProcessingFailed = "AI processing failed. Please try again."
        static let recordingFailed = "Recording failed. Please check microphone permissions."
        static let transcriptionFailed = "Transcription failed. Please try again."
        static let ocrFailed = "Text extraction failed. Please try with a clearer image."
    }
    
    // MARK: - Success Messages
    struct SuccessMessages {
        static let noteSaved = "Note saved successfully"
        static let noteDeleted = "Note deleted successfully"
        static let categoryCreated = "Category created successfully"
        static let syncCompleted = "Sync completed successfully"
        static let exportCompleted = "Export completed successfully"
        static let importCompleted = "Import completed successfully"
        static let permissionGranted = "Permission granted successfully"
        static let settingsSaved = "Settings saved successfully"
    }
    
    // MARK: - Accessibility
    struct Accessibility {
        static let noteCard = "Note card"
        static let recordButton = "Record voice note"
        static let playButton = "Play audio"
        static let pauseButton = "Pause audio"
        static let stopButton = "Stop audio"
        static let deleteButton = "Delete"
        static let editButton = "Edit"
        static let shareButton = "Share"
        static let addButton = "Add new note"
        static let searchField = "Search notes"
        static let categoryFilter = "Filter by category"
        static let sortOptions = "Sort options"
        static let aiAssistant = "AI Assistant"
        static let settings = "Settings"
        static let lockApp = "Lock app"
        static let unlockApp = "Unlock app"
    }
}

// MARK: - Environment Values
struct OnboardingCompletedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var hasCompletedOnboarding: Bool {
        get { self[OnboardingCompletedKey.self] }
        set { self[OnboardingCompletedKey.self] = newValue }
    }
}

// MARK: - Custom Environment Objects
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var isFirstLaunch: Bool
    @Published var currentTheme: Theme = .system
    
    init() {
        let onboardingCompleted = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)
        hasCompletedOnboarding = onboardingCompleted
        isFirstLaunch = !onboardingCompleted
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        isFirstLaunch = false
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)
    }
}

enum Theme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

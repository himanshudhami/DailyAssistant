//
//  SecurityManager.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import UIKit
import LocalAuthentication
import CryptoKit
import Security
import Combine

// MARK: - Security Configuration
struct SecurityConfig {
    static let appLockTimeout: TimeInterval = 300 // 5 minutes
    static let maxFailedAttempts = 5
    static let lockoutDuration: TimeInterval = 900 // 15 minutes
}

// MARK: - Authentication Result
enum AuthenticationResult {
    case success
    case failure(AuthenticationError)
    case biometryNotAvailable
    case biometryNotEnrolled
    case userCancel
    case userFallback
}

enum AuthenticationError: LocalizedError {
    case biometryLockout
    case biometryNotAvailable
    case biometryNotEnrolled
    case authenticationFailed
    case passcodeNotSet
    case systemCancel
    case userCancel
    case userFallback
    case invalidContext
    case notInteractive
    
    var errorDescription: String? {
        switch self {
        case .biometryLockout:
            return "Biometry is locked out due to too many failed attempts"
        case .biometryNotAvailable:
            return "Biometry is not available on this device"
        case .biometryNotEnrolled:
            return "No biometric data is enrolled"
        case .authenticationFailed:
            return "Authentication failed"
        case .passcodeNotSet:
            return "Passcode is not set on this device"
        case .systemCancel:
            return "Authentication was cancelled by the system"
        case .userCancel:
            return "Authentication was cancelled by the user"
        case .userFallback:
            return "User chose to use fallback authentication"
        case .invalidContext:
            return "Invalid authentication context"
        case .notInteractive:
            return "Authentication is not interactive"
        }
    }
}

// MARK: - Security Manager
@MainActor
class SecurityManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAppLocked = false
    @Published var biometryType: LABiometryType = .none
    @Published var isAppLockEnabled = false
    @Published var requiresAuthentication = false
    @Published var failedAttempts = 0
    @Published var isLockedOut = false
    @Published var lockoutEndTime: Date?
    
    // MARK: - Private Properties
    private let context = LAContext()
    private let keychain = KeychainManager()
    private var appLockTimer: Timer?
    private var lockoutTimer: Timer?
    private var backgroundTime: Date?
    
    // MARK: - Encryption Keys
    private var encryptionKey: SymmetricKey?
    
    // MARK: - Initialization
    init() {
        setupBiometry()
        loadSecuritySettings()
        setupAppLifecycleObservers()
        loadEncryptionKey()
    }
    
    private func setupBiometry() {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometryType = context.biometryType
        } else {
            biometryType = .none
        }
    }
    
    private func loadSecuritySettings() {
        isAppLockEnabled = UserDefaults.standard.bool(forKey: "AppLockEnabled")
        failedAttempts = UserDefaults.standard.integer(forKey: "FailedAttempts")
        
        if let lockoutEndTimeData = UserDefaults.standard.data(forKey: "LockoutEndTime"),
           let lockoutEndTime = try? JSONDecoder().decode(Date.self, from: lockoutEndTimeData) {
            self.lockoutEndTime = lockoutEndTime
            
            if lockoutEndTime > Date() {
                isLockedOut = true
                startLockoutTimer()
            }
        }
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.handleAppDidEnterBackground()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.handleAppWillEnterForeground()
            }
        }
    }
    
    private func loadEncryptionKey() {
        if let keyData = keychain.getData(for: "EncryptionKey") {
            encryptionKey = SymmetricKey(data: keyData)
        } else {
            generateNewEncryptionKey()
        }
    }
    
    // MARK: - Authentication Methods
    func authenticateUser(reason: String = "Authenticate to access your notes") async -> AuthenticationResult {
        guard !isLockedOut else {
            return .failure(.biometryLockout)
        }
        
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                return .failure(mapLAError(error))
            }
            return .biometryNotAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            
            if success {
                await handleSuccessfulAuthentication()
                return .success
            } else {
                await handleFailedAuthentication()
                return .failure(.authenticationFailed)
            }
            
        } catch let error as LAError {
            await handleAuthenticationError(error)
            return .failure(mapLAError(error as NSError))
        } catch {
            await handleFailedAuthentication()
            return .failure(.authenticationFailed)
        }
    }
    
    func authenticateWithPasscode(reason: String = "Enter your passcode to access your notes") async -> AuthenticationResult {
        guard !isLockedOut else {
            return .failure(.biometryLockout)
        }
        
        let context = LAContext()
        
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                return .failure(mapLAError(error))
            }
            return .failure(.passcodeNotSet)
        }
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            
            if success {
                await handleSuccessfulAuthentication()
                return .success
            } else {
                await handleFailedAuthentication()
                return .failure(.authenticationFailed)
            }
            
        } catch let error as LAError {
            await handleAuthenticationError(error)
            return .failure(mapLAError(error as NSError))
        } catch {
            await handleFailedAuthentication()
            return .failure(.authenticationFailed)
        }
    }
    
    private func handleSuccessfulAuthentication() async {
        failedAttempts = 0
        isLockedOut = false
        lockoutEndTime = nil
        isAppLocked = false
        requiresAuthentication = false
        
        UserDefaults.standard.set(failedAttempts, forKey: "FailedAttempts")
        UserDefaults.standard.removeObject(forKey: "LockoutEndTime")
        
        startAppLockTimer()
    }
    
    private func handleFailedAuthentication() async {
        failedAttempts += 1
        UserDefaults.standard.set(failedAttempts, forKey: "FailedAttempts")
        
        if failedAttempts >= SecurityConfig.maxFailedAttempts {
            await lockoutUser()
        }
    }
    
    private func handleAuthenticationError(_ error: LAError) async {
        switch error.code {
        case .userCancel, .systemCancel, .appCancel:
            // Don't increment failed attempts for cancellations
            break
        default:
            await handleFailedAuthentication()
        }
    }
    
    private func lockoutUser() async {
        isLockedOut = true
        lockoutEndTime = Date().addingTimeInterval(SecurityConfig.lockoutDuration)
        
        if let lockoutEndTime = lockoutEndTime,
           let lockoutData = try? JSONEncoder().encode(lockoutEndTime) {
            UserDefaults.standard.set(lockoutData, forKey: "LockoutEndTime")
        }
        
        startLockoutTimer()
    }
    
    private func mapLAError(_ error: NSError) -> AuthenticationError {
        guard let laError = error as? LAError else {
            return .authenticationFailed
        }
        
        switch laError.code {
        case .biometryLockout:
            return .biometryLockout
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .systemCancel:
            return .systemCancel
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .invalidContext:
            return .invalidContext
        case .notInteractive:
            return .notInteractive
        default:
            return .authenticationFailed
        }
    }
    
    // MARK: - App Lock Management
    func enableAppLock() {
        isAppLockEnabled = true
        UserDefaults.standard.set(true, forKey: "AppLockEnabled")
        startAppLockTimer()
    }
    
    func disableAppLock() {
        isAppLockEnabled = false
        isAppLocked = false
        UserDefaults.standard.set(false, forKey: "AppLockEnabled")
        appLockTimer?.invalidate()
        appLockTimer = nil
    }
    
    private func startAppLockTimer() {
        guard isAppLockEnabled else { return }
        
        appLockTimer?.invalidate()
        appLockTimer = Timer.scheduledTimer(withTimeInterval: SecurityConfig.appLockTimeout, repeats: false) { _ in
            Task { @MainActor in
                self.lockApp()
            }
        }
    }
    
    private func lockApp() {
        guard isAppLockEnabled else { return }
        isAppLocked = true
        requiresAuthentication = true
    }
    
    private func startLockoutTimer() {
        guard let lockoutEndTime = lockoutEndTime else { return }
        
        let timeInterval = lockoutEndTime.timeIntervalSinceNow
        guard timeInterval > 0 else {
            isLockedOut = false
            self.lockoutEndTime = nil
            return
        }
        
        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            Task { @MainActor in
                self.isLockedOut = false
                self.lockoutEndTime = nil
                self.failedAttempts = 0
                UserDefaults.standard.set(0, forKey: "FailedAttempts")
                UserDefaults.standard.removeObject(forKey: "LockoutEndTime")
            }
        }
    }
    
    // MARK: - App Lifecycle Handlers
    private func handleAppDidEnterBackground() {
        backgroundTime = Date()
        appLockTimer?.invalidate()
    }
    
    private func handleAppWillEnterForeground() {
        guard isAppLockEnabled, let backgroundTime = backgroundTime else { return }
        
        let timeInBackground = Date().timeIntervalSince(backgroundTime)
        
        if timeInBackground >= SecurityConfig.appLockTimeout {
            lockApp()
        } else {
            startAppLockTimer()
        }
        
        self.backgroundTime = nil
    }
    
    // MARK: - Encryption Methods
    func encryptSensitiveData(_ data: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw SecurityError.encryptionKeyNotFound
        }
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    func decryptSensitiveData(_ encryptedData: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw SecurityError.encryptionKeyNotFound
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    private func generateNewEncryptionKey() {
        encryptionKey = SymmetricKey(size: .bits256)
        
        if let keyData = encryptionKey?.withUnsafeBytes({ Data($0) }) {
            keychain.setData(keyData, for: "EncryptionKey")
        }
    }
    
    // MARK: - Utility Methods
    func getBiometryTypeString() -> String {
        switch biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }
    
    func getRemainingLockoutTime() -> TimeInterval {
        guard let lockoutEndTime = lockoutEndTime else { return 0 }
        return max(0, lockoutEndTime.timeIntervalSinceNow)
    }
    
    func formatLockoutTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Security Errors
enum SecurityError: LocalizedError {
    case encryptionKeyNotFound
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .encryptionKeyNotFound:
            return "Encryption key not found"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }
}

// MARK: - Keychain Manager
class KeychainManager {
    
    func setData(_ data: Data, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    func deleteData(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

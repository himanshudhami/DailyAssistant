//
//  PermissionsOnboardingView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct PermissionsOnboardingView: View {
    @StateObject private var permissionManager = PermissionManager()
    @State private var currentStep = 0
    @State private var isRequestingPermissions = false
    let onComplete: () -> Void
    
    private let steps: [PermissionStep] = [
        PermissionStep(
            type: .microphone,
            title: "Voice Recording",
            subtitle: "Capture your thoughts with voice notes",
            description: "Record high-quality voice notes and get real-time transcription to quickly capture your ideas hands-free."
        ),
        PermissionStep(
            type: .speechRecognition,
            title: "Speech Recognition",
            subtitle: "Convert speech to searchable text",
            description: "Transform your voice recordings into searchable text, making your notes more accessible and useful."
        ),
        PermissionStep(
            type: .camera,
            title: "Camera Access",
            subtitle: "Capture documents and images",
            description: "Take photos of documents, whiteboards, and notes with automatic text extraction using OCR technology."
        ),
        PermissionStep(
            type: .photoLibrary,
            title: "Photo Library",
            subtitle: "Import existing images",
            description: "Import images from your photo library and extract text from them to enhance your notes."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            ProgressIndicator(currentStep: currentStep, totalSteps: steps.count)
                .padding(.top)
            
            // Content
            TabView(selection: $currentStep) {
                ForEach(0..<steps.count, id: \.self) { index in
                    PermissionStepView(
                        step: steps[index],
                        permissionManager: permissionManager,
                        isRequestingPermissions: $isRequestingPermissions,
                        onNext: nextStep,
                        onSkip: nextStep,
                        isLastStep: index == steps.count - 1,
                        onComplete: onComplete
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .disabled(isRequestingPermissions)
        }
        .background(Color(.systemBackground))
    }
    
    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            onComplete()
        }
    }
}

struct PermissionStep {
    let type: PermissionType
    let title: String
    let subtitle: String
    let description: String
}

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .padding(.horizontal)
    }
}

struct PermissionStepView: View {
    let step: PermissionStep
    @ObservedObject var permissionManager: PermissionManager
    @Binding var isRequestingPermissions: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    let isLastStep: Bool
    let onComplete: () -> Void
    
    @State private var hasRequestedPermission = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon and Title
            VStack(spacing: 20) {
                Image(systemName: step.type.icon)
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text(step.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(step.subtitle)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Description
            Text(step.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Permission Status
            PermissionStatusView(
                status: permissionManager.getPermissionStatus(for: step.type),
                hasRequested: hasRequestedPermission
            )
            
            // Action Buttons
            VStack(spacing: 16) {
                if permissionManager.getPermissionStatus(for: step.type) == .granted {
                    Button(isLastStep ? "Get Started" : "Continue") {
                        if isLastStep {
                            onComplete()
                        } else {
                            onNext()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else if permissionManager.getPermissionStatus(for: step.type) == .denied {
                    VStack(spacing: 12) {
                        Button("Open Settings") {
                            permissionManager.openAppSettings()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        Button("Skip for Now") {
                            onSkip()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                } else {
                    VStack(spacing: 12) {
                        Button("Allow \(step.type.rawValue)") {
                            requestPermission()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isRequestingPermissions)
                        
                        Button("Skip for Now") {
                            onSkip()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(isRequestingPermissions)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .overlay(
            Group {
                if isRequestingPermissions {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Requesting Permission...")
                            .font(.headline)
                    }
                    .padding(30)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
            }
        )
    }
    
    private func requestPermission() {
        isRequestingPermissions = true
        hasRequestedPermission = true
        
        Task {
            let granted = await requestSpecificPermission()
            
            await MainActor.run {
                isRequestingPermissions = false
                
                if granted {
                    // Small delay to show success state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if isLastStep {
                            onComplete()
                        } else {
                            onNext()
                        }
                    }
                }
            }
        }
    }
    
    private func requestSpecificPermission() async -> Bool {
        switch step.type {
        case .microphone:
            return await permissionManager.requestMicrophonePermission()
        case .speechRecognition:
            return await permissionManager.requestSpeechRecognitionPermission()
        case .camera:
            return await permissionManager.requestCameraPermission()
        case .photoLibrary:
            return await permissionManager.requestPhotoLibraryPermission()
        case .calendar:
            return await permissionManager.requestCalendarPermission()
        case .location:
            return await permissionManager.requestLocationPermission()
        }
    }
}

struct PermissionStatusView: View {
    let status: PermissionStatus
    let hasRequested: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(.headline)
                .foregroundColor(statusColor)
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusIcon: String {
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .restricted:
            return "exclamationmark.triangle.fill"
        case .notDetermined:
            return hasRequested ? "clock.fill" : "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .restricted:
            return .orange
        case .notDetermined:
            return hasRequested ? .orange : .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case .granted:
            return "Permission Granted"
        case .denied:
            return "Permission Denied"
        case .restricted:
            return "Permission Restricted"
        case .notDetermined:
            return hasRequested ? "Waiting for Response..." : "Permission Required"
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    PermissionsOnboardingView {
        print("Onboarding completed")
    }
}

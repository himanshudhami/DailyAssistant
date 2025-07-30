//
//  CameraImagePicker.swift
//  AINoteTakingApp
//
//  Camera image picker wrapped for SwiftUI
//  Handles camera capture functionality with permission checking
//
//  Created by AI Assistant on 2025-01-30.
//

import SwiftUI
import UIKit
import AVFoundation

// MARK: - Camera Picker Errors
enum CameraPickerError: LocalizedError {
    case cameraNotAvailable
    case permissionDenied
    case captureFailed
    
    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .permissionDenied:
            return "Camera permission denied"
        case .captureFailed:
            return "Failed to capture image"
        }
    }
}

// MARK: - Camera Image Picker
struct CameraImagePicker: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onError: (Error) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        
        // Check if camera is available
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            DispatchQueue.main.async {
                onError(CameraPickerError.cameraNotAvailable)
                dismiss()
            }
            return picker
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker
        
        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            } else {
                parent.onError(CameraPickerError.captureFailed)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Camera Permission Helper
@MainActor
class CameraPermissionHelper: ObservableObject {
    @Published var hasPermission = false
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined
    
    init() {
        checkPermission()
    }
    
    func checkPermission() {
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        hasPermission = permissionStatus == .authorized
    }
    
    func requestPermission() async -> Bool {
        guard permissionStatus != .denied && permissionStatus != .restricted else {
            return false
        }
        
        if permissionStatus == .authorized {
            return true
        }
        
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            checkPermission()
        }
        return granted
    }
    
    var permissionMessage: String {
        switch permissionStatus {
        case .authorized:
            return "Camera access granted"
        case .denied:
            return "Camera access denied. Please enable in Settings."
        case .restricted:
            return "Camera access restricted"
        case .notDetermined:
            return "Camera permission not determined"
        @unknown default:
            return "Unknown camera permission status"
        }
    }
}

// MARK: - Camera Image Button View
struct CameraImageButton: View {
    @Environment(\.appTheme) private var theme
    @StateObject private var permissionHelper = CameraPermissionHelper()
    @State private var showingCamera = false
    @State private var showingPermissionAlert = false
    @State private var errorMessage: String?
    
    let onImageCaptured: (UIImage) -> Void
    let style: CameraButtonStyle
    
    init(onImageCaptured: @escaping (UIImage) -> Void, style: CameraButtonStyle = .toolbar) {
        self.onImageCaptured = onImageCaptured
        self.style = style
    }
    
    var body: some View {
        Button(action: handleCameraButtonTap) {
            switch style {
            case .toolbar:
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundColor(theme.textPrimary)
            case .large:
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(theme.accent)
                    }
                    
                    Text("Camera Note")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                }
            case .circular:
                Image(systemName: "camera.circle.fill")
                    .foregroundColor(theme.accent)
                    .font(.title)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker(
                onImageCaptured: onImageCaptured,
                onError: handleCameraError
            )
        }
        .alert("Camera Permission", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionHelper.permissionMessage)
        }
        .alert("Camera Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func handleCameraButtonTap() {
        Task {
            let hasPermission = await permissionHelper.requestPermission()
            if hasPermission {
                showingCamera = true
            } else {
                showingPermissionAlert = true
            }
        }
    }
    
    private func handleCameraError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Camera Button Style
enum CameraButtonStyle {
    case toolbar
    case large
    case circular
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        CameraImageButton(onImageCaptured: { _ in }, style: .toolbar)
        CameraImageButton(onImageCaptured: { _ in }, style: .circular)
        CameraImageButton(onImageCaptured: { _ in }, style: .large)
    }
    .padding()
}

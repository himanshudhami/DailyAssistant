//
//  CameraView.swift
//  AINoteTakingApp
//
//  Camera interface component for capturing images.
//  Provides a simple camera interface using UIImagePickerController.
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI
import UIKit
import Foundation
import Combine

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraDevice = .rear
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Camera View with Processing
// CameraViewWithProcessing is defined in NotesListView.swift

// MARK: - Processing Overlay
struct ProcessingOverlay: View {
    let progress: Double
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Processing icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 50))
                    .foregroundColor(theme.primary)
                    .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.1)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: progress)
                
                // Processing text
                Text("Processing Image...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: theme.primary))
                        .frame(width: 200)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Processing steps
                VStack(alignment: .leading, spacing: 4) {
                    ProcessingStep(
                        title: "Capturing location",
                        isActive: progress >= 0.1,
                        isCompleted: progress > 0.1
                    )
                    ProcessingStep(
                        title: "Extracting text (OCR)",
                        isActive: progress >= 0.4,
                        isCompleted: progress > 0.4
                    )
                    ProcessingStep(
                        title: "Creating attachment",
                        isActive: progress >= 0.7,
                        isCompleted: progress > 0.7
                    )
                    ProcessingStep(
                        title: "Saving note",
                        isActive: progress >= 0.9,
                        isCompleted: progress >= 1.0
                    )
                }
                .padding(.top, 10)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
                    .blur(radius: 1)
            )
        }
    }
}

// MARK: - Processing Step
struct ProcessingStep: View {
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Group {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.primary))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 16, height: 16)
            
            // Step title
            Text(title)
                .font(.caption)
                .foregroundColor(isActive || isCompleted ? .white : .gray)
        }
    }
}

// MARK: - Camera Button
struct CameraButton: View {
    let action: () -> Void
    let isDisabled: Bool
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.circle.fill")
                .foregroundColor(isDisabled ? .gray : theme.accent)
                .font(.title)
        }
        .disabled(isDisabled)
    }
}

#Preview {
    VStack {
        CameraButton(action: {}, isDisabled: false)
        
        ProcessingOverlay(progress: 0.6)
            .frame(height: 400)
    }
}

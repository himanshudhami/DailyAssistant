//
//  CameraProcessingViewModel.swift
//  AINoteTakingApp
//
//  View model for handling camera processing operations.
//  Coordinates between camera UI and processing services.
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import UIKit
import Combine

// MARK: - Camera Processing View Model
@MainActor
class CameraProcessingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var showingCamera = false
    @Published var lastProcessingError: Error?
    
    // MARK: - Dependencies
    private let cameraProcessingService: CameraProcessingService
    private let notesListViewModel: NotesListViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(notesListViewModel: NotesListViewModel) {
        self.cameraProcessingService = CameraProcessingService()
        self.notesListViewModel = notesListViewModel

        setupBindings()
    }

    init(
        cameraProcessingService: CameraProcessingService,
        notesListViewModel: NotesListViewModel
    ) {
        self.cameraProcessingService = cameraProcessingService
        self.notesListViewModel = notesListViewModel

        setupBindings()
    }
    
    // MARK: - Private Methods
    
    /// Sets up bindings to the camera processing service
    private func setupBindings() {
        // Bind processing state
        cameraProcessingService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isProcessing, on: self)
            .store(in: &cancellables)
        
        // Bind processing progress
        cameraProcessingService.$processingProgress
            .receive(on: DispatchQueue.main)
            .assign(to: \.processingProgress, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Shows the camera interface
    func showCamera() {
        showingCamera = true
        lastProcessingError = nil
    }
    
    /// Processes a captured image
    /// - Parameter image: The captured image
    func processCapturedImage(_ image: UIImage) {
        Task {
            let result = await cameraProcessingService.processCameraImage(
                image,
                folderId: notesListViewModel.currentFolder?.id
            )
            
            if result.success {
                // Refresh the notes list to show the new note
                notesListViewModel.loadNotes()
                lastProcessingError = nil
            } else {
                lastProcessingError = result.error
            }
            
            // Dismiss camera
            showingCamera = false
        }
    }
    
    /// Handles camera dismissal
    func dismissCamera() {
        showingCamera = false
    }
    
    /// Clears the last processing error
    func clearError() {
        lastProcessingError = nil
    }
    
    /// Gets a user-friendly error message
    var errorMessage: String? {
        guard let error = lastProcessingError else { return nil }
        return error.localizedDescription
    }
    
    /// Indicates if there's an error to show
    var hasError: Bool {
        return lastProcessingError != nil
    }
}


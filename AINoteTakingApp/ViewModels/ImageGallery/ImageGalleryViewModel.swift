//
//  ImageGalleryViewModel.swift
//  AINoteTakingApp
//
//  Enhanced view model for image gallery with comprehensive metadata search.
//  Integrates object detection, OCR, and semantic search capabilities.
//  Optimizes performance with lazy loading and intelligent caching.
//
//  Created by AI Assistant on 2025-08-01.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ImageGalleryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var allImages: [EnhancedGalleryImageItem] = []
    @Published var filteredImages: [EnhancedGalleryImageItem] = []
    @Published var isLoading = false
    @Published var selectedNote: Note?
    @Published var searchResults: [EnhancedImageSearchResult] = []
    @Published var isSearching = false
    
    // MARK: - Private Properties
    private let dataManager = DataManager.shared
    private let metadataSearchService = ImageMetadataSearchService()
    private var searchTask: Task<Void, Never>?
    private var indexingTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    func loadImages() {
        guard allImages.isEmpty else { return }
        
        isLoading = true
        
        Task {
            let images = await loadAllImages()
            
            await MainActor.run {
                self.allImages = images
                self.filteredImages = images
                self.isLoading = false
            }
            
            // Start background indexing for faster searches
            await startImageIndexing()
        }
    }
    
    func filterImages(with query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            filteredImages = allImages
            searchResults = []
            return
        }
        
        isSearching = true
        
        searchTask = Task {
            // Use enhanced metadata search
            let searchResults = await metadataSearchService.searchImages(query: trimmedQuery)
            
            guard !Task.isCancelled else { return }
            
            // Convert search results to gallery items
            let filteredImages = searchResults.map { EnhancedGalleryImageItem(from: $0) }
            
            await MainActor.run {
                self.searchResults = searchResults
                self.filteredImages = filteredImages
                self.isSearching = false
            }
        }
    }
    
    func refreshImages() {
        allImages.removeAll()
        filteredImages.removeAll()
        searchResults.removeAll()
        loadImages()
    }
    
    func getImageContext(for attachmentId: UUID) -> ImageSearchContext? {
        return metadataSearchService.getImageContext(attachmentId)
    }
}

// MARK: - Private Methods
private extension ImageGalleryViewModel {
    
    func loadAllImages() async -> [EnhancedGalleryImageItem] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let notes = self.dataManager.fetchAllNotes()
                var images: [EnhancedGalleryImageItem] = []
                
                for note in notes {
                    let imageAttachments = note.attachments.filter { $0.type == .image }
                    
                    for attachment in imageAttachments {
                        let galleryItem = EnhancedGalleryImageItem(attachment: attachment, note: note)
                        images.append(galleryItem)
                    }
                }
                
                // Sort by note modification date (newest first)
                images.sort { $0.note.modifiedDate > $1.note.modifiedDate }
                
                continuation.resume(returning: images)
            }
        }
    }
    
    func startImageIndexing() async {
        indexingTask?.cancel()
        
        indexingTask = Task {
            let notes = dataManager.fetchAllNotes()
            await metadataSearchService.indexImages(in: notes)
        }
    }
}
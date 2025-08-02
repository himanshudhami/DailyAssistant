//
//  ImageGalleryView.swift
//  AINoteTakingApp
//
//  Image gallery view for displaying images from notes with lazy loading.
//  Provides grid layout, search functionality, and navigation to containing notes.
//  Follows performance best practices with lazy image loading.
//
//  Created by AI Assistant on 2025-08-01.
//

import SwiftUI
import Foundation

// Note: GalleryImageItem has been moved to ImageGalleryModels.swift for better organization

// MARK: - Image Gallery View
struct ImageGalleryView: View {
    @StateObject private var viewModel = ImageGalleryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: EnhancedGalleryImageItem?
    @State private var showingNoteEditor = false
    @State private var searchText = ""
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                if !viewModel.allImages.isEmpty {
                    ImageGallerySearchBar(
                        searchText: $searchText,
                        onSearchChanged: { query in
                            viewModel.filterImages(with: query)
                        }
                    )
                }
                
                // Main Content
                if viewModel.isLoading {
                    LoadingGalleryView()
                } else if viewModel.isSearching {
                    SearchingGalleryView()
                } else if viewModel.filteredImages.isEmpty {
                    EmptyGalleryView(hasImages: !viewModel.allImages.isEmpty, hasActiveSearch: !searchText.isEmpty)
                } else {
                    EnhancedImageGridView(
                        images: viewModel.filteredImages,
                        onImageTapped: { image in
                            selectedImage = image
                        },
                        onImageLongPressed: { image in
                            // Navigate directly to note
                            viewModel.selectedNote = image.note
                            showingNoteEditor = true
                        }
                    )
                }
            }
            .navigationTitle("Images")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.allImages.isEmpty {
                        Text("\(viewModel.filteredImages.count) images")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(item: $selectedImage) { image in
            EnhancedImageDetailView(
                image: image,
                onNavigateToNote: {
                    selectedImage = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.selectedNote = image.note
                        showingNoteEditor = true
                    }
                }
            )
        }
        .sheet(item: $viewModel.selectedNote) { note in
            NoteEditorView(note: note)
        }
        .onAppear {
            viewModel.loadImages()
        }
    }
}

// MARK: - Enhanced Image Grid View
struct EnhancedImageGridView: View {
    let images: [EnhancedGalleryImageItem]
    let onImageTapped: (EnhancedGalleryImageItem) -> Void
    let onImageLongPressed: (EnhancedGalleryImageItem) -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(images) { image in
                    EnhancedLazyImageCell(
                        image: image,
                        onTapped: { onImageTapped(image) },
                        onLongPressed: { onImageLongPressed(image) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Enhanced Lazy Image Cell
struct EnhancedLazyImageCell: View {
    let image: EnhancedGalleryImageItem
    let onTapped: () -> Void
    let onLongPressed: () -> Void
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Button(action: onTapped) {
            ZStack {
                if let displayImage = loadedImage {
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .cornerRadius(8)
                        .overlay {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                            }
                        }
                }
                
                // Match type indicator (top-left)
                VStack {
                    HStack {
                        if let matchInfo = image.matchInfo {
                            SearchMatchBadge(matchInfo: matchInfo)
                        }
                        Spacer()
                    }
                    .padding(.leading, 4)
                    .padding(.top, 4)
                    Spacer()
                }
                
                // Note indicator (bottom-right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NoteIndicatorBadge(note: image.note)
                    }
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            onLongPressed()
        }
        .onAppear {
            loadImageAsync()
        }
    }
    
    private func loadImageAsync() {
        // First try thumbnail
        if let thumbnail = image.thumbnail {
            loadedImage = thumbnail
            isLoading = false
            return
        }
        
        // Otherwise load full image in background
        Task {
            let fullImage = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = UIImage(contentsOfFile: self.image.attachment.localURL.path)
                    continuation.resume(returning: image)
                }
            }
            
            await MainActor.run {
                if let fullImage = fullImage {
                    self.loadedImage = fullImage.thumbnail(size: CGSize(width: 200, height: 200))
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - Note Indicator Badge
struct NoteIndicatorBadge: View {
    let note: Note
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            
            Text(noteTitle)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
    
    private var noteTitle: String {
        if note.title.isEmpty {
            return "Untitled"
        }
        return String(note.title.prefix(15))
    }
}

// MARK: - Image Gallery Search Bar
struct ImageGallerySearchBar: View {
    @Binding var searchText: String
    let onSearchChanged: (String) -> Void
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search images by note content...", text: $searchText)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        onSearchChanged(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        onSearchChanged("")
                    }
                    .foregroundColor(.gray)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isSearchFocused {
                Button("Cancel") {
                    searchText = ""
                    onSearchChanged("")
                    isSearchFocused = false
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
    }
}

// MARK: - Loading Gallery View
struct LoadingGalleryView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading images...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Search Match Badge
struct SearchMatchBadge: View {
    let matchInfo: ImageMatchInfo
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: matchInfo.iconName)
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(matchInfo.badgeColor)
        .cornerRadius(4)
    }
}

// MARK: - Searching Gallery View
struct SearchingGalleryView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing images...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Searching through image content, text, and objects")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Empty Gallery View
struct EmptyGalleryView: View {
    let hasImages: Bool
    let hasActiveSearch: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasImages ? "magnifyingglass" : "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(hasActiveSearch ? "No matching images" : hasImages ? "No images visible" : "No images found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(hasActiveSearch ? 
                "Try different search terms. Search works with image objects, text in images, filenames, and note content." :
                hasImages ? "All images are currently hidden" : "Add images to your notes to see them here"
            )
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// Note: UIImage thumbnail extension is defined in Models/ImageGalleryModels.swift

#Preview {
    ImageGalleryView()
}
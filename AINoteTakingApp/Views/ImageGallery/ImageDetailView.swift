//
//  ImageDetailView.swift
//  AINoteTakingApp
//
//  Detail view for displaying individual images with navigation to containing note.
//  Provides zoom functionality, image information, and note context.
//
//  Created by AI Assistant on 2025-08-01.
//

import SwiftUI
import Foundation

// MARK: - Enhanced Image Detail View
struct EnhancedImageDetailView: View {
    let image: EnhancedGalleryImageItem
    let onNavigateToNote: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var fullImage: UIImage?
    @State private var isLoadingFullImage = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let displayImage = fullImage {
                    ZoomableImageView(
                        image: displayImage,
                        scale: $scale,
                        offset: $offset,
                        lastScale: $lastScale,
                        lastOffset: $lastOffset
                    )
                } else if isLoadingFullImage {
                    ProgressView("Loading full image...")
                        .foregroundColor(.white)
                } else {
                    // Show thumbnail while loading
                    if let thumbnail = image.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                    }
                }
                
                // Bottom overlay with enhanced info
                VStack {
                    Spacer()
                    EnhancedImageInfoOverlay(
                        image: image,
                        onNavigateToNote: onNavigateToNote
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: onNavigateToNote) {
                            Label("Open Note", systemImage: "doc.text")
                        }
                        
                        if let fullImage = fullImage {
                            Button(action: {
                                saveImageToPhotos(fullImage)
                            }) {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                            }
                        }
                        
                        Button(action: {
                            shareImage()
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        guard fullImage == nil else { return }
        
        isLoadingFullImage = true
        
        Task {
            let loadedImage = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = UIImage(contentsOfFile: self.image.attachment.localURL.path)
                    continuation.resume(returning: image)
                }
            }
            
            await MainActor.run {
                self.fullImage = loadedImage
                self.isLoadingFullImage = false
            }
        }
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    private func shareImage() {
        guard let fullImage = fullImage else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [fullImage],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// Legacy ImageDetailView for backward compatibility
struct ImageDetailView: View {
    let image: EnhancedGalleryImageItem
    let onNavigateToNote: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var fullImage: UIImage?
    @State private var isLoadingFullImage = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let displayImage = fullImage {
                    ZoomableImageView(
                        image: displayImage,
                        scale: $scale,
                        offset: $offset,
                        lastScale: $lastScale,
                        lastOffset: $lastOffset
                    )
                } else if isLoadingFullImage {
                    ProgressView("Loading full image...")
                        .foregroundColor(.white)
                } else {
                    // Show thumbnail while loading
                    if let thumbnail = image.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                    }
                }
                
                // Bottom overlay with note info
                VStack {
                    Spacer()
                    ImageInfoOverlay(
                        image: image,
                        onNavigateToNote: onNavigateToNote
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: onNavigateToNote) {
                            Label("Open Note", systemImage: "doc.text")
                        }
                        
                        if let fullImage = fullImage {
                            Button(action: {
                                saveImageToPhotos(fullImage)
                            }) {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                            }
                        }
                        
                        Button(action: {
                            shareImage()
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        guard fullImage == nil else { return }
        
        isLoadingFullImage = true
        
        Task {
            let loadedImage = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = UIImage(contentsOfFile: self.image.attachment.localURL.path)
                    continuation.resume(returning: image)
                }
            }
            
            await MainActor.run {
                self.fullImage = loadedImage
                self.isLoadingFullImage = false
            }
        }
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    private func shareImage() {
        guard let fullImage = fullImage else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [fullImage],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Zoomable Image View
struct ZoomableImageView: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastScale: CGFloat
    @Binding var lastOffset: CGSize
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    // Magnification gesture
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            // Limit zoom between 0.5x and 5x
                            scale = min(max(newScale, 0.5), 5.0)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        },
                    
                    // Drag gesture
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            )
            .onTapGesture(count: 2) {
                // Double tap to reset zoom
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 1.0
                    offset = .zero
                    lastScale = 1.0
                    lastOffset = .zero
                }
            }
    }
}

// MARK: - Enhanced Image Info Overlay
struct EnhancedImageInfoOverlay: View {
    let image: EnhancedGalleryImageItem
    let onNavigateToNote: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Match info (if available)
            if let matchInfo = image.matchInfo {
                HStack {
                    SearchMatchDetailView(matchInfo: matchInfo)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Note info card
            Button(action: onNavigateToNote) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(noteTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(noteSubtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .buttonStyle(.plain)
            
            // Image metadata
            ImageMetadataView(attachment: image.attachment)
                .padding(.horizontal)
                .padding(.bottom)
                .background(Color.black.opacity(0.7))
        }
    }
    
    private var noteTitle: String {
        if image.note.title.isEmpty {
            return "Untitled Note"
        }
        return image.note.title
    }
    
    private var noteSubtitle: String {
        let date = image.note.modifiedDate.formatted(date: .abbreviated, time: .shortened)
        
        if !image.note.content.isEmpty {
            let preview = String(image.note.content.prefix(100))
            return "\(date) • \(preview)"
        }
        
        return date
    }
}

// MARK: - Search Match Detail View
struct SearchMatchDetailView: View {
    let matchInfo: ImageMatchInfo
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: matchInfo.iconName)
                .font(.caption)
                .foregroundColor(matchInfo.badgeColor)
            
            Text(matchInfo.displayText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }
}

// Legacy Image Info Overlay
struct ImageInfoOverlay: View {
    let image: EnhancedGalleryImageItem
    let onNavigateToNote: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Note info card
            Button(action: onNavigateToNote) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(noteTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(noteSubtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .buttonStyle(.plain)
            
            // Image metadata
            ImageMetadataView(attachment: image.attachment)
                .padding(.horizontal)
                .padding(.bottom)
                .background(Color.black.opacity(0.7))
        }
    }
    
    private var noteTitle: String {
        if image.note.title.isEmpty {
            return "Untitled Note"
        }
        return image.note.title
    }
    
    private var noteSubtitle: String {
        let date = image.note.modifiedDate.formatted(date: .abbreviated, time: .shortened)
        
        if !image.note.content.isEmpty {
            let preview = String(image.note.content.prefix(100))
            return "\(date) • \(preview)"
        }
        
        return date
    }
}

// MARK: - Image Metadata View
struct ImageMetadataView: View {
    let attachment: Attachment
    
    var body: some View {
        HStack {
            MetadataItem(
                icon: "doc.text",
                text: attachment.fileName
            )
            
            Spacer()
            
            MetadataItem(
                icon: "clock",
                text: attachment.createdDate.formatted(date: .abbreviated, time: .omitted)
            )
                        
            Spacer()
            
            MetadataItem(
                icon: "externaldrive",
                text: formatFileSize(attachment.fileSize)
            )
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Metadata Item
struct MetadataItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
    }
}

#Preview {
    let sampleNote = Note(
        title: "Sample Note",
        content: "This is a sample note with an image attachment.",
        modifiedDate: Date()
    )
    
    let sampleAttachment = Attachment(
        fileName: "sample.jpg",
        fileExtension: "jpg",
        mimeType: "image/jpeg",
        fileSize: 1024000,
        localURL: URL(fileURLWithPath: "/tmp/sample.jpg"),
        type: .image
    )
    
    let sampleImage = EnhancedGalleryImageItem(
        attachment: sampleAttachment,
        note: sampleNote
    )
    
    EnhancedImageDetailView(
        image: sampleImage,
        onNavigateToNote: {}
    )
}
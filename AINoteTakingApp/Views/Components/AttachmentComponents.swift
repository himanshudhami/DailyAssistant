//
//  AttachmentComponents.swift
//  AINoteTakingApp
//
//  Attachment-related view components following SRP principle.
//  Separated from NoteEditorView to reduce file size and improve maintainability.
//
//  Created by AI Assistant on 2025-01-30.
//

import SwiftUI

// MARK: - Attachment Cards Container
struct AttachmentsCard: View {
    @Environment(\.appTheme) private var theme
    let attachments: [Attachment]
    let onDelete: (Attachment) -> Void
    @State private var selectedImageURL: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AttachmentHeader(count: attachments.count)
            
            VStack(spacing: 8) {
                ForEach(attachments, id: \.id) { attachment in
                    if attachment.type == .image {
                        ImageAttachmentRow(
                            attachment: attachment,
                            onDelete: { onDelete(attachment) },
                            onTap: { selectedImageURL = attachment.localURL }
                        )
                    } else {
                        FileAttachmentRow(
                            attachment: attachment,
                            onDelete: { onDelete(attachment) }
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(theme.accent.opacity(0.1))
        .cornerRadius(10)
        .sheet(item: Binding<IdentifiableURL?>(
            get: { selectedImageURL.map(IdentifiableURL.init) },
            set: { _ in selectedImageURL = nil }
        )) { identifiableURL in
            FullScreenImageView(imageURL: identifiableURL.url)
        }
    }
}

// MARK: - Header Component
struct AttachmentHeader: View {
    @Environment(\.appTheme) private var theme
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: "paperclip")
                .foregroundColor(theme.accent)
                .font(.subheadline)
            
            Text("Attachments (\(count))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.accent)
        }
    }
}

// MARK: - Image Attachment Row
struct ImageAttachmentRow: View {
    @Environment(\.appTheme) private var theme
    let attachment: Attachment
    let onDelete: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ImagePreviewButton(attachment: attachment, onTap: onTap)
            
            AttachmentInfo(
                fileName: attachment.fileName,
                fileSize: attachment.fileSize
            )
            
            Spacer()
            
            DeleteButton(onDelete: onDelete)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Image Preview Button
struct ImagePreviewButton: View {
    let attachment: Attachment
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Group {
                if let thumbnailData = attachment.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let image = UIImage(contentsOfFile: attachment.localURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ImagePlaceholder()
                        .onAppear {
                            print("❌ Unable to load image from: \(attachment.localURL.path)")
                            print("❌ File exists: \(FileManager.default.fileExists(atPath: attachment.localURL.path))")
                        }
                }
            }
        }
    }
}

// MARK: - Image Placeholder
struct ImagePlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - File Attachment Row
struct FileAttachmentRow: View {
    @Environment(\.appTheme) private var theme
    let attachment: Attachment
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            FileTypeIcon(type: attachment.type)
            
            AttachmentInfo(
                fileName: attachment.fileName,
                fileSize: attachment.fileSize
            )
            
            Spacer()
            
            DeleteButton(onDelete: onDelete)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - File Type Icon
struct FileTypeIcon: View {
    @Environment(\.appTheme) private var theme
    let type: AttachmentType
    
    var body: some View {
        Image(systemName: type.icon)
            .foregroundColor(theme.accent)
            .font(.title3)
            .frame(width: 24)
    }
}

// MARK: - Attachment Info
struct AttachmentInfo: View {
    let fileName: String
    let fileSize: Int64
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fileName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Delete Button
struct DeleteButton: View {
    @Environment(\.appTheme) private var theme
    let onDelete: () -> Void
    
    var body: some View {
        Button("Remove") {
            onDelete()
        }
        .font(.caption)
        .foregroundColor(theme.error)
    }
}

// MARK: - Identifiable URL Wrapper
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ImageContent(
                    imageURL: imageURL,
                    scale: scale,
                    offset: offset,
                    onScaleChange: { scale = $0 },
                    onOffsetChange: { offset = $0 }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Image Content with Gestures
struct ImageContent: View {
    let imageURL: URL
    let scale: CGFloat
    let offset: CGSize
    let onScaleChange: (CGFloat) -> Void
    let onOffsetChange: (CGSize) -> Void
    
    var body: some View {
        if let image = UIImage(contentsOfFile: imageURL.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(imageGestures)
                .onTapGesture(count: 2) {
                    handleDoubleTap()
                }
        } else {
            ErrorImageView()
                .onAppear {
                    print("❌ Full-screen: Unable to load image from: \(imageURL.path)")
                    print("❌ Full-screen: File exists: \(FileManager.default.fileExists(atPath: imageURL.path))")
                }
        }
    }
    
    private var imageGestures: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    onScaleChange(value)
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        if value < 1 {
                            onScaleChange(1)
                            onOffsetChange(.zero)
                        } else if value > 3 {
                            onScaleChange(3)
                        }
                    }
                },
            DragGesture()
                .onChanged { value in
                    onOffsetChange(value.translation)
                }
                .onEnded { _ in
                    if scale <= 1 {
                        withAnimation(.spring()) {
                            onOffsetChange(.zero)
                        }
                    }
                }
        )
    }
    
    private func handleDoubleTap() {
        withAnimation(.spring()) {
            if scale == 1 {
                onScaleChange(2)
            } else {
                onScaleChange(1)
                onOffsetChange(.zero)
            }
        }
    }
}

// MARK: - Error Image View
struct ErrorImageView: View {
    var body: some View {
        VStack {
            Image(systemName: "photo")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            Text("Unable to load image")
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Extensions
extension AttachmentType {
    var icon: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.fill"
        case .document: return "doc.text"
        case .audio: return "waveform"
        case .video: return "video"
        case .other: return "doc"
        }
    }
}
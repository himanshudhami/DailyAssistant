//
//  NoteEditorView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

// MARK: - Main Note Editor View
struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @StateObject private var viewModel: NoteEditorViewModel
    @StateObject private var audioManager = AudioManager()
    @State private var showingFileImporter = false
    @State private var showingImagePicker = false
    @State private var showingAIProcessing = false
    @State private var selectedTab = 0
    @State private var isContentExpanded = true
    
    init(note: Note? = nil, currentFolder: Folder? = nil) {
        _viewModel = StateObject(wrappedValue: NoteEditorViewModel(note: note, currentFolder: currentFolder))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main Content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Collapsible Title & Content Section
                            CollapsibleNoteContent(
                                title: $viewModel.title,
                                content: $viewModel.content,
                                isExpanded: $isContentExpanded
                            )
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Tab Selector
                            if hasAnyContent {
                                TabSelector(
                                    selectedTab: $selectedTab,
                                    hasAIContent: hasAIContent,
                                    hasMediaContent: hasMediaContent,
                                    hasOrganization: hasOrganization
                                )
                                .padding(.horizontal)
                            }
                            
                            // Tab Content
                            TabContentView(
                                selectedTab: selectedTab,
                                viewModel: viewModel,
                                audioManager: audioManager,
                                hasAIContent: hasAIContent,
                                hasMediaContent: hasMediaContent,
                                hasOrganization: hasOrganization,
                                hasLocationData: hasLocationData
                            )
                            .padding(.horizontal)
                            
                            // Spacer for bottom toolbar
                            Color.clear.frame(height: 100)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                
                // Floating Bottom Toolbar
                VStack {
                    Spacer()
                    FloatingToolbar(
                        audioManager: audioManager,
                        showingFileImporter: $showingFileImporter,
                        showingImagePicker: $showingImagePicker,
                        onVoiceRecordingComplete: handleVoiceRecording
                    )
                }
            }
            .navigationTitle(viewModel.isNewNote ? "New Log" : "Edit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if viewModel.hasContent {
                            Button {
                                showingAIProcessing = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("AI Enhance")
                                }
                                .foregroundColor(.green)
                            }
                            .disabled(viewModel.isProcessing)
                        }
                        
                        Button(viewModel.isSaving ? "Saving..." : "Save") {
                            saveAndDismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .disabled(!viewModel.hasContent || viewModel.isSaving)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf, .plainText, .image],
            allowsMultipleSelection: false
        ) { result in
            Task { await viewModel.handleFileImport(result) }
        }
        .sheet(isPresented: $showingImagePicker) {
            SharedImagePicker { image in
                Task { await viewModel.handleImageImport(image) }
            }
        }
        .sheet(isPresented: $showingAIProcessing) {
            AIProcessingView(
                content: viewModel.content + " " + (viewModel.transcript ?? ""),
                onProcessingComplete: viewModel.applyAIProcessing
            )
        }
    }
    
    // MARK: - Computed Properties
    private var hasAIContent: Bool {
        (viewModel.aiSummary?.isEmpty == false) ||
        !viewModel.keyPoints.isEmpty ||
        !viewModel.actionItems.isEmpty
    }
    
    private var hasMediaContent: Bool {
        !viewModel.attachments.isEmpty ||
        viewModel.audioURL != nil ||
        viewModel.transcript != nil ||
        audioManager.isRecording
    }
    
    private var hasOrganization: Bool {
        !viewModel.tags.isEmpty || viewModel.selectedCategory != nil
    }
    
    private var hasAnyContent: Bool {
        hasAIContent || hasMediaContent || hasOrganization
    }

    private var hasLocationData: Bool {
        viewModel.latitude != nil && viewModel.longitude != nil
    }
    
    // MARK: - Helper Methods
    private func handleVoiceRecording(url: URL?, transcript: String?) {
        // Handle audio as attachment (supporting multiple audio files)
        if let audioURL = url {
            Task {
                await viewModel.handleAudioRecording(audioURL: audioURL, transcript: transcript)
            }
        }
        // Note: We no longer use viewModel.audioURL (legacy field)
    }
    
    private func saveAndDismiss() {
        Task {
            await viewModel.saveNote()
            NotificationCenter.default.post(name: Notification.Name("NotesDidChange"), object: nil)
            dismiss()
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Collapsible Note Content
struct CollapsibleNoteContent: View {
    @Binding var title: String
    @Binding var content: String
    @Binding var isExpanded: Bool
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with title
            HStack {
                TextField("Log Title", text: $title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .focused($isTitleFocused)
                    .submitLabel(.next)
                    .onSubmit {
                        isContentFocused = true
                    }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .padding()
            
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                // Content area
                TextEditor(text: $content)
                    .font(.body)
                    .focused($isContentFocused)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(minHeight: 120, maxHeight: 200)
                    .scrollContentBackground(.hidden)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Tab Selector
struct TabSelector: View {
    @Binding var selectedTab: Int
    let hasAIContent: Bool
    let hasMediaContent: Bool
    let hasOrganization: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "AI Insights",
                icon: "sparkles",
                isSelected: selectedTab == 0,
                isEnabled: hasAIContent
            ) {
                selectedTab = 0
            }
            
            TabButton(
                title: "Media",
                icon: "paperclip",
                isSelected: selectedTab == 1,
                isEnabled: hasMediaContent
            ) {
                selectedTab = 1
            }
            
            TabButton(
                title: "Organize",
                icon: "folder",
                isSelected: selectedTab == 2,
                isEnabled: hasOrganization
            ) {
                selectedTab = 2
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .primary : (isEnabled ? .secondary : Color.secondary.opacity(0.5)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color(UIColor.systemBackground) : Color.clear
            )
            .cornerRadius(8)
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Tab Content View
struct TabContentView: View {
    let selectedTab: Int
    @ObservedObject var viewModel: NoteEditorViewModel
    @ObservedObject var audioManager: AudioManager
    let hasAIContent: Bool
    let hasMediaContent: Bool
    let hasOrganization: Bool
    let hasLocationData: Bool
    
    var body: some View {
        Group {
            switch selectedTab {
            case 0:
                if hasAIContent {
                    ModernAIContentSection(viewModel: viewModel)
                }
            case 1:
                if hasMediaContent {
                    ModernMediaSection(
                        viewModel: viewModel,
                        audioManager: audioManager,
                        hasLocationData: hasLocationData
                    )
                }
            case 2:
                if hasOrganization {
                    ModernOrganizationSection(viewModel: viewModel)
                }
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

// MARK: - Modern AI Content Section
struct ModernAIContentSection: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.green)
                    .font(.headline)
                Text("AI Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // AI Summary
            if let aiSummary = viewModel.aiSummary, !aiSummary.isEmpty {
                ModernCard(
                    title: "Summary",
                    icon: "doc.text",
                    color: .green.opacity(0.8)
                ) {
                    Text(aiSummary)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            // Key Points
            if !viewModel.keyPoints.isEmpty {
                ModernCard(
                    title: "Key Points",
                    icon: "list.bullet",
                    color: .blue.opacity(0.8)
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.keyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(point)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            
            // Action Items
            if !viewModel.actionItems.isEmpty {
                ModernCard(
                    title: "Action Items",
                    icon: "checkmark.circle",
                    color: .orange.opacity(0.8)
                ) {
                    VStack(spacing: 8) {
                        ForEach(viewModel.actionItems.indices, id: \.self) { index in
                            ModernActionItemRow(actionItem: $viewModel.actionItems[index])
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Modern Media Section
struct ModernMediaSection: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    @ObservedObject var audioManager: AudioManager
    let hasLocationData: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(.blue)
                    .font(.headline)
                Text("Media & Attachments")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Audio Recording with Waveform
            if viewModel.audioURL != nil || audioManager.isRecording || viewModel.transcript != nil {
                ModernCard(
                    title: "Audio Recording",
                    icon: "waveform",
                    color: .purple.opacity(0.8)
                ) {
                    VStack(spacing: 12) {
                        // Audio Waveform Visualization
                        if audioManager.isRecording || viewModel.audioURL != nil {
                            AudioWaveformView(isRecording: audioManager.isRecording)
                                .frame(height: 60)
                                .background(Color.purple.opacity(0.05))
                                .cornerRadius(8)
                        }
                        
                        // Playback Controls
                        if let audioURL = viewModel.audioURL {
                            HStack(spacing: 16) {
                                Button(action: {
                                    if audioManager.isPlaying {
                                        audioManager.stopPlayback()
                                    } else {
                                        audioManager.playAudio(from: audioURL)
                                    }
                                }) {
                                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.purple)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Audio Note")
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                    Text(audioManager.formatDuration(audioManager.recordingDuration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if audioManager.isPlaying {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                }
                            }
                        } else if audioManager.isRecording {
                            HStack {
                                Image(systemName: "record.circle")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                
                                Text("Recording...")
                                    .foregroundColor(.red)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text(audioManager.formatDuration(audioManager.recordingDuration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Transcript
                        if let transcript = viewModel.transcript, !transcript.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Transcript")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                
                                Text(transcript)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.purple.opacity(0.05))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            
            // Image Attachments Gallery
            let imageAttachments = viewModel.attachments.filter { $0.type == .image }
            if !imageAttachments.isEmpty {
                ModernCard(
                    title: "Photos",
                    icon: "photo",
                    color: .blue.opacity(0.8)
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(imageAttachments) { attachment in
                                ImageThumbnailView(
                                    attachment: attachment,
                                    onDelete: { viewModel.removeAttachment(attachment) }
                                )
                            }
                        }
                    }
                }
            }
            
            // Audio Attachments
            let audioAttachments = viewModel.attachments.filter { $0.type == .audio }
            if !audioAttachments.isEmpty {
                ModernCard(
                    title: "Audio Files",
                    icon: "waveform",
                    color: .purple.opacity(0.8)
                ) {
                    VStack(spacing: 8) {
                        ForEach(audioAttachments) { attachment in
                            AudioAttachmentRow(
                                attachment: attachment,
                                audioManager: audioManager,
                                onDelete: { viewModel.removeAttachment(attachment) }
                            )
                        }
                    }
                }
            }
            
            // Document Attachments
            let documentAttachments = viewModel.attachments.filter { $0.type != .image && $0.type != .audio }
            if !documentAttachments.isEmpty {
                ModernCard(
                    title: "Documents",
                    icon: "doc.fill",
                    color: .indigo.opacity(0.8)
                ) {
                    VStack(spacing: 8) {
                        ForEach(documentAttachments) { attachment in
                            DocumentAttachmentRow(
                                attachment: attachment,
                                onDelete: { viewModel.removeAttachment(attachment) }
                            )
                        }
                    }
                }
            }
            
            // Location
            if hasLocationData {
                ModernLocationCard(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Modern Organization Section
struct ModernOrganizationSection: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.orange)
                    .font(.headline)
                Text("Organization")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Tags
            if !viewModel.tags.isEmpty || viewModel.tags.count < 5 {
                ModernCard(
                    title: "Tags",
                    icon: "tag",
                    color: .teal.opacity(0.8)
                ) {
                    ModernTagsView(tags: $viewModel.tags)
                }
            }
            
            // Category
            ModernCard(
                title: "Category",
                icon: "square.grid.2x2",
                color: .pink.opacity(0.8)
            ) {
                ModernCategoryPicker(selectedCategory: $viewModel.selectedCategory)
            }
        }
    }
}

// MARK: - Modern Card Component
struct ModernCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            content()
                .padding(.leading, 14)
        }
        .padding(12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

// MARK: - Modern Action Item Row
struct ModernActionItemRow: View {
    @Binding var actionItem: ActionItem
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                actionItem.completed.toggle()
            }) {
                Image(systemName: actionItem.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(actionItem.completed ? .green : .gray)
                    .font(.title3)
            }
            
            Text(actionItem.title)
                .font(.body)
                .strikethrough(actionItem.completed)
                .foregroundColor(actionItem.completed ? .secondary : .primary)
            
            Spacer()
            
            Circle()
                .fill(priorityColor(actionItem.priority))
                .frame(width: 8, height: 8)
        }
    }
    
    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
}

// MARK: - Audio Waveform View
struct AudioWaveformView: View {
    let isRecording: Bool
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<40, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.purple.opacity(0.7))
                    .frame(width: 3, height: waveHeight(for: index))
                    .animation(
                        isRecording ? 
                        Animation.easeInOut(duration: 0.5 + Double(index) * 0.02)
                            .repeatForever(autoreverses: true) :
                        .default,
                        value: isRecording
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func waveHeight(for index: Int) -> CGFloat {
        if isRecording {
            return CGFloat.random(in: 8...40)
        } else {
            let heights: [CGFloat] = [12, 25, 18, 32, 15, 28, 22, 35, 16, 30]
            return heights[index % heights.count]
        }
    }
}

// MARK: - Image Thumbnail View
struct ImageThumbnailView: View {
    let attachment: Attachment
    let onDelete: () -> Void
    @State private var thumbnailImage: UIImage?
    @State private var showingFullImage = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                Group {
                    if let thumbnailImage = thumbnailImage {
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let thumbnailData = attachment.thumbnailData,
                              let image = UIImage(data: thumbnailData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .frame(width: 120, height: 120)
                .clipped()
                .cornerRadius(8)
                .onTapGesture {
                    showingFullImage = true
                }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .font(.caption)
                }
                .offset(x: 5, y: -5)
            }
            
            // Filename
            Text(attachment.fileName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)
        }
        .sheet(isPresented: $showingFullImage) {
            FullImageView(attachment: attachment)
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard thumbnailImage == nil else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let resolvedURL = FilePathResolver.shared.resolveFileURL(attachment.localURL),
               let image = UIImage(contentsOfFile: resolvedURL.path) {
                let thumbnail = image.resizedForThumbnail(to: CGSize(width: 120, height: 120))
                DispatchQueue.main.async {
                    self.thumbnailImage = thumbnail
                }
            }
        }
    }
}

// MARK: - Full Image View
struct FullImageView: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let fullImage = fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .navigationTitle(attachment.fileName)
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
        .onAppear {
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let resolvedURL = FilePathResolver.shared.resolveFileURL(attachment.localURL),
               let image = UIImage(contentsOfFile: resolvedURL.path) {
                DispatchQueue.main.async {
                    self.fullImage = image
                }
            }
        }
    }
}

// MARK: - Audio Attachment Row
struct AudioAttachmentRow: View {
    let attachment: Attachment
    @ObservedObject var audioManager: AudioManager
    let onDelete: () -> Void
    @State private var isPlaying = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button(action: {
                togglePlayback()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.fileName)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("Audio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatFileSize(attachment.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Waveform indicator
            if isPlaying {
                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.purple.opacity(0.6))
                            .frame(width: 2, height: CGFloat.random(in: 8...16))
                            .animation(
                                Animation.easeInOut(duration: 0.3 + Double(index) * 0.05)
                                    .repeatForever(autoreverses: true),
                                value: isPlaying
                            )
                    }
                }
                .frame(width: 20)
            }
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .onDisappear {
            if isPlaying {
                audioManager.stopPlayback()
            }
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioManager.stopPlayback()
            isPlaying = false
        } else {
            // Try to play the audio file
            if let resolvedURL = FilePathResolver.shared.resolveFileURL(attachment.localURL) {
                audioManager.playAudio(from: resolvedURL)
                isPlaying = true
            }
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Document Attachment Row
struct DocumentAttachmentRow: View {
    let attachment: Attachment
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // File type icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(fileTypeColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: attachment.type.systemImageName)
                    .foregroundColor(.white)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.fileName)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(attachment.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatFileSize(attachment.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var fileTypeColor: Color {
        switch attachment.type {
        case .pdf: return .red
        case .document: return .blue
        case .video: return .orange
        default: return .gray
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Modern Tags View
struct ModernTagsView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
            
            if tags.count < 5 {
                HStack {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addTag()
                        }
                    
                    Button("Add") {
                        addTag()
                    }
                    .disabled(newTag.isEmpty)
                }
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) && tags.count < 5 {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
}

// MARK: - Modern Category Picker
struct ModernCategoryPicker: View {
    @Binding var selectedCategory: Category?
    
    private let availableCategories = [
        Category(name: "Personal", color: "#34C759"),
        Category(name: "Work", color: "#007AFF"),
        Category(name: "Ideas", color: "#AF52DE"),
        Category(name: "Tasks", color: "#FF3B30")
    ]
    
    var body: some View {
        Menu {
            Button("None") {
                selectedCategory = nil
            }
            
            Divider()
            
            ForEach(availableCategories) { category in
                Button(category.name) {
                    selectedCategory = category
                }
            }
        } label: {
            HStack {
                Text(selectedCategory?.name ?? "Select Category")
                    .foregroundColor(selectedCategory != nil ? .primary : .secondary)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(8)
            .background(Color(UIColor.quaternarySystemFill))
            .cornerRadius(6)
        }
    }
}

// MARK: - Modern Location Card
struct ModernLocationCard: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    
    var body: some View {
        if let latitude = viewModel.latitude, let longitude = viewModel.longitude {
            ModernCard(
                title: "Location",
                icon: "location.fill",
                color: .red.opacity(0.8)
            ) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.6f, %.6f", latitude, longitude))
                            .font(.footnote)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        let urlString = "http://maps.apple.com/?ll=\(latitude),\(longitude)"
                        if let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "map")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}



// AttachmentsCard and related components moved to AttachmentComponents.swift for better organization


struct TagChip: View {
    let text: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(text)")
                .font(.caption)
                .foregroundColor(.blue)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}


// MARK: - Floating Toolbar
struct FloatingToolbar: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var showingFileImporter: Bool
    @Binding var showingImagePicker: Bool
    let onVoiceRecordingComplete: (URL?, String?) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Attach button
            ToolbarButton(
                icon: "paperclip",
                label: "Attach",
                color: .gray
            ) {
                showingFileImporter = true
            }
            
            // Photo button
            ToolbarButton(
                icon: "camera.fill",
                label: "Photo",
                color: .blue
            ) {
                showingImagePicker = true
            }
            
            // Voice button
            ToolbarButton(
                icon: audioManager.isRecording ? "stop.circle.fill" : "mic.fill",
                label: audioManager.isRecording ? "Stop" : "Voice",
                color: audioManager.isRecording ? .red : .green
            ) {
                if audioManager.isRecording {
                    audioManager.stopRecording()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let url = audioManager.getRecordingURL()
                        let transcript = audioManager.currentTranscript.isEmpty ? nil : audioManager.currentTranscript
                        onVoiceRecordingComplete(url, transcript)
                        audioManager.clearRecorder()
                    }
                } else {
                    audioManager.startRecording()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                    y: bounds.minY + result.frames[index].minY),
                         proposal: ProposedViewSize(result.frames[index].size))
        }
    }
}

struct FlowResult {
    let size: CGSize
    let frames: [CGRect]
    
    init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
        var frames: [CGRect] = []
        var currentRow: (width: CGFloat, height: CGFloat) = (0, 0)
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentRow.width + subviewSize.width > maxWidth && !frames.isEmpty {
                // Start new row
                totalHeight += currentRow.height + spacing
                currentRow = (0, 0)
            }
            
            frames.append(CGRect(x: currentRow.width,
                               y: totalHeight,
                               width: subviewSize.width,
                               height: subviewSize.height))
            
            currentRow.width += subviewSize.width + spacing
            currentRow.height = max(currentRow.height, subviewSize.height)
        }
        
        totalHeight += currentRow.height
        
        self.frames = frames
        self.size = CGSize(width: maxWidth, height: totalHeight)
    }
}


// MARK: - Location Section
struct LocationSection: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var viewModel: NoteEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(Color.green)
                    .font(.headline)
                
                Text("Location")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.green)
                
                Spacer()
            }

            if let latitude = viewModel.latitude, let longitude = viewModel.longitude {
                LocationCard(
                    latitude: latitude,
                    longitude: longitude
                )
            } else {
                Text("No location data available")
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.cardBackground)
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Location Card
struct LocationCard: View {
    @Environment(\.appTheme) private var theme
    let latitude: Double
    let longitude: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("GPS Coordinates")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)

                    Text(coordinateString)
                        .font(.body)
                        .foregroundColor(theme.textSecondary)
                        .textSelection(.enabled)
                }

                Spacer()
            }

            // Map buttons
            HStack(spacing: 12) {
                Button(action: openInAppleMaps) {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                        Text("Apple Maps")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }

                Button(action: openInGoogleMaps) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text("Google Maps")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                }

                Spacer()
            }
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var coordinateString: String {
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    private func openInAppleMaps() {
        let urlString = "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=Note%20Location"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func openInGoogleMaps() {
        let urlString = "https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - UIImage Extensions
private extension UIImage {
    func resizedForThumbnail(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    NoteEditorView()
}
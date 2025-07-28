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
    
    init(note: Note? = nil) {
        _viewModel = StateObject(wrappedValue: NoteEditorViewModel(note: note))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Basic Note Fields
                        BasicNoteFields(viewModel: viewModel)
                        
                        // AI Enhanced Content
                        if hasAIContent {
                            AIContentSection(viewModel: viewModel)
                        }
                        
                        // Media & Attachments
                        if hasMediaContent {
                            MediaSection(
                                viewModel: viewModel,
                                audioManager: audioManager
                            )
                        }
                        
                        // Organization
                        OrganizationSection(viewModel: viewModel)
                    }
                    .padding()
                }
                
                // Bottom Toolbar
                EditorToolbar(
                    audioManager: audioManager,
                    showingFileImporter: $showingFileImporter,
                    showingImagePicker: $showingImagePicker,
                    showingAIProcessing: $showingAIProcessing,
                    onVoiceRecordingComplete: handleVoiceRecording
                )
            }
            .onTapGesture {
                dismissKeyboard()
            }
            .navigationTitle(viewModel.isNewNote ? "New Log" : "Edit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if viewModel.hasContent {
                            Button("AI Enhance") {
                                showingAIProcessing = true
                            }
                            .disabled(viewModel.isProcessing)
                            .font(.subheadline)
                        }
                        
                        Button("Save") {
                            saveAndDismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.hasContent)
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
            ImagePicker { image in
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
        audioManager.isRecording
    }
    
    // MARK: - Helper Methods
    private func handleVoiceRecording(url: URL?, transcript: String?) {
        viewModel.audioURL = url
        viewModel.transcript = transcript
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

// MARK: - Basic Note Fields
struct BasicNoteFields: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title Field
            TextField("Log Title", text: $viewModel.title)
                .font(.title2)
                .fontWeight(.semibold)
                .textFieldStyle(.plain)
            
            Divider()
            
            // Content Editor
            TextEditor(text: $viewModel.content)
                .font(.body)
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - AI Content Section
struct AIContentSection: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "AI Insights",
                icon: "brain.head.profile",
                color: .blue
            )
            
            VStack(alignment: .leading, spacing: 12) {
                // AI Summary
                if let aiSummary = viewModel.aiSummary, !aiSummary.isEmpty {
                    InfoCard(
                        title: "Summary",
                        content: aiSummary,
                        color: .blue,
                        icon: "text.alignleft"
                    )
                }
                
                // Key Points
                if !viewModel.keyPoints.isEmpty {
                    BulletPointCard(
                        title: "Key Points",
                        items: viewModel.keyPoints,
                        color: .orange,
                        icon: "key.fill"
                    )
                }
                
                // Action Items
                if !viewModel.actionItems.isEmpty {
                    ActionItemsCard(actionItems: $viewModel.actionItems)
                }
            }
        }
    }
}

// MARK: - Media Section
struct MediaSection: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Media & Attachments",
                icon: "paperclip",
                color: .purple
            )
            
            VStack(spacing: 12) {
                // Audio Recording
                if viewModel.audioURL != nil || audioManager.isRecording {
                    AudioPlayerCard(
                        audioURL: viewModel.audioURL,
                        audioManager: audioManager,
                        transcript: $viewModel.transcript
                    )
                }
                
                // Attachments
                if !viewModel.attachments.isEmpty {
                    AttachmentsCard(
                        attachments: viewModel.attachments,
                        onDelete: viewModel.removeAttachment
                    )
                }
            }
        }
    }
}

// MARK: - Organization Section
struct OrganizationSection: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Organization",
                icon: "folder",
                color: .green
            )
            
            VStack(spacing: 12) {
                // Tags
                TagsCard(tags: $viewModel.tags)
                
                // Category
                CategoryCard(selectedCategory: $viewModel.selectedCategory)
            }
        }
    }
}

// MARK: - Reusable Components
struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.headline)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Spacer()
        }
    }
}

struct InfoCard: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let content: String
    let color: Color?
    let icon: String
    
    init(title: String, content: String, color: Color? = nil, icon: String) {
        self.title = title
        self.content = content
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        let cardColor = color ?? theme.primary
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(cardColor)
                    .font(.subheadline)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(cardColor)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(theme.textPrimary)
        }
        .padding(12)
        .background(cardColor.opacity(0.1))
        .cornerRadius(10)
    }
}

struct BulletPointCard: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let items: [String]
    let color: Color?
    let icon: String
    
    init(title: String, items: [String], color: Color? = nil, icon: String) {
        self.title = title
        self.items = items
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        let cardColor = color ?? theme.primary
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(cardColor)
                    .font(.subheadline)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(cardColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(cardColor)
                            .fontWeight(.bold)
                        
                        Text(item)
                            .font(.body)
                            .foregroundColor(theme.textPrimary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(cardColor.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ActionItemsCard: View {
    @Environment(\.appTheme) private var theme
    @Binding var actionItems: [ActionItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(theme.success)
                    .font(.subheadline)
                
                Text("Action Items")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.success)
            }
            
            VStack(spacing: 8) {
                ForEach(actionItems.indices, id: \.self) { index in
                    ActionItemRow(actionItem: $actionItems[index])
                }
            }
        }
        .padding(12)
        .background(theme.success.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ActionItemRow: View {
    @Environment(\.appTheme) private var theme
    @Binding var actionItem: ActionItem
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                actionItem.completed.toggle()
            }) {
                Image(systemName: actionItem.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(actionItem.completed ? theme.success : theme.textSecondary)
                    .font(.title3)
            }
            
            Text(actionItem.title)
                .font(.body)
                .strikethrough(actionItem.completed)
                .foregroundColor(actionItem.completed ? theme.textSecondary : theme.textPrimary)
            
            Spacer()
            
            // Priority indicator
            Circle()
                .fill(actionItem.priority.themedColor(for: theme))
                .frame(width: 8, height: 8)
        }
    }
}

struct AudioPlayerCard: View {
    @Environment(\.appTheme) private var theme
    let audioURL: URL?
    @ObservedObject var audioManager: AudioManager
    @Binding var transcript: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(theme.warning)
                    .font(.subheadline)
                
                Text("Audio Recording")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.warning)
            }
            
            VStack(spacing: 8) {
                if let audioURL = audioURL {
                    // Audio playback controls would go here
                    HStack {
                        Button("Play") {
                            audioManager.playAudio(from: audioURL)
                        }
                        .disabled(audioManager.isPlaying)
                        
                        Spacer()
                        
                        Text(audioManager.formatDuration(audioManager.recordingDuration))
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                } else if audioManager.isRecording {
                    HStack {
                        Image(systemName: "record.circle")
                            .foregroundColor(.red)
                        
                        Text("Recording...")
                            .foregroundColor(theme.error)
                        
                        Spacer()
                        
                        Text(audioManager.formatDuration(audioManager.recordingDuration))
                            .font(.caption)
                    }
                }
                
                if let transcript = transcript, !transcript.isEmpty {
                    Text("Transcript: \(transcript)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(theme.warning.opacity(0.1))
        .cornerRadius(10)
    }
}

struct AttachmentsCard: View {
    @Environment(\.appTheme) private var theme
    let attachments: [Attachment]
    let onDelete: (Attachment) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(theme.accent)
                    .font(.subheadline)
                
                Text("Attachments (\(attachments.count))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.accent)
            }
            
            VStack(spacing: 4) {
                ForEach(attachments, id: \.id) { attachment in
                    HStack {
                        Image(systemName: attachment.type.icon)
                        Text(attachment.fileName)
                            .font(.caption)
                        
                        Spacer()
                        
                        Button("Remove") {
                            onDelete(attachment)
                        }
                        .font(.caption)
                        .foregroundColor(theme.error)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.accent.opacity(0.1))
        .cornerRadius(10)
    }
}

struct TagsCard: View {
    @Environment(\.appTheme) private var theme
    @Binding var tags: [String]
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(theme.primary)
                    .font(.subheadline)
                
                Text("Tags")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
            }
            
            // Existing tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
            
            // Add new tag
            if tags.count < 5 {  // Limit to 5 tags
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
            } else {
                Text("Maximum 5 tags allowed")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(12)
        .background(theme.primary.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) && tags.count < 5 {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
}

struct TagChip: View {
    @Environment(\.appTheme) private var theme
    let text: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(text)")
                .font(.caption)
                .foregroundColor(theme.primary)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(theme.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.primary.opacity(0.2))
        .cornerRadius(8)
    }
}

struct CategoryCard: View {
    @Environment(\.appTheme) private var theme
    @Binding var selectedCategory: Category?
    // This would typically fetch categories from the view model
    private let availableCategories = [
        Category(name: "Personal", color: "#34C759"),
        Category(name: "Work", color: "#007AFF"),
        Category(name: "Ideas", color: "#AF52DE"),
        Category(name: "Tasks", color: "#FF3B30")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(theme.success)
                    .font(.subheadline)
                
                Text("Category")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.success)
            }
            
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
                        .foregroundColor(selectedCategory != nil ? theme.textPrimary : theme.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(theme.textSecondary)
                        .font(.caption)
                }
                .padding(12)
                .background(theme.sectionBackground)
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(theme.success.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Bottom Toolbar
struct EditorToolbar: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var audioManager: AudioManager
    @Binding var showingFileImporter: Bool
    @Binding var showingImagePicker: Bool
    @Binding var showingAIProcessing: Bool
    let onVoiceRecordingComplete: (URL?, String?) -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // File attachment
            Button(action: { showingFileImporter = true }) {
                Image(systemName: "paperclip")
                    .font(.title2)
                    .foregroundColor(theme.textPrimary)
            }
            
            // Image attachment
            Button(action: { showingImagePicker = true }) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(theme.textPrimary)
            }
            
            // Voice recording
            Button(action: {
                if audioManager.isRecording {
                    audioManager.stopRecording()
                    let url = audioManager.getRecordingURL()
                    let transcript = audioManager.currentTranscript
                    onVoiceRecordingComplete(url, transcript)
                } else {
                    audioManager.startRecording()
                }
            }) {
                Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle")
                    .font(.title2)
                    .foregroundColor(audioManager.isRecording ? theme.error : theme.textPrimary)
            }
            
            Spacer()
        }
        .padding()
        .background(theme.background)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(theme.separator),
            alignment: .top
        )
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

#Preview {
    NoteEditorView()
}
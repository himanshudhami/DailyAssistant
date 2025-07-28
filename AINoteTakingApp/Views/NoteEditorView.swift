//
//  NoteEditorView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
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
                // Editor Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Title Field
                        TextField("Note Title", text: $viewModel.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .textFieldStyle(.plain)
                        
                        Divider()
                        
                        // Content Editor
                        TextEditor(text: $viewModel.content)
                            .font(.body)
                            .frame(minHeight: 200)
                        
                        // AI Summary Section
                        if let aiSummary = viewModel.aiSummary, !aiSummary.isEmpty {
                            AISummarySection(summary: aiSummary)
                        }
                        
                        // Key Points Section
                        if !viewModel.keyPoints.isEmpty {
                            KeyPointsSection(keyPoints: viewModel.keyPoints)
                        }
                        
                        // Action Items Section
                        if !viewModel.actionItems.isEmpty {
                            ActionItemsSection(actionItems: $viewModel.actionItems)
                        }
                        
                        // Attachments Section
                        if !viewModel.attachments.isEmpty {
                            AttachmentsSection(
                                attachments: viewModel.attachments,
                                onDelete: viewModel.removeAttachment
                            )
                        }
                        
                        // Audio Recording Section
                        if viewModel.audioURL != nil || audioManager.isRecording {
                            AudioSection(
                                audioURL: viewModel.audioURL,
                                audioManager: audioManager,
                                transcript: $viewModel.transcript
                            )
                        }
                        
                        // Tags Section
                        TagsSection(tags: $viewModel.tags)
                        
                        // Category Section
                        CategorySection(selectedCategory: $viewModel.selectedCategory)
                    }
                    .padding()
                }
                
                // Bottom Toolbar
                BottomToolbar(
                    audioManager: audioManager,
                    showingFileImporter: $showingFileImporter,
                    showingImagePicker: $showingImagePicker,
                    showingAIProcessing: $showingAIProcessing,
                    onVoiceRecordingComplete: { url, transcript in
                        viewModel.audioURL = url
                        viewModel.transcript = transcript
                    }
                )
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationTitle(viewModel.isNewNote ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if viewModel.hasContent {
                            Button("AI Enhance") {
                                showingAIProcessing = true
                            }
                            .disabled(viewModel.isProcessing)
                        }
                        
                        Button("Save") {
                            Task {
                                await viewModel.saveNote()
                                // Notify that notes should be refreshed
                                NotificationCenter.default.post(name: Notification.Name("NotesDidChange"), object: nil)
                                dismiss()
                            }
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
            Task {
                await viewModel.handleFileImport(result)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker { image in
                Task {
                    await viewModel.handleImageImport(image)
                }
            }
        }
        .sheet(isPresented: $showingAIProcessing) {
            AIProcessingView(
                content: viewModel.content + " " + (viewModel.transcript ?? ""),
                onProcessingComplete: { processedContent in
                    viewModel.applyAIProcessing(processedContent)
                }
            )
        }
    }
}

struct AISummarySection: View {
    let summary: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("AI Summary")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Text(summary)
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct KeyPointsSection: View {
    let keyPoints: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                Text("Key Points")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(keyPoints, id: \.self) { point in
                    HStack(alignment: .top) {
                        Text("•")
                            .foregroundColor(.orange)
                        Text(point)
                            .font(.body)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct ActionItemsSection: View {
    @Binding var actionItems: [ActionItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                Text("Action Items")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 8) {
                ForEach(actionItems.indices, id: \.self) { index in
                    HStack {
                        Button(action: {
                            actionItems[index].completed.toggle()
                        }) {
                            Image(systemName: actionItems[index].completed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(actionItems[index].completed ? .green : .gray)
                        }
                        
                        Text(actionItems[index].title)
                            .font(.body)
                            .strikethrough(actionItems[index].completed)
                            .foregroundColor(actionItems[index].completed ? .secondary : .primary)
                        
                        Spacer()
                        
                        // Priority indicator
                        Circle()
                            .fill(Color(hex: actionItems[index].priority.color))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct AttachmentsSection: View {
    let attachments: [Attachment]
    let onDelete: (Attachment) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(.purple)
                Text("Attachments")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentCard(attachment: attachment) {
                        onDelete(attachment)
                    }
                }
            }
        }
    }
}

struct AttachmentCard: View {
    let attachment: Attachment
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail or icon
            if let thumbnailData = attachment.thumbnailData,
               let image = UIImage(data: thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 60)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Image(systemName: attachment.type.systemImageName)
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
                    .frame(height: 60)
            }
            
            Text(attachment.fileName)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct AudioSection: View {
    let audioURL: URL?
    @ObservedObject var audioManager: AudioManager
    @Binding var transcript: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.red)
                Text("Audio Recording")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 12) {
                if audioManager.isRecording {
                    // Recording UI
                    VStack(spacing: 8) {
                        Text("Recording...")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(audioManager.formatDuration(audioManager.recordingDuration))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        if !audioManager.currentTranscript.isEmpty {
                            Text(audioManager.currentTranscript)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                } else if let audioURL = audioURL {
                    // Playback UI
                    HStack {
                        Button(action: {
                            if audioManager.isPlaying {
                                audioManager.pausePlayback()
                            } else {
                                audioManager.playAudio(from: audioURL)
                            }
                        }) {
                            Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        
                        ProgressView(value: audioManager.playbackProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Button("Stop") {
                            audioManager.stopPlayback()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    if let transcript = transcript, !transcript.isEmpty {
                        Text("Transcript:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(transcript)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct TagsSection: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(.blue)
                Text("Tags")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            // Existing tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(tag: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
            
            // Add new tag
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
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
}

struct TagChip: View {
    let tag: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

struct CategorySection: View {
    @Binding var selectedCategory: Category?
    @State private var availableCategories: [Category] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.orange)
                Text("Category")
                    .font(.headline)
                    .foregroundColor(.orange)
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
                    if let category = selectedCategory {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 12, height: 12)
                        Text(category.name)
                    } else {
                        Text("Select Category")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .onAppear {
            loadCategories()
        }
    }
    
    private func loadCategories() {
        // Load categories from Core Data or create default ones
        availableCategories = [
            Category(name: "General", color: "#8E8E93"),
            Category(name: "Work", color: "#007AFF"),
            Category(name: "Personal", color: "#34C759"),
            Category(name: "Ideas", color: "#AF52DE"),
            Category(name: "Tasks", color: "#FF3B30")
        ]
    }
}

struct BottomToolbar: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var showingFileImporter: Bool
    @Binding var showingImagePicker: Bool
    @Binding var showingAIProcessing: Bool
    let onVoiceRecordingComplete: (URL?, String?) -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Voice Recording Button
            Button(action: toggleRecording) {
                Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle")
                    .font(.title2)
                    .foregroundColor(audioManager.isRecording ? .red : .blue)
            }
            
            // File Import Button
            Button(action: { showingFileImporter = true }) {
                Image(systemName: "paperclip.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Image Import Button
            Button(action: { showingImagePicker = true }) {
                Image(systemName: "camera.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // AI Processing Button
            Button(action: { showingAIProcessing = true }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text("AI Enhance")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
    
    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            
            // Get the recording URL and transcript
            if let recordingURL = audioManager.getRecordingURL() {
                Task {
                    let transcript = await audioManager.transcribeAudioFile(at: recordingURL)
                    await MainActor.run {
                        onVoiceRecordingComplete(recordingURL, transcript)
                    }
                }
            }
        } else {
            audioManager.startRecording()
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
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }
}

struct FlowResult {
    let size: CGSize
    let positions: [CGPoint]
    
    init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
        var positions: [CGPoint] = []
        var currentPosition = CGPoint.zero
        var lineHeight: CGFloat = 0
        var maxY: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentPosition.x + subviewSize.width > maxWidth && currentPosition.x > 0 {
                // Move to next line
                currentPosition.x = 0
                currentPosition.y += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(currentPosition)
            currentPosition.x += subviewSize.width + spacing
            lineHeight = max(lineHeight, subviewSize.height)
            maxY = max(maxY, currentPosition.y + subviewSize.height)
        }
        
        self.positions = positions
        self.size = CGSize(width: maxWidth, height: maxY)
    }
}

#Preview {
    NoteEditorView()
}

//
//  AIProcessingView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

// MARK: - AI Processing View
/// Main view for AI content processing with manual trigger
struct AIProcessingView: View {
    let content: String
    let onProcessingComplete: (ProcessedContent) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiProcessor = AIProcessor()
    @State private var processedContent: ProcessedContent?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if aiProcessor.isProcessing {
                    ProcessingView(progress: aiProcessor.processingProgress)
                } else if let processed = processedContent {
                    ProcessedContentView(content: processed) {
                        onProcessingComplete(processed)
                        dismiss()
                    }
                } else {
                    ContentPreview(content: content, onStartProcessing: processContent)
                }
            }
            .padding()
            .navigationTitle("AI Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func processContent() {
        // Process only when user manually triggers it
        guard processedContent == nil else { return }
        
        Task {
            print("🚀 AI Enhancement: Starting manual content processing...")
            
            let result = await aiProcessor.processContent(content)
            
            await MainActor.run {
                processedContent = result
            }
            
            print("✅ AI Enhancement: Manual processing complete")
        }
    }
}

// MARK: - Content Preview
/// Shows content preview with manual trigger button
struct ContentPreview: View {
    let content: String
    let onStartProcessing: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content to Process")
                .font(.headline)
            
            ScrollView {
                Text(content)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 300)
            
            Button("Start AI Processing") {
                onStartProcessing()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Processing View
/// Shows processing animation and progress
struct ProcessingView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // AI Brain Animation
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.1)
                .animation(.easeInOut(duration: 1).repeatForever(), value: UUID())
            
            Text("AI is processing your content...")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(maxWidth: 200)
            
            Text("\(Int(progress * 100))% complete")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Processed Content View
/// Shows AI processing results
struct ProcessedContentView: View {
    let content: ProcessedContent
    let onApply: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary
                if !content.summary.isEmpty {
                    ProcessedSection(
                        title: "Summary",
                        icon: "text.alignleft",
                        color: .blue
                    ) {
                        Text(content.summary)
                    }
                }
                
                // Key Points
                if !content.keyPoints.isEmpty {
                    ProcessedSection(
                        title: "Key Points",
                        icon: "key.fill",
                        color: .orange
                    ) {
                        ForEach(content.keyPoints, id: \.self) { point in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(point)
                                Spacer()
                            }
                        }
                    }
                }
                
                // Action Items
                if !content.actionItems.isEmpty {
                    ProcessedSection(
                        title: "Action Items",
                        icon: "checkmark.circle",
                        color: .green
                    ) {
                        ForEach(content.actionItems) { item in
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                                Text(item.title)
                                Spacer()
                                Circle()
                                    .fill(priorityColor(for: item.priority))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                
                // Suggested Tags
                if !content.suggestedTags.isEmpty {
                    ProcessedSection(
                        title: "Suggested Tags",
                        icon: "tag",
                        color: .purple
                    ) {
                        FlowLayout(spacing: 8) {
                            ForEach(content.suggestedTags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Apply Button
                Button("Apply AI Enhancements") {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.top)
            }
        }
    }
    
    private func priorityColor(for priority: Priority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
}

// MARK: - Processed Section
/// Reusable section component for processed content
struct ProcessedSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#Preview {
    AIProcessingView(content: "Sample content for AI processing") { processed in
        print("Processing complete: \(processed)")
    }
}
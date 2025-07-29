//
//  FolderView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

// MARK: - Folder Row View
struct FolderRowView: View {
    let folder: Folder
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @State private var showingContextMenu = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Folder icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: folder.gradientColors.map { Color(hex: $0) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 40)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    Text(folder.sentiment.emoji)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(folder.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if folder.noteCount > 0 {
                            Text("\(folder.noteCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack {
                        Text(folder.sentiment.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatRelativeDate(folder.modifiedDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Rename", action: onRename)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Folder Grid View
struct FolderGridView: View {
    let folder: Folder
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Folder card with gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: folder.gradientColors.map { Color(hex: $0) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    VStack {
                        Text(folder.sentiment.emoji)
                            .font(.largeTitle)
                        
                        if folder.noteCount > 0 {
                            Text("\(folder.noteCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                VStack(spacing: 2) {
                    Text(folder.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(folder.sentiment.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Rename", action: onRename)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Create Folder Sheet
struct CreateFolderSheet: View {
    @State private var folderName = ""
    @State private var isCreating = false
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter folder name", text: $folderName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            createFolder()
                        }
                }
                
                // Preview of gradient colors
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Folder colors will be automatically assigned based on the sentiment of notes inside.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(FolderSentiment.allCases, id: \.self) { sentiment in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: sentiment.gradientColors.map { Color(hex: $0) },
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(height: 40)
                                    .overlay {
                                        Text(sentiment.emoji)
                                            .font(.title3)
                                    }
                                
                                Text(sentiment.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createFolder()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createFolder() {
        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isCreating = true
        onCreate(trimmedName)
        dismiss()
    }
}


#Preview {
    VStack {
        FolderRowView(
            folder: Folder(name: "Happy Memories", sentiment: .positive, noteCount: 5),
            onTap: {},
            onRename: {},
            onDelete: {}
        )
        
        FolderGridView(
            folder: Folder(name: "Work Notes", sentiment: .mixed, noteCount: 12),
            onTap: {},
            onRename: {},
            onDelete: {}
        )
    }
}

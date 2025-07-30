//
//  NotesListBreadcrumb.swift
//  AINoteTakingApp
//
//  Breadcrumb navigation component for the notes list view.
//  Provides hierarchical navigation and quick folder switching.
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI

// MARK: - Notes List Breadcrumb
struct NotesListBreadcrumb: View {
    @ObservedObject var viewModel: NotesListViewModel
    
    var body: some View {
        if !viewModel.folderHierarchy.isEmpty || viewModel.currentFolder != nil {
            VStack(spacing: 0) {
                BreadcrumbNavigation(
                    hierarchy: viewModel.folderHierarchy,
                    onNavigate: { folder in
                        viewModel.enterFolder(folder)
                    },
                    onNavigateToRoot: {
                        viewModel.currentFolder = nil
                        viewModel.loadFolders()
                        viewModel.loadNotes()
                    }
                )
                
                QuickFolderSwitcher(
                    folders: viewModel.folders,
                    currentFolder: viewModel.currentFolder,
                    onFolderTap: { folder in
                        viewModel.enterFolder(folder)
                    }
                )
            }
        }
    }
}

// MARK: - Breadcrumb Navigation
struct BreadcrumbNavigation: View {
    let hierarchy: [Folder]
    let onNavigate: (Folder) -> Void
    let onNavigateToRoot: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Home button
                BreadcrumbButton(
                    title: "Home",
                    isRoot: true,
                    action: onNavigateToRoot
                )
                
                // Folder hierarchy
                ForEach(hierarchy, id: \.id) { folder in
                    HStack(spacing: 4) {
                        BreadcrumbSeparator()
                        
                        BreadcrumbButton(
                            title: folder.name,
                            isRoot: false,
                            action: { onNavigate(folder) }
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(BreadcrumbBackground())
        .frame(minHeight: 40)
    }
}

// MARK: - Breadcrumb Button
struct BreadcrumbButton: View {
    let title: String
    let isRoot: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isRoot {
                    Image(systemName: "house.fill")
                        .font(.caption2)
                } else {
                    Image(systemName: "folder.fill")
                        .font(.caption2)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Breadcrumb Separator
struct BreadcrumbSeparator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}

// MARK: - Breadcrumb Background
struct BreadcrumbBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(.systemGray6), Color(.systemGray5)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Quick Folder Switcher
struct QuickFolderSwitcher: View {
    let folders: [Folder]
    let currentFolder: Folder?
    let onFolderTap: (Folder) -> Void
    
    var body: some View {
        if !folders.isEmpty && currentFolder == nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(folders.prefix(10), id: \.id) { folder in
                        FolderChip(
                            folder: folder,
                            onTap: { onFolderTap(folder) }
                        )
                    }
                    
                    if folders.count > 10 {
                        MoreFoldersChip(remainingCount: folders.count - 10)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 32)
        }
    }
}

// MARK: - Folder Chip
struct FolderChip: View {
    let folder: Folder
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle()
                    .fill(folderGradient)
                    .frame(width: 12, height: 12)
                
                Text(folder.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var folderGradient: LinearGradient {
        LinearGradient(
            colors: folder.gradientColors.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - More Folders Chip
struct MoreFoldersChip: View {
    let remainingCount: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "ellipsis")
                .font(.caption2)
            
            Text("+\(remainingCount)")
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .foregroundColor(.secondary)
        .clipShape(Capsule())
    }
}

// MARK: - Breadcrumb Actions Protocol
protocol BreadcrumbActions {
    func navigateToRoot()
    func navigateToFolder(_ folder: Folder)
}

// MARK: - Breadcrumb Configuration
struct BreadcrumbConfiguration {
    let showQuickSwitcher: Bool
    let maxQuickSwitcherItems: Int
    let showFolderIcons: Bool
    
    static let `default` = BreadcrumbConfiguration(
        showQuickSwitcher: true,
        maxQuickSwitcherItems: 10,
        showFolderIcons: true
    )
    
    static let minimal = BreadcrumbConfiguration(
        showQuickSwitcher: false,
        maxQuickSwitcherItems: 5,
        showFolderIcons: false
    )
}

// MARK: - Configurable Breadcrumb
struct ConfigurableBreadcrumb: View {
    let hierarchy: [Folder]
    let folders: [Folder]
    let currentFolder: Folder?
    let configuration: BreadcrumbConfiguration
    let actions: BreadcrumbActions
    
    var body: some View {
        if !hierarchy.isEmpty || currentFolder != nil {
            VStack(spacing: 0) {
                BreadcrumbNavigation(
                    hierarchy: hierarchy,
                    onNavigate: actions.navigateToFolder,
                    onNavigateToRoot: actions.navigateToRoot
                )
                
                if configuration.showQuickSwitcher {
                    QuickFolderSwitcher(
                        folders: folders,
                        currentFolder: currentFolder,
                        onFolderTap: actions.navigateToFolder
                    )
                }
            }
        }
    }
}

// MARK: - Breadcrumb State
struct BreadcrumbState {
    let hierarchy: [Folder]
    let currentFolder: Folder?
    let availableFolders: [Folder]
    
    var isAtRoot: Bool {
        return currentFolder == nil
    }
    
    var hasHierarchy: Bool {
        return !hierarchy.isEmpty
    }
    
    var canShowQuickSwitcher: Bool {
        return isAtRoot && !availableFolders.isEmpty
    }
}

#Preview {
    VStack(spacing: 20) {
        // Sample breadcrumb with hierarchy
        BreadcrumbNavigation(
            hierarchy: [
                Folder(name: "Work", sentiment: .neutral, noteCount: 5),
                Folder(name: "Projects", sentiment: .positive, noteCount: 3)
            ],
            onNavigate: { _ in },
            onNavigateToRoot: {}
        )
        
        // Sample quick folder switcher
        QuickFolderSwitcher(
            folders: [
                Folder(name: "Personal", sentiment: .positive, noteCount: 10),
                Folder(name: "Ideas", sentiment: .mixed, noteCount: 7),
                Folder(name: "Travel", sentiment: .veryPositive, noteCount: 15)
            ],
            currentFolder: nil,
            onFolderTap: { _ in }
        )
    }
    .padding()
}

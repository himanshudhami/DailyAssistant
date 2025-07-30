//
//  TopControlsBar.swift
//  AINoteTakingApp
//
//  Top controls bar component for the notes list view.
//  Provides search, filtering, sorting, and view mode controls.
//
//  Created by AI Assistant on 2025-01-29.
//

import SwiftUI

// MARK: - Top Controls Bar
struct TopControlsBar: View {
    @Environment(\.appTheme) private var theme
    @Binding var searchText: String
    @Binding var selectedCategory: Category?
    @Binding var sortOption: NoteSortOption
    @Binding var viewMode: ViewMode
    let categories: [Category]
    let onCreateFolder: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            // First row: Category and Sort
            HStack {
                CategoryFilterButton(
                    selectedCategory: $selectedCategory,
                    categories: categories
                )
                
                Spacer()
                
                SortOptionsButton(sortOption: $sortOption)
                
                if let onCreateFolder = onCreateFolder {
                    Button(action: onCreateFolder) {
                        Image(systemName: "folder.badge.plus")
                            .font(.caption)
                            .foregroundColor(theme.primary)
                    }
                }
                
                ViewModeButton(viewMode: $viewMode)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(theme.background)
    }
}

// MARK: - Filter Components
struct CategoryFilterButton: View {
    @Environment(\.appTheme) private var theme
    @Binding var selectedCategory: Category?
    let categories: [Category]
    
    var body: some View {
        Menu {
            Button("All Categories") {
                selectedCategory = nil
            }
            
            Divider()
            
            ForEach(categories) { category in
                Button(category.name) {
                    selectedCategory = category
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.caption)
                Text(selectedCategory?.name ?? "All")
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.sectionBackground)
            .cornerRadius(8)
        }
    }
}

struct SortOptionsButton: View {
    @Environment(\.appTheme) private var theme
    @Binding var sortOption: NoteSortOption
    
    var body: some View {
        Menu {
            ForEach(NoteSortOption.allCases, id: \.self) { option in
                Button(option.rawValue) {
                    sortOption = option
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                Text(sortOption.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.sectionBackground)
            .cornerRadius(8)
        }
    }
}

struct ViewModeButton: View {
    @Environment(\.appTheme) private var theme
    @Binding var viewMode: ViewMode
    
    var body: some View {
        Button(action: {
            viewMode = viewMode == .grid ? .list : .grid
        }) {
            Image(systemName: viewMode.systemImageName)
                .font(.caption)
                .foregroundColor(theme.textPrimary)
                .padding(8)
                .background(theme.sectionBackground)
                .cornerRadius(8)
        }
    }
}

// MARK: - Controls Configuration
struct TopControlsConfiguration {
    let showCategoryFilter: Bool
    let showSortOptions: Bool
    let showViewModeToggle: Bool
    let showCreateFolder: Bool
    
    static let `default` = TopControlsConfiguration(
        showCategoryFilter: true,
        showSortOptions: true,
        showViewModeToggle: true,
        showCreateFolder: true
    )
    
    static let minimal = TopControlsConfiguration(
        showCategoryFilter: false,
        showSortOptions: true,
        showViewModeToggle: true,
        showCreateFolder: false
    )
}

// MARK: - Configurable Top Controls
struct ConfigurableTopControlsBar: View {
    @Environment(\.appTheme) private var theme
    @Binding var searchText: String
    @Binding var selectedCategory: Category?
    @Binding var sortOption: NoteSortOption
    @Binding var viewMode: ViewMode
    let categories: [Category]
    let configuration: TopControlsConfiguration
    let onCreateFolder: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                if configuration.showCategoryFilter {
                    CategoryFilterButton(
                        selectedCategory: $selectedCategory,
                        categories: categories
                    )
                }
                
                Spacer()
                
                if configuration.showSortOptions {
                    SortOptionsButton(sortOption: $sortOption)
                }
                
                if configuration.showCreateFolder, let onCreateFolder = onCreateFolder {
                    Button(action: onCreateFolder) {
                        Image(systemName: "folder.badge.plus")
                            .font(.caption)
                            .foregroundColor(theme.primary)
                    }
                }
                
                if configuration.showViewModeToggle {
                    ViewModeButton(viewMode: $viewMode)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(theme.background)
    }
}

#Preview {
    VStack(spacing: 20) {
        TopControlsBar(
            searchText: .constant(""),
            selectedCategory: .constant(nil),
            sortOption: .constant(.modifiedDate),
            viewMode: .constant(.list),
            categories: [],
            onCreateFolder: {}
        )
        
        HStack {
            CategoryFilterButton(
                selectedCategory: .constant(nil),
                categories: []
            )
            SortOptionsButton(sortOption: .constant(.modifiedDate))
            ViewModeButton(viewMode: .constant(.list))
        }
    }
    .padding()
}

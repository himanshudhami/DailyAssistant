//
//  AINoteTakingAppApp.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI
import CoreData

@main
struct AINoteTakingAppApp: App {
    let dataManager = DataManager.shared
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = AppThemeManager()
    @StateObject private var folderManager = FolderManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, dataManager.context)
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(folderManager)
                .environment(\.appTheme, themeManager.currentTheme)
                .preferredColorScheme(appState.currentTheme.colorScheme)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingOnboarding = false

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                ContentView()
            } else {
                PermissionsOnboardingView {
                    appState.completeOnboarding()
                }
            }
        }
        .onAppear {
            showingOnboarding = appState.isFirstLaunch
        }
    }
}

// MARK: - Preview Support
extension DataManager {
    static var preview: DataManager = {
        // For previews, we can use the shared instance or create a separate one
        let manager = DataManager.shared
        let context = manager.context
        
        // Add sample data for previews
        let sampleFolder = FolderEntity(context: context)
        let folder = Folder(name: "Sample Folder", sentiment: .positive, noteCount: 1)
        folder.updateEntity(sampleFolder, context: context)
        
        let sampleNote = NoteEntity(context: context)
        let note = Note(
            title: "Sample Note",
            content: "This is a sample note for preview purposes.",
            folderId: folder.id
        )
        note.updateEntity(sampleNote, context: context)
        sampleNote.folder = sampleFolder
        
        try? context.save()
        return manager
    }()
}

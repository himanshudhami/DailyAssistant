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
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = AppThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .environmentObject(themeManager)
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

// MARK: - Core Data Stack
class PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Add sample data for previews
        let sampleNote = NoteEntity(context: viewContext)
        sampleNote.id = UUID()
        sampleNote.title = "Sample Note"
        sampleNote.content = "This is a sample note for preview purposes."
        sampleNote.createdDate = Date()
        sampleNote.modifiedDate = Date()
        sampleNote.tags = "sample,preview"
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DataModel")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

//
//  ContentView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var securityManager = SecurityManager()
    @StateObject private var notesViewModel = NotesListViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if securityManager.requiresAuthentication || securityManager.isAppLocked {
                AuthenticationView(securityManager: securityManager)
            } else {
                MainTabView(selectedTab: $selectedTab)
                    .environmentObject(securityManager)
                    .environmentObject(notesViewModel)
            }
        }
        .onAppear {
            if securityManager.isAppLockEnabled {
                securityManager.requiresAuthentication = true
            }
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var securityManager: SecurityManager
    @EnvironmentObject var notesViewModel: NotesListViewModel
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NotesListView()
                .tabItem {
                    Image(systemName: "note.text")
                    Text("Notes")
                }
                .tag(0)
            
            AIAssistantView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Assistant")
                }
                .tag(1)
            
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct AuthenticationView: View {
    @ObservedObject var securityManager: SecurityManager
    @State private var showingPasscodeOption = false
    @State private var isAuthenticating = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon and Title
            VStack(spacing: 16) {
                ZStack {
                    // Background circle with gradient
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // Main brain icon
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                    
                    // Accent pencil icon
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .offset(x: 25, y: 25)
                }
                
                Text("AI Note Taking")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Secure your notes with biometric authentication")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Authentication Content
            VStack(spacing: 20) {
                if securityManager.isLockedOut {
                    LockedOutView(securityManager: securityManager)
                } else {
                    AuthenticationButtons(
                        securityManager: securityManager,
                        isAuthenticating: $isAuthenticating,
                        showingPasscodeOption: $showingPasscodeOption
                    )
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct LockedOutView: View {
    @ObservedObject var securityManager: SecurityManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Too Many Failed Attempts")
                .font(.headline)
                .foregroundColor(.red)
            
            Text("Please wait before trying again")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
}

struct AuthenticationButtons: View {
    @ObservedObject var securityManager: SecurityManager
    @Binding var isAuthenticating: Bool
    @Binding var showingPasscodeOption: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Biometric Authentication Button
            if securityManager.biometryType != .none {
                Button(action: authenticateWithBiometry) {
                    HStack {
                        Image(systemName: biometryIcon)
                            .font(.title2)
                        Text("Unlock with \(securityManager.getBiometryTypeString())")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isAuthenticating)
            }
            
            // Passcode Authentication Button
            Button(action: authenticateWithPasscode) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.title2)
                    Text("Use Passcode")
                        .font(.headline)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .disabled(isAuthenticating)
            
            if isAuthenticating {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding()
            }
        }
    }
    
    private var biometryIcon: String {
        switch securityManager.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "key.fill"
        }
    }
    
    private func authenticateWithBiometry() {
        isAuthenticating = true
        
        Task {
            let result = await securityManager.authenticateUser()
            
            await MainActor.run {
                isAuthenticating = false
                handleAuthenticationResult(result)
            }
        }
    }
    
    private func authenticateWithPasscode() {
        isAuthenticating = true
        
        Task {
            let result = await securityManager.authenticateWithPasscode()
            
            await MainActor.run {
                isAuthenticating = false
                handleAuthenticationResult(result)
            }
        }
    }
    
    private func handleAuthenticationResult(_ result: AuthenticationResult) {
        switch result {
        case .success:
            // Authentication successful - the SecurityManager will handle state updates
            break
        case .failure(let error):
            // Handle authentication errors
            print("Authentication failed: \(error.localizedDescription)")
        case .biometryNotAvailable, .biometryNotEnrolled:
            showingPasscodeOption = true
        case .userCancel, .userFallback:
            // User cancelled or chose fallback - no action needed
            break
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

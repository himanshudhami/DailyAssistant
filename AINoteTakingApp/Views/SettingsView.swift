//
//  SettingsView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var securityManager: SecurityManager
    @ObservedObject var networkService = NetworkService.shared
    @State private var showingAbout = false
    @State private var showingLogoutConfirmation = false
    
    init() {
        // Set default value for location capture (enabled by default)
        if UserDefaults.standard.object(forKey: "enableLocationCapture") == nil {
            UserDefaults.standard.set(true, forKey: "enableLocationCapture")
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Account Section
                if networkService.isAuthenticated {
                    Section("Account") {
                        if let user = networkService.currentUser {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("\(user.firstName) \(user.lastName)")
                                        .font(.body)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button(action: { showingLogoutConfirmation = true }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Security Section
                Section("Security & Privacy") {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.blue)
                        Text("App Lock")
                        Spacer()
                        Toggle("", isOn: .constant(securityManager.isAppLockEnabled))
                            .onChange(of: securityManager.isAppLockEnabled) { newValue in
                                if newValue {
                                    securityManager.enableAppLock()
                                } else {
                                    securityManager.disableAppLock()
                                }
                            }
                    }
                    
                    HStack {
                        Image(systemName: securityManager.biometryType == .faceID ? "faceid" : "touchid")
                            .foregroundColor(.green)
                        Text("Biometric Authentication")
                        Spacer()
                        Text(securityManager.getBiometryTypeString())
                            .foregroundColor(.secondary)
                    }
                }
                
                // Privacy & Location Section
                Section("Privacy & Location") {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Capture Location Data")
                            Text("Adds GPS coordinates to camera notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "enableLocationCapture") },
                            set: { UserDefaults.standard.set($0, forKey: "enableLocationCapture") }
                        ))
                    }
                }
                
                // AI & Processing Section
                Section("AI & Processing") {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        Text("Auto-enhance Notes")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.orange)
                        Text("Real-time Transcription")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                }
                
                // Storage Section
                Section("Storage") {
                    HStack {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                        Text("iCloud Sync")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundColor(.gray)
                        Text("Storage Used")
                        Spacer()
                        Text("2.3 GB")
                            .foregroundColor(.secondary)
                    }
                }
                
                // About Section
                Section("About") {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("About AI Note Taking")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                networkService.logout()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access your notes.")
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("AI Note Taking")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("An intelligent note-taking app powered by AI to help you capture, organize, and enhance your thoughts.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SecurityManager())
}

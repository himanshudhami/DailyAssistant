//
//  SettingsView.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var securityManager: SecurityManager
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
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

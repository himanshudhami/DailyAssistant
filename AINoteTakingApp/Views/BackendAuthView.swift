//
//  BackendAuthView.swift
//  AINoteTakingApp
//
//  Backend authentication flow for user login/register
//
//  Created by AI Assistant on 2025-08-22.
//

import SwiftUI

struct BackendAuthView: View {
    @ObservedObject var networkService = NetworkService.shared
    @State private var isLoginMode = true
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // App Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text("MyLogs AI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(isLoginMode ? "Welcome back!" : "Create your account")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Auth Form
                VStack(spacing: 16) {
                    if !isLoginMode {
                        HStack(spacing: 12) {
                            TextField("First Name", text: $firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Last Name", text: $lastName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    if !successMessage.isEmpty {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    Button(action: authenticate) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text(isLoginMode ? "Sign In" : "Sign Up")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || !isFormValid)
                    
                    Button(action: { isLoginMode.toggle() }) {
                        Text(isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                            .foregroundColor(.blue)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .alert("Registration Successful", isPresented: $showingSuccessAlert) {
                Button("Continue to Login") {
                    isLoginMode = true
                    clearForm()
                }
            } message: {
                Text("Your account has been created successfully. You can now sign in with your credentials.")
            }
        }
    }
    
    private var isFormValid: Bool {
        if isLoginMode {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !username.isEmpty && !email.isEmpty && !password.isEmpty && !firstName.isEmpty && !lastName.isEmpty
        }
    }
    
    private func authenticate() {
        errorMessage = ""
        successMessage = ""
        isLoading = true
        
        if isLoginMode {
            let request = UserLoginRequest(email: email, password: password)
            
            networkService.login(request)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        isLoading = false
                        if case .failure(let error) = completion {
                            // Check for specific validation errors
                            if let networkError = error as? NetworkError {
                                errorMessage = networkError.localizedDescription
                            } else {
                                errorMessage = "Request failed. Please check your input and try again."
                            }
                        }
                    },
                    receiveValue: { response in
                        // Login successful - NetworkService will handle token storage
                        isLoading = false
                    }
                )
                .store(in: &networkService.cancellables)
        } else {
            let request = UserCreateRequest(
                email: email,
                username: username,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            
            networkService.register(request)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        isLoading = false
                        if case .failure(let error) = completion {
                            // Check for specific validation errors
                            if let networkError = error as? NetworkError {
                                errorMessage = networkError.localizedDescription
                            } else {
                                errorMessage = "Request failed. Please check your input and try again."
                            }
                        }
                    },
                    receiveValue: { response in
                        // Registration successful - show success message
                        isLoading = false
                        successMessage = "Registration successful!"
                        showingSuccessAlert = true
                    }
                )
                .store(in: &networkService.cancellables)
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        username = ""
        firstName = ""
        lastName = ""
        errorMessage = ""
        successMessage = ""
    }
}

#Preview {
    BackendAuthView()
}
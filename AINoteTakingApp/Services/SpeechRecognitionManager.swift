//
//  SpeechRecognitionManager.swift
//  AINoteTakingApp
//
//  Speech recognition service following SRP
//  Handles all speech-to-text functionality for the AI Assistant
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var justFinishedRecording = false
    @Published var recognizedText = ""
    @Published var shouldAutoSend = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var speechAuthorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    private var finalTranscription = ""
    
    // MARK: - Public Methods
    
    func setup() {
        speechAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
        
        if speechAuthorizationStatus == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.speechAuthorizationStatus = status
                }
            }
        }
    }
    
    func toggleVoiceRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // MARK: - Private Methods
    
    private func startRecording() {
        guard speechAuthorizationStatus == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            return
        }
        
        do {
            // Cancel previous task
            recognitionTask?.cancel()
            recognitionTask = nil
            
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            let inputNode = audioEngine.inputNode
            
            guard let recognitionRequest = recognitionRequest else {
                errorMessage = "Unable to create recognition request"
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // Create recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        let transcription = result.bestTranscription.formattedString
                        self.recognizedText = transcription
                        
                        if result.isFinal {
                            self.finalTranscription = transcription
                        }
                    }
                }
                
                if let error = error {
                    print("Speech recognition error: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            
            // Configure input node
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            
        } catch {
            errorMessage = "Error starting recording: \(error.localizedDescription)"
            isRecording = false
        }
    }
    
    private func stopRecording() {
        let currentText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        justFinishedRecording = true
        
        // Use final transcription or current text, whichever is better
        let textToUse = !finalTranscription.isEmpty ? finalTranscription : currentText
        
        if !textToUse.isEmpty {
            recognizedText = textToUse
            
            // Auto-send message after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !textToUse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.shouldAutoSend = true
                    // Reset the flag after triggering
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.shouldAutoSend = false
                        self.justFinishedRecording = false
                    }
                } else {
                    self.justFinishedRecording = false
                }
            }
        } else {
            justFinishedRecording = false
        }
        
        // Reset final transcription for next recording
        finalTranscription = ""
    }
}
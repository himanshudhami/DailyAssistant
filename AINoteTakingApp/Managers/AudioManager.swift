//
//  AudioManager.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import Foundation
import AVFoundation
import Speech
import Combine

// MARK: - Audio Manager
@MainActor
class AudioManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentTranscript = ""
    @Published var recordingDuration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var hasPermission = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupAudioSession()
        setupSpeechRecognizer()
        requestPermissions()
    }
    
    // MARK: - Setup Methods
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        speechRecognizer?.delegate = self
    }
    
    private func requestPermissions() {
        Task {
            let microphonePermission = await requestMicrophonePermission()
            let speechPermission = await requestSpeechRecognitionPermission()
            
            await MainActor.run {
                hasPermission = microphonePermission && speechPermission
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Recording Methods
    func startRecording() {
        guard hasPermission else {
            errorMessage = "Microphone and speech recognition permissions are required"
            return
        }
        
        guard !isRecording else { return }
        
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingDuration = 0
            currentTranscript = ""
            
            startRecordingTimer()
            startSpeechRecognition()
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }

        // Stop recording first but keep reference for URL
        audioRecorder?.stop()
        // Don't set audioRecorder to nil yet - we need the URL

        // Update state
        isRecording = false

        // Clean up timer
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Stop speech recognition gracefully
        stopSpeechRecognition()

        // Clear any error messages related to recording
        if errorMessage?.contains("Speech recognition error") == true {
            errorMessage = nil
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.recordingDuration = self.audioRecorder?.currentTime ?? 0
            }
        }
    }
    
    // MARK: - Speech Recognition Methods
    private func startSpeechRecognition() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available"
            return
        }
        
        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                Task { @MainActor in
                    if let result = result {
                        self.currentTranscript = result.bestTranscription.formattedString
                    }
                    
                    if let error = error {
                        // Only show error if we're still recording and it's not a normal completion
                        if self.isRecording && !error.localizedDescription.contains("no speech") {
                            self.errorMessage = "Speech recognition error: \(error.localizedDescription)"
                        }
                        self.stopSpeechRecognition()
                    }
                }
            }
            
        } catch {
            errorMessage = "Failed to start speech recognition: \(error.localizedDescription)"
        }
    }
    
    private func stopSpeechRecognition() {
        // Stop the audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // Remove the tap safely
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // End the recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Cancel the recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    // MARK: - Playback Methods
    func playAudio(from url: URL) {
        guard !isPlaying else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            isPlaying = true
            playbackProgress = 0
            
            startPlaybackTimer()
            
        } catch {
            errorMessage = "Failed to play audio: \(error.localizedDescription)"
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        isPlaying = false
        playbackProgress = 0
        
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard let player = self.audioPlayer else { return }
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }
    
    // MARK: - Utility Methods
    func getRecordingURL() -> URL? {
        return audioRecorder?.url
    }
    
    func clearRecorder() {
        audioRecorder = nil
    }
    
    func transcribeAudioFile(at url: URL) async -> String? {
        guard let speechRecognizer = speechRecognizer else { return nil }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        return await withCheckedContinuation { continuation in
            speechRecognizer.recognitionTask(with: request) { result, error in
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error = error {
                    print("Transcription error: \(error)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Recording failed"
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                errorMessage = "Recording encode error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            playbackProgress = 0
            playbackTimer?.invalidate()
            playbackTimer = nil
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                errorMessage = "Playback decode error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension AudioManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                errorMessage = "Speech recognizer became unavailable"
            }
        }
    }
}

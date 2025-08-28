//
//  OCRService.swift
//  AINoteTakingApp
//
//  Complete OCR service with all functionality consolidated
//

import Foundation
import Vision
import UIKit
import CoreGraphics

// MARK: - Supporting Types

/// Options for image preprocessing
struct ImagePreprocessingOptions {
    let enhanceContrast: Bool
    let correctRotation: Bool
    let denoiseImage: Bool
    let sharpenText: Bool
    let normalizeColors: Bool
    
    init(enhanceContrast: Bool = false, 
         correctRotation: Bool = false, 
         denoiseImage: Bool = false, 
         sharpenText: Bool = false, 
         normalizeColors: Bool = false) {
        self.enhanceContrast = enhanceContrast
        self.correctRotation = correctRotation
        self.denoiseImage = denoiseImage
        self.sharpenText = sharpenText
        self.normalizeColors = normalizeColors
    }
    
    static let `default` = ImagePreprocessingOptions()
    static let minimal = ImagePreprocessingOptions(enhanceContrast: true)
    static let receipt = ImagePreprocessingOptions(enhanceContrast: true, correctRotation: true)
    static let businessCard = ImagePreprocessingOptions(enhanceContrast: true, correctRotation: true, sharpenText: true)
}

/// OCR processing result
struct OCRResult {
    let rawText: String
    let detectedTables: [TableData]
    let confidence: Float
    let preprocessedImage: UIImage
    let structuredData: StructuredTextData?
    let documentType: DocumentType
}

/// Table data structure
struct TableData {
    let title: String?
    let headers: [String]
    let rows: [[String]]
    let boundingBox: CGRect
    let confidence: Float
    
    var isValid: Bool {
        return !headers.isEmpty && !rows.isEmpty && confidence > 0.3
    }
}

// MARK: - Main OCR Service
@MainActor
class OCRService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let imagePreprocessor = ImagePreprocessor()
    private let tableDetector = TableDetector()
    
    // MARK: - Public Methods
    
    /// Performs OCR on an image with default options
    func performOCR(on image: UIImage, options: ImagePreprocessingOptions = .default) async -> OCRResult {
        return await performOCR(on: image, options: options, isBusinessCard: false)
    }
    
    /// Performs specialized business card OCR
    func performBusinessCardOCR(on image: UIImage, options: ImagePreprocessingOptions = .businessCard) async -> OCRResult {
        return await performOCR(on: image, options: options, isBusinessCard: true)
    }
    
    /// Performs optimized receipt OCR
    func performReceiptOCR(on image: UIImage, options: ImagePreprocessingOptions = .receipt) async -> OCRResult {
        return await performOCR(on: image, options: options, isReceipt: true)
    }
    
    // MARK: - Private Implementation
    
    private func performOCR(on image: UIImage, options: ImagePreprocessingOptions = .default, isBusinessCard: Bool = false, isReceipt: Bool = false) async -> OCRResult {
        isProcessing = true
        processingProgress = 0
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0
            }
        }
        
        // Preprocess image for better OCR accuracy
        await MainActor.run { processingProgress = 0.1 }
        let enhancedOptions: ImagePreprocessingOptions
        if isBusinessCard {
            enhancedOptions = imagePreprocessor.enhanceOptionsForBusinessCard(options)
        } else if isReceipt {
            enhancedOptions = options // Receipts need minimal preprocessing
        } else {
            enhancedOptions = options
        }
        let preprocessedImage = await imagePreprocessor.preprocessImage(image, options: enhancedOptions)
        
        guard let cgImage = preprocessedImage.cgImage else {
            return OCRResult(rawText: "", detectedTables: [], confidence: 0.0, preprocessedImage: preprocessedImage, structuredData: nil, documentType: .generic)
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                Task { @MainActor in
                    self.processingProgress = 0.5
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(rawText: "", detectedTables: [], confidence: 0.0, preprocessedImage: preprocessedImage, structuredData: nil, documentType: .generic))
                    return
                }
                
                Task {
                    let result = await self.processOCRObservations(
                        observations, 
                        imageSize: preprocessedImage.size, 
                        preprocessedImage: preprocessedImage, 
                        isBusinessCard: isBusinessCard,
                        isReceipt: isReceipt
                    )
                    await MainActor.run {
                        self.processingProgress = 1.0
                    }
                    continuation.resume(returning: result)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            
            // Optimize for business cards and documents
            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }
            
            // Configure for better text detection
            request.minimumTextHeight = 0.01  // Detect smaller text
            request.recognitionLanguages = ["en-US", "en"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func processOCRObservations(
        _ observations: [VNRecognizedTextObservation], 
        imageSize: CGSize, 
        preprocessedImage: UIImage, 
        isBusinessCard: Bool = false,
        isReceipt: Bool = false
    ) async -> OCRResult {
        var rawText = ""
        var textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)] = []
        
        // Extract all text with positions
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let text = topCandidate.string
            let boundingBox = observation.boundingBox
            let confidence = topCandidate.confidence
            
            rawText += text + "\n"
            textBlocks.append((text: text, boundingBox: boundingBox, confidence: confidence))
        }
        
        // Detect tables from text blocks
        let detectedTables = await tableDetector.detectTables(from: textBlocks, imageSize: imageSize)
        
        let averageConfidence = textBlocks.isEmpty ? 0.0 : textBlocks.map { $0.confidence }.reduce(0, +) / Float(textBlocks.count)
        
        // Extract structured data using the new services
        let structuredExtractor = StructuredTextExtractor()
        
        // Use appropriate optimization based on document type
        var extractionOptions: StructuredExtractionOptions
        if isBusinessCard {
            extractionOptions = .businessCard
        } else if isReceipt {
            extractionOptions = .minimal  // Receipts don't need complex extraction
        } else {
            extractionOptions = .comprehensive
        }
        
        let structuredData = await structuredExtractor.extractStructuredData(
            from: rawText,
            textBlocks: textBlocks,
            image: preprocessedImage,
            options: extractionOptions
        )
        
        return OCRResult(
            rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedTables: detectedTables,
            confidence: averageConfidence,
            preprocessedImage: preprocessedImage,
            structuredData: structuredData,
            documentType: structuredData.documentType
        )
    }
}
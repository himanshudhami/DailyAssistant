//
//  ImageSearchManager.swift
//  AINoteTakingApp
//
//  Advanced image search manager using Vision framework for feature extraction and similarity search.
//  Handles image similarity detection, visual feature comparison, and intelligent image discovery.
//  Follows SRP by focusing solely on image search and similarity functionality.
//
//  Created by AI Assistant on 2025-01-30.
//

import Foundation
import Vision
import UIKit
import CoreImage

// MARK: - Image Search Result Types
struct ImageSimilarityResult {
    let note: Note
    let attachment: Attachment
    let similarityScore: Float
    let matchType: ImageMatchType
}

enum ImageMatchType {
    case visualSimilarity
    case objectDetection
    case textSimilarity
    case colorPalette
    case composition
}

// MARK: - Image Feature Data
struct ImageFeatures {
    let attachmentId: UUID
    let noteId: UUID
    let featurePrint: VNFeaturePrintObservation?
    let dominantColors: [UIColor]
    let detectedObjects: [String]
    let imageSize: CGSize
    let createdDate: Date
}

// MARK: - Image Search Manager
@MainActor
class ImageSearchManager: ObservableObject {
    
    // MARK: - Private Properties
    private var imageFeatureCache: [UUID: ImageFeatures] = [:]
    private let visionQueue = DispatchQueue(label: "vision.processing", qos: .userInitiated)
    private var featurePrintRequest: VNGenerateImageFeaturePrintRequest
    private var objectRecognitionRequest: VNClassifyImageRequest
    
    // MARK: - Initialization
    init() {
        self.featurePrintRequest = VNGenerateImageFeaturePrintRequest()
        self.objectRecognitionRequest = VNClassifyImageRequest()
        setupVisionRequests()
    }
    
    // MARK: - Public Methods
    
    /// Finds visually similar images to the given image
    func findSimilarImages(to targetImage: UIImage, in notes: [Note], threshold: Float = 0.7) async -> [ImageSimilarityResult] {
        guard let targetFeatures = await extractImageFeatures(from: targetImage, attachmentId: UUID(), noteId: UUID()) else {
            return []
        }
        
        var results: [ImageSimilarityResult] = []
        
        for note in notes {
            for attachment in note.attachments where attachment.type == .image {
                if let cachedFeatures = imageFeatureCache[attachment.id] {
                    let similarity = calculateSimilarity(between: targetFeatures.featurePrint, and: cachedFeatures.featurePrint)
                    
                    if similarity >= threshold {
                        results.append(ImageSimilarityResult(
                            note: note,
                            attachment: attachment,
                            similarityScore: similarity,
                            matchType: .visualSimilarity
                        ))
                    }
                } else {
                    // Extract features for uncached images
                    if let image = await loadImage(from: attachment),
                       let features = await extractImageFeatures(from: image, attachmentId: attachment.id, noteId: note.id) {
                        imageFeatureCache[attachment.id] = features
                        
                        let similarity = calculateSimilarity(between: targetFeatures.featurePrint, and: features.featurePrint)
                        
                        if similarity >= threshold {
                            results.append(ImageSimilarityResult(
                                note: note,
                                attachment: attachment,
                                similarityScore: similarity,
                                matchType: .visualSimilarity
                            ))
                        }
                    }
                }
            }
        }
        
        return results.sorted { $0.similarityScore > $1.similarityScore }
    }
    
    /// Searches for images containing specific objects
    func searchImagesByObject(_ objectQuery: String, in notes: [Note]) async -> [ImageSimilarityResult] {
        var results: [ImageSimilarityResult] = []
        let lowercasedQuery = objectQuery.lowercased()
        
        for note in notes {
            for attachment in note.attachments where attachment.type == .image {
                if let cachedFeatures = imageFeatureCache[attachment.id] {
                    // Check if any detected object matches the query
                    let matchingObjects = cachedFeatures.detectedObjects.filter { 
                        $0.lowercased().contains(lowercasedQuery) 
                    }
                    
                    if !matchingObjects.isEmpty {
                        // Score based on how many objects match and how well
                        let score = Float(matchingObjects.count) / Float(cachedFeatures.detectedObjects.count)
                        
                        results.append(ImageSimilarityResult(
                            note: note,
                            attachment: attachment,
                            similarityScore: min(score, 1.0),
                            matchType: .objectDetection
                        ))
                    }
                } else {
                    // Process uncached images
                    if let image = await loadImage(from: attachment),
                       let features = await extractImageFeatures(from: image, attachmentId: attachment.id, noteId: note.id) {
                        imageFeatureCache[attachment.id] = features
                        
                        let matchingObjects = features.detectedObjects.filter { 
                            $0.lowercased().contains(lowercasedQuery) 
                        }
                        
                        if !matchingObjects.isEmpty {
                            let score = Float(matchingObjects.count) / Float(features.detectedObjects.count)
                            
                            results.append(ImageSimilarityResult(
                                note: note,
                                attachment: attachment,
                                similarityScore: min(score, 1.0),
                                matchType: .objectDetection
                            ))
                        }
                    }
                }
            }
        }
        
        return results.sorted { $0.similarityScore > $1.similarityScore }
    }
    
    /// Searches for images with similar color palettes
    func searchImagesByColor(_ targetColors: [UIColor], in notes: [Note], threshold: Float = 0.6) async -> [ImageSimilarityResult] {
        var results: [ImageSimilarityResult] = []
        
        for note in notes {
            for attachment in note.attachments where attachment.type == .image {
                if let cachedFeatures = imageFeatureCache[attachment.id] {
                    let colorSimilarity = calculateColorSimilarity(between: targetColors, and: cachedFeatures.dominantColors)
                    
                    if colorSimilarity >= threshold {
                        results.append(ImageSimilarityResult(
                            note: note,
                            attachment: attachment,
                            similarityScore: colorSimilarity,
                            matchType: .colorPalette
                        ))
                    }
                }
            }
        }
        
        return results.sorted { $0.similarityScore > $1.similarityScore }
    }
    
    /// Pre-processes and caches features for an image
    func indexImage(_ attachment: Attachment, from note: Note) async {
        guard attachment.type == .image else { return }
        
        if let image = await loadImage(from: attachment),
           let features = await extractImageFeatures(from: image, attachmentId: attachment.id, noteId: note.id) {
            imageFeatureCache[attachment.id] = features
        }
    }
    
    /// Removes cached features for an image
    func removeFromIndex(_ attachmentId: UUID) {
        imageFeatureCache.removeValue(forKey: attachmentId)
    }
    
    /// Gets cached feature count for diagnostics
    var cachedFeaturesCount: Int {
        imageFeatureCache.count
    }
}

// MARK: - Private Methods
private extension ImageSearchManager {
    
    func setupVisionRequests() {
        // Configure feature print request for similarity
        featurePrintRequest.usesCPUOnly = false // Use GPU if available
        
        // Configure object recognition request
        objectRecognitionRequest.usesCPUOnly = false
    }
    
    func extractImageFeatures(from image: UIImage, attachmentId: UUID, noteId: UUID) async -> ImageFeatures? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<ImageFeatures?, Never>) in
            visionQueue.async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var featurePrint: VNFeaturePrintObservation?
                var detectedObjects: [String] = []
                var dominantColors: [UIColor] = []
                
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                // Extract feature print
                do {
                    try requestHandler.perform([self.featurePrintRequest])
                    featurePrint = self.featurePrintRequest.results?.first
                } catch {
                    print("Feature extraction failed: \(error)")
                }
                
                // Extract objects
                do {
                    try requestHandler.perform([self.objectRecognitionRequest])
                    
                    if let results = self.objectRecognitionRequest.results {
                        detectedObjects = results.compactMap { observation in
                            guard observation.confidence > 0.3 else { return nil }
                            return observation.identifier
                        }
                    }
                } catch {
                    print("Object detection failed: \(error)")
                }
                
                // Extract dominant colors
                dominantColors = self.extractDominantColors(from: image)
                
                let features = ImageFeatures(
                    attachmentId: attachmentId,
                    noteId: noteId,
                    featurePrint: featurePrint,
                    dominantColors: dominantColors,
                    detectedObjects: detectedObjects,
                    imageSize: image.size,
                    createdDate: Date()
                )
                
                continuation.resume(returning: features)
            }
        }
    }
    
    func loadImage(from attachment: Attachment) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let image = UIImage(contentsOfFile: attachment.localURL.path)
                continuation.resume(returning: image)
            }
        }
    }
    
    func calculateSimilarity(between featurePrint1: VNFeaturePrintObservation?, and featurePrint2: VNFeaturePrintObservation?) -> Float {
        guard let print1 = featurePrint1, let print2 = featurePrint2 else { return 0.0 }
        
        do {
            var distance: Float = 0
            try print1.computeDistance(&distance, to: print2)
            // Convert distance to similarity (closer distance = higher similarity)
            return max(0, 1.0 - distance)
        } catch {
            print("Failed to compute feature print distance: \(error)")
            return 0.0
        }
    }
    
    func calculateColorSimilarity(between colors1: [UIColor], and colors2: [UIColor]) -> Float {
        guard !colors1.isEmpty && !colors2.isEmpty else { return 0.0 }
        
        var totalSimilarity: Float = 0.0
        var comparisons = 0
        
        for color1 in colors1 {
            for color2 in colors2 {
                totalSimilarity += colorDistance(color1, color2)
                comparisons += 1
            }
        }
        
        return comparisons > 0 ? totalSimilarity / Float(comparisons) : 0.0
    }
    
    func colorDistance(_ color1: UIColor, _ color2: UIColor) -> Float {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let distance = sqrt(pow(r1 - r2, 2) + pow(g1 - g2, 2) + pow(b1 - b2, 2))
        return 1.0 - Float(distance) // Convert distance to similarity
    }
    
    func extractDominantColors(from image: UIImage, maxColors: Int = 5) -> [UIColor] {
        guard let cgImage = image.cgImage else { return [] }
        
        // Simple color extraction - in a production app, you might use more sophisticated algorithms
        let width = cgImage.width
        let height = cgImage.height
        let sampleSize = min(50, min(width, height)) // Sample a smaller area for performance
        
        guard let context = CGContext(
            data: nil,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        
        guard let data = context.data else { return [] }
        let pixels = data.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)
        
        var colorCounts: [String: Int] = [:]
        
        // Sample pixels and count colors (simplified approach)
        for i in stride(from: 0, to: sampleSize * sampleSize * 4, by: 16) { // Sample every 4th pixel
            let r = pixels[i]
            let g = pixels[i + 1]
            let b = pixels[i + 2]
            
            // Quantize colors to reduce variety
            let quantizedR = (r / 32) * 32
            let quantizedG = (g / 32) * 32
            let quantizedB = (b / 32) * 32
            
            let colorKey = "\(quantizedR)-\(quantizedG)-\(quantizedB)"
            colorCounts[colorKey, default: 0] += 1
        }
        
        // Get most common colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        
        return sortedColors.prefix(maxColors).compactMap { colorKey, _ in
            let components = colorKey.split(separator: "-").compactMap { Int($0) }
            guard components.count == 3 else { return nil }
            
            return UIColor(
                red: CGFloat(components[0]) / 255.0,
                green: CGFloat(components[1]) / 255.0,
                blue: CGFloat(components[2]) / 255.0,
                alpha: 1.0
            )
        }
    }
}
//
//  DocumentClassifier.swift
//  AINoteTakingApp
//
//  Smart document type detection using image analysis and lightweight heuristics
//

import Foundation
import Vision
import UIKit
import CoreImage

// MARK: - Document Types
enum DocumentCategory: String, CaseIterable {
    case businessCard = "business_card"
    case receipt = "receipt"
    case invoice = "invoice"
    case handwritten = "handwritten"
    case printedDocument = "printed_document"
    case photo = "photo"
    case screenshot = "screenshot"
    case whiteboard = "whiteboard"
    case unknown = "unknown"
    
    var requiresDetailedOCR: Bool {
        switch self {
        case .businessCard, .invoice:
            return true
        case .receipt, .printedDocument:
            return false // Simple OCR is enough
        case .handwritten, .whiteboard:
            return true // Needs special handling
        case .photo, .screenshot, .unknown:
            return false
        }
    }
    
    var ocrStrategy: OCRStrategy {
        switch self {
        case .businessCard:
            return .businessCard
        case .receipt:
            return .receipt
        case .invoice:
            return .structured
        case .handwritten:
            return .handwritten
        case .printedDocument, .whiteboard:
            return .standard
        case .photo, .screenshot, .unknown:
            return .minimal
        }
    }
}

enum OCRStrategy {
    case minimal      // Quick text extraction only
    case standard     // Standard OCR with formatting
    case structured   // Tables, forms, structured data
    case businessCard // Contact info extraction
    case receipt      // Line items, totals
    case handwritten  // Handwriting recognition
}

// MARK: - Classification Result
struct DocumentClassification {
    let category: DocumentCategory
    let confidence: Float
    let aspectRatio: Float
    let dominantColors: [UIColor]
    let hasText: Bool
    let textDensity: Float
    let suggestedStrategy: OCRStrategy
    let metadata: [String: Any]
}

// MARK: - Document Classifier
@MainActor
class DocumentClassifier {
    
    // MARK: - Properties
    private let context = CIContext()
    private let colorAnalyzer = ColorAnalyzer()
    
    // Business card typical dimensions (in points)
    private let businessCardAspectRatio: ClosedRange<Float> = 1.5...1.8
    private let receiptAspectRatio: ClosedRange<Float> = 2.5...4.0
    
    // MARK: - Public Methods
    
    /// Classifies a document from an image using fast heuristics
    /// This runs BEFORE OCR to determine the best processing strategy
    func classifyDocument(_ image: UIImage) async -> DocumentClassification {
        // Start with basic image analysis
        let imageAnalysis = analyzeImageProperties(image)
        
        // Quick text detection (not full OCR)
        let textMetrics = await detectTextRegions(image)
        
        // Analyze colors and patterns
        let colorProfile = colorAnalyzer.analyzeColors(image)
        
        // Make classification decision
        let category = determineCategory(
            aspectRatio: imageAnalysis.aspectRatio,
            textMetrics: textMetrics,
            colorProfile: colorProfile
        )
        
        return DocumentClassification(
            category: category,
            confidence: calculateConfidence(category, imageAnalysis: imageAnalysis, textMetrics: textMetrics),
            aspectRatio: imageAnalysis.aspectRatio,
            dominantColors: colorProfile.dominantColors,
            hasText: textMetrics.hasText,
            textDensity: textMetrics.density,
            suggestedStrategy: category.ocrStrategy,
            metadata: [
                "width": imageAnalysis.width,
                "height": imageAnalysis.height,
                "textRegions": textMetrics.regionCount,
                "isMonochrome": colorProfile.isMonochrome
            ]
        )
    }
    
    // MARK: - Private Analysis Methods
    
    private func analyzeImageProperties(_ image: UIImage) -> ImageAnalysis {
        let width = image.size.width
        let height = image.size.height
        let aspectRatio = Float(width / height)
        
        return ImageAnalysis(
            width: width,
            height: height,
            aspectRatio: aspectRatio
        )
    }
    
    private func detectTextRegions(_ image: UIImage) async -> TextMetrics {
        guard let cgImage = image.cgImage else {
            return TextMetrics(hasText: false, density: 0, regionCount: 0, averageTextSize: 0)
        }
        
        return await withCheckedContinuation { continuation in
            // Use text detection (NOT recognition) for speed
            let request = VNDetectTextRectanglesRequest { request, error in
                guard let observations = request.results as? [VNTextObservation] else {
                    continuation.resume(returning: TextMetrics(hasText: false, density: 0, regionCount: 0, averageTextSize: 0))
                    return
                }
                
                let hasText = !observations.isEmpty
                let regionCount = observations.count
                
                // Calculate text density (percentage of image covered by text)
                let totalTextArea = observations.reduce(0.0) { sum, obs in
                    sum + (obs.boundingBox.width * obs.boundingBox.height)
                }
                let density = Float(totalTextArea)
                
                // Calculate average text size
                let avgSize = observations.isEmpty ? 0 : 
                    Float(observations.reduce(0.0) { $0 + $1.boundingBox.height } / Double(observations.count))
                
                let metrics = TextMetrics(
                    hasText: hasText,
                    density: density,
                    regionCount: regionCount,
                    averageTextSize: avgSize
                )
                
                continuation.resume(returning: metrics)
            }
            
            request.reportCharacterBoxes = false // We don't need character-level detail
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func determineCategory(
        aspectRatio: Float,
        textMetrics: TextMetrics,
        colorProfile: ColorProfile
    ) -> DocumentCategory {
        
        // Quick photo detection
        if !textMetrics.hasText && !colorProfile.isMonochrome {
            return .photo
        }
        
        // Screenshot detection (usually has UI elements, specific aspect ratios)
        if aspectRatio < 0.7 || aspectRatio > 2.0 {
            if textMetrics.hasText && colorProfile.hasHighContrast {
                return .screenshot
            }
        }
        
        // Business card detection (aspect ratio + text pattern)
        if businessCardAspectRatio.contains(aspectRatio) {
            if textMetrics.regionCount >= 3 && textMetrics.regionCount <= 15 {
                if textMetrics.density > 0.05 && textMetrics.density < 0.3 {
                    return .businessCard
                }
            }
        }
        
        // Receipt detection (tall and narrow)
        if receiptAspectRatio.contains(aspectRatio) || aspectRatio < 0.5 {
            if textMetrics.hasText && colorProfile.isMonochrome {
                return .receipt
            }
        }
        
        // Invoice/structured document (lots of text regions, table-like)
        if textMetrics.regionCount > 20 && textMetrics.density > 0.3 {
            return .invoice
        }
        
        // Handwritten detection (irregular text patterns)
        if textMetrics.hasText && textMetrics.averageTextSize > 0.05 {
            if !colorProfile.isMonochrome || textMetrics.density < 0.2 {
                // Handwritten text tends to be less dense and irregular
                return .handwritten
            }
        }
        
        // Whiteboard detection
        if colorProfile.backgroundColor?.isLight == true && textMetrics.hasText {
            if textMetrics.density < 0.2 && textMetrics.regionCount < 10 {
                return .whiteboard
            }
        }
        
        // Default to printed document if has text
        if textMetrics.hasText {
            return .printedDocument
        }
        
        return .unknown
    }
    
    private func calculateConfidence(
        _ category: DocumentCategory,
        imageAnalysis: ImageAnalysis,
        textMetrics: TextMetrics
    ) -> Float {
        var confidence: Float = 0.5 // Base confidence
        
        switch category {
        case .businessCard:
            // Strong indicators for business card
            if businessCardAspectRatio.contains(imageAnalysis.aspectRatio) {
                confidence += 0.3
            }
            if textMetrics.regionCount >= 5 && textMetrics.regionCount <= 12 {
                confidence += 0.2
            }
            
        case .receipt:
            if imageAnalysis.aspectRatio > 2.5 {
                confidence += 0.3
            }
            if textMetrics.density > 0.2 {
                confidence += 0.2
            }
            
        case .photo:
            if !textMetrics.hasText {
                confidence = 0.9
            }
            
        default:
            // General confidence based on text detection
            if textMetrics.hasText {
                confidence += 0.2
            }
        }
        
        return min(confidence, 1.0)
    }
}

// MARK: - Supporting Types

private struct ImageAnalysis {
    let width: CGFloat
    let height: CGFloat
    let aspectRatio: Float
}

private struct TextMetrics {
    let hasText: Bool
    let density: Float // 0.0 to 1.0
    let regionCount: Int
    let averageTextSize: Float
}

private struct ColorProfile {
    let dominantColors: [UIColor]
    let isMonochrome: Bool
    let hasHighContrast: Bool
    let backgroundColor: UIColor?
}

// MARK: - Color Analyzer

private class ColorAnalyzer {
    
    func analyzeColors(_ image: UIImage) -> ColorProfile {
        guard let cgImage = image.cgImage else {
            return ColorProfile(dominantColors: [], isMonochrome: false, hasHighContrast: false, backgroundColor: nil)
        }
        
        // Simplified color analysis
        let colors = extractDominantColors(from: cgImage, maxColors: 5)
        let isMonochrome = checkIfMonochrome(colors)
        let hasHighContrast = checkContrast(colors)
        let backgroundColor = detectBackgroundColor(from: cgImage)
        
        return ColorProfile(
            dominantColors: colors,
            isMonochrome: isMonochrome,
            hasHighContrast: hasHighContrast,
            backgroundColor: backgroundColor
        )
    }
    
    private func extractDominantColors(from cgImage: CGImage, maxColors: Int) -> [UIColor] {
        // Sample pixels from the image
        let width = min(cgImage.width, 50) // Downsample for speed
        let height = min(cgImage.height, 50)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return [] }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var colorCounts: [UIColor: Int] = [:]
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = CGFloat(buffer[offset]) / 255.0
                let g = CGFloat(buffer[offset + 1]) / 255.0
                let b = CGFloat(buffer[offset + 2]) / 255.0
                
                // Quantize colors to reduce variations
                let quantizedColor = UIColor(
                    red: round(r * 10) / 10,
                    green: round(g * 10) / 10,
                    blue: round(b * 10) / 10,
                    alpha: 1.0
                )
                
                colorCounts[quantizedColor, default: 0] += 1
            }
        }
        
        // Get top colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        return Array(sortedColors.prefix(maxColors).map { $0.key })
    }
    
    private func checkIfMonochrome(_ colors: [UIColor]) -> Bool {
        guard !colors.isEmpty else { return false }
        
        // Check if all colors are grayscale
        for color in colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            
            let variance = abs(r - g) + abs(g - b) + abs(r - b)
            if variance > 0.15 { // Allow small variance
                return false
            }
        }
        
        return true
    }
    
    private func checkContrast(_ colors: [UIColor]) -> Bool {
        guard colors.count >= 2 else { return false }
        
        // Simple contrast check between first two colors
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
        
        colors[0].getRed(&r1, green: &g1, blue: &b1, alpha: nil)
        colors[1].getRed(&r2, green: &g2, blue: &b2, alpha: nil)
        
        let luminance1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
        let luminance2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
        
        return abs(luminance1 - luminance2) > 0.5
    }
    
    private func detectBackgroundColor(from cgImage: CGImage) -> UIColor? {
        // Sample corners to detect background
        let cornerSampleSize = 10
        let width = cgImage.width
        let height = cgImage.height
        
        guard width > cornerSampleSize * 2 && height > cornerSampleSize * 2 else { return nil }
        
        // This is simplified - in production you'd sample actual corner pixels
        return UIColor.white // Placeholder
    }
}

// MARK: - UIColor Extension
private extension UIColor {
    var isLight: Bool {
        var white: CGFloat = 0
        getWhite(&white, alpha: nil)
        return white > 0.7
    }
}
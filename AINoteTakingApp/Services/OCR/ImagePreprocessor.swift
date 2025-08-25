//
//  ImagePreprocessor.swift
//  AINoteTakingApp
//
//  Handles image preprocessing for better OCR accuracy
//
//  Created by AI Assistant on 2025-08-24.
//

import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

class ImagePreprocessor {
    
    private let context = CIContext()
    
    func preprocessImage(_ image: UIImage, options: ImagePreprocessingOptions) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let ciImage = CIImage(image: image) else {
                    continuation.resume(returning: image)
                    return
                }
                
                var processedImage = ciImage
                
                // Apply preprocessing steps in optimal order
                if options.correctRotation {
                    processedImage = self.correctImageRotation(processedImage)
                }
                
                if options.normalizeColors {
                    processedImage = self.normalizeImageColors(processedImage)
                }
                
                if options.enhanceContrast {
                    processedImage = self.enhanceContrast(processedImage)
                }
                
                if options.denoiseImage {
                    processedImage = self.denoiseImage(processedImage)
                }
                
                if options.sharpenText {
                    processedImage = self.sharpenForText(processedImage)
                }
                
                // Convert back to UIImage
                guard let cgImage = self.context.createCGImage(processedImage, from: processedImage.extent) else {
                    continuation.resume(returning: image)
                    return
                }
                
                let resultImage = UIImage(cgImage: cgImage)
                continuation.resume(returning: resultImage)
            }
        }
    }
    
    func enhanceOptionsForBusinessCard(_ options: ImagePreprocessingOptions) -> ImagePreprocessingOptions {
        // More aggressive processing for business cards
        return ImagePreprocessingOptions(
            enhanceContrast: true,
            correctRotation: true,
            denoiseImage: true,
            sharpenText: true,
            normalizeColors: true
        )
    }
    
    // MARK: - Private Image Processing Methods
    
    private func correctImageRotation(_ image: CIImage) -> CIImage {
        // Detect text orientation and correct rotation
        let request = VNDetectTextRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        
        do {
            try handler.perform([request])
            
            if let results = request.results, !results.isEmpty {
                // Analyze text orientation from multiple text rectangles
                var angles: [Float] = []
                
                for observation in results.prefix(10) { // Limit to first 10 for performance
                    let boundingBox = observation.boundingBox
                    
                    // Simple heuristic: if width >> height, likely horizontal text
                    // if height >> width, likely vertical text
                    let aspectRatio = boundingBox.width / boundingBox.height
                    
                    if aspectRatio < 0.5 {
                        // Likely rotated 90 degrees
                        angles.append(90.0)
                    } else if aspectRatio > 2.0 {
                        // Likely horizontal
                        angles.append(0.0)
                    }
                }
                
                // Find most common angle
                if !angles.isEmpty {
                    let mostCommonAngle = angles.max(by: { angle1, angle2 in
                        angles.filter { $0 == angle1 }.count < angles.filter { $0 == angle2 }.count
                    }) ?? 0.0
                    
                    if abs(mostCommonAngle) > 0 {
                        let radians = mostCommonAngle * .pi / 180
                        return image.transformed(by: CGAffineTransform(rotationAngle: CGFloat(-radians)))
                    }
                }
            }
        } catch {
            print("Text orientation detection failed: \(error)")
        }
        
        return image
    }
    
    private func normalizeImageColors(_ image: CIImage) -> CIImage {
        // Apply color normalization for better text contrast
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = 0.0  // Convert to grayscale
        filter.brightness = 0.1  // Slight brightness increase
        filter.contrast = 1.2    // Increase contrast
        
        return filter.outputImage ?? image
    }
    
    private func enhanceContrast(_ image: CIImage) -> CIImage {
        // Use histogram equalization for better contrast
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        
        // Analyze image brightness to determine optimal exposure
        let averageFilter = CIFilter.areaAverage()
        averageFilter.inputImage = image
        averageFilter.extent = image.extent
        
        if let averageImage = averageFilter.outputImage {
            // Simple brightness analysis
            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(averageImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
            
            let brightness = (Int(bitmap[0]) + Int(bitmap[1]) + Int(bitmap[2])) / 3
            
            // Adjust exposure based on brightness
            if brightness < 128 {
                filter.ev = 0.5  // Brighten dark images
            } else if brightness > 200 {
                filter.ev = -0.3  // Darken very bright images
            }
        }
        
        return filter.outputImage ?? image
    }
    
    private func denoiseImage(_ image: CIImage) -> CIImage {
        // Apply noise reduction
        let filter = CIFilter.noiseReduction()
        filter.inputImage = image
        filter.noiseLevel = 0.02
        filter.sharpness = 0.4
        
        return filter.outputImage ?? image
    }
    
    private func sharpenForText(_ image: CIImage) -> CIImage {
        // Apply unsharp mask optimized for text
        let filter = CIFilter.unsharpMask()
        filter.inputImage = image
        filter.radius = 2.5
        filter.intensity = 0.5
        
        return filter.outputImage ?? image
    }
}
//
//  ImageMetadataIndex.swift
//  AINoteTakingApp
//
//  High-performance image metadata indexing service for fast search operations.
//  Handles caching, persistence, and efficient retrieval of image metadata.
//  Follows SRP by focusing solely on image metadata indexing and caching.
//
//  Created by AI Assistant on 2025-01-30.
//

import Foundation
import UIKit
import CoreData

// MARK: - Image Metadata Types
struct ImageMetadata: Codable {
    let attachmentId: UUID
    let noteId: UUID
    let fileName: String
    let fileSize: Int64
    let imageDimensions: CGSize
    let dominantColors: [ColorData]
    let detectedObjects: [String]
    let ocrText: String?
    let featureHash: String
    let indexedDate: Date
    let lastAccessDate: Date
}

struct ColorData: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    init(from color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }
}

// MARK: - Search Index Types
struct ImageSearchIndex {
    var byObjects: [String: Set<UUID>] = [:]
    var byFilename: [String: Set<UUID>] = [:]
    var byColors: [String: Set<UUID>] = [:]
    var bySize: [(CGSize, UUID)] = []
    var byFileSize: [(Int64, UUID)] = []
}

// MARK: - Image Metadata Index Manager
@MainActor
class ImageMetadataIndex: ObservableObject {
    
    // MARK: - Private Properties
    private var metadataCache: [UUID: ImageMetadata] = [:]
    private var searchIndex = ImageSearchIndex()
    private let indexQueue = DispatchQueue(label: "image.metadata.index", qos: .utility)
    private let persistenceQueue = DispatchQueue(label: "image.metadata.persistence", qos: .background)
    
    // Cache configuration
    private let maxCacheSize = 1000
    private let cacheExpirationTime: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // MARK: - Initialization
    init() {
        loadPersistedMetadata()
    }
    
    // MARK: - Public Methods
    
    /// Indexes metadata for an image attachment
    func indexImageMetadata(_ metadata: ImageMetadata) async {
        await withCheckedContinuation { continuation in
            indexQueue.async {
                // Store in cache
                self.metadataCache[metadata.attachmentId] = metadata
                
                // Update search indices
                self.updateSearchIndices(for: metadata)
                
                // Persist to disk asynchronously
                self.persistMetadata(metadata)
                
                // Cleanup old entries if cache is too large
                self.cleanupCacheIfNeeded()
                
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
        }
    }
    
    /// Retrieves metadata for an attachment
    func getMetadata(for attachmentId: UUID) -> ImageMetadata? {
        return metadataCache[attachmentId]
    }
    
    /// Fast search for images by detected objects
    func findImagesByObject(_ objectName: String) -> [UUID] {
        let lowercasedObject = objectName.lowercased()
        
        // First try exact match
        if let exactMatches = searchIndex.byObjects[lowercasedObject] {
            return Array(exactMatches)
        }
        
        // Then try partial matches
        var partialMatches: Set<UUID> = []
        for (indexedObject, attachmentIds) in searchIndex.byObjects {
            if indexedObject.contains(lowercasedObject) || lowercasedObject.contains(indexedObject) {
                partialMatches.formUnion(attachmentIds)
            }
        }
        
        return Array(partialMatches)
    }
    
    /// Fast search for images by filename patterns
    func findImagesByFilename(_ pattern: String) -> [UUID] {
        let lowercasedPattern = pattern.lowercased()
        var matches: Set<UUID> = []
        
        for (filename, attachmentIds) in searchIndex.byFilename {
            if filename.contains(lowercasedPattern) {
                matches.formUnion(attachmentIds)
            }
        }
        
        return Array(matches)
    }
    
    /// Fast search for images by similar colors
    func findImagesByColor(_ targetColor: UIColor, tolerance: Double = 0.3) -> [UUID] {
        let colorKey = colorToKey(targetColor)
        var matches: Set<UUID> = []
        
        // Find colors within tolerance
        for (indexedColorKey, attachmentIds) in searchIndex.byColors {
            if colorSimilarity(colorKey, indexedColorKey) >= (1.0 - tolerance) {
                matches.formUnion(attachmentIds)
            }
        }
        
        return Array(matches)
    }
    
    /// Fast search for images by size range
    func findImagesBySize(minSize: CGSize, maxSize: CGSize) -> [UUID] {
        return searchIndex.bySize.compactMap { size, uuid in
            if size.width >= minSize.width && size.width <= maxSize.width &&
               size.height >= minSize.height && size.height <= maxSize.height {
                return uuid
            }
            return nil
        }
    }
    
    /// Fast search for images by file size range
    func findImagesByFileSize(minBytes: Int64, maxBytes: Int64) -> [UUID] {
        return searchIndex.byFileSize.compactMap { fileSize, uuid in
            if fileSize >= minBytes && fileSize <= maxBytes {
                return uuid
            }
            return nil
        }
    }
    
    /// Removes metadata for an attachment
    func removeMetadata(for attachmentId: UUID) {
        indexQueue.async {
            // Remove from cache
            let removedMetadata = self.metadataCache.removeValue(forKey: attachmentId)
            
            // Remove from search indices
            if let metadata = removedMetadata {
                self.removeFromSearchIndices(metadata)
            }
            
            // Remove from persistent storage
            self.removePersistentMetadata(for: attachmentId)
        }
    }
    
    /// Updates access time for an attachment (for cache management)
    func markAsAccessed(_ attachmentId: UUID) {
        indexQueue.async {
            if var metadata = self.metadataCache[attachmentId] {
                metadata = ImageMetadata(
                    attachmentId: metadata.attachmentId,
                    noteId: metadata.noteId,
                    fileName: metadata.fileName,
                    fileSize: metadata.fileSize,
                    imageDimensions: metadata.imageDimensions,
                    dominantColors: metadata.dominantColors,
                    detectedObjects: metadata.detectedObjects,
                    ocrText: metadata.ocrText,
                    featureHash: metadata.featureHash,
                    indexedDate: metadata.indexedDate,
                    lastAccessDate: Date()
                )
                self.metadataCache[attachmentId] = metadata
            }
        }
    }
    
    /// Gets cache statistics
    var cacheStats: (count: Int, memoryUsage: String) {
        let count = metadataCache.count
        let estimatedBytes = count * 1024 // Rough estimate
        let memoryUsage = ByteCountFormatter.string(fromByteCount: Int64(estimatedBytes), countStyle: .memory)
        return (count, memoryUsage)
    }
    
    /// Forces cache cleanup
    func cleanupCache() {
        indexQueue.async {
            self.cleanupCacheIfNeeded(force: true)
        }
    }
}

// MARK: - Private Methods
private extension ImageMetadataIndex {
    
    func updateSearchIndices(for metadata: ImageMetadata) {
        let attachmentId = metadata.attachmentId
        
        // Update objects index
        for object in metadata.detectedObjects {
            let key = object.lowercased()
            searchIndex.byObjects[key, default: Set()].insert(attachmentId)
        }
        
        // Update filename index
        let filenameKey = metadata.fileName.lowercased()
        searchIndex.byFilename[filenameKey, default: Set()].insert(attachmentId)
        
        // Update colors index
        for colorData in metadata.dominantColors {
            let colorKey = colorToKey(colorData.uiColor)
            searchIndex.byColors[colorKey, default: Set()].insert(attachmentId)
        }
        
        // Update size indices
        searchIndex.bySize.append((metadata.imageDimensions, attachmentId))
        searchIndex.byFileSize.append((metadata.fileSize, attachmentId))
        
        // Keep size indices sorted and trimmed
        searchIndex.bySize.sort { $0.0.width * $0.0.height < $1.0.width * $1.0.height }
        searchIndex.byFileSize.sort { $0.0 < $1.0 }
        
        if searchIndex.bySize.count > maxCacheSize {
            searchIndex.bySize = Array(searchIndex.bySize.suffix(maxCacheSize))
        }
        if searchIndex.byFileSize.count > maxCacheSize {
            searchIndex.byFileSize = Array(searchIndex.byFileSize.suffix(maxCacheSize))
        }
    }
    
    func removeFromSearchIndices(_ metadata: ImageMetadata) {
        let attachmentId = metadata.attachmentId
        
        // Remove from objects index
        for object in metadata.detectedObjects {
            let key = object.lowercased()
            searchIndex.byObjects[key]?.remove(attachmentId)
            if searchIndex.byObjects[key]?.isEmpty == true {
                searchIndex.byObjects.removeValue(forKey: key)
            }
        }
        
        // Remove from filename index
        let filenameKey = metadata.fileName.lowercased()
        searchIndex.byFilename[filenameKey]?.remove(attachmentId)
        if searchIndex.byFilename[filenameKey]?.isEmpty == true {
            searchIndex.byFilename.removeValue(forKey: filenameKey)
        }
        
        // Remove from colors index
        for colorData in metadata.dominantColors {
            let colorKey = colorToKey(colorData.uiColor)
            searchIndex.byColors[colorKey]?.remove(attachmentId)
            if searchIndex.byColors[colorKey]?.isEmpty == true {
                searchIndex.byColors.removeValue(forKey: colorKey)
            }
        }
        
        // Remove from size indices
        searchIndex.bySize.removeAll { $0.1 == attachmentId }
        searchIndex.byFileSize.removeAll { $0.1 == attachmentId }
    }
    
    func colorToKey(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Quantize to reduce key space
        let quantizedR = Int(r * 8) * 32
        let quantizedG = Int(g * 8) * 32
        let quantizedB = Int(b * 8) * 32
        
        return "\(quantizedR)-\(quantizedG)-\(quantizedB)"
    }
    
    func colorSimilarity(_ key1: String, _ key2: String) -> Double {
        let components1 = key1.split(separator: "-").compactMap { Double($0) }
        let components2 = key2.split(separator: "-").compactMap { Double($0) }
        
        guard components1.count == 3 && components2.count == 3 else { return 0.0 }
        
        let distance = sqrt(
            pow(components1[0] - components2[0], 2) +
            pow(components1[1] - components2[1], 2) +
            pow(components1[2] - components2[2], 2)
        )
        
        let maxDistance = sqrt(3 * pow(255, 2))
        return 1.0 - (distance / maxDistance)
    }
    
    func cleanupCacheIfNeeded(force: Bool = false) {
        let shouldCleanup = force || metadataCache.count > maxCacheSize
        
        guard shouldCleanup else { return }
        
        let now = Date()
        let expiredIds = metadataCache.compactMap { key, metadata in
            let isExpired = now.timeIntervalSince(metadata.lastAccessDate) > cacheExpirationTime
            return isExpired ? key : nil
        }
        
        // Remove expired entries
        for id in expiredIds {
            if let metadata = metadataCache.removeValue(forKey: id) {
                removeFromSearchIndices(metadata)
            }
        }
        
        // If still too large, remove least recently accessed
        if metadataCache.count > maxCacheSize {
            let sortedByAccess = metadataCache.sorted { 
                $0.value.lastAccessDate < $1.value.lastAccessDate 
            }
            
            let toRemove = sortedByAccess.prefix(metadataCache.count - maxCacheSize)
            for (id, metadata) in toRemove {
                metadataCache.removeValue(forKey: id)
                removeFromSearchIndices(metadata)
            }
        }
    }
    
    // MARK: - Persistence Methods
    
    func loadPersistedMetadata() {
        persistenceQueue.async {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let metadataURL = documentsPath.appendingPathComponent("ImageMetadataIndex.json")
            
            guard FileManager.default.fileExists(atPath: metadataURL.path),
                  let data = try? Data(contentsOf: metadataURL),
                  let metadataArray = try? JSONDecoder().decode([ImageMetadata].self, from: data) else {
                return
            }
            
            DispatchQueue.main.async {
                self.indexQueue.async {
                    for metadata in metadataArray {
                        self.metadataCache[metadata.attachmentId] = metadata
                        self.updateSearchIndices(for: metadata)
                    }
                }
            }
        }
    }
    
    func persistMetadata(_ metadata: ImageMetadata) {
        persistenceQueue.async {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let metadataURL = documentsPath.appendingPathComponent("ImageMetadataIndex.json")
            
            var allMetadata = Array(self.metadataCache.values)
            
            // Update or add the new metadata
            if let index = allMetadata.firstIndex(where: { $0.attachmentId == metadata.attachmentId }) {
                allMetadata[index] = metadata
            } else {
                allMetadata.append(metadata)
            }
            
            do {
                let data = try JSONEncoder().encode(allMetadata)
                try data.write(to: metadataURL)
            } catch {
                print("Failed to persist image metadata: \(error)")
            }
        }
    }
    
    func removePersistentMetadata(for attachmentId: UUID) {
        persistenceQueue.async {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let metadataURL = documentsPath.appendingPathComponent("ImageMetadataIndex.json")
            
            guard let data = try? Data(contentsOf: metadataURL),
                  var metadataArray = try? JSONDecoder().decode([ImageMetadata].self, from: data) else {
                return
            }
            
            metadataArray.removeAll { $0.attachmentId == attachmentId }
            
            do {
                let updatedData = try JSONEncoder().encode(metadataArray)
                try updatedData.write(to: metadataURL)
            } catch {
                print("Failed to remove persistent metadata: \(error)")
            }
        }
    }
}
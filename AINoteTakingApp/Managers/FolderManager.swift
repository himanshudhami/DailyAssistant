//
//  FolderManager.swift
//  AINoteTakingApp
//
//  Specialized manager for hierarchical folder operations and navigation.
//  Handles folder creation, deletion, movement, and sentiment analysis.
//  Provides navigation utilities for n-level deep folder structures.
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import CoreData

class FolderManager: ObservableObject {
    
    private let dataManager = DataManager.shared
    
    @Published var folders: [Folder] = []
    @Published var currentFolder: Folder?
    @Published var folderPath: [Folder] = []
    
    init() {
        loadRootFolders()
    }
    
    func loadRootFolders() {
        folders = dataManager.fetchFolders()
        updateFolderPath()
    }
    
    func loadSubfolders(of parentFolder: Folder) {
        folders = dataManager.fetchFolders(parentFolder: parentFolder)
        currentFolder = parentFolder
        updateFolderPath()
    }
    
    func navigateToFolder(_ folder: Folder) {
        currentFolder = folder
        folders = dataManager.fetchFolders(parentFolder: folder)
        updateFolderPath()
    }
    
    func navigateUp() {
        if let currentFolder = currentFolder,
           let parentId = currentFolder.parentFolderId {
            let allFolders = dataManager.fetchAllFolders()
            if let parentFolder = allFolders.first(where: { $0.id == parentId }) {
                navigateToFolder(parentFolder)
            } else {
                navigateToRoot()
            }
        } else {
            navigateToRoot()
        }
    }
    
    func navigateToRoot() {
        currentFolder = nil
        loadRootFolders()
    }
    
    func createFolder(name: String) {
        let newFolder = dataManager.createFolder(name: name, parentFolder: currentFolder)
        folders.append(newFolder)
        folders.sort { $0.name < $1.name }
    }
    
    func renameFolder(_ folder: Folder, to newName: String) {
        var updatedFolder = folder
        updatedFolder.name = newName
        updatedFolder.modifiedDate = Date()
        
        dataManager.updateFolder(updatedFolder)
        
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = updatedFolder
        }
        folders.sort { $0.name < $1.name }
    }
    
    func deleteFolder(_ folder: Folder) {
        dataManager.deleteFolder(folder)
        folders.removeAll { $0.id == folder.id }
    }
    
    func refreshCurrentFolder() {
        if let currentFolder = currentFolder {
            folders = dataManager.fetchFolders(parentFolder: currentFolder)
        } else {
            loadRootFolders()
        }
    }
    
    func updateFolderSentiment(_ folder: Folder, sentiment: FolderSentiment) {
        var updatedFolder = folder
        updatedFolder.sentiment = sentiment
        updatedFolder.modifiedDate = Date()
        
        dataManager.updateFolder(updatedFolder)
        
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = updatedFolder
        }
    }
    
    func getFolderHierarchy() -> [Folder] {
        return folderPath
    }
    
    func canMoveFolder(_ folder: Folder, to destination: Folder?) -> Bool {
        guard folder.id != destination?.id else { return false }
        
        var current = destination
        while let currentFolder = current {
            if currentFolder.id == folder.id {
                return false
            }
            
            if let parentId = currentFolder.parentFolderId {
                let allFolders = dataManager.fetchAllFolders()
                current = allFolders.first { $0.id == parentId }
            } else {
                current = nil
            }
        }
        
        return true
    }
    
    func moveFolder(_ folder: Folder, to destination: Folder?) {
        guard canMoveFolder(folder, to: destination) else { return }
        
        var updatedFolder = folder
        updatedFolder.parentFolderId = destination?.id
        updatedFolder.modifiedDate = Date()
        
        dataManager.updateFolder(updatedFolder)
        refreshCurrentFolder()
    }
    
    func searchFolders(query: String) -> [Folder] {
        let allFolders = dataManager.fetchAllFolders()
        return allFolders.filter { folder in
            folder.name.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getFolderStats(_ folder: Folder) -> (noteCount: Int, subfolderCount: Int) {
        let subfolders = dataManager.fetchFolders(parentFolder: folder)
        let notes = dataManager.fetchNotes(in: folder)
        return (noteCount: notes.count, subfolderCount: subfolders.count)
    }
    
    private func updateFolderPath() {
        if let currentFolder = currentFolder {
            folderPath = dataManager.getFolderPath(currentFolder)
        } else {
            folderPath = []
        }
    }
    
    func calculateFolderSentiment(_ folder: Folder) -> FolderSentiment {
        let notes = dataManager.fetchNotes(in: folder)
        
        guard !notes.isEmpty else { return .neutral }
        
        let sentiments = notes.compactMap { note -> FolderSentiment? in
            if let aiSummary = note.aiSummary {
                return analyzeSentimentFromText(aiSummary)
            } else if !note.content.isEmpty {
                return analyzeSentimentFromText(note.content)
            }
            return nil
        }
        
        return calculateAverageSentiment(sentiments)
    }
    
    private func analyzeSentimentFromText(_ text: String) -> FolderSentiment {
        let positiveKeywords = ["happy", "good", "great", "excellent", "amazing", "wonderful", "fantastic", "love", "joy", "success", "achievement"]
        let negativeKeywords = ["sad", "bad", "terrible", "awful", "hate", "angry", "frustrated", "problem", "issue", "error", "fail"]
        
        let lowercasedText = text.lowercased()
        
        let positiveCount = positiveKeywords.reduce(0) { count, keyword in
            count + lowercasedText.components(separatedBy: keyword).count - 1
        }
        
        let negativeCount = negativeKeywords.reduce(0) { count, keyword in
            count + lowercasedText.components(separatedBy: keyword).count - 1
        }
        
        let totalWords = text.components(separatedBy: .whitespacesAndNewlines).count
        let positiveRatio = Double(positiveCount) / Double(totalWords)
        let negativeRatio = Double(negativeCount) / Double(totalWords)
        
        if positiveRatio > negativeRatio {
            if positiveRatio > 0.1 {
                return .veryPositive
            } else if positiveRatio > 0.05 {
                return .positive
            }
        } else if negativeRatio > positiveRatio {
            if negativeRatio > 0.1 {
                return .veryNegative
            } else if negativeRatio > 0.05 {
                return .negative
            }
        }
        
        if positiveCount > 0 && negativeCount > 0 {
            return .mixed
        }
        
        return .neutral
    }
    
    private func calculateAverageSentiment(_ sentiments: [FolderSentiment]) -> FolderSentiment {
        guard !sentiments.isEmpty else { return .neutral }
        
        let sentimentValues: [FolderSentiment: Int] = [
            .veryNegative: -2,
            .negative: -1,
            .neutral: 0,
            .positive: 1,
            .veryPositive: 2,
            .mixed: 0
        ]
        
        let totalValue = sentiments.compactMap { sentimentValues[$0] }.reduce(0, +)
        let averageValue = Double(totalValue) / Double(sentiments.count)
        
        let mixedCount = sentiments.filter { $0 == .mixed }.count
        let mixedRatio = Double(mixedCount) / Double(sentiments.count)
        
        if mixedRatio > 0.3 {
            return .mixed
        }
        
        switch averageValue {
        case 1.5...:
            return .veryPositive
        case 0.5..<1.5:
            return .positive
        case -0.5..<0.5:
            return .neutral
        case -1.5..<(-0.5):
            return .negative
        case ...(-1.5):
            return .veryNegative
        default:
            return .neutral
        }
    }
}
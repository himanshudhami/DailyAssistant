//
//  OCRService.swift
//  AINoteTakingApp
//
//  Optical Character Recognition service following SRP
//  Extracted from AIProcessor for better separation of concerns
//
//  Created by AI Assistant on 2025-01-29.
//

import Foundation
import Vision
import UIKit

// MARK: - OCR Result Models
struct OCRResult {
    let rawText: String
    let detectedTables: [TableData]
    let confidence: Float
}

struct TableData {
    let title: String?
    let headers: [String]
    let rows: [[String]]
    let boundingBox: CGRect
    let confidence: Float
    
    enum OutputFormat {
        case markdown
        case csv
        case json
        case plainText
    }
    
    var formattedText: String {
        return formatAs(.markdown)
    }
    
    func formatAs(_ format: OutputFormat) -> String {
        switch format {
        case .markdown:
            return formatAsMarkdown()
        case .csv:
            return formatAsCSV()
        case .json:
            return formatAsJSON()
        case .plainText:
            return formatAsPlainText()
        }
    }
    
    var isValid: Bool {
        return !headers.isEmpty && !rows.isEmpty && confidence > 0.3
    }
    
    var rowCount: Int {
        return rows.count
    }
    
    var columnCount: Int {
        return headers.count
    }
}

// MARK: - OCR Service
@MainActor
class OCRService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var errorMessage: String?
    
    // MARK: - Public Methods
    
    func performOCR(on image: UIImage) async -> OCRResult {
        isProcessing = true
        processingProgress = 0
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0
            }
        }
        
        guard let cgImage = image.cgImage else {
            return OCRResult(rawText: "", detectedTables: [], confidence: 0.0)
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                Task { @MainActor in
                    self.processingProgress = 0.5
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(rawText: "", detectedTables: [], confidence: 0.0))
                    return
                }
                
                Task {
                    let result = await self.processOCRObservations(observations, imageSize: image.size)
                    await MainActor.run {
                        self.processingProgress = 1.0
                    }
                    continuation.resume(returning: result)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    func validateAndCorrectTable(_ table: TableData) -> TableData {
        var correctedHeaders = validateHeaders(table.headers)
        var correctedRows = validateRows(table.rows, expectedColumnCount: correctedHeaders.count)
        
        // Clean and normalize text
        correctedHeaders = correctedHeaders.map { cleanText($0) }
        correctedRows = correctedRows.map { row in
            row.map { cleanText($0) }
        }
        
        // Remove completely empty rows
        correctedRows = correctedRows.filter { row in
            !row.allSatisfy { $0.isEmpty }
        }
        
        // Merge split cells if detected
        correctedRows = mergeSplitCells(correctedRows)
        
        return TableData(
            title: table.title?.trimmingCharacters(in: .whitespacesAndNewlines),
            headers: correctedHeaders,
            rows: correctedRows,
            boundingBox: table.boundingBox,
            confidence: calculateCorrectedConfidence(originalConfidence: table.confidence, headers: correctedHeaders, rows: correctedRows)
        )
    }
}

// MARK: - Private Methods
private extension OCRService {
    
    func processOCRObservations(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) async -> OCRResult {
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
        let detectedTables = await detectTables(from: textBlocks, imageSize: imageSize)
        
        let averageConfidence = textBlocks.isEmpty ? 0.0 : textBlocks.map { $0.confidence }.reduce(0, +) / Float(textBlocks.count)
        
        return OCRResult(
            rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedTables: detectedTables,
            confidence: averageConfidence
        )
    }
    
    func detectTables(from textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)], imageSize: CGSize) async -> [TableData] {
        var tables: [TableData] = []
        
        // Group text blocks by vertical position to identify potential rows
        let sortedBlocks = textBlocks.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        var processedBlocks = Set<Int>()
        
        for (index, block) in sortedBlocks.enumerated() {
            if processedBlocks.contains(index) { continue }
            
            // Find blocks that could form a table row (similar Y position)
            var rowBlocks: [(text: String, boundingBox: CGRect, confidence: Float)] = [block]
            let rowY = block.boundingBox.minY
            let rowTolerance: CGFloat = 0.02 // 2% tolerance
            
            for (otherIndex, otherBlock) in sortedBlocks.enumerated() {
                if otherIndex == index || processedBlocks.contains(otherIndex) { continue }
                
                if abs(otherBlock.boundingBox.minY - rowY) <= rowTolerance {
                    rowBlocks.append(otherBlock)
                    processedBlocks.insert(otherIndex)
                }
            }
            
            // If we found multiple blocks in a row, check if it could be part of a table
            if rowBlocks.count >= 2 {
                processedBlocks.insert(index)
                
                // Sort blocks by X position for proper column order
                rowBlocks.sort { $0.boundingBox.minX < $1.boundingBox.minX }
                
                // Look for additional rows below this one
                var tableRows: [[String]] = [rowBlocks.map { $0.text }]
                var tableBoundingBox = rowBlocks.reduce(rowBlocks[0].boundingBox) { result, block in
                    result.union(block.boundingBox)
                }
                
                // Search for additional rows
                let columnCount = rowBlocks.count
                let columnPositions = rowBlocks.map { $0.boundingBox.minX }
                
                for (searchIndex, searchBlock) in sortedBlocks.enumerated() {
                    if processedBlocks.contains(searchIndex) { continue }
                    
                    // Check if this block could start a new row below the current table
                    if searchBlock.boundingBox.minY < (rowY - 0.05) { // 5% below current row
                        var newRowBlocks: [(text: String, boundingBox: CGRect)] = []
                        
                        // Try to find blocks for each column position
                        for columnX in columnPositions {
                            let columnTolerance: CGFloat = 0.03
                            
                            if let matchingBlock = sortedBlocks.first(where: { otherBlock in
                                !processedBlocks.contains(sortedBlocks.firstIndex(where: { $0.boundingBox == otherBlock.boundingBox }) ?? -1) &&
                                abs(otherBlock.boundingBox.minX - columnX) <= columnTolerance &&
                                abs(otherBlock.boundingBox.minY - searchBlock.boundingBox.minY) <= rowTolerance
                            }) {
                                newRowBlocks.append((text: matchingBlock.text, boundingBox: matchingBlock.boundingBox))
                            }
                        }
                        
                        // If we found blocks for most columns, add this as a table row
                        if newRowBlocks.count >= max(2, columnCount - 1) {
                            newRowBlocks.sort { $0.boundingBox.minX < $1.boundingBox.minX }
                            
                            // Pad row to match column count
                            var rowData = newRowBlocks.map { $0.text }
                            while rowData.count < columnCount {
                                rowData.append("")
                            }
                            
                            tableRows.append(Array(rowData.prefix(columnCount)))
                            
                            // Update table bounding box
                            for block in newRowBlocks {
                                tableBoundingBox = tableBoundingBox.union(block.boundingBox)
                            }
                            
                            // Mark these blocks as processed
                            for block in newRowBlocks {
                                if let blockIndex = sortedBlocks.firstIndex(where: { $0.boundingBox == block.boundingBox }) {
                                    processedBlocks.insert(blockIndex)
                                }
                            }
                        }
                    }
                }
                
                // Create table if we have at least 2 rows
                if tableRows.count >= 2 {
                    let headers = tableRows[0]
                    let dataRows = Array(tableRows[1...])
                    
                    let averageConfidence = rowBlocks.map { $0.confidence }.reduce(0, +) / Float(rowBlocks.count)
                    
                    let rawTable = TableData(
                        title: detectTableTitle(near: tableBoundingBox, in: textBlocks),
                        headers: headers,
                        rows: dataRows,
                        boundingBox: tableBoundingBox,
                        confidence: averageConfidence
                    )
                    
                    // Validate and correct the table
                    let correctedTable = validateAndCorrectTable(rawTable)
                    
                    // Only add valid tables
                    if correctedTable.isValid {
                        tables.append(correctedTable)
                    }
                }
            }
        }
        
        return tables
    }
    
    func detectTableTitle(near tableBoundingBox: CGRect, in textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> String? {
        let titleSearchArea = CGRect(
            x: tableBoundingBox.minX - 0.1,
            y: tableBoundingBox.maxY,
            width: tableBoundingBox.width + 0.2,
            height: 0.1
        )
        
        let potentialTitles = textBlocks.filter { block in
            titleSearchArea.intersects(block.boundingBox) &&
            !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        return potentialTitles.sorted { $0.boundingBox.minY > $1.boundingBox.minY }.first?.text
    }
    
    func validateHeaders(_ headers: [String]) -> [String] {
        var validatedHeaders = headers
        
        // Remove empty headers at the end
        while validatedHeaders.last?.isEmpty == true {
            validatedHeaders.removeLast()
        }
        
        // Fill empty headers with generic names
        for (index, header) in validatedHeaders.enumerated() {
            if header.isEmpty {
                validatedHeaders[index] = "Column \(index + 1)"
            }
        }
        
        // Ensure minimum 2 columns for a valid table
        if validatedHeaders.count < 2 {
            while validatedHeaders.count < 2 {
                validatedHeaders.append("Column \(validatedHeaders.count + 1)")
            }
        }
        
        return validatedHeaders
    }
    
    func validateRows(_ rows: [[String]], expectedColumnCount: Int) -> [[String]] {
        return rows.map { row in
            var validatedRow = row
            
            // Pad row to match expected column count
            while validatedRow.count < expectedColumnCount {
                validatedRow.append("")
            }
            
            // Trim row if it exceeds expected column count
            if validatedRow.count > expectedColumnCount {
                validatedRow = Array(validatedRow.prefix(expectedColumnCount))
            }
            
            return validatedRow
        }
    }
    
    func cleanText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[\\x00-\\x1F\\x7F]", with: "", options: .regularExpression) // Remove control characters
    }
    
    func mergeSplitCells(_ rows: [[String]]) -> [[String]] {
        guard !rows.isEmpty else { return rows }
        
        var mergedRows: [[String]] = []
        var i = 0
        
        while i < rows.count {
            let currentRow = rows[i]
            
            // Check if this row might be a continuation of the previous row
            if i > 0 && shouldMergeWithPreviousRow(currentRow, previousRow: rows[i-1]) {
                // Merge with the last row in mergedRows
                if !mergedRows.isEmpty {
                    let lastIndex = mergedRows.count - 1
                    mergedRows[lastIndex] = mergeRows(mergedRows[lastIndex], currentRow)
                }
            } else {
                mergedRows.append(currentRow)
            }
            
            i += 1
        }
        
        return mergedRows
    }
    
    func shouldMergeWithPreviousRow(_ currentRow: [String], previousRow: [String]) -> Bool {
        // Check if current row has significantly fewer non-empty cells
        let currentNonEmpty = currentRow.filter { !$0.isEmpty }.count
        let previousNonEmpty = previousRow.filter { !$0.isEmpty }.count
        
        // If current row has very few cells and previous row has more, likely a split
        if currentNonEmpty > 0 && currentNonEmpty < previousNonEmpty / 2 {
            return true
        }
        
        // Check if current row starts with what looks like continuation text
        let firstNonEmpty = currentRow.first { !$0.isEmpty }
        if let text = firstNonEmpty {
            let startsWithLowercase = text.first?.isLowercase == true
            let hasNoPunctuation = !text.contains(".") && !text.contains("!") && !text.contains("?")
            return startsWithLowercase && hasNoPunctuation && text.count < 30
        }
        
        return false
    }
    
    func mergeRows(_ row1: [String], _ row2: [String]) -> [String] {
        let maxCount = max(row1.count, row2.count)
        var merged: [String] = []
        
        for i in 0..<maxCount {
            let cell1 = i < row1.count ? row1[i] : ""
            let cell2 = i < row2.count ? row2[i] : ""
            
            if cell1.isEmpty {
                merged.append(cell2)
            } else if cell2.isEmpty {
                merged.append(cell1)
            } else {
                merged.append(cell1 + " " + cell2)
            }
        }
        
        return merged
    }
    
    func calculateCorrectedConfidence(originalConfidence: Float, headers: [String], rows: [[String]]) -> Float {
        var confidence = originalConfidence
        
        // Reduce confidence for tables with many empty cells
        let totalCells = headers.count * (rows.count + 1) // +1 for header row
        let emptyCells = headers.filter { $0.isEmpty }.count + 
                        rows.flatMap { $0 }.filter { $0.isEmpty }.count
        
        let emptyRatio = Float(emptyCells) / Float(totalCells)
        confidence *= (1.0 - emptyRatio * 0.5) // Reduce by up to 50% based on empty cells
        
        // Boost confidence for well-structured tables
        if rows.count >= 3 && headers.count >= 2 {
            confidence *= 1.1 // 10% boost for substantial tables
        }
        
        return min(max(confidence, 0.0), 1.0) // Clamp between 0 and 1
    }
}

// MARK: - Table Data Extensions
extension TableData {
    
    private func formatAsMarkdown() -> String {
        var result = ""
        
        if let title = title, !title.isEmpty {
            result += "**\(title)**\n\n"
        }
        
        // Create markdown table format
        if !headers.isEmpty {
            result += "| " + headers.joined(separator: " | ") + " |\n"
            result += "|" + String(repeating: "---|", count: headers.count) + "\n"
        }
        
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            result += "| " + paddedRow.joined(separator: " | ") + " |\n"
        }
        
        return result
    }
    
    private func formatAsCSV() -> String {
        var result = ""
        
        if let title = title, !title.isEmpty {
            result += "\"\(title)\"\n"
        }
        
        // Add headers
        if !headers.isEmpty {
            result += headers.map { "\"\($0)\"" }.joined(separator: ",") + "\n"
        }
        
        // Add rows
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            result += paddedRow.map { "\"\($0)\"" }.joined(separator: ",") + "\n"
        }
        
        return result
    }
    
    private func formatAsJSON() -> String {
        var tableDict: [String: Any] = [:]
        
        if let title = title, !title.isEmpty {
            tableDict["title"] = title
        }
        
        tableDict["headers"] = headers
        tableDict["rows"] = rows.map { padRowToMatchHeaders($0) }
        tableDict["confidence"] = confidence
        
        // Convert to structured data
        var tableData: [[String: String]] = []
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            var rowDict: [String: String] = [:]
            
            for (index, header) in headers.enumerated() {
                let value = index < paddedRow.count ? paddedRow[index] : ""
                rowDict[header] = value
            }
            tableData.append(rowDict)
        }
        
        tableDict["data"] = tableData
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: tableDict, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to serialize table data\"}"
        }
    }
    
    private func formatAsPlainText() -> String {
        var result = ""
        
        if let title = title, !title.isEmpty {
            result += "\(title)\n"
            result += String(repeating: "=", count: title.count) + "\n\n"
        }
        
        // Calculate column widths
        let columnWidths = calculateColumnWidths()
        
        // Add headers
        if !headers.isEmpty {
            let headerRow = headers.enumerated().map { index, header in
                let width = index < columnWidths.count ? columnWidths[index] : header.count
                return header.padding(toLength: width, withPad: " ", startingAt: 0)
            }.joined(separator: " | ")
            
            result += headerRow + "\n"
            result += String(repeating: "-", count: headerRow.count) + "\n"
        }
        
        // Add rows
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            let formattedRow = paddedRow.enumerated().map { index, cell in
                let width = index < columnWidths.count ? columnWidths[index] : cell.count
                return cell.padding(toLength: width, withPad: " ", startingAt: 0)
            }.joined(separator: " | ")
            
            result += formattedRow + "\n"
        }
        
        return result
    }
    
    private func padRowToMatchHeaders(_ row: [String]) -> [String] {
        var paddedRow = row
        while paddedRow.count < headers.count {
            paddedRow.append("")
        }
        return Array(paddedRow.prefix(headers.count))
    }
    
    private func calculateColumnWidths() -> [Int] {
        var widths = headers.map { $0.count }
        
        for row in rows {
            let paddedRow = padRowToMatchHeaders(row)
            for (index, cell) in paddedRow.enumerated() {
                if index < widths.count {
                    widths[index] = max(widths[index], cell.count)
                }
            }
        }
        
        return widths
    }
}
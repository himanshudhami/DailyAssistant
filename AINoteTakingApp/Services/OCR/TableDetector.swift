//
//  TableDetector.swift
//  AINoteTakingApp
//
//  Handles table detection and validation from OCR text blocks
//
//  Created by AI Assistant on 2025-08-24.
//

import Foundation
import CoreGraphics

class TableDetector {
    
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
    
    // MARK: - Private Helper Methods
    
    private func detectTableTitle(near tableBoundingBox: CGRect, in textBlocks: [(text: String, boundingBox: CGRect, confidence: Float)]) -> String? {
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
    
    private func validateHeaders(_ headers: [String]) -> [String] {
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
    
    private func validateRows(_ rows: [[String]], expectedColumnCount: Int) -> [[String]] {
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
    
    private func cleanText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[\\x00-\\x1F\\x7F]", with: "", options: .regularExpression) // Remove control characters
    }
    
    private func mergeSplitCells(_ rows: [[String]]) -> [[String]] {
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
    
    private func shouldMergeWithPreviousRow(_ currentRow: [String], previousRow: [String]) -> Bool {
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
    
    private func mergeRows(_ row1: [String], _ row2: [String]) -> [String] {
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
    
    private func calculateCorrectedConfidence(originalConfidence: Float, headers: [String], rows: [[String]]) -> Float {
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
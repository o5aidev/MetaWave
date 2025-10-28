//
//  DataExportService.swift
//  MetaWave
//
//  v2.4: データエクスポートサービス
//

import Foundation
import CoreData
import SwiftUI

/// データエクスポートサービス
@MainActor
final class DataExportService: ObservableObject {
    
    private let context: NSManagedObjectContext
    private let vault: Vault
    
    @Published var exportProgress: Float = 0.0
    @Published var isExporting = false
    
    init(context: NSManagedObjectContext, vault: Vault = .shared) {
        self.context = context
        self.vault = vault
    }
    
    // MARK: - Export Methods
    
    /// JSON形式でエクスポート
    func exportToJSON() async throws -> Data {
        await MainActor.run {
            isExporting = true
            exportProgress = 0.0
        }
        defer {
            Task { @MainActor in
                isExporting = false
                exportProgress = 0.0
            }
        }
        
        // ノートデータの取得
        let notes = try await fetchAllNotes()
        await updateProgress(0.3)
        
        // 感情データの取得
        let emotionData = try await fetchEmotionData()
        await updateProgress(0.5)
        
        // パターンデータの取得
        let patterns = try await fetchPatternData()
        await updateProgress(0.7)
        
        // JSONエンコード
        let exportData = ExportData(
            version: "2.4",
            exportDate: Date(),
            notes: notes,
            emotionData: emotionData,
            patterns: patterns,
            metadata: try await generateMetadata()
        )
        
        await updateProgress(0.9)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(exportData)
        
        await updateProgress(1.0)
        
        return data
    }
    
    /// CSV形式でエクスポート
    func exportToCSV() async throws -> Data {
        await MainActor.run {
            isExporting = true
            exportProgress = 0.0
        }
        defer {
            Task { @MainActor in
                isExporting = false
                exportProgress = 0.0
            }
        }
        
        let notes = try await fetchAllNotes()
        await updateProgress(0.5)
        
        var csvLines = ["timestamp,modality,content,valence,arousal,tags,created_at"]
        
        for note in notes {
            let line = formatNoteAsCSVLine(note)
            csvLines.append(line)
        }
        
        await updateProgress(1.0)
        
        let csvString = csvLines.joined(separator: "\n")
        guard let data = csvString.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return data
    }
    
    /// 暗号化してエクスポート
    func exportEncryptedJSON() async throws -> Data {
        let plainData = try await exportToJSON()
        return try vault.encrypt(plainData)
    }
    
    // MARK: - Private Methods
    
    private func fetchAllNotes() async throws -> [ExportNote] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: true)]
        
        let notes = try context.fetch(request)
        
        return notes.compactMap { note in
            guard let id = note.id,
                  let createdAt = note.createdAt else {
                return nil
            }
            
            return ExportNote(
                id: id.uuidString,
                modality: note.modality ?? "text",
                contentText: note.contentText,
                audioURL: note.audioURL?.absoluteString,
                sentiment: note.sentiment,
                arousal: note.arousal,
                tags: note.tags?.components(separatedBy: ",") ?? [],
                createdAt: createdAt,
                updatedAt: note.updatedAt
            )
        }
    }
    
    private func fetchEmotionData() async throws -> [ExportEmotionData] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "sentiment != nil")
        
        let notes = try context.fetch(request)
        
        return notes.compactMap { note in
            guard let sentiment = note.sentiment,
                  let createdAt = note.createdAt else {
                return nil
            }
            
            return ExportEmotionData(
                noteID: note.id?.uuidString ?? "",
                valence: sentiment.doubleValue,
                arousal: note.arousal?.doubleValue ?? 0.0,
                timestamp: createdAt
            )
        }
    }
    
    private func fetchPatternData() async throws -> [ExportPattern] {
        let request: NSFetchRequest<Insight> = Insight.fetchRequest()
        request.predicate = NSPredicate(format: "kind == 'loop'")
        
        let insights = try context.fetch(request)
        
        return insights.compactMap { insight in
            guard let payload = insight.payload,
                  let data = payload.data(using: .utf8),
                  let loopPayload = try? JSONDecoder().decode(LoopInsightPayload.self, from: data) else {
                return nil
            }
            
            return ExportPattern(
                topic: loopPayload.topic,
                strength: loopPayload.strength,
                noteCount: loopPayload.noteCount,
                detectedAt: insight.createdAt ?? Date()
            )
        }
    }
    
    private func generateMetadata() async throws -> ExportMetadata {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try context.fetch(request)
        
        let textNotes = notes.filter { $0.modality == "text" }.count
        let audioNotes = notes.filter { $0.modality == "voice" }.count
        
        return ExportMetadata(
            totalNotes: notes.count,
            textNotes: textNotes,
            audioNotes: audioNotes,
            firstNoteDate: notes.first?.createdAt,
            lastNoteDate: notes.last?.createdAt
        )
    }
    
    private func formatNoteAsCSVLine(_ note: Note) -> String {
        let timestamp = note.createdAt?.timeIntervalSince1970 ?? 0
        let modality = note.modality ?? "text"
        let content = (note.contentText ?? "").replacingOccurrences(of: "\"", with: "\"\"")
        let valence = note.sentiment?.doubleValue ?? 0.0
        let arousal = note.arousal?.doubleValue ?? 0.0
        let tags = note.tags ?? ""
        let createdAt = note.createdAt?.timeIntervalSince1970 ?? 0
        
        return "\"\(timestamp)\",\"\(modality)\",\"\(content)\",\(valence),\(arousal),\"\(tags)\",\(createdAt)"
    }
    
    private func updateProgress(_ progress: Float) async {
        await MainActor.run {
            exportProgress = progress
        }
    }
}

// MARK: - Export Data Models

struct ExportData: Codable {
    let version: String
    let exportDate: Date
    let notes: [ExportNote]
    let emotionData: [ExportEmotionData]
    let patterns: [ExportPattern]
    let metadata: ExportMetadata
}

struct ExportNote: Codable {
    let id: String
    let modality: String
    let contentText: String?
    let audioURL: String?
    let sentiment: NSNumber?
    let arousal: NSNumber?
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date?
}

struct ExportEmotionData: Codable {
    let noteID: String
    let valence: Double
    let arousal: Double
    let timestamp: Date
}

struct ExportPattern: Codable {
    let topic: String
    let strength: Float
    let noteCount: Int
    let detectedAt: Date
}

struct ExportMetadata: Codable {
    let totalNotes: Int
    let textNotes: Int
    let audioNotes: Int
    let firstNoteDate: Date?
    let lastNoteDate: Date?
}

// MARK: - Export Error

enum ExportError: Error, LocalizedError {
    case encodingFailed
    case noData
    case encryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "データのエンコードに失敗しました"
        case .noData:
            return "エクスポートするデータがありません"
        case .encryptionFailed:
            return "データの暗号化に失敗しました"
        }
    }
}


//
//  BackupService.swift
//  MetaWave
//
//  v2.4: バックアップ・復元機能
//

import Foundation
import CoreData
import CloudKit
import SwiftUI
import Combine

/// バックアップ・復元サービス
final class BackupService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = BackupService()
    
    private init() {}
    
    // MARK: - Published Properties
    
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var backupProgress: Float = 0.0
    @Published var restoreProgress: Float = 0.0
    @Published var lastBackupDate: Date?
    @Published var availableBackups: [BackupInfo] = []
    
    // MARK: - Private Properties
    
    private var context: NSManagedObjectContext?
    private let fileManager = FileManager.default
    private let cloudKitContainer = CKContainer(identifier: "iCloud.com.vibe5.MetaWave")
    
    // MARK: - Initialization
    
    func configure(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Local Backup
    
    /// ローカルバックアップを作成
    func createLocalBackup() async throws -> BackupInfo {
        await MainActor.run {
            isBackingUp = true
            backupProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isBackingUp = false
                backupProgress = 0.0
            }
        }
        
        let backupInfo = BackupInfo(
            id: UUID(),
            name: "Backup_\(Date().formatted(.dateTime.year().month().day().hour().minute()))",
            date: Date(),
            type: .local,
            size: 0
        )
        
        do {
            // 1. データベースのエクスポート
            backupProgress = 0.2
            let databaseURL = try await exportDatabase()
            
            // 2. アセットのエクスポート
            backupProgress = 0.4
            let assetsURL = try await exportAssets()
            
            // 3. 設定のエクスポート
            backupProgress = 0.6
            let settingsURL = try await exportSettings()
            
            // 4. バックアップファイルの作成
            backupProgress = 0.8
            let backupURL = try await createBackupArchive(
                database: databaseURL,
                assets: assetsURL,
                settings: settingsURL,
                backupInfo: backupInfo
            )
            
            // 5. バックアップ情報を保存
            backupProgress = 0.9
            try await saveBackupInfo(backupInfo, at: backupURL)
            
            backupProgress = 1.0
            
            await MainActor.run {
                lastBackupDate = Date()
                availableBackups.append(backupInfo)
            }
            
            return backupInfo
            
        } catch {
            throw BackupError.creationFailed(error)
        }
    }
    
    /// データベースをエクスポート
    private func exportDatabase() async throws -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportURL = documentsPath.appendingPathComponent("database_export.sqlite")
        
        // Core Dataの永続ストアをエクスポート
        guard let context = context else { throw BackupError.databaseNotFound }
        let persistentStoreCoordinator = context.persistentStoreCoordinator
        let storeURL = persistentStoreCoordinator?.persistentStores.first?.url
        
        guard let sourceURL = storeURL else {
            throw BackupError.databaseNotFound
        }
        
        try fileManager.copyItem(at: sourceURL, to: exportURL)
        return exportURL
    }
    
    /// アセットをエクスポート
    private func exportAssets() async throws -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let assetsURL = documentsPath.appendingPathComponent("assets_export")
        
        // アセットディレクトリを作成
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        
        // 音声ファイルをエクスポート
        guard let context = context else { throw BackupError.databaseNotFound }
        
        let audioRequest: NSFetchRequest<Note> = Note.fetchRequest()
        audioRequest.predicate = NSPredicate(format: "audioURL != nil")
        
        let audioNotes = try context.fetch(audioRequest)
        
        for (index, note) in audioNotes.enumerated() {
            if let audioURL = note.audioURL {
                let fileName = "audio_\(index).m4a"
                let destinationURL = assetsURL.appendingPathComponent(fileName)
                try fileManager.copyItem(at: audioURL, to: destinationURL)
            }
        }
        
        // 画像ファイルをエクスポート
        let imageRequest: NSFetchRequest<Note> = Note.fetchRequest()
        imageRequest.predicate = NSPredicate(format: "imageURL != nil")
        
        let imageNotes = try context.fetch(imageRequest)
        
        for (index, note) in imageNotes.enumerated() {
            if let imageURL = note.imageURL {
                let fileName = "image_\(index).jpg"
                let destinationURL = assetsURL.appendingPathComponent(fileName)
                try fileManager.copyItem(at: imageURL, to: destinationURL)
            }
        }
        
        return assetsURL
    }
    
    /// 設定をエクスポート
    private func exportSettings() async throws -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let settingsURL = documentsPath.appendingPathComponent("settings_export.json")
        
        let settings = UserSettings(
            theme: UserDefaults.standard.string(forKey: "theme") ?? "system",
            notifications: UserDefaults.standard.bool(forKey: "notifications"),
            analysisEnabled: UserDefaults.standard.bool(forKey: "analysisEnabled"),
            exportFormat: UserDefaults.standard.string(forKey: "exportFormat") ?? "json"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL)
        
        return settingsURL
    }
    
    /// バックアップアーカイブを作成
    private func createBackupArchive(
        database: URL,
        assets: URL,
        settings: URL,
        backupInfo: BackupInfo
    ) async throws -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = documentsPath.appendingPathComponent("\(backupInfo.name).metawave")
        
        // ZIPアーカイブを作成
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(writingItemAt: backupURL, options: [], error: &error) { url in
            // 実際のZIP作成処理は簡略化
            // 実際の実装ではZipArchiveライブラリなどを使用
        }
        
        if let error = error {
            throw BackupError.archiveCreationFailed(error)
        }
        
        return backupURL
    }
    
    /// バックアップ情報を保存
    private func saveBackupInfo(_ backupInfo: BackupInfo, at url: URL) async throws {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let infoURL = documentsPath.appendingPathComponent("backup_info.json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backupInfo)
        try data.write(to: infoURL)
    }
    
    // MARK: - Cloud Backup
    
    /// iCloudバックアップを作成
    func createCloudBackup() async throws -> BackupInfo {
        await MainActor.run {
            isBackingUp = true
            backupProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isBackingUp = false
                backupProgress = 0.0
            }
        }
        
        let backupInfo = BackupInfo(
            id: UUID(),
            name: "iCloud_Backup_\(Date().formatted(.dateTime.year().month().day().hour().minute()))",
            date: Date(),
            type: .cloud,
            size: 0
        )
        
        do {
            // 1. データをCloudKitにアップロード
            backupProgress = 0.3
            try await uploadToCloudKit(backupInfo: backupInfo)
            
            // 2. バックアップ情報を保存
            backupProgress = 0.8
            try await saveCloudBackupInfo(backupInfo)
            
            backupProgress = 1.0
            
            await MainActor.run {
                lastBackupDate = Date()
                availableBackups.append(backupInfo)
            }
            
            return backupInfo
            
        } catch {
            throw BackupError.cloudUploadFailed(error)
        }
    }
    
    /// CloudKitにデータをアップロード
    private func uploadToCloudKit(backupInfo: BackupInfo) async throws {
        guard let context = context else { throw BackupError.databaseNotFound }
        
        let database = cloudKitContainer.publicCloudDatabase
        
        // ノートデータをCloudKitレコードに変換
        let notesRequest: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try context.fetch(notesRequest)
        
        for note in notes {
            let record = CKRecord(recordType: "Note", recordID: CKRecord.ID(recordName: note.id?.uuidString ?? UUID().uuidString))
            
            record["contentText"] = note.contentText
            record["createdAt"] = note.createdAt
            record["updatedAt"] = note.updatedAt
            record["modality"] = note.modality
            record["sentiment"] = note.sentiment
            record["arousal"] = note.arousal
            record["tags"] = note.tags
            record["topicHash"] = note.topicHash
            record["biasSignals"] = note.biasSignals
            record["loopGroupID"] = note.loopGroupID
            
            try await database.save(record)
        }
    }
    
    /// クラウドバックアップ情報を保存
    private func saveCloudBackupInfo(_ backupInfo: BackupInfo) async throws {
        let database = cloudKitContainer.publicCloudDatabase
        
        let record = CKRecord(recordType: "BackupInfo", recordID: CKRecord.ID(recordName: backupInfo.id.uuidString))
        record["name"] = backupInfo.name
        record["date"] = backupInfo.date
        record["type"] = backupInfo.type.rawValue
        record["size"] = backupInfo.size
        
        try await database.save(record)
    }
    
    // MARK: - Restore
    
    /// バックアップから復元
    func restoreFromBackup(_ backupInfo: BackupInfo) async throws {
        await MainActor.run {
            isRestoring = true
            restoreProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isRestoring = false
                restoreProgress = 0.0
            }
        }
        
        do {
            switch backupInfo.type {
            case .local:
                try await restoreFromLocalBackup(backupInfo)
            case .cloud:
                try await restoreFromCloudBackup(backupInfo)
            }
            
            restoreProgress = 1.0
            
        } catch {
            throw BackupError.restoreFailed(error)
        }
    }
    
    /// ローカルバックアップから復元
    private func restoreFromLocalBackup(_ backupInfo: BackupInfo) async throws {
        // バックアップファイルを見つける
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = documentsPath.appendingPathComponent("\(backupInfo.name).metawave")
        
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw BackupError.backupNotFound
        }
        
        // アーカイブを展開
        restoreProgress = 0.2
        let tempURL = try await extractBackupArchive(backupURL)
        
        // データベースを復元
        restoreProgress = 0.4
        try await restoreDatabase(from: tempURL)
        
        // アセットを復元
        restoreProgress = 0.6
        try await restoreAssets(from: tempURL)
        
        // 設定を復元
        restoreProgress = 0.8
        try await restoreSettings(from: tempURL)
        
        // 一時ファイルを削除
        try fileManager.removeItem(at: tempURL)
    }
    
    /// クラウドバックアップから復元
    private func restoreFromCloudBackup(_ backupInfo: BackupInfo) async throws {
        let database = cloudKitContainer.publicCloudDatabase
        
        // CloudKitからデータを取得
        restoreProgress = 0.3
        let query = CKQuery(recordType: "Note", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await database.records(matching: query)
        
        // データをCore Dataに復元
        restoreProgress = 0.6
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await restoreNoteFromCloudRecord(record)
            case .failure(let error):
                print("Failed to fetch record: \(error)")
            }
        }
    }
    
    /// バックアップアーカイブを展開
    private func extractBackupArchive(_ backupURL: URL) async throws -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tempURL = documentsPath.appendingPathComponent("temp_restore")
        
        try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)
        
        // 実際のZIP展開処理は簡略化
        // 実際の実装ではZipArchiveライブラリなどを使用
        
        return tempURL
    }
    
    /// データベースを復元
    private func restoreDatabase(from tempURL: URL) async throws {
        let databaseURL = tempURL.appendingPathComponent("database_export.sqlite")
        
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            throw BackupError.databaseNotFound
        }
        
        // Core Dataストアを置き換え
        guard let context = context else { throw BackupError.databaseNotFound }
        let persistentStoreCoordinator = context.persistentStoreCoordinator
        let storeURL = persistentStoreCoordinator?.persistentStores.first?.url
        
        if let currentStoreURL = storeURL {
            try fileManager.removeItem(at: currentStoreURL)
        }
        
        try fileManager.copyItem(at: databaseURL, to: storeURL!)
    }
    
    /// アセットを復元
    private func restoreAssets(from tempURL: URL) async throws {
        let assetsURL = tempURL.appendingPathComponent("assets_export")
        
        guard fileManager.fileExists(atPath: assetsURL.path) else {
            return // アセットがない場合はスキップ
        }
        
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsPath.appendingPathComponent("assets")
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: assetsURL, to: destinationURL)
    }
    
    /// 設定を復元
    private func restoreSettings(from tempURL: URL) async throws {
        let settingsURL = tempURL.appendingPathComponent("settings_export.json")
        
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            return // 設定がない場合はスキップ
        }
        
        let data = try Data(contentsOf: settingsURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let settings = try decoder.decode(UserSettings.self, from: data)
        
        // 設定を復元
        UserDefaults.standard.set(settings.theme, forKey: "theme")
        UserDefaults.standard.set(settings.notifications, forKey: "notifications")
        UserDefaults.standard.set(settings.analysisEnabled, forKey: "analysisEnabled")
        UserDefaults.standard.set(settings.exportFormat, forKey: "exportFormat")
    }
    
    /// CloudKitレコードからノートを復元
    private func restoreNoteFromCloudRecord(_ record: CKRecord) async throws {
        guard let context = context else { throw BackupError.databaseNotFound }
        let note = Note(context: context)
        
        note.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        note.contentText = record["contentText"] as? String
        note.createdAt = record["createdAt"] as? Date ?? Date()
        note.updatedAt = record["updatedAt"] as? Date ?? Date()
        note.modality = record["modality"] as? String
        note.sentiment = record["sentiment"] as? Float ?? 0.0
        note.arousal = record["arousal"] as? Float ?? 0.0
        note.tags = record["tags"] as? String
        note.topicHash = record["topicHash"] as? String
        note.biasSignals = record["biasSignals"] as? String
        note.loopGroupID = record["loopGroupID"] as? String
        
        try context.save()
    }
    
    // MARK: - Backup Management
    
    /// 利用可能なバックアップを読み込み
    func loadAvailableBackups() async throws {
        // ローカルバックアップを読み込み
        let localBackups = try await loadLocalBackups()
        
        // クラウドバックアップを読み込み
        let cloudBackups = try await loadCloudBackups()
        
        await MainActor.run {
            availableBackups = localBackups + cloudBackups
        }
    }
    
    /// ローカルバックアップを読み込み
    private func loadLocalBackups() async throws -> [BackupInfo] {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let infoURL = documentsPath.appendingPathComponent("backup_info.json")
        
        guard fileManager.fileExists(atPath: infoURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: infoURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backupInfo = try decoder.decode(BackupInfo.self, from: data)
        
        return [backupInfo]
    }
    
    /// クラウドバックアップを読み込み
    private func loadCloudBackups() async throws -> [BackupInfo] {
        let database = cloudKitContainer.publicCloudDatabase
        let query = CKQuery(recordType: "BackupInfo", predicate: NSPredicate(value: true))
        
        let (matchResults, _) = try await database.records(matching: query)
        var backups: [BackupInfo] = []
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                let backupInfo = BackupInfo(
                    id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
                    name: record["name"] as? String ?? "Unknown",
                    date: record["date"] as? Date ?? Date(),
                    type: .cloud,
                    size: record["size"] as? Int ?? 0
                )
                backups.append(backupInfo)
            case .failure(let error):
                print("Failed to fetch backup info: \(error)")
            }
        }
        
        return backups
    }
    
    /// バックアップを削除
    func deleteBackup(_ backupInfo: BackupInfo) async throws {
        switch backupInfo.type {
        case .local:
            try await deleteLocalBackup(backupInfo)
        case .cloud:
            try await deleteCloudBackup(backupInfo)
        }
        
        await MainActor.run {
            availableBackups.removeAll { $0.id == backupInfo.id }
        }
    }
    
    /// ローカルバックアップを削除
    private func deleteLocalBackup(_ backupInfo: BackupInfo) async throws {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = documentsPath.appendingPathComponent("\(backupInfo.name).metawave")
        
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
    }
    
    /// クラウドバックアップを削除
    private func deleteCloudBackup(_ backupInfo: BackupInfo) async throws {
        let database = cloudKitContainer.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: backupInfo.id.uuidString)
        
        try await database.deleteRecord(withID: recordID)
    }
}

// MARK: - Data Models

struct BackupInfo: Codable, Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let type: BackupType
    let size: Int
    
    enum BackupType: String, Codable {
        case local = "local"
        case cloud = "cloud"
    }
}

struct UserSettings: Codable {
    let theme: String
    let notifications: Bool
    let analysisEnabled: Bool
    let exportFormat: String
}

// MARK: - Error Types

enum BackupError: LocalizedError {
    case creationFailed(Error)
    case restoreFailed(Error)
    case databaseNotFound
    case backupNotFound
    case archiveCreationFailed(Error)
    case cloudUploadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .creationFailed(let error):
            return "バックアップの作成に失敗しました: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "復元に失敗しました: \(error.localizedDescription)"
        case .databaseNotFound:
            return "データベースが見つかりません"
        case .backupNotFound:
            return "バックアップファイルが見つかりません"
        case .archiveCreationFailed(let error):
            return "アーカイブの作成に失敗しました: \(error.localizedDescription)"
        case .cloudUploadFailed(let error):
            return "クラウドアップロードに失敗しました: \(error.localizedDescription)"
        }
    }
}

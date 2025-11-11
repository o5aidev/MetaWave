//
//  BackupService.swift
//  MetaWave
//

import Foundation
import CoreData
import CloudKit
import Combine

struct BackupProgress: Identifiable {
    let id = UUID()
    let phase: String
    let value: Float
    let type: BackupInfo.BackupType
}

typealias BackupProgressHandler = (BackupProgress) -> Void

/// バックアップ・復元サービス
final class BackupService: ObservableObject {
    
    static let shared = BackupService()
    
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var backupProgress: Float = 0.0
    @Published var restoreProgress: Float = 0.0
    @Published var lastBackupDate: Date?
    @Published var availableBackups: [BackupInfo] = []
    
    private var context: NSManagedObjectContext?
    private let localStorage: BackupStorage
    private let cloudStorage: BackupStorage
    private let progressRelay = PassthroughSubject<BackupProgress, Never>()
    
    init(
        localStorage: BackupStorage = LocalBackupStorage(),
        cloudStorage: BackupStorage = CloudBackupStorage()
    ) {
        self.localStorage = localStorage
        self.cloudStorage = cloudStorage
    }
    
    func configure(context: NSManagedObjectContext) {
        self.context = context
        localStorage.configure(context: context)
        cloudStorage.configure(context: context)
    }
    
    func observeProgress() -> AnyPublisher<BackupProgress, Never> {
        progressRelay.eraseToAnyPublisher()
    }
    
    func createLocalBackup() async throws -> BackupInfo {
        guard context != nil else { throw BackupError.databaseNotFound }
        
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
        
        do {
            let backup = try await localStorage.createBackup(progress: progressHandler(type: .local, isRestore: false))
            await MainActor.run {
                lastBackupDate = backup.date
                updateAvailableBackups(with: backup)
            }
            return backup
        } catch {
            throw BackupError.creationFailed(error)
        }
    }
    
    func createCloudBackup() async throws -> BackupInfo {
        guard context != nil else { throw BackupError.databaseNotFound }
        
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
        
        do {
            let backup = try await cloudStorage.createBackup(progress: progressHandler(type: .cloud, isRestore: false))
            await MainActor.run {
                lastBackupDate = backup.date
                updateAvailableBackups(with: backup)
            }
            return backup
        } catch {
            throw BackupError.cloudUploadFailed(error)
        }
    }
    
    func restoreFromBackup(_ backup: BackupInfo) async throws {
        guard context != nil else { throw BackupError.databaseNotFound }
        
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
            let handler = progressHandler(type: backup.type, isRestore: true)
            switch backup.type {
            case .local:
                try await localStorage.restoreBackup(backup, progress: handler)
            case .cloud:
                try await cloudStorage.restoreBackup(backup, progress: handler)
            }
            await MainActor.run { restoreProgress = 1.0 }
        } catch {
            throw BackupError.restoreFailed(error)
        }
    }
    
    func loadAvailableBackups() async throws {
        let local = try await localStorage.loadBackups()
        let cloud = try await cloudStorage.loadBackups()
        await MainActor.run {
            availableBackups = (local + cloud).sorted(by: { $0.date > $1.date })
        }
    }
    
    func deleteBackup(_ backup: BackupInfo) async throws {
        switch backup.type {
        case .local: try await localStorage.deleteBackup(backup)
        case .cloud: try await cloudStorage.deleteBackup(backup)
        }
        await MainActor.run {
            availableBackups.removeAll { $0.id == backup.id }
        }
    }
    
    // MARK: - Helpers
    
    private func updateAvailableBackups(with backup: BackupInfo) {
        if let index = availableBackups.firstIndex(where: { $0.id == backup.id }) {
            availableBackups[index] = backup
        } else {
            availableBackups.append(backup)
        }
        availableBackups.sort(by: { $0.date > $1.date })
    }
    
    private func progressHandler(type: BackupInfo.BackupType, isRestore: Bool) -> BackupProgressHandler {
        { [weak self] progress in
            guard let self else { return }
            let normalized = min(max(progress.value, 0.0), 1.0)
            let payload = BackupProgress(phase: progress.phase, value: normalized, type: type)
            Task { @MainActor in
                if isRestore {
                    self.restoreProgress = normalized
                } else {
                    self.backupProgress = normalized
                }
            }
            self.progressRelay.send(payload)
        }
    }
}

// MARK: - Backup Storage Abstractions

protocol BackupStorage {
    func configure(context: NSManagedObjectContext)
    func createBackup(progress: BackupProgressHandler?) async throws -> BackupInfo
    func restoreBackup(_ backup: BackupInfo, progress: BackupProgressHandler?) async throws
    func loadBackups() async throws -> [BackupInfo]
    func deleteBackup(_ backup: BackupInfo) async throws
}

// MARK: - Local Backup Storage

final class LocalBackupStorage: BackupStorage {
    
    private var context: NSManagedObjectContext?
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private struct ArtifactURLs {
        let database: URL
        let assets: URL
        let settings: URL
        let archive: URL
    }
    
    func configure(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func createBackup(progress: BackupProgressHandler?) async throws -> BackupInfo {
        guard let context else { throw BackupError.databaseNotFound }
        let emit = emitter(for: .local, handler: progress)
        
        let info = BackupInfo(
            id: UUID(),
            name: "Backup_\(Date().formatted(.dateTime.year().month().day().hour().minute()))",
            date: Date(),
            type: .local,
            size: 0
        )
        
        let urls = try await prepareArtifacts(info: info, context: context, emit: emit)
        let archiveURL = urls.archive
        let attributes = try fileManager.attributesOfItem(atPath: archiveURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        let completedInfo = info.updatingSize(fileSize)
        
        try saveBackupInfo(completedInfo, archiveURL: archiveURL)
        emit("completed", 1.0)
        return completedInfo
    }
    
    func restoreBackup(_ backup: BackupInfo, progress: BackupProgressHandler?) async throws {
        guard let context else { throw BackupError.databaseNotFound }
        let emit = emitter(for: backup.type, handler: progress)
        let archiveURL = try backupArchiveURL(for: backup)
        emit("extract", 0.15)
        let tempURL = try extractArchive(at: archiveURL)
        defer { try? fileManager.removeItem(at: tempURL) }
        
        emit("restore_database", 0.35)
        try restoreDatabase(from: tempURL, context: context)
        emit("restore_assets", 0.55)
        try restoreAssets(from: tempURL)
        emit("restore_settings", 0.75)
        try restoreSettings(from: tempURL)
        emit("completed", 1.0)
    }
    
    func loadBackups() async throws -> [BackupInfo] {
        return try readStoredBackups()
    }
    
    func deleteBackup(_ backup: BackupInfo) async throws {
        let archiveURL = try backupArchiveURL(for: backup)
        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }
        
        var infos = try readStoredBackups()
        infos.removeAll { $0.id == backup.id }
        let data = try encoder.encode(infos)
        try data.write(to: backupInfoURL())
    }
    
    // MARK: - Artifact Helpers
    
    private func prepareArtifacts(info: BackupInfo, context: NSManagedObjectContext, emit: (String, Float) -> Void) async throws -> ArtifactURLs {
        emit("export_database", 0.1)
        let databaseURL = try exportDatabase(context: context)
        emit("export_assets", 0.3)
        let assetsURL = try exportAssets(context: context)
        emit("export_settings", 0.5)
        let settingsURL = try exportSettings()
        emit("archive", 0.7)
        let archiveURL = try createArchive(database: databaseURL, assets: assetsURL, settings: settingsURL, backup: info)
        return ArtifactURLs(database: databaseURL, assets: assetsURL, settings: settingsURL, archive: archiveURL)
    }
    
    private func exportDatabase(context: NSManagedObjectContext) throws -> URL {
        guard let storeURL = context.persistentStoreCoordinator?.persistentStores.first?.url else {
            throw BackupError.databaseNotFound
        }
        let exportURL = temporaryDirectory().appendingPathComponent("database_export.sqlite")
        if fileManager.fileExists(atPath: exportURL.path) {
            try fileManager.removeItem(at: exportURL)
        }
        try fileManager.copyItem(at: storeURL, to: exportURL)
        return exportURL
    }
    
    private func exportAssets(context: NSManagedObjectContext) throws -> URL {
        let assetsURL = temporaryDirectory().appendingPathComponent("assets_export")
        if fileManager.fileExists(atPath: assetsURL.path) {
            try fileManager.removeItem(at: assetsURL)
        }
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        
        let audioRequest: NSFetchRequest<Note> = Note.fetchRequest()
        audioRequest.predicate = NSPredicate(format: "audioURL != nil")
        let audioNotes = try context.fetch(audioRequest)
        for (index, note) in audioNotes.enumerated() {
            guard let audioURL = note.audioURL else { continue }
            let destination = assetsURL.appendingPathComponent("audio_\(index).m4a")
            try fileManager.copyItem(at: audioURL, to: destination)
        }
        
        let imageRequest: NSFetchRequest<Note> = Note.fetchRequest()
        imageRequest.predicate = NSPredicate(format: "imageURL != nil")
        let imageNotes = try context.fetch(imageRequest)
        for (index, note) in imageNotes.enumerated() {
            guard let imageURL = note.imageURL else { continue }
            let destination = assetsURL.appendingPathComponent("image_\(index).jpg")
            try fileManager.copyItem(at: imageURL, to: destination)
        }
        
        return assetsURL
    }
    
    private func exportSettings() throws -> URL {
        let settingsURL = temporaryDirectory().appendingPathComponent("settings_export.json")
        let settings = UserSettings(
            theme: UserDefaults.standard.string(forKey: "theme") ?? "system",
            notifications: UserDefaults.standard.bool(forKey: "notifications"),
            analysisEnabled: UserDefaults.standard.bool(forKey: "analysisEnabled"),
            exportFormat: UserDefaults.standard.string(forKey: "exportFormat") ?? "json"
        )
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL)
        return settingsURL
    }
    
    private func createArchive(database: URL, assets: URL, settings: URL, backup: BackupInfo) throws -> URL {
        let archiveURL = documentsDirectory().appendingPathComponent("\(backup.name).metawave")
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(writingItemAt: archiveURL, options: [], error: &error) { _ in
            // TODO: Integrate real ZIP archiver
        }
        if let error {
            throw BackupError.archiveCreationFailed(error)
        }
        return archiveURL
    }
    
    private func restoreDatabase(from tempURL: URL, context: NSManagedObjectContext) throws {
        let sourceURL = tempURL.appendingPathComponent("database_export.sqlite")
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw BackupError.databaseNotFound
        }
        if let destination = context.persistentStoreCoordinator?.persistentStores.first?.url {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceURL, to: destination)
        }
    }
    
    private func restoreAssets(from tempURL: URL) throws {
        let source = tempURL.appendingPathComponent("assets_export")
        guard fileManager.fileExists(atPath: source.path) else { return }
        let destination = documentsDirectory().appendingPathComponent("assets")
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }
    
    private func restoreSettings(from tempURL: URL) throws {
        let source = tempURL.appendingPathComponent("settings_export.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        let data = try Data(contentsOf: source)
        let settings = try decoder.decode(UserSettings.self, from: data)
        UserDefaults.standard.set(settings.theme, forKey: "theme")
        UserDefaults.standard.set(settings.notifications, forKey: "notifications")
        UserDefaults.standard.set(settings.analysisEnabled, forKey: "analysisEnabled")
        UserDefaults.standard.set(settings.exportFormat, forKey: "exportFormat")
    }
    
    private func extractArchive(at url: URL) throws -> URL {
        let temp = temporaryDirectory().appendingPathComponent("restore_temp_\(UUID().uuidString)")
        try fileManager.createDirectory(at: temp, withIntermediateDirectories: true)
        // TODO: unzip real archive
        return temp
    }
    
    private func saveBackupInfo(_ info: BackupInfo, archiveURL: URL) throws {
        var infos = try (loadBackups())
        infos.removeAll { $0.id == info.id }
        var updated = infos
        updated.append(info)
        let data = try encoder.encode(updated)
        try data.write(to: backupInfoURL())
    }
    
    private func backupArchiveURL(for info: BackupInfo) throws -> URL {
        let url = documentsDirectory().appendingPathComponent("\(info.name).metawave")
        guard fileManager.fileExists(atPath: url.path) else {
            throw BackupError.backupNotFound
        }
        return url
    }
    
    private func backupInfoURL() -> URL {
        documentsDirectory().appendingPathComponent("backup_info.json")
    }
    
    private func documentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func temporaryDirectory() -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent("MetaWaveBackup", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    private func emitter(for type: BackupInfo.BackupType, handler: BackupProgressHandler?) -> (String, Float) -> Void {
        return { phase, value in
            handler?(BackupProgress(phase: phase, value: value, type: type))
        }
    }
    
    private func readStoredBackups() throws -> [BackupInfo] {
        let url = backupInfoURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try decoder.decode([BackupInfo].self, from: data)
    }
}

// MARK: - Cloud Backup Storage

final class CloudBackupStorage: BackupStorage {
    
    private var context: NSManagedObjectContext?
    private let container = CKContainer(identifier: "iCloud.com.vibe5.MetaWave")
    
    func configure(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func createBackup(progress: BackupProgressHandler?) async throws -> BackupInfo {
        guard let context else { throw BackupError.databaseNotFound }
        let emit = emitter(for: .cloud, handler: progress)
        emit("prepare", 0.1)
        
        let info = BackupInfo(
            id: UUID(),
            name: "iCloud_Backup_\(Date().formatted(.dateTime.year().month().day().hour().minute()))",
            date: Date(),
            type: .cloud,
            size: 0
        )
        
        emit("upload_records", 0.4)
        try await uploadNotes(context: context)
        
        emit("store_metadata", 0.7)
        try await storeBackupInfo(info)
        
        emit("completed", 1.0)
        return info
    }
    
    func restoreBackup(_ backup: BackupInfo, progress: BackupProgressHandler?) async throws {
        guard let context else { throw BackupError.databaseNotFound }
        let emit = emitter(for: .cloud, handler: progress)
        
        emit("fetch_records", 0.3)
        let records = try await fetchNoteRecords()
        emit("restore_records", 0.6)
        try await restoreNotes(from: records, context: context)
        emit("completed", 1.0)
    }
    
    func loadBackups() async throws -> [BackupInfo] {
        let database = container.publicCloudDatabase
        let query = CKQuery(recordType: "BackupInfo", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await database.records(matching: query)
        return matchResults.compactMap { (_, result) -> BackupInfo? in
            guard case .success(let record) = result else { return nil }
            return BackupInfo(
                    id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
                name: record["name"] as? String ?? "iCloud Backup",
                    date: record["date"] as? Date ?? Date(),
                    type: .cloud,
                    size: record["size"] as? Int ?? 0
                )
        }
    }
    
    func deleteBackup(_ backup: BackupInfo) async throws {
        let database = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: backup.id.uuidString)
        try await database.deleteRecord(withID: recordID)
    }
    
    private func uploadNotes(context: NSManagedObjectContext) async throws {
        let database = container.publicCloudDatabase
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try context.fetch(request)
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
            _ = try await database.save(record)
        }
    }
    
    private func storeBackupInfo(_ info: BackupInfo) async throws {
        let database = container.publicCloudDatabase
        let record = CKRecord(recordType: "BackupInfo", recordID: CKRecord.ID(recordName: info.id.uuidString))
        record["name"] = info.name
        record["date"] = info.date
        record["type"] = info.type.rawValue
        record["size"] = info.size
        _ = try await database.save(record)
    }
    
    private func fetchNoteRecords() async throws -> [CKRecord] {
        let database = container.publicCloudDatabase
        let query = CKQuery(recordType: "Note", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await database.records(matching: query)
        return matchResults.compactMap { (_, result) -> CKRecord? in
            guard case .success(let record) = result else { return nil }
            return record
        }
    }
    
    private func restoreNotes(from records: [CKRecord], context: NSManagedObjectContext) async throws {
        for record in records {
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
        }
        try context.save()
    }
    
    private func emitter(for type: BackupInfo.BackupType, handler: BackupProgressHandler?) -> (String, Float) -> Void {
        { phase, value in
            handler?(BackupProgress(phase: phase, value: value, type: type))
        }
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
    
    func updatingSize(_ size: Int) -> BackupInfo {
        BackupInfo(id: id, name: name, date: date, type: type, size: size)
    }
}

struct UserSettings: Codable {
    let theme: String
    let notifications: Bool
    let analysisEnabled: Bool
    let exportFormat: String
}

// MARK: - Errors

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

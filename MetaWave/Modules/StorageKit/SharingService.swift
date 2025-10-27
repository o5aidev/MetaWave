import Foundation
import CoreData
import CryptoKit
import UIKit

// MARK: - 共有ノート
struct SharedNote {
    let id: UUID
    let title: String
    let content: String
    let sharedBy: String
    let sharedAt: Date
    let permissions: SharingPermissions
    let encryptionKey: Data
}

// MARK: - 共有権限
struct SharingPermissions {
    let canRead: Bool
    let canWrite: Bool
    let canShare: Bool
    let expiresAt: Date?
}

// MARK: - 共有エラー
enum SharingError: Error, LocalizedError {
    case encryptionFailed
    case keyGenerationFailed
    case sharingFailed(String)
    case permissionDenied
    case noteNotFound
    case invalidShareKey
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "暗号化に失敗しました"
        case .keyGenerationFailed:
            return "共有キーの生成に失敗しました"
        case .sharingFailed(let message):
            return "共有に失敗しました: \(message)"
        case .permissionDenied:
            return "共有権限がありません"
        case .noteNotFound:
            return "ノートが見つかりません"
        case .invalidShareKey:
            return "無効な共有キーです"
        }
    }
}

// MARK: - 共有サービスプロトコル
protocol SharingServiceProtocol {
    func shareNote(_ noteId: UUID, with permissions: SharingPermissions) async throws -> ShareInfo
    func joinSharedNote(_ shareKey: String) async throws -> SharedNote
    func updateSharedNote(_ noteId: UUID, content: String) async throws
    func revokeShare(_ noteId: UUID) async throws
    func getSharedNotes() async throws -> [SharedNote]
    func getShareInfo(_ noteId: UUID) async throws -> ShareInfo
}

// MARK: - 共有情報
struct ShareInfo {
    let shareKey: String
    let qrCode: UIImage
    let shareUrl: URL
    let expiresAt: Date?
}

// MARK: - E2E共有サービス実装
@MainActor
final class SharingService: SharingServiceProtocol {
    
    // MARK: - プロパティ
    private let persistentContainer: NSPersistentContainer
    private let vault: Vaulting
    private let cloudSyncService: CloudSyncServiceProtocol
    
    // 共有ノートのキャッシュ
    private var sharedNotesCache: [UUID: SharedNote] = [:]
    
    // MARK: - 初期化
    init(persistentContainer: NSPersistentContainer, vault: Vaulting, cloudSyncService: CloudSyncServiceProtocol) {
        self.persistentContainer = persistentContainer
        self.vault = vault
        self.cloudSyncService = cloudSyncService
    }
    
    // MARK: - ノートの共有
    func shareNote(_ noteId: UUID, with permissions: SharingPermissions) async throws -> ShareInfo {
        // ノートの取得
        guard let note = try await getNote(by: noteId) else {
            throw SharingError.noteNotFound
        }
        
        // 共有キーの生成
        let shareKey = try generateShareKey()
        
        // 暗号化キーの生成
        let encryptionKey = try generateEncryptionKey()
        
        // ノートの暗号化
        let encryptedContent = try encryptNoteContent(note, with: encryptionKey)
        
        // 共有ノートの作成
        let sharedNote = SharedNote(
            id: noteId,
            title: note.title ?? "共有ノート",
            content: encryptedContent,
            sharedBy: getCurrentUser(),
            sharedAt: Date(),
            permissions: permissions,
            encryptionKey: encryptionKey
        )
        
        // 共有ノートの保存
        try await saveSharedNote(sharedNote, shareKey: shareKey)
        
        // 共有情報の生成
        let shareInfo = try await generateShareInfo(shareKey: shareKey, sharedNote: sharedNote)
        
        return shareInfo
    }
    
    // MARK: - 共有ノートへの参加
    func joinSharedNote(_ shareKey: String) async throws -> SharedNote {
        // 共有キーの検証
        guard isValidShareKey(shareKey) else {
            throw SharingError.invalidShareKey
        }
        
        // 共有ノートの取得
        guard let sharedNote = try await getSharedNote(by: shareKey) else {
            throw SharingError.noteNotFound
        }
        
        // 権限の確認
        guard hasPermissionToAccess(sharedNote) else {
            throw SharingError.permissionDenied
        }
        
        // 共有ノートの復号化
        let decryptedNote = try decryptSharedNote(sharedNote)
        
        // 共有ノートのキャッシュに追加
        sharedNotesCache[sharedNote.id] = decryptedNote
        
        return decryptedNote
    }
    
    // MARK: - 共有ノートの更新
    func updateSharedNote(_ noteId: UUID, content: String) async throws {
        // 共有ノートの取得
        guard let sharedNote = sharedNotesCache[noteId] else {
            throw SharingError.noteNotFound
        }
        
        // 書き込み権限の確認
        guard sharedNote.permissions.canWrite else {
            throw SharingError.permissionDenied
        }
        
        // 内容の暗号化
        let encryptedContent = try encryptContent(content, with: sharedNote.encryptionKey)
        
        // 更新された共有ノートの作成
        let updatedSharedNote = SharedNote(
            id: sharedNote.id,
            title: sharedNote.title,
            content: encryptedContent,
            sharedBy: sharedNote.sharedBy,
            sharedAt: sharedNote.sharedAt,
            permissions: sharedNote.permissions,
            encryptionKey: sharedNote.encryptionKey
        )
        
        // 共有ノートの更新
        try await updateSharedNoteInDatabase(updatedSharedNote)
        
        // キャッシュの更新
        sharedNotesCache[noteId] = updatedSharedNote
        
        // クラウド同期
        try await cloudSyncService.forceSync()
    }
    
    // MARK: - 共有の取り消し
    func revokeShare(_ noteId: UUID) async throws {
        // 共有ノートの削除
        try await deleteSharedNote(noteId)
        
        // キャッシュからの削除
        sharedNotesCache.removeValue(forKey: noteId)
        
        // クラウド同期
        try await cloudSyncService.forceSync()
    }
    
    // MARK: - 共有ノートの一覧取得
    func getSharedNotes() async throws -> [SharedNote] {
        // データベースから共有ノートを取得
        let sharedNotes = try await fetchSharedNotesFromDatabase()
        
        // キャッシュの更新
        for sharedNote in sharedNotes {
            sharedNotesCache[sharedNote.id] = sharedNote
        }
        
        return sharedNotes
    }
    
    // MARK: - 共有情報の取得
    func getShareInfo(_ noteId: UUID) async throws -> ShareInfo {
        // 共有キーの取得
        guard let shareKey = try await getShareKey(for: noteId) else {
            throw SharingError.noteNotFound
        }
        
        // 共有ノートの取得
        guard let sharedNote = sharedNotesCache[noteId] else {
            throw SharingError.noteNotFound
        }
        
        // 共有情報の生成
        return try await generateShareInfo(shareKey: shareKey, sharedNote: sharedNote)
    }
    
    // MARK: - ノートの取得
    private func getNote(by id: UUID) async throws -> NSManagedObject? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let results = try context.fetch(request)
        return results.first
    }
    
    // MARK: - 共有キーの生成
    private func generateShareKey() throws -> String {
        // 安全な共有キーの生成
        let keyData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return keyData.base64EncodedString()
    }
    
    // MARK: - 暗号化キーの生成
    private func generateEncryptionKey() throws -> Data {
        // 共有用の暗号化キーの生成
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }
    
    // MARK: - ノート内容の暗号化
    private func encryptNoteContent(_ note: NSManagedObject, with key: Data) throws -> String {
        // ノートの内容を取得
        let content = note.value(forKey: "contentText") as? String ?? ""
        
        // 内容の暗号化
        let contentData = content.data(using: .utf8) ?? Data()
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(contentData, using: symmetricKey)
        
        // 暗号化されたデータのエンコード
        let encryptedData = sealedBox.combined ?? Data()
        return encryptedData.base64EncodedString()
    }
    
    // MARK: - 内容の暗号化
    private func encryptContent(_ content: String, with key: Data) throws -> String {
        let contentData = content.data(using: .utf8) ?? Data()
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(contentData, using: symmetricKey)
        
        let encryptedData = sealedBox.combined ?? Data()
        return encryptedData.base64EncodedString()
    }
    
    // MARK: - 共有ノートの保存
    private func saveSharedNote(_ sharedNote: SharedNote, shareKey: String) async throws {
        let context = persistentContainer.viewContext
        
        // 共有ノートエンティティの作成
        let sharedNoteEntity = NSEntityDescription.entity(forEntityName: "SharedNote", in: context)!
        let sharedNoteObject = NSManagedObject(entity: sharedNoteEntity, insertInto: context)
        
        // 属性の設定
        sharedNoteObject.setValue(sharedNote.id, forKey: "id")
        sharedNoteObject.setValue(sharedNote.title, forKey: "title")
        sharedNoteObject.setValue(sharedNote.content, forKey: "content")
        sharedNoteObject.setValue(sharedNote.sharedBy, forKey: "sharedBy")
        sharedNoteObject.setValue(sharedNote.sharedAt, forKey: "sharedAt")
        sharedNoteObject.setValue(sharedNote.encryptionKey, forKey: "encryptionKey")
        sharedNoteObject.setValue(shareKey, forKey: "shareKey")
        
        // 権限の設定
        let permissionsData = try JSONEncoder().encode(sharedNote.permissions)
        sharedNoteObject.setValue(permissionsData, forKey: "permissions")
        
        // 保存
        try context.save()
    }
    
    // MARK: - 共有情報の生成
    private func generateShareInfo(shareKey: String, sharedNote: SharedNote) async throws -> ShareInfo {
        // QRコードの生成
        let qrCode = try generateQRCode(for: shareKey)
        
        // 共有URLの生成
        let shareUrl = try generateShareUrl(for: shareKey)
        
        return ShareInfo(
            shareKey: shareKey,
            qrCode: qrCode,
            shareUrl: shareUrl,
            expiresAt: sharedNote.permissions.expiresAt
        )
    }
    
    // MARK: - QRコードの生成
    private func generateQRCode(for shareKey: String) throws -> UIImage {
        // QRコードの生成
        let data = shareKey.data(using: .utf8)!
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(data, forKey: "inputMessage")
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let output = filter.outputImage!.transformed(by: transform)
        
        let context = CIContext()
        let cgImage = context.createCGImage(output, from: output.extent)!
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - 共有URLの生成
    private func generateShareUrl(for shareKey: String) throws -> URL {
        // 共有URLの生成
        let baseUrl = "https://metawave.app/share"
        let urlString = "\(baseUrl)?key=\(shareKey)"
        
        guard let url = URL(string: urlString) else {
            throw SharingError.sharingFailed("無効なURL")
        }
        
        return url
    }
    
    // MARK: - 共有キーの検証
    private func isValidShareKey(_ shareKey: String) -> Bool {
        // 共有キーの形式検証
        return shareKey.count >= 32 && shareKey.count <= 64
    }
    
    // MARK: - 共有ノートの取得
    private func getSharedNote(by shareKey: String) async throws -> SharedNote? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "SharedNote")
        request.predicate = NSPredicate(format: "shareKey == %@", shareKey)
        
        let results = try context.fetch(request)
        guard let sharedNoteObject = results.first else {
            return nil
        }
        
        // 共有ノートオブジェクトの作成
        return try createSharedNote(from: sharedNoteObject)
    }
    
    // MARK: - 共有ノートオブジェクトの作成
    private func createSharedNote(from object: NSManagedObject) throws -> SharedNote {
        let id = object.value(forKey: "id") as! UUID
        let title = object.value(forKey: "title") as! String
        let content = object.value(forKey: "content") as! String
        let sharedBy = object.value(forKey: "sharedBy") as! String
        let sharedAt = object.value(forKey: "sharedAt") as! Date
        let encryptionKey = object.value(forKey: "encryptionKey") as! Data
        
        let permissionsData = object.value(forKey: "permissions") as! Data
        let permissions = try JSONDecoder().decode(SharingPermissions.self, from: permissionsData)
        
        return SharedNote(
            id: id,
            title: title,
            content: content,
            sharedBy: sharedBy,
            sharedAt: sharedAt,
            permissions: permissions,
            encryptionKey: encryptionKey
        )
    }
    
    // MARK: - アクセス権限の確認
    private func hasPermissionToAccess(_ sharedNote: SharedNote) -> Bool {
        // 期限の確認
        if let expiresAt = sharedNote.permissions.expiresAt {
            if Date() > expiresAt {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - 共有ノートの復号化
    private func decryptSharedNote(_ sharedNote: SharedNote) throws -> SharedNote {
        // 暗号化された内容の復号化
        let encryptedData = Data(base64Encoded: sharedNote.content) ?? Data()
        let symmetricKey = SymmetricKey(data: sharedNote.encryptionKey)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        let decryptedContent = String(data: decryptedData, encoding: .utf8) ?? ""
        
        // 復号化された共有ノートの作成
        return SharedNote(
            id: sharedNote.id,
            title: sharedNote.title,
            content: decryptedContent,
            sharedBy: sharedNote.sharedBy,
            sharedAt: sharedNote.sharedAt,
            permissions: sharedNote.permissions,
            encryptionKey: sharedNote.encryptionKey
        )
    }
    
    // MARK: - 現在のユーザー取得
    private func getCurrentUser() -> String {
        // 現在のユーザーIDの取得
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
    
    // MARK: - データベースから共有ノートを取得
    private func fetchSharedNotesFromDatabase() async throws -> [SharedNote] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "SharedNote")
        
        let results = try context.fetch(request)
        return try results.map { try createSharedNote(from: $0) }
    }
    
    // MARK: - 共有キーの取得
    private func getShareKey(for noteId: UUID) async throws -> String? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "SharedNote")
        request.predicate = NSPredicate(format: "id == %@", noteId as CVarArg)
        
        let results = try context.fetch(request)
        return results.first?.value(forKey: "shareKey") as? String
    }
    
    // MARK: - 共有ノートの更新
    private func updateSharedNoteInDatabase(_ sharedNote: SharedNote) async throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "SharedNote")
        request.predicate = NSPredicate(format: "id == %@", sharedNote.id as CVarArg)
        
        let results = try context.fetch(request)
        guard let sharedNoteObject = results.first else {
            throw SharingError.noteNotFound
        }
        
        // 属性の更新
        sharedNoteObject.setValue(sharedNote.content, forKey: "content")
        
        // 保存
        try context.save()
    }
    
    // MARK: - 共有ノートの削除
    private func deleteSharedNote(_ noteId: UUID) async throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "SharedNote")
        request.predicate = NSPredicate(format: "id == %@", noteId as CVarArg)
        
        let results = try context.fetch(request)
        for result in results {
            context.delete(result)
        }
        
        try context.save()
    }
}

// MARK: - SharingPermissions の Codable 対応
extension SharingPermissions: Codable {}

// MARK: - 共有サービスの拡張
extension SharingService {
    
    // MARK: - 共有統計の取得
    func getSharingStatistics() -> SharingStatistics {
        return SharingStatistics(
            totalSharedNotes: sharedNotesCache.count,
            activeShares: sharedNotesCache.filter { $0.value.permissions.expiresAt == nil || $0.value.permissions.expiresAt! > Date() }.count,
            expiredShares: sharedNotesCache.filter { $0.value.permissions.expiresAt != nil && $0.value.permissions.expiresAt! <= Date() }.count
        )
    }
}

// MARK: - 共有統計
struct SharingStatistics {
    let totalSharedNotes: Int
    let activeShares: Int
    let expiredShares: Int
}

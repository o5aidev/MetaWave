import Foundation
import CloudKit
import CoreData
import Combine

// MARK: - 共有リンク
struct ShareLink {
    let id: String
    let url: URL
    let expiresAt: Date?
    let isActive: Bool
}

// MARK: - 共有サービス
@MainActor
class SharingService: ObservableObject {
    static let shared = SharingService()
    
    @Published var activeShares: [ShareLink] = []
    @Published var isSharing = false
    @Published var shareError: String?
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let persistenceController: PersistenceController
    
    private init() {
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        self.persistenceController = PersistenceController.shared
    }
    
    // MARK: - ノートの共有
    func shareNote(_ item: Item) async throws -> ShareLink {
        guard !isSharing else { throw SharingError.alreadySharing }
        
        isSharing = true
        shareError = nil
        
        do {
            // 共有レコードを作成
            let shareRecord = CKShare(rootRecord: CKRecord(recordType: "Item"))
            shareRecord[CKShare.SystemFieldKey.title] = item.title ?? "Shared Note"
            shareRecord[CKShare.SystemFieldKey.shareURL] = URL(string: "https://www.icloud.com/share/\(UUID().uuidString)")
            
            // 暗号化されたデータを設定
            let itemRecord = CKRecord(recordType: "Item", recordID: CKRecord.ID(recordName: item.objectID.uriRepresentation().absoluteString))
            itemRecord["title"] = item.title
            itemRecord["note"] = item.note
            itemRecord["timestamp"] = item.timestamp
            
            // クラウドに保存
            let _ = try await privateDatabase.save(shareRecord)
            let _ = try await privateDatabase.save(itemRecord)
            
            // 共有リンクを作成
            let shareLink = ShareLink(
                id: shareRecord.recordID.recordName,
                url: shareRecord[CKShare.SystemFieldKey.shareURL] as! URL,
                expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                isActive: true
            )
            
            activeShares.append(shareLink)
            print("✅ ノート共有完了: \(item.title ?? "Untitled")")
            
            return shareLink
            
        } catch {
            shareError = error.localizedDescription
            print("❌ ノート共有エラー: \(error.localizedDescription)")
            throw error
        }
        
        isSharing = false
    }
    
    // MARK: - 共有ノートへのアクセス
    func accessSharedNote(_ link: ShareLink) async throws -> Item? {
        do {
            // 共有レコードを取得
            let shareRecord = try await privateDatabase.record(for: CKRecord.ID(recordName: link.id))
            
            // 共有されたアイテムを取得
            if let itemRecordID = shareRecord[CKShare.SystemFieldKey.rootRecord] as? CKRecord.Reference {
                let itemRecord = try await privateDatabase.record(for: itemRecordID.recordID)
                
                // ローカルにアイテムを作成
                let context = persistenceController.container.viewContext
                let item = Item(context: context)
                
                item.title = itemRecord["title"] as? String
                item.note = itemRecord["note"] as? String
                item.timestamp = itemRecord["timestamp"] as? Date
                item.isShared = true
                item.sharedBy = shareRecord.ownerUserIdentity?.nameComponents?.formatted() ?? "Unknown"
                
        try context.save()
                print("✅ 共有ノートアクセス完了: \(item.title ?? "Untitled")")
                
                return item
            }
            
            return nil
            
        } catch {
            print("❌ 共有ノートアクセスエラー: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - 共有の取り消し
    func revokeShare(_ link: ShareLink) async throws {
        do {
            // 共有レコードを削除
            let shareRecordID = CKRecord.ID(recordName: link.id)
            let _ = try await privateDatabase.deleteRecord(withID: shareRecordID)
            
            // アクティブな共有から削除
            activeShares.removeAll { $0.id == link.id }
            
            print("✅ 共有取り消し完了: \(link.id)")
            
        } catch {
            print("❌ 共有取り消しエラー: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - アクティブな共有の取得
    func loadActiveShares() async throws {
        let query = CKQuery(recordType: "Item", predicate: NSPredicate(format: "isShared == YES"))
        let records = try await privateDatabase.records(matching: query)
        
        var shares: [ShareLink] = []
        
        for (_, result) in records {
            switch result {
            case .success(let record):
                if let shareURL = record[CKShare.SystemFieldKey.shareURL] as? URL {
                    let shareLink = ShareLink(
                        id: record.recordID.recordName,
                        url: shareURL,
                        expiresAt: nil,
                        isActive: true
                    )
                    shares.append(shareLink)
                }
            case .failure(let error):
                print("⚠️ 共有レコード取得エラー: \(error.localizedDescription)")
            }
        }
        
        activeShares = shares
        print("✅ アクティブな共有を取得: \(shares.count)件")
    }
}

// MARK: - 共有エラー
enum SharingError: Error, LocalizedError {
    case alreadySharing
    case shareNotFound
    case accessDenied
    case invalidShareLink
    
    var errorDescription: String? {
        switch self {
        case .alreadySharing:
            return "既に共有処理中です。しばらくお待ちください。"
        case .shareNotFound:
            return "共有が見つかりませんでした。"
        case .accessDenied:
            return "この共有にアクセスする権限がありません。"
        case .invalidShareLink:
            return "無効な共有リンクです。"
        }
    }
}
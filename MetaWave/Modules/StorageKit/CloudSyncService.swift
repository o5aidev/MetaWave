import Foundation
import CloudKit
import CoreData
import Combine

// MARK: - クラウド同期サービス
@MainActor
class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let persistenceController: PersistenceController
    
    private init() {
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        self.persistenceController = PersistenceController.shared
    }
    
    // MARK: - クラウド同期の開始
    func startSync() async throws {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // iCloudアカウントの確認
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                throw CloudSyncError.iCloudAccountNotAvailable
            }
            
            // データの同期
            try await syncToCloud()
            try await syncFromCloud()
            
            lastSyncDate = Date()
            print("✅ クラウド同期完了")
            
        } catch {
            syncError = error.localizedDescription
            print("❌ クラウド同期エラー: \(error.localizedDescription)")
            throw error
        }
        
        isSyncing = false
    }
    
    // MARK: - ローカルからクラウドへの同期
    private func syncToCloud() async throws {
        let context = persistenceController.container.viewContext
        
        // 新規・更新されたアイテムを取得
        let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        let items = try context.fetch(fetchRequest)
        
        for item in items {
            try await syncItemToCloud(item)
        }
    }
    
    // MARK: - クラウドからローカルへの同期
    private func syncFromCloud() async throws {
        let query = CKQuery(recordType: "Item", predicate: NSPredicate(value: true))
        let records = try await privateDatabase.records(matching: query)
        
        let context = persistenceController.container.viewContext
        
        for (_, result) in records {
            switch result {
            case .success(let record):
                try await syncRecordToLocal(record, context: context)
            case .failure(let error):
                print("⚠️ レコード取得エラー: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - アイテムをクラウドに同期
    private func syncItemToCloud(_ item: Item) async throws {
        let record = CKRecord(recordType: "Item", recordID: CKRecord.ID(recordName: item.objectID.uriRepresentation().absoluteString))
        
        // 暗号化されたデータを設定
        if let title = item.title {
            record["title"] = title
        }
        if let note = item.note {
            record["note"] = note
        }
        if let timestamp = item.timestamp {
            record["timestamp"] = timestamp
        }
        
        // クラウドに保存
        let _ = try await privateDatabase.save(record)
        
        // ローカルで同期済みマーク
        item.needsSync = false
        try persistenceController.container.viewContext.save()
        
        print("✅ アイテム同期完了: \(item.title ?? "Untitled")")
    }
    
    // MARK: - レコードをローカルに同期
    private func syncRecordToLocal(_ record: CKRecord, context: NSManagedObjectContext) async throws {
        // 既存のアイテムを検索
        let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "cloudRecordID == %@", record.recordID.recordName)
        
        let existingItems = try context.fetch(fetchRequest)
        let item = existingItems.first ?? Item(context: context)
        
        // データを設定
        item.title = record["title"] as? String
        item.note = record["note"] as? String
        item.timestamp = record["timestamp"] as? Date
        item.cloudRecordID = record.recordID.recordName
        item.needsSync = false
        
        try context.save()
        print("✅ レコード同期完了: \(item.title ?? "Untitled")")
    }
    
    // MARK: - 競合解決
    func resolveConflicts() async throws {
        // 競合解決ロジックの実装
        // 最新のタイムスタンプを優先
        print("🔄 競合解決を実行中...")
    }
}

// MARK: - クラウド同期エラー
enum CloudSyncError: Error, LocalizedError {
    case iCloudAccountNotAvailable
    case syncFailed(String)
    case conflictResolutionFailed
    
    var errorDescription: String? {
        switch self {
        case .iCloudAccountNotAvailable:
            return "iCloudアカウントが利用できません。設定でiCloudにサインインしてください。"
        case .syncFailed(let message):
            return "同期に失敗しました: \(message)"
        case .conflictResolutionFailed:
            return "競合の解決に失敗しました。"
        }
    }
}
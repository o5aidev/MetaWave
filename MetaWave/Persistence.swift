//
//  Persistence.swift
//  MetaWave
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    /// プレビュー用（メモリ上にダミーデータを投入）
    static var preview: PersistenceController = {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        for i in 0..<5 {
            let item = Item(context: ctx)
            item.timestamp = Date().addingTimeInterval(TimeInterval(-i * 3600))
            item.title = "Sample \(i + 1)"
            item.note  = "Preview data"
        }
        try? ctx.save()
        return c
    }()

    // ▼ ローカル保存のみ（CloudKit無効）
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // モデル名を MetaWave に統一
        let container = NSPersistentContainer(name: "MetaWave")

        // --- 安全ガード：記述が無い場合に空の記述を設定 ---
        if container.persistentStoreDescriptions.isEmpty {
            container.persistentStoreDescriptions = [NSPersistentStoreDescription()]
        }

        // メモリストア（プレビュー/ユニットテスト用）
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // 軽量マイグレーション
        if let desc = container.persistentStoreDescriptions.first {
            desc.shouldMigrateStoreAutomatically = true
            desc.shouldInferMappingModelAutomatically = true
        }

        // ストアをロード
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        // コンテキスト設定
        let ctx = container.viewContext
        ctx.automaticallyMergesChangesFromParent = true
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // パフォーマンス最適化
        ctx.stalenessInterval = 0.0 // 常に最新データ
        ctx.undoManager = nil // メモリ節約

        self.container = container
    }

    // 背景保存用の新規コンテキスト（必要なときに使用）
    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.undoManager = nil // バックグラウンド処理では不要
        return ctx
    }
    
    // MARK: - バッチフェッチの最適化
    func fetchItemsWithLimit(_ limit: Int = 50) -> NSFetchRequest<Item> {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.fetchLimit = limit
        request.fetchBatchSize = 20
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)]
        return request
    }
}

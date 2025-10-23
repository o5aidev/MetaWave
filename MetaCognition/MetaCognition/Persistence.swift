import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let ctx = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: ctx)
            newItem.timestamp = Date()
            newItem.title = "Sample"
            newItem.note  = "Preview"
        }
        try? ctx.save()
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // ★ .xcdatamodeld と一致させる
        container = NSPersistentContainer(name: "MetaCognition")

        // 安全ガード：デフォルト記述が無い場合は作る
        if container.persistentStoreDescriptions.isEmpty {
            container.persistentStoreDescriptions = [NSPersistentStoreDescription()]
        }

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // 軽量マイグレーション
        let desc = container.persistentStoreDescriptions.first!
        desc.shouldMigrateStoreAutomatically = true
        desc.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        let ctx = container.viewContext
        ctx.automaticallyMergesChangesFromParent = true
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

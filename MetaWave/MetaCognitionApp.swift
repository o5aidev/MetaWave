//
//  MetaCognitionApp.swift
//  MetaCognition
//
//  Created by 渡部一生 on 2025/10/21.
//

import SwiftUI
import CoreData

@main
struct MetaCognitionApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        // ① 旧フォーマットの包み鍵があれば iCloud 同期属性つきに移行
        migrateWrappedKeyToSynchronizableIfNeeded()
        // ② Vault 用のマスターキーを生成/読込（Keychainに保存・再利用）
        _ = try? Vault.generateOrLoadVaultKey()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

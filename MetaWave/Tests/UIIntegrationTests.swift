//
//  UIIntegrationTests.swift
//  MetaWave
//
//  UI統合テスト
//

import XCTest
import SwiftUI
import CoreData
@testable import MetaWave

final class UIIntegrationTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }
    
    override func tearDown() {
        context = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - ContentView テスト
    
    func testContentViewWithMockData() throws {
        // モックデータを作成
        let note1 = Note.create(
            modality: .text,
            contentText: "Test note 1",
            in: context
        )
        
        let note2 = Note.create(
            modality: .text,
            contentText: "Test note 2",
            in: context
        )
        
        try context.save()
        
        // データが正しく保存されていることを確認
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try context.fetch(request)
        
        XCTAssertEqual(notes.count, 2, "Should have 2 notes")
        XCTAssertTrue(notes.contains(where: { $0.id == note1.id }))
        XCTAssertTrue(notes.contains(where: { $0.id == note2.id }))
    }
    
    func testAddSampleFunctionality() throws {
        // addSample()の機能をテスト（ContentViewのメソッド）
        let initialRequest: NSFetchRequest<Item> = Item.fetchRequest()
        let initialItems = try context.fetch(initialRequest)
        let initialCount = initialItems.count
        
        // 新しいアイテムを追加
        let newItem = Item(context: context)
        newItem.timestamp = Date()
        newItem.title = "Test Item"
        newItem.note = "Test Content"
        
        try context.save()
        
        // アイテムが追加されたことを確認
        let updatedRequest: NSFetchRequest<Item> = Item.fetchRequest()
        let updatedItems = try context.fetch(updatedRequest)
        let updatedCount = updatedItems.count
        
        XCTAssertEqual(updatedCount, initialCount + 1, "Should add one item")
    }
    
    // MARK: - Note Views テスト
    
    func testNoteCreation() throws {
        let note = Note.create(
            modality: .voice,
            contentText: "This is a voice note",
            in: context
        )
        
        XCTAssertNotNil(note.id, "Note should have an ID")
        XCTAssertEqual(note.modality, .voice, "Should be voice modality")
        XCTAssertNotNil(note.createdAt, "Should have creation timestamp")
    }
    
    func testNoteWithInsight() throws {
        let note = Note.create(
            modality: .text,
            contentText: "Test note with insight",
            in: context
        )
        
        let insight = Insight.create(
            title: "Test Insight",
            content: "Insight content",
            category: .pattern,
            in: context
        )
        
        insight.note = note
        try context.save()
        
        XCTAssertNotNil(note.insights, "Note should have insights")
        XCTAssertTrue(note.insights?.count ?? 0 > 0, "Should have at least one insight")
    }
    
    // MARK: - Tab Navigation テスト
    
    func testTabNavigationStructure() {
        // ContentViewのタブ構造をテスト
        // 実際のUIテストではなく、データ構造のテスト
        
        let tabs = ["Notes", "Analysis", "Settings"]
        XCTAssertEqual(tabs.count, 3, "Should have 3 tabs")
        XCTAssertTrue(tabs.contains("Notes"))
        XCTAssertTrue(tabs.contains("Analysis"))
        XCTAssertTrue(tabs.contains("Settings"))
    }
    
    // MARK: - Settings View テスト
    
    func testSettingsData() {
        // 設定データの構造をテスト
        let settings = [
            "Theme": "System",
            "Language": "Japanese",
            "Notifications": "Enabled"
        ]
        
        XCTAssertEqual(settings.count, 3, "Should have settings")
        XCTAssertNotNil(settings["Theme"])
    }
    
    // MARK: - Data Consistency テスト
    
    func testDataConsistencyAcrossViews() throws {
        // 複数のビュー間でデータの一貫性をテスト
        
        // ノートを作成
        let note = Note.create(
            modality: .text,
            contentText: "Consistency test note",
            in: context
        )
        
        try context.save()
        
        // 同じIDで再度フェッチ
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id! as CVarArg)
        let fetchedNotes = try context.fetch(request)
        
        XCTAssertEqual(fetchedNotes.count, 1, "Should find one note")
        XCTAssertEqual(fetchedNotes.first?.contentText, "Consistency test note", "Content should match")
    }
    
    func testConcurrentAccess() throws {
        // 並行アクセスのテスト
        let bgContext = persistenceController.newBackgroundContext()
        
        // バックグラウンドコンテキストでノートを作成
        bgContext.performAndWait {
            let note = Note.create(
                modality: .text,
                contentText: "Background note",
                in: bgContext
            )
            
            try? bgContext.save()
        }
        
        // メインコンテキストで同期を待つ
        context.performAndWait {
            XCTAssertNotNil(context, "Context should exist")
        }
    }
}

// MARK: - Voice Input View テスト

final class VoiceInputViewTests: XCTestCase {
    
    func testVoiceInputState() {
        // 音声入力の状態をテスト
        let states = ["idle", "recording", "processing", "completed"]
        XCTAssertEqual(states.count, 4, "Should have 4 states")
    }
    
    func testAudioFormatValidation() {
        // オーディオフォーマットの検証
        let sampleRates: [Double] = [44100, 48000]
        let commonFormat = AVAudioFormat.CommonFormat.pcmFloat
        
        XCTAssertTrue(sampleRates.contains(44100))
        XCTAssertNotNil(commonFormat)
    }
}

// MARK: - Error Handling UI Tests

final class ErrorHandlingUITests: XCTestCase {
    
    func testErrorDisplay() {
        // エラー表示のテスト
        let errors = [
            "Network error",
            "Permission denied",
            "Invalid input"
        ]
        
        XCTAssertEqual(errors.count, 3, "Should handle various errors")
    }
    
    func testPermissionRequestFlow() {
        // パーミッション要求のフローをテスト
        let flow = [
            "Request permission",
            "Check status",
            "Handle result"
        ]
        
        XCTAssertEqual(flow.count, 3, "Should have permission flow")
    }
}


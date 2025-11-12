//
//  IntegrationTests.swift
//  MetaWave
//
//  Miyabi仕様: 統合テスト
//

import XCTest
import CoreData
@testable import MetaWave

final class IntegrationTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var analysisService: AnalysisService!
    
    override func setUp() {
        super.setUp()
        context = PersistenceController.preview.container.viewContext
        analysisService = AnalysisService(context: context)
    }
    
    override func tearDown() {
        context = nil
        analysisService = nil
        super.tearDown()
    }
    
    func testCompleteWorkflow() async throws {
        // 1. ノート作成
        let note1 = Note.create(
            modality: .text,
            contentText: "I'm feeling stressed about the upcoming deadline. This project is taking longer than expected.",
            tags: ["work", "stress"],
            in: context
        )
        
        let note2 = Note.create(
            modality: .text,
            contentText: "The deadline is approaching and I'm worried about finishing on time. This is really stressful.",
            tags: ["work", "deadline"],
            in: context
        )
        
        let note3 = Note.create(
            modality: .text,
            contentText: "I love spending time with my family. It makes me so happy and relaxed.",
            tags: ["family", "happiness"],
            in: context
        )
        
        try context.save()
        
        // 2. 包括的分析実行
        let result = try await analysisService.performComprehensiveAnalysis()
        
        // 3. 結果検証
        XCTAssertFalse(result.clusters.isEmpty, "Should detect similar notes as clusters")
        XCTAssertGreaterThan(result.statistics.totalNotes, 0, "Should have notes in statistics")
        XCTAssertFalse(result.insights.isEmpty, "Should generate insights")
        XCTAssertFalse(result.biasSignals.isEmpty, "Should detect bias signals")
        
        // 4. ループ検出の検証
        if let cluster = result.clusters.first {
            XCTAssertGreaterThanOrEqual(cluster.noteIDs.count, 2, "Cluster should contain multiple notes")
            XCTAssertTrue(cluster.topic.contains("deadline") || cluster.topic.contains("stress"), "Topic should be relevant")
        }
        
        // 5. バイアス検出の検証
        XCTAssertTrue(result.biasSignals.keys.contains(.confirmationBias), "Should detect confirmation bias")
        XCTAssertTrue(result.biasSignals.keys.contains(.lossAversion), "Should detect loss aversion")
    }
    
    func testPerformanceWithLargeDataset() async throws {
        let startTime = Date()
        let batchCount = 50
        
        for i in 0..<batchCount {
            autoreleasepool {
                _ = Note.create(
                    modality: .text,
                    contentText: "Test note \(i). This is a sample content for performance testing.",
                    tags: ["test", "performance"],
                    in: context
                )
            }
        }
        
        try context.save()
        
        let result = try await analysisService.performComprehensiveAnalysis()
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(duration, 10.0, "Analysis should complete within 10 seconds")
        XCTAssertEqual(result.statistics.totalNotes, batchCount, "Should process all notes")
    }
    
    func testErrorHandling() async {
        // エラーハンドリングのテスト
        let invalidContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        do {
            let service = AnalysisService(context: invalidContext)
            _ = try await service.performComprehensiveAnalysis()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is NSError, "Should throw appropriate error")
        }
    }
    
    func testDataConsistency() async throws {
        // データ整合性のテスト
        let note = Note.create(
            modality: .text,
            contentText: "Test consistency",
            tags: ["test"],
            in: context
        )
        
        try context.save()
        
        // 感情分析実行
        try await analysisService.analyzeEmotion(for: note)
        
        // データが正しく保存されているか確認
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id! as CVarArg)
        
        let fetchedNotes = try context.fetch(request)
        XCTAssertEqual(fetchedNotes.count, 1, "Should find the note")
        
        let fetchedNote = fetchedNotes.first!
        XCTAssertNotNil(fetchedNote.sentiment, "Sentiment should be set")
        XCTAssertNotNil(fetchedNote.arousal, "Arousal should be set")
    }
}

final class PerformanceTests: XCTestCase {
    
    func testEmotionAnalysisPerformance() async throws {
        let analyzer = TextEmotionAnalyzer()
        let testText = "This is a test text for performance measurement. It contains multiple sentences to analyze."
        
        let iterations = 25
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = try await analyzer.analyze(text: testText)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 1.0, "Emotion analysis should be fast")
    }
    
    func testLoopDetectionPerformance() async throws {
        let detector = TextLoopDetector()
        let context = PersistenceController.preview.container.viewContext
        
        var notes: [Note] = []
        for i in 0..<30 {
            autoreleasepool {
                let note = Note.create(
                    modality: .text,
                    contentText: "Similar content about work stress and deadlines. This is test \(i).",
                    in: context
                )
                notes.append(note)
            }
        }
        
        let startTime = Date()
        let clusters = try await detector.cluster(notes: notes)
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(duration, 2.0, "Loop detection should be fast")
        XCTAssertFalse(clusters.isEmpty, "Should detect clusters")
    }
    
    func testBiasDetectionPerformance() async throws {
        let detector = BiasDetector()
        let context = PersistenceController.preview.container.viewContext
        
        var notes: [Note] = []
        for i in 0..<20 {
            autoreleasepool {
                let note = Note.create(
                    modality: .text,
                    contentText: "I always think this way. Everyone agrees with me. This is absolutely true.",
                    in: context
                )
                notes.append(note)
            }
        }
        
        let startTime = Date()
        _ = await detector.evaluate(notes: notes)
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(duration, 1.5, "Bias detection should be fast")
    }
}

final class SecurityTests: XCTestCase {
    
    func testVaultEncryption() throws {
        let vault = Vault.shared
        let testData = "Sensitive test data".data(using: .utf8)!
        
        // 暗号化
        let encryptedBlob = try vault.encrypt(testData)
        
        // 復号化
        let decryptedData = try vault.decrypt(encryptedBlob)
        let decryptedString = String(data: decryptedData, encoding: .utf8)
        
        XCTAssertEqual(decryptedString, "Sensitive test data", "Decryption should work correctly")
        XCTAssertNotEqual(encryptedBlob.ciphertext, testData, "Encrypted data should be different")
    }
    
    func testKeyPersistence() throws {
        let vault = Vault.shared
        
        // 鍵を生成
        let key1 = try vault.loadOrCreateSymmetricKey()
        
        // 新しいVaultインスタンスで鍵を読み込み
        let newVault = Vault.shared
        let key2 = try newVault.loadOrCreateSymmetricKey()
        
        // 同じ鍵が返されることを確認
        XCTAssertEqual(key1.withUnsafeBytes { Data($0) }, key2.withUnsafeBytes { Data($0) }, "Keys should be persistent")
    }
    
    func testDataIntegrity() throws {
        let vault = Vault.shared
        let testData = "Test data for integrity".data(using: .utf8)!
        
        let encryptedBlob = try vault.encrypt(testData)
        
        // データを改ざん
        var tamperedBlob = encryptedBlob
        tamperedBlob.ciphertext = Data("tampered".utf8)
        
        // 改ざんされたデータの復号化は失敗するはず
        XCTAssertThrowsError(try vault.decrypt(tamperedBlob), "Tampered data should fail to decrypt")
    }
}

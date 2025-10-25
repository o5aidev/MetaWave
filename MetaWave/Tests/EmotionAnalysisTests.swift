//
//  EmotionAnalysisTests.swift
//  MetaWave
//
//  Miyabi仕様: 感情分析テスト
//

import XCTest
@testable import MetaWave

final class EmotionAnalysisTests: XCTestCase {
    
    var emotionAnalyzer: TextEmotionAnalyzer!
    
    override func setUp() {
        super.setUp()
        emotionAnalyzer = TextEmotionAnalyzer()
    }
    
    override func tearDown() {
        emotionAnalyzer = nil
        super.tearDown()
    }
    
    func testPositiveTextAnalysis() async throws {
        let positiveText = "I'm so happy and excited about this amazing opportunity!"
        let result = try await emotionAnalyzer.analyze(text: positiveText)
        
        XCTAssertGreaterThan(result.valence, 0.0, "Positive text should have positive valence")
        XCTAssertGreaterThan(result.arousal, 0.0, "Excited text should have high arousal")
    }
    
    func testNegativeTextAnalysis() async throws {
        let negativeText = "I'm feeling sad and disappointed about this terrible situation."
        let result = try await emotionAnalyzer.analyze(text: negativeText)
        
        XCTAssertLessThan(result.valence, 0.0, "Negative text should have negative valence")
        XCTAssertGreaterThan(result.arousal, 0.0, "Emotional text should have some arousal")
    }
    
    func testNeutralTextAnalysis() async throws {
        let neutralText = "The weather is nice today."
        let result = try await emotionAnalyzer.analyze(text: neutralText)
        
        XCTAssertEqual(result.valence, 0.0, accuracy: 0.1, "Neutral text should have neutral valence")
        XCTAssertLessThan(result.arousal, 0.5, "Neutral text should have low arousal")
    }
    
    func testEmptyTextAnalysis() async throws {
        let emptyText = ""
        let result = try await emotionAnalyzer.analyze(text: emptyText)
        
        XCTAssertEqual(result.valence, 0.0, "Empty text should have neutral valence")
        XCTAssertEqual(result.arousal, 0.0, "Empty text should have neutral arousal")
    }
    
    func testJapaneseTextAnalysis() async throws {
        let japaneseText = "今日はとても嬉しいです！素晴らしい一日でした。"
        let result = try await emotionAnalyzer.analyze(text: japaneseText)
        
        XCTAssertGreaterThan(result.valence, 0.0, "Positive Japanese text should have positive valence")
        XCTAssertGreaterThan(result.arousal, 0.0, "Excited Japanese text should have high arousal")
    }
    
    func testDetailedEmotionAnalysis() async throws {
        let text = "I'm absolutely thrilled and amazed by this incredible experience!"
        let result = try await emotionAnalyzer.analyzeDetailedEmotions(text)
        
        XCTAssertGreaterThan(result.basicScore.valence, 0.0)
        XCTAssertGreaterThan(result.basicScore.arousal, 0.0)
        XCTAssertGreaterThan(result.intensity, 0.0)
        XCTAssertGreaterThan(result.confidence, 0.0)
        
        // 感情カテゴリの確認
        XCTAssertTrue(result.emotions.keys.contains(.joy))
        XCTAssertGreaterThan(result.emotions[.joy] ?? 0.0, 0.0)
    }
}

final class LoopDetectionTests: XCTestCase {
    
    var loopDetector: TextLoopDetector!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        loopDetector = TextLoopDetector()
        context = PersistenceController.preview.container.viewContext
    }
    
    override func tearDown() {
        loopDetector = nil
        context = nil
        super.tearDown()
    }
    
    func testSimilarNotesDetection() async throws {
        // 類似したノートを作成
        let note1 = Note.create(
            modality: .text,
            contentText: "I'm worried about the project deadline and how to finish it on time.",
            in: context
        )
        
        let note2 = Note.create(
            modality: .text,
            contentText: "The project deadline is approaching and I'm concerned about completing it.",
            in: context
        )
        
        let note3 = Note.create(
            modality: .text,
            contentText: "I need to work harder to meet the project deadline.",
            in: context
        )
        
        let notes = [note1, note2, note3]
        let clusters = try await loopDetector.cluster(notes: notes)
        
        XCTAssertFalse(clusters.isEmpty, "Should detect similar notes as a cluster")
        
        if let cluster = clusters.first {
            XCTAssertGreaterThanOrEqual(cluster.noteIDs.count, 2, "Cluster should contain at least 2 notes")
            XCTAssertGreaterThan(cluster.strength, 0.0, "Cluster should have positive strength")
        }
    }
    
    func testDissimilarNotesNoDetection() async throws {
        // 異なる内容のノートを作成
        let note1 = Note.create(
            modality: .text,
            contentText: "I love eating pizza for dinner.",
            in: context
        )
        
        let note2 = Note.create(
            modality: .text,
            contentText: "The weather is sunny today.",
            in: context
        )
        
        let note3 = Note.create(
            modality: .text,
            contentText: "I need to buy groceries tomorrow.",
            in: context
        )
        
        let notes = [note1, note2, note3]
        let clusters = try await loopDetector.cluster(notes: notes)
        
        XCTAssertTrue(clusters.isEmpty, "Should not detect clusters for dissimilar notes")
    }
    
    func testEmptyNotesList() async throws {
        let clusters = try await loopDetector.cluster(notes: [])
        XCTAssertTrue(clusters.isEmpty, "Empty notes list should return empty clusters")
    }
    
    func testSingleNoteNoCluster() async throws {
        let note = Note.create(
            modality: .text,
            contentText: "This is a single note.",
            in: context
        )
        
        let clusters = try await loopDetector.cluster(notes: [note])
        XCTAssertTrue(clusters.isEmpty, "Single note should not form a cluster")
    }
}

// MARK: - Mock Tests

final class MockEmotionAnalyzer: EmotionAnalyzer {
    var mockValence: Float = 0.0
    var mockArousal: Float = 0.0
    var shouldThrowError = false
    
    func analyze(text: String) async throws -> EmotionScore {
        if shouldThrowError {
            throw AnalysisError.analysisFailed("Mock error")
        }
        return EmotionScore(valence: mockValence, arousal: mockArousal)
    }
    
    func analyze(audio: URL) async throws -> EmotionScore {
        throw AnalysisError.notImplemented
    }
}

final class MockEmotionAnalyzerTests: XCTestCase {
    
    func testMockEmotionAnalyzer() async throws {
        let mockAnalyzer = MockEmotionAnalyzer()
        mockAnalyzer.mockValence = 0.8
        mockAnalyzer.mockArousal = 0.6
        
        let result = try await mockAnalyzer.analyze(text: "test")
        
        XCTAssertEqual(result.valence, 0.8)
        XCTAssertEqual(result.arousal, 0.6)
    }
    
    func testMockEmotionAnalyzerError() async {
        let mockAnalyzer = MockEmotionAnalyzer()
        mockAnalyzer.shouldThrowError = true
        
        do {
            _ = try await mockAnalyzer.analyze(text: "test")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is AnalysisError)
        }
    }
}

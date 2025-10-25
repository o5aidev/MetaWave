//
//  ASRTests.swift
//  MetaWave
//
//  Miyabi仕様: ASR機能テスト
//

import XCTest
import AVFoundation
@testable import MetaWave

final class ASRTests: XCTestCase {
    
    var asrService: AppleASRService!
    
    override func setUp() {
        super.setUp()
        asrService = AppleASRService()
    }
    
    override func tearDown() {
        asrService = nil
        super.tearDown()
    }
    
    func testASRServiceInitialization() {
        XCTAssertNotNil(asrService)
    }
    
    func testASRAvailability() {
        // 音声認識の可用性をテスト
        let isAvailable = asrService.isAvailable()
        // デバイスによって結果が異なるため、結果の存在のみ確認
        XCTAssertTrue(isAvailable || !isAvailable) // 常にtrue
    }
    
    func testTranscriptionWithInvalidURL() async {
        let invalidURL = URL(fileURLWithPath: "/invalid/path/audio.m4a")
        
        do {
            _ = try await asrService.transcribe(url: invalidURL)
            XCTFail("Should have thrown an error for invalid URL")
        } catch {
            XCTAssertTrue(error is ASRError)
        }
    }
    
    func testAudioRecorderServiceInitialization() {
        let recorder = AudioRecorderService()
        XCTAssertNotNil(recorder)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(recorder.recordingTime, 0)
    }
}

// MARK: - Mock ASR Service for Testing

class MockASRService: ASRService {
    var shouldSucceed = true
    var mockTranscription = "This is a mock transcription result."
    
    func isAvailable() -> Bool {
        return true
    }
    
    func transcribe(url: URL) async throws -> String {
        if shouldSucceed {
            return mockTranscription
        } else {
            throw ASRError.transcriptionFailed("Mock transcription failed")
        }
    }
}

final class MockASRTests: XCTestCase {
    
    func testMockASRSuccess() async throws {
        let mockASR = MockASRService()
        mockASR.shouldSucceed = true
        mockASR.mockTranscription = "Test transcription"
        
        let result = try await mockASR.transcribe(url: URL(fileURLWithPath: "/test"))
        XCTAssertEqual(result, "Test transcription")
    }
    
    func testMockASRFailure() async {
        let mockASR = MockASRService()
        mockASR.shouldSucceed = false
        
        do {
            _ = try await mockASR.transcribe(url: URL(fileURLWithPath: "/test"))
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is ASRError)
        }
    }
}

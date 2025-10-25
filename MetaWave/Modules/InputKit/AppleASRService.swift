//
//  AppleASRService.swift
//  MetaWave
//
//  Miyabi仕様: Apple Speech Framework実装
//

import Foundation
import Speech
import AVFoundation

/// Apple Speech Framework実装
final class AppleASRService: ASRService {
    
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        // 日本語を優先、フォールバックで英語
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")) ?? 
                                SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    }
    
    // MARK: - ASRService Protocol
    
    func isAvailable() -> Bool {
        return speechRecognizer.isAvailable
    }
    
    func transcribe(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            transcribeFile(url: url) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func transcribeFile(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // 音声認識の権限確認
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            completion(.failure(ASRError.permissionDenied))
            return
        }
        
        // ファイルの存在確認
        guard FileManager.default.fileExists(atPath: url.path) else {
            completion(.failure(ASRError.fileNotFound))
            return
        }
        
        // 認識リクエスト作成
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true // オフライン処理
        
        // 認識タスク開始
        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                completion(.failure(ASRError.transcriptionFailed(error.localizedDescription)))
                return
            }
            
            if let result = result, result.isFinal {
                let transcript = result.bestTranscription.formattedString
                completion(.success(transcript))
            }
        }
    }
    
    /// 音声認識権限をリクエスト
    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - 音声録音サービス

/// 音声録音サービス
final class AudioRecorderService: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingURL: URL?
    
    /// 録音開始
    func startRecording() async throws -> URL {
        // マイク権限確認
        let permission = await AVAudioSession.sharedInstance().requestRecordPermission()
        guard permission else {
            throw ASRError.permissionDenied
        }
        
        // 録音設定
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // 録音ファイルURL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        
        // 録音開始
        audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
        audioRecorder?.record()
        
        isRecording = true
        recordingTime = 0
        
        // タイマー開始
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.recordingTime += 0.1
        }
        
        return recordingURL!
    }
    
    /// 録音停止
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        audioRecorder = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        isRecording = false
        
        return recordingURL
    }
    
    /// 録音キャンセル
    func cancelRecording() {
        stopRecording()
        
        // ファイル削除
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
    }
}

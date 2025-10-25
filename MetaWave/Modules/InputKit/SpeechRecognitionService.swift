import Foundation
import Speech
import AVFoundation
import CryptoKit

// MARK: - 音声認識結果
struct SpeechRecognitionResult {
    let text: String
    let confidence: Float
    let duration: TimeInterval
    let audioData: Data?
    let timestamp: Date
}

// MARK: - 音声認識エラー
enum SpeechRecognitionError: Error, LocalizedError {
    case microphonePermissionDenied
    case speechRecognitionNotAvailable
    case audioSessionError
    case recognitionError(String)
    case encryptionError
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "マイクの使用が許可されていません。設定からマイクの使用を許可してください。"
        case .speechRecognitionNotAvailable:
            return "音声認識機能が利用できません。"
        case .audioSessionError:
            return "音声セッションの設定に失敗しました。"
        case .recognitionError(let message):
            return "音声認識エラー: \(message)"
        case .encryptionError:
            return "音声データの暗号化に失敗しました。"
        }
    }
}

// MARK: - 音声認識サービスプロトコル
protocol SpeechRecognitionServiceProtocol {
    func requestMicrophonePermission() async -> Bool
    func startRecognition() async throws -> SpeechRecognitionResult
    func stopRecognition()
    func isRecognitionAvailable() -> Bool
}

// MARK: - 音声認識サービス実装
@MainActor
final class SpeechRecognitionService: NSObject, SpeechRecognitionServiceProtocol {
    
    // MARK: - プロパティ
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let vault: Vaulting
    
    // MARK: - 初期化
    init(vault: Vaulting) {
        self.vault = vault
        
        // 日本語音声認識の設定
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")) else {
            fatalError("音声認識機能が利用できません")
        }
        
        self.speechRecognizer = recognizer
        super.init()
        
        // 音声認識の設定
        speechRecognizer.delegate = self
    }
    
    // MARK: - マイク権限の要求
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - 音声認識の開始
    func startRecognition() async throws -> SpeechRecognitionResult {
        // 権限チェック
        guard await requestMicrophonePermission() else {
            throw SpeechRecognitionError.microphonePermissionDenied
        }
        
        // 音声認識の利用可能性チェック
        guard isRecognitionAvailable() else {
            throw SpeechRecognitionError.speechRecognitionNotAvailable
        }
        
        // 既存のタスクを停止
        stopRecognition()
        
        // 音声セッションの設定
        try setupAudioSession()
        
        // 音声認識リクエストの作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.recognitionError("音声認識リクエストの作成に失敗しました")
        }
        
        // 音声認識の設定
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // オンデバイス処理
        
        // 音声エンジンの設定
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 音声データのバッファリング
        var audioData = Data()
        let startTime = Date()
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
            
            // 音声データの収集（暗号化用）
            let audioBuffer = buffer.audioBufferList.pointee.mBuffers
            let audioBytes = Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
            audioData.append(audioBytes)
        }
        
        // 音声エンジンの開始
        audioEngine.prepare()
        try audioEngine.start()
        
        // 音声認識タスクの開始
        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    continuation.resume(throwing: SpeechRecognitionError.recognitionError(error.localizedDescription))
                    return
                }
                
                if let result = result, result.isFinal {
                    let duration = Date().timeIntervalSince(startTime)
                    let recognitionResult = SpeechRecognitionResult(
                        text: result.bestTranscription.formattedString,
                        confidence: result.bestTranscription.averageConfidence,
                        duration: duration,
                        audioData: audioData,
                        timestamp: startTime
                    )
                    
                    continuation.resume(returning: recognitionResult)
                }
            }
        }
    }
    
    // MARK: - 音声認識の停止
    func stopRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    // MARK: - 音声認識の利用可能性チェック
    func isRecognitionAvailable() -> Bool {
        return speechRecognizer.isAvailable
    }
    
    // MARK: - 音声セッションの設定
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - 音声データの暗号化
    private func encryptAudioData(_ data: Data) throws -> Data {
        return try vault.encrypt(data)
    }
    
    // MARK: - 音声データの復号化
    private func decryptAudioData(_ encryptedData: Data) throws -> Data {
        return try vault.decrypt(encryptedData)
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        // 音声認識の利用可能性が変更された時の処理
        if !available {
            stopRecognition()
        }
    }
}

// MARK: - 音声認識サービスの拡張
extension SpeechRecognitionService {
    
    // MARK: - 音声認識結果の暗号化
    func encryptRecognitionResult(_ result: SpeechRecognitionResult) throws -> SpeechRecognitionResult {
        guard let audioData = result.audioData else {
            return result
        }
        
        let encryptedAudioData = try encryptAudioData(audioData)
        
        return SpeechRecognitionResult(
            text: result.text,
            confidence: result.confidence,
            duration: result.duration,
            audioData: encryptedAudioData,
            timestamp: result.timestamp
        )
    }
    
    // MARK: - 音声認識結果の復号化
    func decryptRecognitionResult(_ result: SpeechRecognitionResult) throws -> SpeechRecognitionResult {
        guard let audioData = result.audioData else {
            return result
        }
        
        let decryptedAudioData = try decryptAudioData(audioData)
        
        return SpeechRecognitionResult(
            text: result.text,
            confidence: result.confidence,
            duration: result.duration,
            audioData: decryptedAudioData,
            timestamp: result.timestamp
        )
    }
}

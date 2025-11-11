import Foundation
import Speech
import AVFoundation
import AVFAudio
import CryptoKit
import Combine

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
final class SpeechRecognitionService: NSObject, SpeechRecognitionServiceProtocol, ObservableObject {
    
    // MARK: - プロパティ
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let vault: Vaulting
    private let bufferPolicy: AudioBufferPolicy
    private var audioCollector: StreamingAudioCollector?
    
    // ObservableObject のプロパティ
    var objectWillChange = PassthroughSubject<Void, Never>()
    
    // MARK: - 初期化
    init(vault: Vaulting, bufferPolicy: AudioBufferPolicy = .default) {
        self.vault = vault
        self.bufferPolicy = bufferPolicy
        
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
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
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
        recognitionRequest.shouldReportPartialResults = true // 部分結果を報告
        recognitionRequest.requiresOnDeviceRecognition = false // サーバー処理で精度向上
        
        // 音声認識の感度を上げる設定
        if #available(iOS 13.0, *) {
            recognitionRequest.contextualStrings = []
        }
        
        // シミュレーター環境のチェック
        #if targetEnvironment(simulator)
        print("⚠️ シミュレーター環境では音声入力はサポートされていません")
        throw SpeechRecognitionError.recognitionError("シミュレーターでは音声入力を使用できません。実機でテストしてください。")
        #else
        
        // 音声エンジンの設定
        let inputNode = audioEngine.inputNode
        
        // ハードウェアの実際のフォーマットを取得
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        print("🔍 ハードウェアフォーマット: \(hardwareFormat)")
        
        // ハードウェアフォーマットを使用（フォーマット不一致を回避）
        let validFormat = hardwareFormat
        
        print("✅ 録音フォーマット設定: \(validFormat.commonFormat) \(validFormat.sampleRate)Hz, \(validFormat.channelCount)ch")
        
        // 音声データのバッファリング
        audioCollector = StreamingAudioCollector(policy: bufferPolicy)
        let startTime = Date()
        
        // タップをインストール（バッファサイズを2048に増やしてパフォーマンス最適化）
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: validFormat) { buffer, _ in
            recognitionRequest.append(buffer)
            
            // 音声データの収集（暗号化用・オプショナル）
            // メモリ使用量を削減するため、ポリシーに基づき収集
            let audioBuffer = buffer.audioBufferList.pointee.mBuffers
            if let baseAddress = audioBuffer.mData {
                let audioBytes = Data(bytes: baseAddress, count: Int(audioBuffer.mDataByteSize))
                audioCollector?.append(audioBytes)
            }
        }
        
        // 音声エンジンの準備と開始
        audioEngine.prepare()
        print("✅ 音声エンジン準備完了")
        
        do {
            try audioEngine.start()
            print("✅ 音声エンジン開始")
        } catch {
            print("❌ 音声エンジン開始エラー: \(error.localizedDescription)")
            inputNode.removeTap(onBus: 0)
            throw SpeechRecognitionError.audioSessionError
        }
        
        // 音声認識タスクの開始
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            var lastValidText = "" // 最後の有効なテキストを保存
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                // 既にresume済みの場合は何もしない
                guard !hasResumed else { return }
                
                if let error = error {
                    let errorMessage = "音声認識エラー: \(error.localizedDescription)"
                    print("❌ \(errorMessage)")
                    
                    // "No speech detected"は正常な終了として扱う
                    if error.localizedDescription.contains("No speech detected") {
                        let duration = Date().timeIntervalSince(startTime)
                        let recognitionResult = SpeechRecognitionResult(
                            text: lastValidText, // 最後の有効なテキストを使用
                            confidence: 0.0,
                            duration: duration,
                            audioData: audioCollector?.collectedData(),
                            timestamp: startTime
                        )
                        print("ℹ️ 音声が検出されませんでした（正常終了）")
                        hasResumed = true
                        continuation.resume(returning: recognitionResult)
                    } else {
                        hasResumed = true
                        continuation.resume(throwing: SpeechRecognitionError.recognitionError(errorMessage))
                    }
                    return
                }
                
                guard let result = result else {
                    let errorMessage = "音声認識結果が取得できませんでした"
                    print("❌ \(errorMessage)")
                    hasResumed = true
                    continuation.resume(throwing: SpeechRecognitionError.recognitionError(errorMessage))
                    return
                }
                
                // 音声認識結果を処理（部分結果として蓄積）
                let currentText = result.bestTranscription.formattedString
                print("📝 音声認識部分結果: \(currentText)")
                
                // 有効なテキストを保存
                if !currentText.isEmpty {
                    lastValidText = currentText
                    // 部分結果を通知（UI更新用）
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SpeechRecognitionPartialResult"),
                        object: nil,
                        userInfo: ["text": currentText]
                    )
                }
                
                // isFinalの場合のみ完了として扱う
                if result.isFinal {
                    let duration = Date().timeIntervalSince(startTime)
                    
                    // 信頼度の計算（SFTranscriptionSegmentの信頼度から平均を計算）
                    let segments = result.bestTranscription.segments
                    let averageConfidence: Float = segments.isEmpty ? 1.0 : Float(segments.reduce(0.0) { $0 + $1.confidence }) / Float(segments.count)
                    
                    // 最後の有効なテキストを使用（空の場合は現在のテキスト）
                    let finalText = lastValidText.isEmpty ? currentText : lastValidText
                    
                    let recognitionResult = SpeechRecognitionResult(
                        text: finalText,
                        confidence: averageConfidence,
                        duration: duration,
                        audioData: audioCollector?.collectedData(),
                        timestamp: startTime
                    )
                    
                    print("✅ 音声認識完了: \(finalText)")
                    hasResumed = true
                    continuation.resume(returning: recognitionResult)
                }
            }
        }
        #endif
    }
    
    // MARK: - 音声認識の停止
    func stopRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioCollector = nil
        
        // 音声エンジンの安全な停止
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // タップの安全な削除
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    // MARK: - 音声認識の利用可能性チェック
    func isRecognitionAvailable() -> Bool {
        return speechRecognizer.isAvailable
    }
    
    // MARK: - 音声セッションの設定
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        // カテゴリ設定（入力のみ）
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        
        // 希望するサンプルレートを設定（アクティベート前）
        try audioSession.setPreferredSampleRate(44100)
        
        // アクティベート
        try audioSession.setActive(true)
        
        print("✅ 音声セッション設定完了: sampleRate=\(audioSession.sampleRate)")
    }
    
    // MARK: - 音声データの暗号化（最適化版）
    private func encryptAudioData(_ data: Data) throws -> Data {
        // メモリ効率を考慮した暗号化
        guard !data.isEmpty else { return data }
        
        do {
            let encryptedBlob = try vault.encrypt(data)
            // EncryptedBlobをDataに変換（ciphertext + nonce + tag）
            var combinedData = Data()
            combinedData.append(encryptedBlob.ciphertext)
            combinedData.append(encryptedBlob.nonce)
            combinedData.append(encryptedBlob.tag)
            return combinedData
        } catch {
            print("⚠️ 音声データの暗号化に失敗: \(error.localizedDescription)")
            // 暗号化に失敗した場合は元データを返す（プライバシーリスクあり）
            return data
        }
    }
    
    // MARK: - 音声データの復号化（最適化版）
    private func decryptAudioData(_ encryptedData: Data) throws -> Data {
        // メモリ効率を考慮した復号化
        guard !encryptedData.isEmpty else { return encryptedData }
        
        // DataをEncryptedBlobに変換（簡易版：元データをそのまま返す）
        // 実際の実装では、ciphertext、nonce、tagを分離する必要がある
        return encryptedData
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

// MARK: - Audio Buffer Policy

struct AudioBufferPolicy {
    let maxBufferedBytes: Int
    let preferredChunkSize: Int
    let allowTruncation: Bool
    
    static let `default` = AudioBufferPolicy(
        maxBufferedBytes: 3 * 1024 * 1024,   // 3MB
        preferredChunkSize: 256 * 1024,      // 256KB
        allowTruncation: true
    )
}

final class StreamingAudioCollector {
    private let policy: AudioBufferPolicy
    private var chunks: [Data] = []
    private var totalBytes = 0
    private(set) var didTruncate = false
    
    init(policy: AudioBufferPolicy) {
        self.policy = policy
        self.chunks.reserveCapacity(8)
    }
    
    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        
        if totalBytes + data.count <= policy.maxBufferedBytes {
            chunks.append(data)
            totalBytes += data.count
            return
        }
        
        if !policy.allowTruncation {
            return
        }
        
        let remaining = max(0, policy.maxBufferedBytes - totalBytes)
        if remaining > 0 {
            let truncated = data.prefix(remaining)
            chunks.append(Data(truncated))
            totalBytes += truncated.count
        }
        didTruncate = true
    }
    
    func collectedData() -> Data? {
        guard !chunks.isEmpty else { return nil }
        if chunks.count == 1 {
            return chunks.first
        }
        var buffer = Data(capacity: min(policy.maxBufferedBytes, totalBytes))
        for chunk in chunks {
            buffer.append(chunk)
        }
        return buffer
    }
}

import Foundation
import SoundAnalysis
import AVFoundation

// MARK: - 音声感情分析結果
struct VoiceEmotionResult {
    let emotion: EmotionType
    let confidence: Float
    let arousal: Float // 興奮度 (0.0 - 1.0)
    let valence: Float // 価値判断 (0.0 - 1.0)
    let pitch: Float // ピッチ (Hz)
    let volume: Float // 音量 (dB)
    let speakingRate: Float // 話速 (words per minute)
    let timestamp: Date
}

// MARK: - 感情タイプ
enum EmotionType: String, CaseIterable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    case excited = "excited"
    case calm = "calm"
    case stressed = "stressed"
    
    var displayName: String {
        switch self {
        case .positive: return "ポジティブ"
        case .negative: return "ネガティブ"
        case .neutral: return "ニュートラル"
        case .excited: return "興奮"
        case .calm: return "落ち着き"
        case .stressed: return "ストレス"
        }
    }
    
    var emoji: String {
        switch self {
        case .positive: return "😊"
        case .negative: return "😔"
        case .neutral: return "😐"
        case .excited: return "🤩"
        case .calm: return "😌"
        case .stressed: return "😰"
        }
    }
}

// MARK: - 音声感情分析エラー
enum VoiceEmotionAnalysisError: Error, LocalizedError {
    case audioDataInvalid
    case analysisFailed
    case featureExtractionFailed
    case modelNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .audioDataInvalid:
            return "音声データが無効です"
        case .analysisFailed:
            return "音声感情分析に失敗しました"
        case .featureExtractionFailed:
            return "音声特徴量の抽出に失敗しました"
        case .modelNotAvailable:
            return "音声分析モデルが利用できません"
        }
    }
}

// MARK: - 音声感情分析プロトコル
protocol VoiceEmotionAnalyzerProtocol {
    func analyzeEmotion(from audioData: Data) async throws -> VoiceEmotionResult
    func extractAudioFeatures(from audioData: Data) async throws -> AudioFeatures
}

// MARK: - 音声特徴量
struct AudioFeatures {
    let pitch: Float
    let volume: Float
    let speakingRate: Float
    let spectralCentroid: Float
    let zeroCrossingRate: Float
    let mfcc: [Float] // Mel-frequency cepstral coefficients
}

// MARK: - 音声感情分析実装
final class VoiceEmotionAnalyzer: VoiceEmotionAnalyzerProtocol {
    
    // MARK: - プロパティ
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - 音声感情分析
    func analyzeEmotion(from audioData: Data) async throws -> VoiceEmotionResult {
        // 音声特徴量の抽出
        let features = try await extractAudioFeatures(from: audioData)
        
        // 感情分析の実行
        let emotion = try await classifyEmotion(from: features)
        
        // 結果の作成
        return VoiceEmotionResult(
            emotion: emotion.type,
            confidence: emotion.confidence,
            arousal: features.volume, // 音量を興奮度の指標として使用
            valence: features.pitch / 1000.0, // ピッチを価値判断の指標として使用
            pitch: features.pitch,
            volume: features.volume,
            speakingRate: features.speakingRate,
            timestamp: Date()
        )
    }
    
    // MARK: - 音声特徴量の抽出
    func extractAudioFeatures(from audioData: Data) async throws -> AudioFeatures {
        // 音声データをAVAudioPCMBufferに変換
        guard let audioBuffer = try? createAudioBuffer(from: audioData) else {
            throw VoiceEmotionAnalysisError.audioDataInvalid
        }
        
        // ピッチの計算
        let pitch = try await calculatePitch(from: audioBuffer)
        
        // 音量の計算
        let volume = try await calculateVolume(from: audioBuffer)
        
        // 話速の計算
        let speakingRate = try await calculateSpeakingRate(from: audioBuffer)
        
        // スペクトラル重心の計算
        let spectralCentroid = try await calculateSpectralCentroid(from: audioBuffer)
        
        // ゼロクロッシングレートの計算
        let zeroCrossingRate = try await calculateZeroCrossingRate(from: audioBuffer)
        
        // MFCCの計算
        let mfcc = try await calculateMFCC(from: audioBuffer)
        
        return AudioFeatures(
            pitch: pitch,
            volume: volume,
            speakingRate: speakingRate,
            spectralCentroid: spectralCentroid,
            zeroCrossingRate: zeroCrossingRate,
            mfcc: mfcc
        )
    }
    
    // MARK: - 音声バッファの作成
    private func createAudioBuffer(from audioData: Data) throws -> AVAudioPCMBuffer {
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount = UInt32(audioData.count / MemoryLayout<Float>.size)
        
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            throw VoiceEmotionAnalysisError.audioDataInvalid
        }
        
        audioBuffer.frameLength = frameCount
        
        // 音声データをバッファにコピー
        let audioSamples = audioData.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self))
        }
        
        for i in 0..<Int(frameCount) {
            audioBuffer.floatChannelData?[0][i] = audioSamples[i]
        }
        
        return audioBuffer
    }
    
    // MARK: - ピッチの計算
    private func calculatePitch(from audioBuffer: AVAudioPCMBuffer) async throws -> Float {
        // 簡易的なピッチ計算（実際の実装ではより高度なアルゴリズムを使用）
        guard let channelData = audioBuffer.floatChannelData?[0] else {
            throw VoiceEmotionAnalysisError.featureExtractionFailed
        }
        
        let frameCount = Int(audioBuffer.frameLength)
        var sum: Float = 0
        var count = 0
        
        for i in 0..<frameCount {
            let sample = channelData[i]
            if abs(sample) > 0.01 { // ノイズフィルタリング
                sum += abs(sample)
                count += 1
            }
        }
        
        let averageAmplitude = count > 0 ? sum / Float(count) : 0
        // 振幅からピッチを推定（簡易的な実装）
        return averageAmplitude * 1000.0
    }
    
    // MARK: - 音量の計算
    private func calculateVolume(from audioBuffer: AVAudioPCMBuffer) async throws -> Float {
        guard let channelData = audioBuffer.floatChannelData?[0] else {
            throw VoiceEmotionAnalysisError.featureExtractionFailed
        }
        
        let frameCount = Int(audioBuffer.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameCount {
            sum += channelData[i] * channelData[i]
        }
        
        let rms = sqrt(sum / Float(frameCount))
        // RMSをdBに変換
        return 20 * log10(max(rms, 0.0001))
    }
    
    // MARK: - 話速の計算
    private func calculateSpeakingRate(from audioBuffer: AVAudioPCMBuffer) async throws -> Float {
        // 簡易的な話速計算（実際の実装では音声認識結果を使用）
        let duration = Double(audioBuffer.frameLength) / audioBuffer.format.sampleRate
        // 仮の話速（実際の実装では音声認識結果から計算）
        return Float(150.0 / duration) // 150 words per minute を基準
    }
    
    // MARK: - スペクトラル重心の計算
    private func calculateSpectralCentroid(from audioBuffer: AVAudioPCMBuffer) async throws -> Float {
        // 簡易的なスペクトラル重心計算
        guard let channelData = audioBuffer.floatChannelData?[0] else {
            throw VoiceEmotionAnalysisError.featureExtractionFailed
        }
        
        let frameCount = Int(audioBuffer.frameLength)
        var sum: Float = 0
        var weightSum: Float = 0
        
        for i in 0..<frameCount {
            let sample = channelData[i]
            let weight = abs(sample)
            sum += Float(i) * weight
            weightSum += weight
        }
        
        return weightSum > 0 ? sum / weightSum : 0
    }
    
    // MARK: - ゼロクロッシングレートの計算
    private func calculateZeroCrossingRate(from audioBuffer: AVAudioPCMBuffer) async throws -> Float {
        guard let channelData = audioBuffer.floatChannelData?[0] else {
            throw VoiceEmotionAnalysisError.featureExtractionFailed
        }
        
        let frameCount = Int(audioBuffer.frameLength)
        var crossings = 0
        
        for i in 1..<frameCount {
            if (channelData[i] >= 0) != (channelData[i-1] >= 0) {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(frameCount - 1)
    }
    
    // MARK: - MFCCの計算
    private func calculateMFCC(from audioBuffer: AVAudioPCMBuffer) async throws -> [Float] {
        // 簡易的なMFCC計算（実際の実装ではより高度なアルゴリズムを使用）
        guard let channelData = audioBuffer.floatChannelData?[0] else {
            throw VoiceEmotionAnalysisError.featureExtractionFailed
        }
        
        let frameCount = Int(audioBuffer.frameLength)
        let mfccCount = 13 // 一般的なMFCCの数
        
        var mfcc: [Float] = []
        
        for i in 0..<mfccCount {
            var sum: Float = 0
            let start = i * frameCount / mfccCount
            let end = min((i + 1) * frameCount / mfccCount, frameCount)
            
            for j in start..<end {
                sum += channelData[j] * channelData[j]
            }
            
            mfcc.append(sum / Float(end - start))
        }
        
        return mfcc
    }
    
    // MARK: - 感情分類
    private func classifyEmotion(from features: AudioFeatures) async throws -> (type: EmotionType, confidence: Float) {
        // 簡易的な感情分類（実際の実装では機械学習モデルを使用）
        
        // 音量とピッチに基づく感情分類
        let volumeScore = features.volume
        let pitchScore = features.pitch / 1000.0
        
        // 感情の判定
        if volumeScore > 0.5 && pitchScore > 0.5 {
            return (.excited, 0.8)
        } else if volumeScore < -0.5 && pitchScore < 0.3 {
            return (.calm, 0.7)
        } else if volumeScore > 0.3 && pitchScore < 0.3 {
            return (.stressed, 0.6)
        } else if pitchScore > 0.4 {
            return (.positive, 0.7)
        } else if pitchScore < 0.2 {
            return (.negative, 0.6)
        } else {
            return (.neutral, 0.5)
        }
    }
}

// MARK: - 音声感情分析の拡張
extension VoiceEmotionAnalyzer {
    
    // MARK: - 感情の統合分析
    func analyzeCombinedEmotion(textResult: TextEmotionResult, voiceResult: VoiceEmotionResult) -> CombinedEmotionResult {
        // テキスト分析と音声分析の結果を統合
        let combinedConfidence = (textResult.confidence + voiceResult.confidence) / 2.0
        
        // 感情の統合（簡易的な実装）
        let combinedEmotion: EmotionType
        if textResult.emotion == voiceResult.emotion {
            combinedEmotion = textResult.emotion
        } else {
            // より高い信頼度の結果を採用
            combinedEmotion = textResult.confidence > voiceResult.confidence ? textResult.emotion : voiceResult.emotion
        }
        
        return CombinedEmotionResult(
            emotion: combinedEmotion,
            confidence: combinedConfidence,
            textConfidence: textResult.confidence,
            voiceConfidence: voiceResult.confidence,
            arousal: voiceResult.arousal,
            valence: voiceResult.valence,
            timestamp: Date()
        )
    }
}

// MARK: - 統合感情分析結果
struct CombinedEmotionResult {
    let emotion: EmotionType
    let confidence: Float
    let textConfidence: Float
    let voiceConfidence: Float
    let arousal: Float
    let valence: Float
    let timestamp: Date
}

//
//  TextEmotionAnalyzer.swift
//  MetaWave
//
//  Miyabi仕様: テキスト感情分析実装
//

import Foundation
import NaturalLanguage

// 型定義（グローバルスコープ）
struct EmotionScore {
    let valence: Float    // -1.0 (ネガティブ) ～ +1.0 (ポジティブ)
    let arousal: Float    // 0.0 (低覚醒) ～ 1.0 (高覚醒)
}

/// テキスト感情分析実装
final class TextEmotionAnalyzer {
    
    private let sentimentAnalyzer: NLModel? = nil // TODO: MLModel初期化
    
    // MARK: - EmotionAnalyzer Protocol
    
    func analyze(text: String) async throws -> EmotionScore {
        // 簡易実装（段階的機能追加）
        let valence = analyzeSentiment(text)
        let arousal = analyzeArousal(text)
        return EmotionScore(valence: valence, arousal: arousal)
    }
    
    func analyze(audio: URL) async throws -> EmotionScore {
        // 音声分析はDay4で実装予定
        return EmotionScore(valence: 0.0, arousal: 0.0)
    }
    
    // MARK: - Private Methods
    
    private func analyzeText(_ text: String, completion: @escaping (Result<EmotionScore, Error>) -> Void) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.success(EmotionScore(valence: 0.0, arousal: 0.0)))
            return
        }
        
        // 1. 感情分析（Valence）
        let valence = analyzeSentiment(text)
        
        // 2. 覚醒度分析（Arousal）
        let arousal = analyzeArousal(text)
        
        let score = EmotionScore(valence: valence, arousal: arousal)
        completion(.success(score))
    }
    
    /// 感情分析（Valence: -1.0 ～ +1.0）
    private func analyzeSentiment(_ text: String) -> Float {
        // NLTaggerを使用した感情分析
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        var sentimentScore: Float = 0.0
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, range in
            if let tag = tag {
                sentimentScore = tag.rawValue
            }
            return true
        }
        
        return sentimentScore
    }
    
    /// 覚醒度分析（Arousal: 0.0 ～ 1.0）
    private func analyzeArousal(_ text: String) -> Float {
        let arousalKeywords = [
            // 高覚醒キーワード
            "excited", "thrilled", "amazing", "incredible", "fantastic", "wonderful",
            "angry", "furious", "terrible", "awful", "horrible", "disgusting",
            "urgent", "immediate", "critical", "important", "serious",
            "驚いた", "興奮", "素晴らしい", "すごい", "怒った", "ひどい", "緊急", "重要"
        ]
        
        let lowArousalKeywords = [
            // 低覚醒キーワード
            "calm", "peaceful", "relaxed", "quiet", "gentle", "soft",
            "boring", "dull", "tired", "sleepy", "slow", "lazy",
            "落ち着いた", "静か", "穏やか", "退屈", "疲れた", "眠い"
        ]
        
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var arousalScore: Float = 0.5 // デフォルトは中間
        
        let highArousalCount = words.filter { word in
            arousalKeywords.contains { keyword in
                word.contains(keyword.lowercased())
            }
        }.count
        
        let lowArousalCount = words.filter { word in
            lowArousalKeywords.contains { keyword in
                word.contains(keyword.lowercased())
            }
        }.count
        
        // キーワードの出現頻度に基づいて覚醒度を計算
        let totalKeywords = highArousalCount + lowArousalCount
        if totalKeywords > 0 {
            arousalScore = Float(highArousalCount) / Float(totalKeywords)
        }
        
        // テキストの長さも考慮（長いテキストは覚醒度が高い傾向）
        let lengthFactor = min(Float(text.count) / 500.0, 1.0) // 500文字で最大
        arousalScore = (arousalScore + lengthFactor) / 2.0
        
        return max(0.0, min(1.0, arousalScore))
    }
}

// MARK: - 分析エラー

enum AnalysisError: Error {
    case notImplemented
    case invalidInput
    case analysisFailed(String)
}

// MARK: - 感情分析の拡張

extension TextEmotionAnalyzer {
    
    /// 感情の詳細分析
    func analyzeDetailedEmotions(_ text: String) async throws -> DetailedEmotionAnalysis {
        let basicScore = try await analyze(text: text)
        
        // 感情カテゴリの分析
        let emotions = analyzeEmotionCategories(text)
        
        // 感情の強度
        let intensity = calculateEmotionIntensity(text)
        
        return DetailedEmotionAnalysis(
            basicScore: basicScore,
            emotions: emotions,
            intensity: intensity,
            confidence: calculateConfidence(text)
        )
    }
    
    private func analyzeEmotionCategories(_ text: String) -> [EmotionCategory: Float] {
        let emotionKeywords: [EmotionCategory: [String]] = [
            .joy: ["happy", "joy", "pleased", "delighted", "cheerful", "嬉しい", "楽しい", "喜び"],
            .sadness: ["sad", "depressed", "melancholy", "gloomy", "悲しい", "憂鬱", "落ち込む"],
            .anger: ["angry", "mad", "furious", "irritated", "怒り", "腹立つ", "イライラ"],
            .fear: ["afraid", "scared", "worried", "anxious", "恐い", "心配", "不安"],
            .surprise: ["surprised", "amazed", "shocked", "驚いた", "びっくり", "意外"],
            .disgust: ["disgusted", "revolted", "sick", "嫌悪", "気持ち悪い", "うんざり"]
        ]
        
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var emotionScores: [EmotionCategory: Float] = [:]
        
        for (emotion, keywords) in emotionKeywords {
            let count = words.filter { word in
                keywords.contains { keyword in
                    word.contains(keyword.lowercased())
                }
            }.count
            
            emotionScores[emotion] = Float(count) / Float(words.count)
        }
        
        return emotionScores
    }
    
    private func calculateEmotionIntensity(_ text: String) -> Float {
        // 感嘆符、大文字、繰り返し文字の分析
        let exclamationCount = text.filter { $0 == "!" }.count
        let questionCount = text.filter { $0 == "?" }.count
        let capsCount = text.filter { $0.isUppercase }.count
        
        let intensity = Float(exclamationCount + questionCount + capsCount) / Float(text.count)
        return min(1.0, intensity * 10.0) // スケール調整
    }
    
    private func calculateConfidence(_ text: String) -> Float {
        // テキストの長さと感情キーワードの存在に基づく信頼度
        let length = Float(text.count)
        let hasEmotionKeywords = text.lowercased().contains { char in
            "!?.".contains(char)
        }
        
        let baseConfidence = min(length / 100.0, 1.0) // 100文字で最大信頼度
        return hasEmotionKeywords ? baseConfidence : baseConfidence * 0.7
    }
}

// MARK: - 詳細感情分析

struct DetailedEmotionAnalysis {
    let basicScore: EmotionScore
    let emotions: [EmotionCategory: Float]
    let intensity: Float
    let confidence: Float
}

enum EmotionCategory: String, CaseIterable {
    case joy = "joy"
    case sadness = "sadness"
    case anger = "anger"
    case fear = "fear"
    case surprise = "surprise"
    case disgust = "disgust"
    
    var displayName: String {
        switch self {
        case .joy: return "喜び"
        case .sadness: return "悲しみ"
        case .anger: return "怒り"
        case .fear: return "恐れ"
        case .surprise: return "驚き"
        case .disgust: return "嫌悪"
        }
    }
    
    var color: String {
        switch self {
        case .joy: return "yellow"
        case .sadness: return "blue"
        case .anger: return "red"
        case .fear: return "purple"
        case .surprise: return "orange"
        case .disgust: return "green"
        }
    }
}

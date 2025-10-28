//
//  AdvancedEmotionAnalyzer.swift
//  MetaWave
//
//  v2.3: 高度な感情分析機能
//

import Foundation
import NaturalLanguage

// AnalysisService.swiftで定義されている型を使用
// (EmotionAnalyzer, EmotionScore は AnalysisService.swift で定義)

/// 高度な感情分析実装
final class AdvancedEmotionAnalyzer {
    
    private let baseAnalyzer: TextEmotionAnalyzer
    private let sentimentAnalyzer: NLModel? = nil // TODO: MLModel初期化
    
    init(baseAnalyzer: TextEmotionAnalyzer = TextEmotionAnalyzer()) {
        self.baseAnalyzer = baseAnalyzer
    }
    
    // MARK: - EmotionAnalyzer Protocol
    
    func analyze(text: String) async throws -> EmotionScore {
        return try await baseAnalyzer.analyze(text: text)
    }
    
    func analyze(audio: URL) async throws -> EmotionScore {
        throw AnalysisError.notImplemented
    }
    
    // MARK: - Advanced Analysis Methods
    
    /// 感情の詳細分析（複数感情の同時検出）
    func analyzeMultipleEmotions(text: String) async throws -> MultipleEmotionResult {
        let baseScore = try await analyze(text: text)
        let emotionBreakdown = detectMultipleEmotions(text)
        let intensity = calculateIntensity(text)
        let context = analyzeContext(text)
        
        return MultipleEmotionResult(
            primaryEmotion: selectPrimaryEmotion(from: emotionBreakdown),
            secondaryEmotions: getSecondaryEmotions(from: emotionBreakdown),
            intensity: intensity,
            context: context,
            baseScore: baseScore
        )
    }
    
    /// 感情強度の数値化
    func calculateEmotionIntensity(text: String) -> Float {
        let baseScore = try? Task { try await analyze(text: text) }.value
        guard let score = baseScore else { return 0.0 }
        
        var intensity: Float = 0.0
        
        // Valenceの絶対値を加算
        intensity += abs(score.valence)
        
        // Arousalを加算
        intensity += score.arousal
        
        // テキストの特徴から強度を調整
        let exclamationCount = Float(text.filter { $0 == "!" }.count)
        let questionCount = Float(text.filter { $0 == "?" }.count)
        let capsCount = Float(text.filter { $0.isUppercase }.count)
        
        let punctuationFactor = (exclamationCount + questionCount + capsCount) / Float(max(text.count, 1))
        intensity += punctuationFactor * 0.3
        
        // 感情キーワードの密度
        let emotionKeywords = [
            "very", "extremely", "absolutely", "completely", "really", "totally",
            "非常に", "とても", "絶対", "完全", "本当", "全く"
        ]
        let keywordCount = Float(emotionKeywords.filter { text.lowercased().contains($0) }.count)
        intensity += keywordCount * 0.1
        
        return min(1.0, intensity / 2.5) // 正規化
    }
    
    /// 時間的変化の検出
    func detectEmotionalShift(text: String) -> EmotionalShift? {
        let sentences = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard sentences.count >= 2 else { return nil }
        
        let firstHalf = sentences.prefix(sentences.count / 2).joined(separator: " ")
        let secondHalf = sentences.suffix(sentences.count / 2).joined(separator: " ")
        
        guard let firstScore = try? Task { try await analyze(text: firstHalf) }.value,
              let secondScore = try? Task { try await analyze(text: secondHalf) }.value else {
            return nil
        }
        
        let valenceShift = secondScore.valence - firstScore.valence
        let arousalShift = secondScore.arousal - firstScore.arousal
        
        guard abs(valenceShift) > 0.2 || abs(arousalShift) > 0.2 else {
            return nil
        }
        
        return EmotionalShift(
            from: firstScore,
            to: secondScore,
            valenceShift: valenceShift,
            arousalShift: arousalShift
        )
    }
    
    // MARK: - Private Methods
    
    private func detectMultipleEmotions(_ text: String) -> [EmotionCategory: Float] {
        var scores: [EmotionCategory: Float] = [:]
        
        // 感情キーワードの検出
        let emotionKeywords: [EmotionCategory: [String]] = [
            .joy: ["happy", "joy", "excited", "delighted", "pleased", "glad", "cheerful",
                   "嬉しい", "喜び", "興奮", "楽しい", "幸せ", "愉快"],
            .sadness: ["sad", "sorrowful", "depressed", "melancholy", "gloomy", "down",
                       "悲しい", "憂鬱", "落ち込む", "寂しい", "切ない"],
            .anger: ["angry", "mad", "furious", "irritated", "annoyed", "upset",
                     "怒り", "腹立つ", "イライラ", "憤り", "不満"],
            .fear: ["afraid", "scared", "worried", "anxious", "nervous", "terrified",
                    "恐い", "心配", "不安", "恐怖", "怯える"],
            .surprise: ["surprised", "amazed", "shocked", "astonished", "stunned",
                        "驚いた", "びっくり", "意外", "驚愕"],
            .disgust: ["disgusted", "revolted", "sick", "nauseated", "repulsed",
                       "嫌悪", "気持ち悪い", "うんざり", "嫌い"]
        ]
        
        let lowercasedText = text.lowercased()
        let words = lowercasedText.components(separatedBy: .whitespacesAndNewlines)
        let totalWords = max(words.count, 1)
        
        for (emotion, keywords) in emotionKeywords {
            var count = 0
            for keyword in keywords {
                if lowercasedText.contains(keyword) {
                    count += text.components(separatedBy: keyword).count - 1
                }
            }
            scores[emotion] = Float(count) / Float(totalWords)
        }
        
        // 肯定・否定キーワードによる調整
        let positiveKeywords = ["not bad", "not sad", "not angry", "isn't sad", "isn't angry"]
        let negativeKeywords = ["not good", "not happy", "isn't good", "isn't happy"]
        
        for keyword in positiveKeywords {
            if lowercasedText.contains(keyword) {
                scores[.joy] = (scores[.joy] ?? 0) + 0.2
                scores[.sadness] = max(0, (scores[.sadness] ?? 0) - 0.2)
            }
        }
        
        for keyword in negativeKeywords {
            if lowercasedText.contains(keyword) {
                scores[.sadness] = (scores[.sadness] ?? 0) + 0.2
                scores[.joy] = max(0, (scores[.joy] ?? 0) - 0.2)
            }
        }
        
        return scores
    }
    
    private func calculateIntensity(_ text: String) -> Float {
        var intensity: Float = 0.0
        
        // 感嘆符の密度
        let exclamationDensity = Float(text.filter { $0 == "!" }.count) / Float(max(text.count, 1))
        intensity += exclamationDensity * 0.3
        
        // 大文字の使用
        let capsDensity = Float(text.filter { $0.isUppercase }.count) / Float(max(text.count, 1))
        intensity += capsDensity * 0.3
        
        // 繰り返し文字
        let repeatedChars = text.matches(of: /(.)\1{2,}/).count
        intensity += Float(repeatedChars) * 0.1
        
        // 感情語の使用
        let emotionWords = ["really", "very", "extremely", "absolutely", "completely",
                            "とても", "非常に", "超", "めっちゃ", "とっても"]
        let emotionWordCount = Float(emotionWords.filter { text.lowercased().contains($0) }.count)
        intensity += emotionWordCount * 0.1
        
        return min(1.0, intensity)
    }
    
    private func analyzeContext(_ text: String) -> EmotionContext {
        let lowercasedText = text.lowercased()
        
        var domains: [EmotionDomain] = []
        var triggers: [EmotionTrigger] = []
        
        // ドメインの検出
        if lowercasedText.contains("work") || lowercasedText.contains("仕事") {
            domains.append(.work)
        }
        if lowercasedText.contains("family") || lowercasedText.contains("家族") {
            domains.append(.family)
        }
        if lowercasedText.contains("health") || lowercasedText.contains("健康") {
            domains.append(.health)
        }
        if lowercasedText.contains("friend") || lowercasedText.contains("友達") {
            domains.append(.relationships)
        }
        if lowercasedText.contains("money") || lowercasedText.contains("金") {
            domains.append(.finance)
        }
        
        // トリガーの検出
        if lowercasedText.contains("deadline") || lowercasedText.contains("締切") {
            triggers.append(.deadline)
        }
        if lowercasedText.contains("meeting") || lowercasedText.contains("会議") {
            triggers.append(.socialEvent)
        }
        if lowercasedText.contains("achievement") || lowercasedText.contains("達成") {
            triggers.append(.achievement)
        }
        if lowercasedText.contains("conflict") || lowercasedText.contains("衝突") {
            triggers.append(.conflict)
        }
        
        return EmotionContext(
            domains: domains.isEmpty ? [.general] : domains,
            triggers: triggers
        )
    }
    
    private func selectPrimaryEmotion(from emotions: [EmotionCategory: Float]) -> EmotionCategory {
        return emotions.max(by: { $0.value < $1.value })?.key ?? .joy
    }
    
    private func getSecondaryEmotions(from emotions: [EmotionCategory: Float], topN: Int = 2) -> [EmotionCategory] {
        return emotions.sorted(by: { $0.value > $1.value })
            .prefix(topN)
            .map { $0.key }
    }
}

// MARK: - Advanced Result Types

struct MultipleEmotionResult {
    let primaryEmotion: EmotionCategory
    let secondaryEmotions: [EmotionCategory]
    let intensity: Float
    let context: EmotionContext
    let baseScore: EmotionScore
}

struct EmotionalShift {
    let from: EmotionScore
    let to: EmotionScore
    let valenceShift: Float
    let arousalShift: Float
    
    var isPositive: Bool {
        valenceShift > 0
    }
    
    var shiftMagnitude: Float {
        return sqrt(valenceShift * valenceShift + arousalShift * arousalShift)
    }
}

struct EmotionContext {
    let domains: [EmotionDomain]
    let triggers: [EmotionTrigger]
}

enum EmotionDomain: String, CaseIterable {
    case work = "work"
    case family = "family"
    case health = "health"
    case relationships = "relationships"
    case finance = "finance"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .work: return "仕事"
        case .family: return "家族"
        case .health: return "健康"
        case .relationships: return "人間関係"
        case .finance: return "お金"
        case .general: return "一般"
        }
    }
}

enum EmotionTrigger: String, CaseIterable {
    case deadline = "deadline"
    case socialEvent = "social_event"
    case achievement = "achievement"
    case conflict = "conflict"
    case loss = "loss"
    case success = "success"
    
    var displayName: String {
        switch self {
        case .deadline: return "締切"
        case .socialEvent: return "社交イベント"
        case .achievement: return "達成"
        case .conflict: return "衝突"
        case .loss: return "喪失"
        case .success: return "成功"
        }
    }
}


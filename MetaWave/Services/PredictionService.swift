//
//  PredictionService.swift
//  MetaWave
//
//  v2.3: 予測機能サービス
//

import Foundation
import CoreData
import SwiftUI
import Combine

/// 予測機能サービス
final class PredictionService: ObservableObject {
    
    private let context: NSManagedObjectContext
    private let patternService: PatternAnalysisService
    
    @Published var predictions: [Prediction] = []
    
    init(context: NSManagedObjectContext, patternService: PatternAnalysisService) {
        self.context = context
        self.patternService = patternService
    }
    
    // MARK: - 予測生成
    
    func generatePredictions(completion: @escaping ([Prediction]) -> Void) {
        Task {
            var predictions: [Prediction] = []
            
            // 1. 感情トレンド予測
            if let emotionPrediction = predictEmotionTrend() {
                predictions.append(emotionPrediction)
            }
            
            // 2. ループパターン予測
            if let loopPrediction = predictLoopPattern() {
                predictions.append(loopPrediction)
            }
            
            // 3. バイアス傾向予測
            if let biasPrediction = predictBiasTendency() {
                predictions.append(biasPrediction)
            }
            
            await MainActor.run {
                self.predictions = predictions
                completion(predictions)
            }
        }
    }
    
    // MARK: - Private Prediction Methods
    
    private func predictEmotionTrend() -> Prediction? {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "contentText != nil AND createdAt >= %@",
                                      Calendar.current.date(byAdding: .day, value: -7, to: Date())! as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: true)]
        
        guard let notes = try? context.fetch(request), notes.count >= 5 else {
            return nil
        }
        
        let recentScores = notes.compactMap { $0.getEmotionScore() }
        guard recentScores.count >= 3 else { return nil }
        
        // 直近3日間の平均感情スコア
        let lastScores = recentScores.suffix(3)
        let avgValence = lastScores.map { $0.valence }.reduce(0, +) / Float(lastScores.count)
        let avgArousal = lastScores.map { $0.arousal }.reduce(0, +) / Float(lastScores.count)
        
        // その前3日間の平均感情スコア
        let previousScores = recentScores.prefix(recentScores.count - 3).suffix(3)
        guard previousScores.count >= 2 else { return nil }
        let prevAvgValence = previousScores.map { $0.valence }.reduce(0, +) / Float(previousScores.count)
        let prevAvgArousal = previousScores.map { $0.arousal }.reduce(0, +) / Float(previousScores.count)
        
        // トレンドの判定
        let valenceTrend = avgValence - prevAvgValence
        let arousalTrend = avgArousal - prevAvgArousal
        
        let trendType: PredictionType
        var message = ""
        var confidence: Float = 0.7
        
        if valenceTrend > 0.2 && abs(valenceTrend) > 0.1 {
            trendType = .positiveTrend
            message = "最近の記録でポジティブな感情が増加しています。この調子で良い状態が続く可能性があります。"
            confidence = min(0.9, 0.6 + abs(valenceTrend))
        } else if valenceTrend < -0.2 && abs(valenceTrend) > 0.1 {
            trendType = .negativeTrend
            message = "最近の記録でネガティブな感情が増加しています。休息やポジティブな活動を意識すると良いかもしれません。"
            confidence = min(0.9, 0.6 + abs(valenceTrend))
        } else if arousalTrend > 0.2 {
            trendType = .highArousal
            message = "最近の記録で覚醒度が高くなっています。リラックス時間を確保することをお勧めします。"
            confidence = 0.7
        } else {
            trendType = .stable
            message = "感情状態は比較的安定しています。"
            confidence = 0.6
        }
        
        return Prediction(
            type: trendType,
            title: "感情トレンド予測",
            message: message,
            confidence: confidence,
            impact: calculateImpact(valenceTrend: valenceTrend, arousalTrend: arousalTrend),
            timeframe: "今後1週間"
        )
    }
    
    private func predictLoopPattern() -> Prediction? {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "modality == 'text'")
        
        guard let notes = try? context.fetch(request), notes.count >= 10 else {
            return nil
        }
        
        // 類似パターンの検出
        let topics = extractCommonTopics(from: notes)
        
        guard !topics.isEmpty, let topTopic = topics.first else { return nil }
        
        // 最近の出現頻度を計算
        let recentNotes = notes.filter { note in
            guard let createdAt = note.createdAt else { return false }
            return createdAt >= Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }
        
        let recentTopicCount = countTopicOccurrences(topic: topTopic, in: recentNotes)
        let oldTopicCount = countTopicOccurrences(topic: topTopic, in: notes.filter { !recentNotes.contains($0) })
        
        let frequencyIncrease = Float(recentTopicCount) / Float(max(oldTopicCount, 1))
        
        if frequencyIncrease > 1.5 && recentTopicCount >= 3 {
            return Prediction(
                type: .recurringPattern,
                title: "繰り返しパターン",
                message: "「\(topTopic)」に関する思考パターンが繰り返し出現しています。意識的にこのパターンを観察し、変化の余地があるかを検討することをお勧めします。",
                confidence: min(0.8, 0.5 + frequencyIncrease * 0.1),
                impact: .medium,
                timeframe: "現在継続中"
            )
        }
        
        return nil
    }
    
    private func predictBiasTendency() -> Prediction? {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        
        guard let notes = try? context.fetch(request), notes.count >= 10 else {
            return nil
        }
        
        var biasCounts: [String: Int] = [:]
        
        for note in notes {
            // 簡易的なバイアス検出
            if isNegativeBias(note) {
                biasCounts["negative_bias", default: 0] += 1
            }
            if isConfirmationBias(note, in: notes) {
                biasCounts["confirmation_bias", default: 0] += 1
            }
        }
        
        let totalBiasCount = biasCounts.values.reduce(0, +)
        let biasRatio = Float(totalBiasCount) / Float(notes.count)
        
        if biasRatio > 0.3, let dominantBiasKey = biasCounts.max(by: { $0.value < $1.value })?.key {
            let displayName = dominantBiasKey.replacingOccurrences(of: "_", with: " ").capitalized
            return Prediction(
                type: .biasDetection,
                title: "認知バイアス傾向",
                message: "\(displayName)の傾向が見られます。異なる視点から考える機会を増やすことをお勧めします。",
                confidence: min(0.8, biasRatio),
                impact: .high,
                timeframe: "継続中"
            )
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func extractCommonTopics(from notes: [Note]) -> [String] {
        var wordFrequency: [String: Int] = [:]
        
        for note in notes {
            guard let text = note.contentText?.lowercased() else { continue }
            let words = text.components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 } // 3文字以上の単語のみ
            
            for word in words {
                wordFrequency[word, default: 0] += 1
            }
        }
        
        // 共通語を除外
        let stopWords = ["the", "this", "that", "with", "from", "about",
                         "この", "その", "もの", "こと", "ため", "それ"]
        
        for stopWord in stopWords {
            wordFrequency.removeValue(forKey: stopWord)
        }
        
        return wordFrequency.sorted(by: { $0.value > $1.value })
            .prefix(5)
            .map { $0.key }
    }
    
    private func countTopicOccurrences(topic: String, in notes: [Note]) -> Int {
        return notes.filter { note in
            note.contentText?.lowercased().contains(topic.lowercased()) ?? false
        }.count
    }
    
    private func isNegativeBias(_ note: Note) -> Bool {
        guard let score = note.getEmotionScore() else { return false }
        return score.valence < -0.3
    }
    
    private func isConfirmationBias(_ note: Note, in allNotes: [Note]) -> Bool {
        guard let text = note.contentText?.lowercased() else { return false }
        
        let confirmKeywords = ["always", "never", "everyone", "nobody", "completely", "absolutely",
                               "いつも", "絶対", "完全", "全く"]
        
        return confirmKeywords.contains { text.contains($0) }
    }
    
    private func calculateImpact(valenceTrend: Float, arousalTrend: Float) -> PredictionImpact {
        let totalChange = abs(valenceTrend) + abs(arousalTrend)
        
        if totalChange > 0.4 {
            return .high
        } else if totalChange > 0.2 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Data Models

struct Prediction: Identifiable {
    let id = UUID()
    let type: PredictionType
    let title: String
    let message: String
    let confidence: Float
    let impact: PredictionImpact
    let timeframe: String
}

enum PredictionType: String, CaseIterable {
    case positiveTrend = "positive_trend"
    case negativeTrend = "negative_trend"
    case stable = "stable"
    case highArousal = "high_arousal"
    case recurringPattern = "recurring_pattern"
    case biasDetection = "bias_detection"
    
    var displayName: String {
        switch self {
        case .positiveTrend: return "ポジティブトレンド"
        case .negativeTrend: return "ネガティブトレンド"
        case .stable: return "安定"
        case .highArousal: return "高覚醒"
        case .recurringPattern: return "繰り返しパターン"
        case .biasDetection: return "バイアス検出"
        }
    }
    
    var icon: String {
        switch self {
        case .positiveTrend: return "arrow.up.circle.fill"
        case .negativeTrend: return "arrow.down.circle.fill"
        case .stable: return "equal.circle.fill"
        case .highArousal: return "exclamationmark.circle.fill"
        case .recurringPattern: return "repeat.circle.fill"
        case .biasDetection: return "eye.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .positiveTrend: return "green"
        case .negativeTrend: return "red"
        case .stable: return "blue"
        case .highArousal: return "orange"
        case .recurringPattern: return "purple"
        case .biasDetection: return "yellow"
        }
    }
}

enum PredictionImpact: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}


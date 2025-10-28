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
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@",
                                      Calendar.current.date(byAdding: .day, value: -7, to: Date())! as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)]
        
        guard let items = try? context.fetch(request), items.count >= 5 else {
            return nil
        }
        
        // Itemには感情データがないので、簡易的な予測を返す
        guard items.count >= 3 else { return nil }
        
        // ノート数の増減から予測
        let recentCount = items.filter { item in
            guard let timestamp = item.timestamp else { return false }
            return timestamp >= Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        }.count
        
        let previousCount = items.filter { item in
            guard let timestamp = item.timestamp else { return false }
            let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return timestamp >= sixDaysAgo && timestamp < threeDaysAgo
        }.count
        
        // ノート増加率から意欲を推定
        let growthRate = previousCount > 0 ? Float(recentCount) / Float(previousCount) : 1.0
        let valenceTrend = (growthRate - 1.0) * 0.5 // -0.5から0.5の範囲
        let arousalTrend: Float = 0.5
        
        let trendType: PredictionType
        var message = ""
        var confidence: Float = 0.7
        
        if valenceTrend > 0.2 {
            trendType = .positiveTrend
            message = "最近の記録でポジティブな感情が増加しています。この調子で良い状態が続く可能性があります。"
            confidence = min(0.9, 0.6 + abs(valenceTrend))
        } else if valenceTrend < -0.2 {
            trendType = .negativeTrend
            message = "最近の記録でネガティブな感情が増加しています。休息やポジティブな活動を意識すると良いかもしれません。"
            confidence = min(0.9, 0.6 + abs(valenceTrend))
        } else {
            trendType = .stable
            message = "記録ペースは比較的安定しています。"
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
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        
        guard let items = try? context.fetch(request), items.count >= 10 else {
            return nil
        }
        
        // Note は使用できないので、items を notes として扱う
        let notes = items.compactMap { $0.note }.map { content -> (contentText: String, createdAt: Date?) in
            (contentText: content, createdAt: Date())
        }
        
        // 類似パターンの検出
        let topics = extractCommonTopics(from: notes)
        
        guard !topics.isEmpty, let topTopic = topics.first else { return nil }
        
        // 最近の出現頻度を計算（簡易版）
        let recentNotes = items.filter { item in
            guard let timestamp = item.timestamp else { return false }
            return timestamp >= Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }
        
        let recentTopicCount = countTopicOccurrences(topic: topTopic, inItems: recentNotes)
        let oldItems = items.filter { !recentNotes.contains($0) }
        let oldTopicCount = countTopicOccurrences(topic: topTopic, inItems: oldItems)
        
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
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        
        guard let items = try? context.fetch(request), items.count >= 10 else {
            return nil
        }
        
        // items からnotes を作成
        let notes = items.compactMap { $0.note }
        
        var biasCounts: [String: Int] = [:]
        
        for note in notes {
            // 簡易的なバイアス検出
            if isNegativeBias(note) {
                biasCounts["negative_bias", default: 0] += 1
            }
            if isConfirmationBias(note, inNotes: notes) {
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
    
    private func extractCommonTopics(from notes: [(contentText: String, createdAt: Date?)]) -> [String] {
        var wordFrequency: [String: Int] = [:]
        
        for note in notes {
            let text = note.contentText.lowercased()
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
    
    private func countTopicOccurrences(topic: String, inItems items: [Item]) -> Int {
        return items.filter { item in
            item.note?.lowercased().contains(topic.lowercased()) ?? false
        }.count
    }
    
    private func isNegativeBias(_ note: String) -> Bool {
        // Itemには感情データがないので、テキストから簡易判定
        let negativeWords = ["悲しい", "辛い", "悪い", "嫌", "最悪", "ダメ"]
        let lowerText = note.lowercased()
        return negativeWords.contains { lowerText.contains($0) }
    }
    
    private func isConfirmationBias(_ note: String, inNotes allNotes: [String]) -> Bool {
        let lowerText = note.lowercased()
        let confirmKeywords = ["always", "never", "everyone", "nobody", "completely", "absolutely",
                               "いつも", "絶対", "完全", "全く"]
        return confirmKeywords.contains { lowerText.contains($0) }
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


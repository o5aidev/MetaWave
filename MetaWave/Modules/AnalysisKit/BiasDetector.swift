//
//  BiasDetector.swift
//  MetaWave
//
//  Miyabi仕様: 認知バイアス検出実装
//

import Foundation
import NaturalLanguage

/// 認知バイアス検出実装
final class BiasDetector: BiasSignalDetector {
    
    // MARK: - BiasSignalDetector Protocol
    
    func evaluate(notes: [Note]) async -> [BiasSignal: Float] {
        return await withCheckedContinuation { continuation in
            detectBiases(notes) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func detectBiases(_ notes: [Note], completion: @escaping ([BiasSignal: Float]) -> Void) {
        var biasScores: [BiasSignal: Float] = [:]
        
        // 各バイアスを検出
        biasScores[.confirmationBias] = detectConfirmationBias(notes)
        biasScores[.availabilityBias] = detectAvailabilityBias(notes)
        biasScores[.anchoringBias] = detectAnchoringBias(notes)
        biasScores[.lossAversion] = detectLossAversion(notes)
        biasScores[.sunkCost] = detectSunkCostBias(notes)
        
        completion(biasScores)
    }
    
    // MARK: - Individual Bias Detection
    
    /// 確証バイアス検出
    private func detectConfirmationBias(_ notes: [Note]) -> Float {
        let textNotes = notes.filter { $0.modality == "text" && $0.contentText != nil }
        guard textNotes.count >= 3 else { return 0.0 }
        
        var confirmationScore: Float = 0.0
        
        // 1. 極端な表現の頻度
        let extremeWords = ["always", "never", "all", "none", "everyone", "nobody", "完全に", "絶対に", "すべて", "誰も"]
        let extremeCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + extremeWords.filter { text.contains($0) }.count
        }
        confirmationScore += Float(extremeCount) / Float(textNotes.count) * 0.3
        
        // 2. 否定的な表現の偏り
        let negativeWords = ["but", "however", "although", "despite", "しかし", "でも", "けれども"]
        let negativeCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + negativeWords.filter { text.contains($0) }.count
        }
        confirmationScore += Float(negativeCount) / Float(textNotes.count) * 0.2
        
        // 3. 感情の一貫性（同じ方向の感情が続く）
        let emotionScores = textNotes.compactMap { $0.getEmotionScore() }
        if emotionScores.count >= 3 {
            let valenceValues = emotionScores.map { $0.valence }
            let consistency = calculateEmotionConsistency(valenceValues)
            confirmationScore += consistency * 0.5
        }
        
        return min(1.0, confirmationScore)
    }
    
    /// 利用可能性バイアス検出
    private func detectAvailabilityBias(_ notes: [Note]) -> Float {
        let textNotes = notes.filter { $0.modality == "text" && $0.contentText != nil }
        guard textNotes.count >= 5 else { return 0.0 }
        
        var availabilityScore: Float = 0.0
        
        // 1. 最近の出来事への過度な言及
        let recentKeywords = ["recently", "lately", "just happened", "最近", "この間", "先日"]
        let recentCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + recentKeywords.filter { text.contains($0) }.count
        }
        availabilityScore += Float(recentCount) / Float(textNotes.count) * 0.4
        
        // 2. 感情的な出来事への偏り
        let emotionalWords = ["shocking", "amazing", "terrible", "incredible", "驚き", "すごい", "ひどい", "信じられない"]
        let emotionalCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + emotionalWords.filter { text.contains($0) }.count
        }
        availabilityScore += Float(emotionalCount) / Float(textNotes.count) * 0.3
        
        // 3. 個人的な経験への過度な依存
        let personalWords = ["I think", "I feel", "I believe", "私の考え", "私の感じ", "私の意見"]
        let personalCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + personalWords.filter { text.contains($0) }.count
        }
        availabilityScore += Float(personalCount) / Float(textNotes.count) * 0.3
        
        return min(1.0, availabilityScore)
    }
    
    /// アンカリングバイアス検出
    private func detectAnchoringBias(_ notes: [Note]) -> Float {
        let textNotes = notes.filter { $0.modality == "text" && $0.contentText != nil }
        guard textNotes.count >= 3 else { return 0.0 }
        
        var anchoringScore: Float = 0.0
        
        // 1. 数値の最初の提示への依存
        let numberPattern = try! NSRegularExpression(pattern: "\\d+")
        var firstNumbers: [Int] = []
        
        for note in textNotes {
            let text = note.contentText!
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = numberPattern.firstMatch(in: text, range: range) {
                let numberString = (text as NSString).substring(with: match.range)
                if let number = Int(numberString) {
                    firstNumbers.append(number)
                }
            }
        }
        
        if firstNumbers.count >= 2 {
            let variance = calculateVariance(firstNumbers)
            anchoringScore += (1.0 - min(1.0, variance / 100.0)) * 0.4
        }
        
        // 2. 比較表現の頻度
        let comparisonWords = ["compared to", "versus", "vs", "compared with", "比較して", "対して", "比べて"]
        let comparisonCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + comparisonWords.filter { text.contains($0) }.count
        }
        anchoringScore += Float(comparisonCount) / Float(textNotes.count) * 0.3
        
        // 3. 最初の印象への言及
        let firstImpressionWords = ["first", "initially", "at first", "最初", "初め", "最初に"]
        let firstImpressionCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + firstImpressionWords.filter { text.contains($0) }.count
        }
        anchoringScore += Float(firstImpressionCount) / Float(textNotes.count) * 0.3
        
        return min(1.0, anchoringScore)
    }
    
    /// 損失回避バイアス検出
    private func detectLossAversion(_ notes: [Note]) -> Float {
        let textNotes = notes.filter { $0.modality == "text" && $0.contentText != nil }
        guard textNotes.count >= 3 else { return 0.0 }
        
        var lossAversionScore: Float = 0.0
        
        // 1. 損失に関する表現の頻度
        let lossWords = ["lose", "loss", "waste", "miss", "fail", "失う", "損失", "無駄", "失敗"]
        let lossCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + lossWords.filter { text.contains($0) }.count
        }
        lossAversionScore += Float(lossCount) / Float(textNotes.count) * 0.4
        
        // 2. リスク回避の表現
        let riskWords = ["safe", "secure", "avoid", "prevent", "安全", "安心", "避ける", "防ぐ"]
        let riskCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + riskWords.filter { text.contains($0) }.count
        }
        lossAversionScore += Float(riskCount) / Float(textNotes.count) * 0.3
        
        // 3. ネガティブな感情の頻度
        let emotionScores = textNotes.compactMap { $0.getEmotionScore() }
        if !emotionScores.isEmpty {
            let negativeEmotionRatio = emotionScores.filter { $0.valence < -0.2 }.count / Float(emotionScores.count)
            lossAversionScore += negativeEmotionRatio * 0.3
        }
        
        return min(1.0, lossAversionScore)
    }
    
    /// サンクコストバイアス検出
    private func detectSunkCostBias(_ notes: [Note]) -> Float {
        let textNotes = notes.filter { $0.modality == "text" && $0.contentText != nil }
        guard textNotes.count >= 3 else { return 0.0 }
        
        var sunkCostScore: Float = 0.0
        
        // 1. 投資・努力に関する表現
        let investmentWords = ["invested", "effort", "time", "money", "energy", "投資", "努力", "時間", "お金", "エネルギー"]
        let investmentCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + investmentWords.filter { text.contains($0) }.count
        }
        sunkCostScore += Float(investmentCount) / Float(textNotes.count) * 0.3
        
        // 2. 継続・続行の表現
        let continuationWords = ["continue", "keep going", "persist", "stick with", "続ける", "継続", "続行", "粘る"]
        let continuationCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + continuationWords.filter { text.contains($0) }.count
        }
        sunkCostScore += Float(continuationCount) / Float(textNotes.count) * 0.3
        
        // 3. 過去の決定への言及
        let pastDecisionWords = ["already", "since", "because", "given that", "すでに", "だから", "なので", "ということで"]
        let pastDecisionCount = textNotes.reduce(0) { count, note in
            let text = note.contentText!.lowercased()
            return count + pastDecisionWords.filter { text.contains($0) }.count
        }
        sunkCostScore += Float(pastDecisionCount) / Float(textNotes.count) * 0.4
        
        return min(1.0, sunkCostScore)
    }
    
    // MARK: - Helper Methods
    
    private func calculateEmotionConsistency(_ values: [Float]) -> Float {
        guard values.count >= 2 else { return 0.0 }
        
        let positiveCount = values.filter { $0 > 0.1 }.count
        let negativeCount = values.filter { $0 < -0.1 }.count
        let totalCount = values.count
        
        let maxConsistency = max(positiveCount, negativeCount)
        return Float(maxConsistency) / Float(totalCount)
    }
    
    private func calculateVariance(_ numbers: [Int]) -> Float {
        guard numbers.count > 1 else { return 0.0 }
        
        let mean = Float(numbers.reduce(0, +)) / Float(numbers.count)
        let squaredDifferences = numbers.map { pow(Float($0) - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Float(numbers.count)
        
        return variance
    }
}

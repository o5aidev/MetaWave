//
//  AnalysisService.swift
//  MetaWave
//
//  Miyabi仕様: 分析サービス統合
//

import Foundation
import CoreData
import SwiftUI
import Combine

/// 分析サービス統合クラス
final class AnalysisService: ObservableObject {
    
    private let emotionAnalyzer: EmotionAnalyzer
    private let loopDetector: LoopDetector
    private let biasDetector: BiasSignalDetector
    private let context: NSManagedObjectContext
    private let performanceMonitor = PerformanceMonitor.shared
    private let performanceOptimizer = PerformanceOptimizer.shared
    private let errorHandler = ErrorHandler.shared
    private let analysisState = AnalysisStateStore()
    
    @Published var isAnalyzing = false
    @Published var analysisProgress: Float = 0.0
    
    init(
        emotionAnalyzer: EmotionAnalyzer = TextEmotionAnalyzer(),
        loopDetector: LoopDetector = TextLoopDetector(),
        biasDetector: BiasSignalDetector = BiasDetector(),
        context: NSManagedObjectContext
    ) {
        self.emotionAnalyzer = emotionAnalyzer
        self.loopDetector = loopDetector
        self.biasDetector = biasDetector
        self.context = context
        
        // パフォーマンス最適化を初期化
        performanceOptimizer.configureImageCache()
        performanceOptimizer.optimizeDatabaseQueries(context: context)
    }
    
    // MARK: - Public Methods
    
    /// ノートの感情分析を実行
    func analyzeEmotion(for note: Note) async throws {
        guard let contentText = note.contentText, !contentText.isEmpty else {
            return
        }
        
        let emotionScore = try await emotionAnalyzer.analyze(text: contentText)
        
        await MainActor.run {
            note.setEmotionScore(emotionScore)
            note.updatedAt = Date()
            
            do {
                try context.save()
            } catch {
                print("Failed to save emotion analysis: \(error)")
            }
        }
    }
    
    /// 全ノートの感情分析を実行
    func analyzeAllEmotions() async throws {
        await MainActor.run {
            isAnalyzing = true
            analysisProgress = 0.0
        }
        
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "contentText != nil AND contentText != ''")
        
        let notes = try context.fetch(request)
        let totalNotes = notes.count
        
        for (index, note) in notes.enumerated() {
            try await analyzeEmotion(for: note)
            
            await MainActor.run {
                analysisProgress = Float(index + 1) / Float(totalNotes)
            }
        }
        
        await MainActor.run {
            isAnalyzing = false
            analysisProgress = 0.0
        }
    }
    
    /// ループ検出を実行
    func detectLoops() async throws -> [LoopCluster] {
        await MainActor.run {
            isAnalyzing = true
            analysisProgress = 0.0
        }
        let clusters = try await performLoopDetectionCore()
        
        await MainActor.run {
            isAnalyzing = false
            analysisProgress = 0.0
        }
        
        return clusters
    }
    
    /// 包括的分析を実行
    func performComprehensiveAnalysis() async throws -> AnalysisResult {
        return try await performanceMonitor.executeBackgroundTask {
            await MainActor.run {
                isAnalyzing = true
                analysisProgress = 0.0
            }
            
            // パフォーマンス最適化を適用
            performanceOptimizer.optimizeBackgroundProcessing()
            
            let settings = performanceMonitor.getOptimalAnalysisSettings()
            
            do {
                // 1. 感情分析（最適化済み）
                try await performanceMonitor.measurePhase("Emotion Analysis") {
                    try await analyzeAllEmotionsOptimized(settings: settings)
                }
                await MainActor.run { analysisProgress = 0.25 }
                
                // 2. ループ検出
                let clusters = try await performanceMonitor.measurePhase("Loop Detection") {
                    try await performLoopDetectionCore()
                }
                await MainActor.run { analysisProgress = 0.5 }
                
                // 3. バイアス検出
                let biasSignals = try await performanceMonitor.measurePhase("Bias Detection") {
                    try await detectBiases()
                }
                await MainActor.run { analysisProgress = 0.75 }
                
                // 4. 統計情報の生成
                let statistics = try await performanceMonitor.measurePhase("Statistics Generation") {
                    try await generateStatistics()
                }
                await MainActor.run { analysisProgress = 0.9 }
                
                // 5. インサイトの生成
                let insights = try await performanceMonitor.measurePhase("Insight Generation") {
                    try await generateInsights(clusters: clusters, statistics: statistics, biasSignals: biasSignals)
                }
                await MainActor.run { analysisProgress = 1.0 }
                
                await MainActor.run {
                    isAnalyzing = false
                    analysisProgress = 0.0
                }
                
                let result = AnalysisResult(
                    clusters: clusters,
                    statistics: statistics,
                    insights: insights,
                    biasSignals: biasSignals
                )
                
                analysisState.lastComprehensiveAnalysisDate = Date()
                await MainActor.run {
                    analysisProgress = 0.0
                }
                return result
            } catch {
                errorHandler.logError(error, context: "Comprehensive Analysis")
                await MainActor.run {
                    isAnalyzing = false
                    analysisProgress = 0.0
                }
                throw error
            }
        }
    }
    
    // MARK: - Performance Optimized Methods
    
    /// 最適化された感情分析
    private func analyzeEmotionsOptimized(notes: [Note]) async throws -> [EmotionScore] {
        let batchSize = 10 // バッチサイズを制限
        var results: [EmotionScore] = []
        
        for i in stride(from: 0, to: notes.count, by: batchSize) {
            let batch = Array(notes[i..<min(i + batchSize, notes.count)])
            
            // 並列処理で感情分析を実行
            let batchResults = await withTaskGroup(of: EmotionScore?.self) { group in
                var batchResults: [EmotionScore] = []
                
                for note in batch {
                    group.addTask {
                        do {
                            return try await self.emotionAnalyzer.analyze(text: note.contentText ?? "")
            } catch {
                            return nil
                        }
                    }
                }
                
                for await result in group {
                    if let emotionScore = result {
                        batchResults.append(emotionScore)
                    }
                }
                
                return batchResults
            }
            
            results.append(contentsOf: batchResults)
            
            // メモリクリーンアップ
            if i % (batchSize * 5) == 0 {
                performanceOptimizer.performMemoryCleanup()
            }
        }
        
        return results
    }
    
    /// 最適化されたパターン分析
    private func analyzePatternsOptimized(notes: [Note]) async throws -> [LoopCluster] {
        // メモリ効率的なパターン分析
        let clusters = try await loopDetector.cluster(notes: notes)
        
        // 結果をキャッシュに保存
        // キャッシュロジックは後で実装
        
        return clusters
    }
    
    /// 最適化されたバイアス分析
    private func analyzeBiasOptimized(notes: [Note]) async -> [BiasSignal: Float] {
        // 並列処理でバイアス分析を実行
        return await biasDetector.evaluate(notes: notes)
    }
    
    // MARK: - Private Methods
    
    /// 最適化された感情分析
    private func analyzeAllEmotionsOptimized(settings: AnalysisSettings) async throws {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "contentText != nil AND contentText != ''")
        ]
        if let lastAnalysisDate = analysisState.lastEmotionAnalysisDate {
            predicates.append(NSPredicate(format: "updatedAt > %@", lastAnalysisDate as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchBatchSize = settings.batchSize * 2
        
        let notes = try fetchNotesSync(request)
        let totalNotes = notes.count
        
        guard totalNotes > 0 else {
            analysisState.lastEmotionAnalysisDate = Date()
            return
        }
        
        // バッチ処理
        let batchSize = settings.batchSize
        for i in stride(from: 0, to: totalNotes, by: batchSize) {
            let endIndex = min(i + batchSize, totalNotes)
            let batch = Array(notes[i..<endIndex])
            
            // 並列処理（制限付き）
            await withTaskGroup(of: Void.self) { group in
                let maxConcurrent = settings.maxConcurrentOperations
                var activeTasks = 0
            
            for note in batch {
                    if activeTasks >= maxConcurrent {
                        await group.next()
                        activeTasks -= 1
                    }
                    
                    group.addTask {
                do {
                    try await self.analyzeEmotion(for: note)
                } catch {
                            self.errorHandler.logError(error, context: "Emotion Analysis")
                        }
                    }
                    activeTasks += 1
                }
                
                await group.waitForAll()
            }
            
            // 進捗更新
            await MainActor.run {
                let denominator = max(1, totalNotes)
                analysisProgress = Float(endIndex) / Float(denominator) * 0.25
            }
        }
        analysisState.lastEmotionAnalysisDate = Date()
    }
    
    /// バイアス検出
    private func detectBiases() async throws -> [BiasSignal: Float] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.fetchBatchSize = 50
        let notes = try fetchNotesSync(request)
        
        return await biasDetector.evaluate(notes: notes)
    }
    
    private func performLoopDetectionCore() async throws -> [LoopCluster] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "modality == 'text'")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: true)]
        request.fetchBatchSize = 50
        
        let notes = try fetchNotesSync(request)
        let clusters = try await loopDetector.cluster(notes: notes)
        
        await saveLoopInsights(clusters)
        return clusters
    }
    
    private func saveLoopInsights(_ clusters: [LoopCluster]) async {
        await MainActor.run {
            for cluster in clusters {
                let insight = Insight.create(
                    kind: .loop,
                    noteIDs: cluster.noteIDs,
                    in: context
                )
                
                // ペイロードにクラスタ情報を保存
                let payload = LoopInsightPayload(
                    topic: cluster.topic,
                    strength: cluster.strength,
                    noteCount: cluster.noteIDs.count,
                    timeSpan: calculateTimeSpan(for: cluster.noteIDs)
                )
                
                do {
                    try insight.setPayload(payload)
                    try context.save()
                } catch {
                    print("Failed to save loop insight: \(error)")
                }
            }
        }
    }
    
    private func generateStatistics() async throws -> AnalysisStatistics {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try context.fetch(request)
        
        let textNotes = notes.filter { $0.modality == "text" }
        let audioNotes = notes.filter { $0.modality == "audio" }
        
        let emotionScores = textNotes.compactMap { $0.getEmotionScore() }
        let averageValence = emotionScores.isEmpty ? 0.0 : emotionScores.map { $0.valence }.reduce(0, +) / Float(emotionScores.count)
        let averageArousal = emotionScores.isEmpty ? 0.0 : emotionScores.map { $0.arousal }.reduce(0, +) / Float(emotionScores.count)
        
        return AnalysisStatistics(
            totalNotes: notes.count,
            textNotes: textNotes.count,
            audioNotes: audioNotes.count,
            averageValence: averageValence,
            averageArousal: averageArousal,
            analysisDate: Date()
        )
    }
    
    private func generateInsights(clusters: [LoopCluster], statistics: AnalysisStatistics, biasSignals: [BiasSignal: Float]) async throws -> [Insight] {
        var insights: [Insight] = []
        
        // 感情トレンドインサイト
        if statistics.averageValence < -0.3 {
            let insight = Insight.create(kind: .biorhythm, in: context)
            let payload = BiorhythmInsightPayload(
                type: "negative_trend",
                message: "最近の記録でネガティブな感情が多く見られます。",
                recommendation: "ポジティブな活動や休息を取ることをお勧めします。"
            )
            try insight.setPayload(payload)
            insights.append(insight)
        }
        
        // ループインサイト
        for cluster in clusters.prefix(3) { // 上位3つのループ
            let insight = Insight.create(kind: .loop, noteIDs: cluster.noteIDs, in: context)
                let payload = LoopInsightPayload(
                    topic: cluster.topic,
                    strength: cluster.strength,
                    noteCount: cluster.noteIDs.count,
                timeSpan: calculateTimeSpan(for: cluster.noteIDs)
                )
                try insight.setPayload(payload)
                insights.append(insight)
        }
        
        return insights
    }
    
    private func calculateTimeSpan(for noteIDs: [UUID]) -> TimeInterval {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", noteIDs)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: true)]
        
        do {
            let notes = try context.fetch(request)
            guard let firstDate = notes.first?.createdAt,
                  let lastDate = notes.last?.createdAt else {
                return 0
            }
            return lastDate.timeIntervalSince(firstDate)
        } catch {
            return 0
        }
    }
}

// MARK: - State Store

private struct AnalysisStateStore {
    private let defaults = UserDefaults.standard
    private let emotionKey = "com.metawave.analysis.lastEmotionAnalysisDate"
    private let comprehensiveKey = "com.metawave.analysis.lastComprehensiveAnalysisDate"
    
    var lastEmotionAnalysisDate: Date? {
        get { defaults.object(forKey: emotionKey) as? Date }
        set { defaults.set(newValue, forKey: emotionKey) }
    }
    
    var lastComprehensiveAnalysisDate: Date? {
        get { defaults.object(forKey: comprehensiveKey) as? Date }
        set { defaults.set(newValue, forKey: comprehensiveKey) }
    }
}

// MARK: - Core Data Helpers

private extension AnalysisService {
    func fetchNotesSync(_ request: NSFetchRequest<Note>) throws -> [Note] {
        var result: [Note] = []
        var fetchError: Error?
        
        context.performAndWait {
            do {
                result = try context.fetch(request)
            } catch {
                fetchError = error
            }
        }
        
        if let fetchError {
            throw fetchError
        }
        return result
    }
}

// MARK: - Analysis Result Types
// 型定義はAnalysisTypes.swiftに移動

// MARK: - Support Types (プロトコルとスコア定義)
// 型定義はAnalysisTypes.swiftに移動

struct SentimentClassifier {
    // プレースホルダー実装
    init(mlModel: URL) {
        // MLモデルの読み込み（実装は後で）
    }
}

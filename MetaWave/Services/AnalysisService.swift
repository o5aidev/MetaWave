//
//  AnalysisService.swift
//  MetaWave
//
//  Miyabi仕様: 分析サービス統合
//

import Foundation
import CoreData

/// 分析サービス統合クラス
final class AnalysisService: ObservableObject {
    
    private let emotionAnalyzer: EmotionAnalyzer
    private let loopDetector: LoopDetector
    private let biasDetector: BiasSignalDetector
    private let context: NSManagedObjectContext
    private let performanceMonitor = PerformanceMonitor.shared
    private let errorHandler = ErrorHandler.shared
    
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
        
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "modality == 'text'")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: true)]
        
        let notes = try context.fetch(request)
        let clusters = try await loopDetector.cluster(notes: notes)
        
        // ループクラスタをInsightとして保存
        await saveLoopInsights(clusters)
        
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
            
            let settings = performanceMonitor.getOptimalAnalysisSettings()
            
            do {
                // 1. 感情分析
                try await analyzeAllEmotionsOptimized(settings: settings)
                await MainActor.run { analysisProgress = 0.25 }
                
                // 2. ループ検出
                let clusters = try await detectLoops()
                await MainActor.run { analysisProgress = 0.5 }
                
                // 3. バイアス検出
                let biasSignals = try await detectBiases()
                await MainActor.run { analysisProgress = 0.75 }
                
                // 4. 統計情報の生成
                let statistics = try await generateStatistics()
                await MainActor.run { analysisProgress = 0.9 }
                
                // 5. インサイトの生成
                let insights = try await generateInsights(clusters: clusters, statistics: statistics, biasSignals: biasSignals)
                await MainActor.run { analysisProgress = 1.0 }
                
                await MainActor.run {
                    isAnalyzing = false
                    analysisProgress = 0.0
                }
                
                return AnalysisResult(
                    clusters: clusters,
                    statistics: statistics,
                    insights: insights,
                    biasSignals: biasSignals
                )
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
    
    // MARK: - Private Methods
    
    /// 最適化された感情分析
    private func analyzeAllEmotionsOptimized(settings: AnalysisSettings) async throws {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "contentText != nil AND contentText != ''")
        
        let notes = try context.fetch(request)
        let totalNotes = notes.count
        
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
                analysisProgress = Float(endIndex) / Float(totalNotes) * 0.25
            }
        }
    }
    
    /// バイアス検出
    private func detectBiases() async throws -> [BiasSignal: Float] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try context.fetch(request)
        
        return await biasDetector.evaluate(notes: notes)
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

// MARK: - Analysis Result Types

struct AnalysisResult {
    let clusters: [LoopCluster]
    let statistics: AnalysisStatistics
    let insights: [Insight]
    let biasSignals: [BiasSignal: Float]
}

struct AnalysisStatistics {
    let totalNotes: Int
    let textNotes: Int
    let audioNotes: Int
    let averageValence: Float
    let averageArousal: Float
    let analysisDate: Date
}

// MARK: - Insight Payloads

struct LoopInsightPayload: Codable {
    let topic: String
    let strength: Float
    let noteCount: Int
    let timeSpan: TimeInterval
}

struct BiorhythmInsightPayload: Codable {
    let type: String
    let message: String
    let recommendation: String
}

// MARK: - Loop Cluster

struct LoopCluster: Identifiable {
    let id: UUID
    let topic: String
    let noteIDs: [UUID]
    let strength: Float
    
    init(topic: String, noteIDs: [UUID], strength: Float) {
        self.id = UUID()
        self.topic = topic
        self.noteIDs = noteIDs
        self.strength = strength
    }
}

// MARK: - Support Types (プロトコルとスコア定義)

struct EmotionScore {
    let valence: Float    // -1.0 (ネガティブ) ～ +1.0 (ポジティブ)
    let arousal: Float    // 0.0 (低覚醒) ～ 1.0 (高覚醒)
}

protocol EmotionAnalyzer {
    func analyze(audio: URL) async throws -> EmotionScore
    func analyze(text: String) async throws -> EmotionScore
}

protocol LoopDetector {
    func cluster(notes: [Note]) async throws -> [LoopCluster]
}

enum BiasSignal: String, CaseIterable {
    case confirmationBias = "confirmation"
    case availabilityBias = "availability"
    case anchoringBias = "anchoring"
    case lossAversion = "loss_aversion"
    case sunkCost = "sunk_cost"
}

protocol BiasSignalDetector {
    func evaluate(notes: [Note]) async -> [BiasSignal: Float]
}

struct SentimentClassifier {
    // プレースホルダー実装
    init(mlModel: URL) {
        // MLモデルの読み込み（実装は後で）
    }
}

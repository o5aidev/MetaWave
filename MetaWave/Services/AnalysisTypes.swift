//
//  AnalysisTypes.swift
//  MetaWave
//
//  v2.3: 分析関連の型定義
//

import Foundation

// MARK: - Emotion Score

struct EmotionScore {
    let valence: Float    // -1.0 (ネガティブ) ～ +1.0 (ポジティブ)
    let arousal: Float    // 0.0 (低覚醒) ～ 1.0 (高覚醒)
}

// MARK: - Analysis Protocols

protocol EmotionAnalyzer {
    func analyze(audio: URL) async throws -> EmotionScore
    func analyze(text: String) async throws -> EmotionScore
}

protocol LoopDetector {
    func cluster(notes: [Note]) async throws -> [LoopCluster]
}

protocol BiasSignalDetector {
    func evaluate(notes: [Note]) async -> [BiasSignal: Float]
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

// MARK: - Bias Signals

enum BiasSignal: String, CaseIterable {
    case confirmationBias = "confirmation"
    case availabilityBias = "availability"
    case anchoringBias = "anchoring"
    case lossAversion = "loss_aversion"
    case sunkCost = "sunk_cost"
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

// MARK: - Analysis Settings

struct AnalysisSettings {
    let batchSize: Int
    let maxConcurrentOperations: Int
    let timeoutInterval: TimeInterval
    
    static let `default` = AnalysisSettings(
        batchSize: 10,
        maxConcurrentOperations: 3,
        timeoutInterval: 30.0
    )
}

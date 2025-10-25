//
//  AnalysisServices.swift
//  MetaWave
//
//  Miyabi仕様: 分析サービスプロトコル群
//

import Foundation

/// 感情スコア
struct EmotionScore {
    let valence: Float    // -1.0 (ネガティブ) ～ +1.0 (ポジティブ)
    let arousal: Float    // 0.0 (低覚醒) ～ 1.0 (高覚醒)
}

/// 感情分析プロトコル
protocol EmotionAnalyzer {
    /// 音声から感情を分析
    func analyze(audio: URL) async throws -> EmotionScore
    
    /// テキストから感情を分析
    func analyze(text: String) async throws -> EmotionScore
}

/// ループクラスタ
struct LoopCluster {
    let id: String
    let noteIDs: [UUID]
    let topic: String
    let strength: Float  // 0.0 ～ 1.0
    let createdAt: Date
}

/// ループ検出プロトコル
protocol LoopDetector {
    /// ノート群からループクラスタを検出
    func cluster(notes: [Note]) async throws -> [LoopCluster]
}

/// バイアス信号
enum BiasSignal: String, CaseIterable {
    case confirmationBias = "confirmation"
    case availabilityBias = "availability"
    case anchoringBias = "anchoring"
    case lossAversion = "loss_aversion"
    case sunkCost = "sunk_cost"
}

/// バイアス検出プロトコル
protocol BiasSignalDetector {
    /// ノート群からバイアス信号を検出
    func evaluate(notes: [Note]) async -> [BiasSignal: Float]
}

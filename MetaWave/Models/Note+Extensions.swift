//
//  Note+Extensions.swift
//  MetaWave
//
//  Miyabi仕様: Noteエンティティ拡張
//

import Foundation
import CoreData

// EmotionScore型はTextEmotionAnalyzer.swiftで定義されています
// BiasSignal型はAnalysisService.swiftで定義されています

extension Note {
    
    /// 入力モダリティ
    enum Modality: String, CaseIterable {
        case text = "text"
        case audio = "audio"
        case image = "image"
    }
    
    /// 感情スコアを設定
    func setEmotionScore(_ score: EmotionScore) {
        self.sentiment = score.valence
        self.arousal = score.arousal
    }
    
    /// 感情スコアを取得
    func getEmotionScore() -> EmotionScore? {
        // sentimentとarousalはFloat型なので直接使用
        let sentValue = self.sentiment ?? 0.0
        let arousValue = self.arousal ?? 0.0
        return EmotionScore(valence: sentValue, arousal: arousValue)
    }
    
    /// タグ配列を設定
    func setTags(_ tags: [String]) {
        self.tags = tags.joined(separator: ",")
    }
    
    /// タグ配列を取得
    func getTags() -> [String] {
        guard let tags = self.tags, !tags.isEmpty else { return [] }
        return tags.components(separatedBy: ",")
    }
    
    /// バイアス信号を設定
    func setBiasSignals(_ signals: [String: Float]) {
        let data = try? JSONEncoder().encode(signals)
        self.biasSignals = data?.base64EncodedString()
    }
    
    /// バイアス信号を取得
    func getBiasSignals() -> [String: Float] {
        guard let biasSignals = self.biasSignals,
              let data = Data(base64Encoded: biasSignals),
              let dict = try? JSONDecoder().decode([String: Float].self, from: data) else {
            return [:]
        }
        return dict
    }
    
    /// 新しいNoteを作成
    static func create(
        modality: Modality,
        contentText: String? = nil,
        audioURL: URL? = nil,
        imageURL: URL? = nil,
        tags: [String] = [],
        in context: NSManagedObjectContext
    ) -> Note {
        let note = Note(context: context)
        note.id = UUID()
        note.createdAt = Date()
        note.updatedAt = Date()
        note.modality = modality.rawValue
        note.contentText = contentText
        note.audioURL = audioURL
        note.imageURL = imageURL
        note.setTags(tags)
        return note
    }
}

// MARK: - Dictionary Extension


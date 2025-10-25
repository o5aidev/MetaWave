//
//  Note+Extensions.swift
//  MetaWave
//
//  Miyabi仕様: Noteエンティティ拡張
//

import Foundation
import CoreData

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
        guard let sentiment = self.sentiment,
              let arousal = self.arousal else { return nil }
        return EmotionScore(valence: sentiment, arousal: arousal)
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
    func setBiasSignals(_ signals: [BiasSignal: Float]) {
        let data = try? JSONEncoder().encode(signals.mapKeys { $0.rawValue })
        self.biasSignals = data?.base64EncodedString()
    }
    
    /// バイアス信号を取得
    func getBiasSignals() -> [BiasSignal: Float] {
        guard let biasSignals = self.biasSignals,
              let data = Data(base64Encoded: biasSignals),
              let dict = try? JSONDecoder().decode([String: Float].self, from: data) else {
            return [:]
        }
        
        return Dictionary(uniqueKeysWithValues: dict.compactMap { key, value in
            guard let biasSignal = BiasSignal(rawValue: key) else { return nil }
            return (biasSignal, value)
        })
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

extension Dictionary {
    func mapKeys<T>(_ transform: (Key) throws -> T) rethrows -> [T: Value] {
        return Dictionary(uniqueKeysWithValues: try map { (try transform($0), $1) })
    }
}

//
//  Insight+Extensions.swift
//  MetaWave
//
//  Miyabi仕様: Insightエンティティ拡張
//

import Foundation
import CoreData

extension Insight {
    
    /// インサイトの種類
    enum Kind: String, CaseIterable {
        case biorhythm = "biorhythm"
        case loop = "loop"
        case bias = "bias"
        case creativity = "creativity"
    }
    
    /// ノートID配列を設定
    func setNoteIDs(_ ids: [UUID]) {
        self.noteIDs = ids.map { $0.uuidString }.joined(separator: ",")
    }
    
    /// ノートID配列を取得
    func getNoteIDs() -> [UUID] {
        guard let noteIDs = self.noteIDs, !noteIDs.isEmpty else { return [] }
        return noteIDs.components(separatedBy: ",").compactMap { UUID(uuidString: $0) }
    }
    
    /// ペイロードを設定（JSON）
    func setPayload<T: Codable>(_ payload: T) throws {
        let data = try JSONEncoder().encode(payload)
        self.payload = data.base64EncodedString()
    }
    
    /// ペイロードを取得（JSON）
    func getPayload<T: Codable>(_ type: T.Type) throws -> T? {
        guard let payload = self.payload,
              let data = Data(base64Encoded: payload) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }
    
    /// 新しいInsightを作成
    static func create(
        kind: Kind,
        noteIDs: [UUID] = [],
        payload: Data? = nil,
        in context: NSManagedObjectContext
    ) -> Insight {
        let insight = Insight(context: context)
        insight.id = UUID()
        insight.kind = kind.rawValue
        insight.setNoteIDs(noteIDs)
        insight.payload = payload?.base64EncodedString()
        insight.createdAt = Date()
        return insight
    }
}

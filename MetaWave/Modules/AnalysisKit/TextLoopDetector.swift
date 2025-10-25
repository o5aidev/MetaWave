//
//  TextLoopDetector.swift
//  MetaWave
//
//  Miyabi仕様: テキストループ検出実装
//

import Foundation
import NaturalLanguage

/// テキストループ検出実装
final class TextLoopDetector: LoopDetector {
    
    private let similarityThreshold: Float = 0.7
    private let minClusterSize = 2
    private let maxTimeWindow: TimeInterval = 7 * 24 * 60 * 60 // 7日間
    
    // MARK: - LoopDetector Protocol
    
    func cluster(notes: [Note]) async throws -> [LoopCluster] {
        return try await withCheckedThrowingContinuation { continuation in
            detectLoops(notes) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func detectLoops(_ notes: [Note], completion: @escaping (Result<[LoopCluster], Error>) -> Void) {
        // 1. テキストのみのノートをフィルタリング
        let textNotes = notes.filter { note in
            note.modality == "text" && 
            note.contentText != nil && 
            !note.contentText!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        guard textNotes.count >= minClusterSize else {
            completion(.success([]))
            return
        }
        
        // 2. 時間ウィンドウ内のノートをグループ化
        let timeGroupedNotes = groupNotesByTimeWindow(textNotes)
        
        // 3. 各時間グループ内でループを検出
        var allClusters: [LoopCluster] = []
        
        for timeGroup in timeGroupedNotes {
            let clusters = detectClustersInGroup(timeGroup)
            allClusters.append(contentsOf: clusters)
        }
        
        // 4. クラスタを強度順にソート
        allClusters.sort { $0.strength > $1.strength }
        
        completion(.success(allClusters))
    }
    
    private func groupNotesByTimeWindow(_ notes: [Note]) -> [[Note]] {
        let sortedNotes = notes.sorted { 
            ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) 
        }
        
        var groups: [[Note]] = []
        var currentGroup: [Note] = []
        var lastDate: Date?
        
        for note in sortedNotes {
            let noteDate = note.createdAt ?? Date.distantPast
            
            if let last = lastDate, noteDate.timeIntervalSince(last) > maxTimeWindow {
                if currentGroup.count >= minClusterSize {
                    groups.append(currentGroup)
                }
                currentGroup = [note]
            } else {
                currentGroup.append(note)
            }
            
            lastDate = noteDate
        }
        
        if currentGroup.count >= minClusterSize {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    private func detectClustersInGroup(_ notes: [Note]) -> [LoopCluster] {
        var clusters: [LoopCluster] = []
        var processedNotes: Set<UUID> = []
        
        for i in 0..<notes.count {
            let note1 = notes[i]
            guard let note1ID = note1.id, !processedNotes.contains(note1ID) else { continue }
            
            var clusterNotes: [Note] = [note1]
            var clusterTopics: Set<String> = []
            
            // 類似ノートを検索
            for j in (i+1)..<notes.count {
                let note2 = notes[j]
                guard let note2ID = note2.id, !processedNotes.contains(note2ID) else { continue }
                
                let similarity = calculateSimilarity(note1, note2)
                if similarity >= similarityThreshold {
                    clusterNotes.append(note2)
                    processedNotes.insert(note2ID)
                    
                    // トピックを抽出
                    if let topic = extractTopic(note2.contentText ?? "") {
                        clusterTopics.insert(topic)
                    }
                }
            }
            
            // クラスタが十分なサイズの場合のみ追加
            if clusterNotes.count >= minClusterSize {
                let clusterID = UUID().uuidString
                let noteIDs = clusterNotes.compactMap { $0.id }
                let topic = clusterTopics.first ?? extractTopic(note1.contentText ?? "") ?? "Unknown Topic"
                let strength = calculateClusterStrength(clusterNotes)
                let createdAt = clusterNotes.map { $0.createdAt ?? Date.distantPast }.min() ?? Date()
                
                let cluster = LoopCluster(
                    id: clusterID,
                    noteIDs: noteIDs,
                    topic: topic,
                    strength: strength,
                    createdAt: createdAt
                )
                
                clusters.append(cluster)
                processedNotes.insert(note1ID)
            }
        }
        
        return clusters
    }
    
    private func calculateSimilarity(_ note1: Note, _ note2: Note) -> Float {
        guard let text1 = note1.contentText, let text2 = note2.contentText else {
            return 0.0
        }
        
        // 1. テキストの長さが大きく異なる場合は類似度を下げる
        let lengthRatio = Float(min(text1.count, text2.count)) / Float(max(text1.count, text2.count))
        if lengthRatio < 0.3 {
            return 0.0
        }
        
        // 2. キーワードベースの類似度
        let keywordSimilarity = calculateKeywordSimilarity(text1, text2)
        
        // 3. セマンティック類似度（NLTagger使用）
        let semanticSimilarity = calculateSemanticSimilarity(text1, text2)
        
        // 4. 時間的類似度（同じ時間帯に書かれたか）
        let temporalSimilarity = calculateTemporalSimilarity(note1, note2)
        
        // 重み付き平均
        let finalSimilarity = (keywordSimilarity * 0.4) + (semanticSimilarity * 0.4) + (temporalSimilarity * 0.2)
        
        return min(1.0, max(0.0, finalSimilarity))
    }
    
    private func calculateKeywordSimilarity(_ text1: String, _ text2: String) -> Float {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Float(intersection.count) / Float(union.count)
    }
    
    private func calculateSemanticSimilarity(_ text1: String, _ text2: String) -> Float {
        // NLTaggerを使用した基本的なセマンティック分析
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        
        // 名詞と動詞を抽出
        let nouns1 = extractWords(tagger: tagger, text: text1, tagClass: .noun)
        let nouns2 = extractWords(tagger: tagger, text: text2, tagClass: .noun)
        
        let verbs1 = extractWords(tagger: tagger, text: text1, tagClass: .verb)
        let verbs2 = extractWords(tagger: tagger, text: text2, tagClass: .verb)
        
        let nounSimilarity = calculateSetSimilarity(nouns1, nouns2)
        let verbSimilarity = calculateSetSimilarity(verbs1, verbs2)
        
        return (nounSimilarity + verbSimilarity) / 2.0
    }
    
    private func extractWords(tagger: NLTagger, text: String, tagClass: NLTag) -> Set<String> {
        tagger.string = text
        var words: Set<String> = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if tag == tagClass {
                let word = String(text[range]).lowercased()
                if word.count > 2 { // 短すぎる単語は除外
                    words.insert(word)
                }
            }
            return true
        }
        
        return words
    }
    
    private func calculateSetSimilarity(_ set1: Set<String>, _ set2: Set<String>) -> Float {
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        return union.isEmpty ? 0.0 : Float(intersection.count) / Float(union.count)
    }
    
    private func calculateTemporalSimilarity(_ note1: Note, _ note2: Note) -> Float {
        guard let date1 = note1.createdAt, let date2 = note2.createdAt else {
            return 0.0
        }
        
        let timeDiff = abs(date1.timeIntervalSince(date2))
        let hoursDiff = timeDiff / 3600.0
        
        // 24時間以内は高類似度、1週間以内は中類似度
        if hoursDiff <= 24 {
            return 1.0
        } else if hoursDiff <= 168 { // 1週間
            return 0.5
        } else {
            return 0.0
        }
    }
    
    private func extractTopic(_ text: String) -> String? {
        // 簡単なトピック抽出（最初の名詞句を抽出）
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var topicWords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if tag == .noun || tag == .adjective {
                let word = String(text[range])
                if word.count > 2 {
                    topicWords.append(word)
                }
            }
            return topicWords.count < 3 // 最大3単語まで
        }
        
        return topicWords.isEmpty ? nil : topicWords.joined(separator: " ")
    }
    
    private func calculateClusterStrength(_ notes: [Note]) -> Float {
        // クラスタの強度を計算（ノート数、時間的集中度、内容の一貫性）
        let noteCount = Float(notes.count)
        let timeConcentration = calculateTimeConcentration(notes)
        let contentConsistency = calculateContentConsistency(notes)
        
        // 正規化（0.0 ～ 1.0）
        let normalizedCount = min(noteCount / 10.0, 1.0) // 10ノートで最大
        
        return (normalizedCount * 0.4) + (timeConcentration * 0.3) + (contentConsistency * 0.3)
    }
    
    private func calculateTimeConcentration(_ notes: [Note]) -> Float {
        let dates = notes.compactMap { $0.createdAt }.sorted()
        guard dates.count > 1 else { return 1.0 }
        
        let timeSpan = dates.last!.timeIntervalSince(dates.first!)
        let expectedSpan = TimeInterval(notes.count) * 24 * 60 * 60 // 1日間隔を期待
        
        return timeSpan > 0 ? min(1.0, Float(expectedSpan / timeSpan)) : 0.0
    }
    
    private func calculateContentConsistency(_ notes: [Note]) -> Float {
        guard notes.count > 1 else { return 1.0 }
        
        var totalSimilarity: Float = 0.0
        var pairCount = 0
        
        for i in 0..<notes.count {
            for j in (i+1)..<notes.count {
                let similarity = calculateSimilarity(notes[i], notes[j])
                totalSimilarity += similarity
                pairCount += 1
            }
        }
        
        return pairCount > 0 ? totalSimilarity / Float(pairCount) : 0.0
    }
}

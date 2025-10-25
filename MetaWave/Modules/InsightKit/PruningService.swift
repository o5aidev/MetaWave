//
//  PruningService.swift
//  MetaWave
//
//  Miyabi仕様: 剪定（Forgetfulness）機能実装
//

import Foundation
import CoreData

/// 剪定サービス
final class PruningService: ObservableObject {
    
    private let context: NSManagedObjectContext
    @Published var pruningCandidates: [PruningCandidate] = []
    @Published var isAnalyzing = false
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Public Methods
    
    /// 剪定候補を分析
    func analyzePruningCandidates() async {
        await MainActor.run {
            isAnalyzing = true
        }
        
        let candidates = await identifyPruningCandidates()
        
        await MainActor.run {
            pruningCandidates = candidates
            isAnalyzing = false
        }
    }
    
    /// 剪定を実行
    func executePruning(_ candidates: [PruningCandidate]) async throws {
        let noteIDs = candidates.map { $0.noteID }
        
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", noteIDs)
        
        let notes = try context.fetch(request)
        
        for note in notes {
            context.delete(note)
        }
        
        try context.save()
        
        await MainActor.run {
            pruningCandidates.removeAll { candidate in
                noteIDs.contains(candidate.noteID)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func identifyPruningCandidates() async -> [PruningCandidate] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: true)]
        
        do {
            let notes = try context.fetch(request)
            return await analyzeNotesForPruning(notes)
        } catch {
            print("Failed to fetch notes for pruning analysis: \(error)")
            return []
        }
    }
    
    private func analyzeNotesForPruning(_ notes: [Note]) async -> [PruningCandidate] {
        var candidates: [PruningCandidate] = []
        let now = Date()
        
        for note in notes {
            let score = await calculatePruningScore(note, currentDate: now)
            
            if score.shouldPrune {
                let candidate = PruningCandidate(
                    noteID: note.id ?? UUID(),
                    title: generateTitle(for: note),
                    content: note.contentText ?? "",
                    createdAt: note.createdAt ?? Date.distantPast,
                    pruningScore: score.totalScore,
                    reasons: score.reasons
                )
                candidates.append(candidate)
            }
        }
        
        // スコア順にソート
        return candidates.sorted { $0.pruningScore > $1.pruningScore }
    }
    
    private func calculatePruningScore(_ note: Note, currentDate: Date) async -> PruningScore {
        var reasons: [String] = []
        var totalScore: Float = 0.0
        
        // 1. 時間ベースのスコア（古いノートほど高スコア）
        let ageScore = calculateAgeScore(note.createdAt ?? Date.distantPast, currentDate: currentDate)
        totalScore += ageScore.value
        if ageScore.value > 0.5 {
            reasons.append("Very old note (\(ageScore.description))")
        }
        
        // 2. 参照頻度スコア（参照されていないノートほど高スコア）
        let referenceScore = calculateReferenceScore(note)
        totalScore += referenceScore.value
        if referenceScore.value > 0.3 {
            reasons.append("Low reference frequency")
        }
        
        // 3. 内容価値スコア（価値の低いノートほど高スコア）
        let valueScore = calculateValueScore(note)
        totalScore += valueScore.value
        if valueScore.value > 0.4 {
            reasons.append("Low content value")
        }
        
        // 4. 感情スコア（ネガティブなノートほど高スコア）
        let emotionScore = calculateEmotionScore(note)
        totalScore += emotionScore.value
        if emotionScore.value > 0.3 {
            reasons.append("Negative emotional content")
        }
        
        // 5. 重複スコア（類似ノートが多いほど高スコア）
        let duplicateScore = await calculateDuplicateScore(note)
        totalScore += duplicateScore.value
        if duplicateScore.value > 0.4 {
            reasons.append("Similar content exists")
        }
        
        let shouldPrune = totalScore > 0.6 // 閾値
        
        return PruningScore(
            totalScore: totalScore,
            shouldPrune: shouldPrune,
            reasons: reasons
        )
    }
    
    private func calculateAgeScore(_ createdAt: Date, currentDate: Date) -> (value: Float, description: String) {
        let ageInDays = currentDate.timeIntervalSince(createdAt) / (24 * 60 * 60)
        
        if ageInDays > 365 { // 1年以上
            return (0.8, "over 1 year")
        } else if ageInDays > 180 { // 6ヶ月以上
            return (0.6, "over 6 months")
        } else if ageInDays > 90 { // 3ヶ月以上
            return (0.4, "over 3 months")
        } else if ageInDays > 30 { // 1ヶ月以上
            return (0.2, "over 1 month")
        } else {
            return (0.0, "recent")
        }
    }
    
    private func calculateReferenceScore(_ note: Note) -> (value: Float, description: String) {
        // 簡易的な参照頻度計算（実際の実装では参照ログが必要）
        let contentLength = note.contentText?.count ?? 0
        let tagCount = note.getTags().count
        
        // 短いノートでタグが少ない場合は参照頻度が低いと仮定
        if contentLength < 50 && tagCount == 0 {
            return (0.5, "short content, no tags")
        } else if contentLength < 100 && tagCount <= 1 {
            return (0.3, "limited content and tags")
        } else {
            return (0.0, "sufficient content")
        }
    }
    
    private func calculateValueScore(_ note: Note) -> (value: Float, description: String) {
        guard let content = note.contentText else {
            return (0.8, "no content")
        }
        
        let contentLength = content.count
        let tagCount = note.getTags().count
        
        // 価値の低いコンテンツの特徴
        let lowValueKeywords = ["test", "hello", "hi", "ok", "yes", "no", "テスト", "こんにちは", "はい", "いいえ"]
        let hasLowValueKeywords = lowValueKeywords.contains { content.lowercased().contains($0) }
        
        if contentLength < 20 {
            return (0.7, "very short content")
        } else if hasLowValueKeywords && contentLength < 50 {
            return (0.6, "low-value keywords")
        } else if tagCount == 0 && contentLength < 100 {
            return (0.4, "no tags, limited content")
        } else {
            return (0.0, "valuable content")
        }
    }
    
    private func calculateEmotionScore(_ note: Note) -> (value: Float, description: String) {
        guard let emotionScore = note.getEmotionScore() else {
            return (0.0, "no emotion data")
        }
        
        // 非常にネガティブな感情のノートは剪定候補
        if emotionScore.valence < -0.7 {
            return (0.6, "very negative emotion")
        } else if emotionScore.valence < -0.4 {
            return (0.3, "negative emotion")
        } else {
            return (0.0, "neutral/positive emotion")
        }
    }
    
    private func calculateDuplicateScore(_ note: Note) async -> (value: Float, description: String) {
        guard let content = note.contentText, !content.isEmpty else {
            return (0.0, "no content to compare")
        }
        
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "id != %@", note.id ?? UUID())
        
        do {
            let otherNotes = try context.fetch(request)
            let similarCount = otherNotes.filter { otherNote in
                guard let otherContent = otherNote.contentText else { return false }
                return calculateSimilarity(content, otherContent) > 0.8
            }.count
            
            if similarCount >= 3 {
                return (0.7, "many similar notes (\(similarCount))")
            } else if similarCount >= 2 {
                return (0.4, "some similar notes (\(similarCount))")
            } else {
                return (0.0, "unique content")
            }
        } catch {
            return (0.0, "comparison failed")
        }
    }
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Float {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Float(intersection.count) / Float(union.count)
    }
    
    private func generateTitle(for note: Note) -> String {
        guard let content = note.contentText, !content.isEmpty else {
            return "Untitled Note"
        }
        
        let firstLine = content.components(separatedBy: .newlines).first ?? content
        return String(firstLine.prefix(50)) + (firstLine.count > 50 ? "..." : "")
    }
}

// MARK: - Data Models

struct PruningCandidate: Identifiable {
    let id = UUID()
    let noteID: UUID
    let title: String
    let content: String
    let createdAt: Date
    let pruningScore: Float
    let reasons: [String]
}

struct PruningScore {
    let totalScore: Float
    let shouldPrune: Bool
    let reasons: [String]
}

//
//  PatternAnalysisService.swift
//  MetaWave
//
//  v2.3: 時間パターン分析サービス
//

import Foundation
import CoreData
import SwiftUI
import Combine

/// 時間パターン分析サービス
final class PatternAnalysisService: ObservableObject {
    
    private let context: NSManagedObjectContext
    
    @Published var hourlyPatterns: [HourlyPattern] = []
    @Published var weeklyPatterns: [WeeklyPattern] = []
    @Published var emotionTrends: [EmotionTrend] = []
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - 時間帯別パターン分析
    
    func analyzeHourlyPatterns(completion: @escaping ([HourlyPattern]) -> Void) {
        Task {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "contentText != nil")
            
            do {
                let notes = try context.fetch(request)
                let patterns = calculateHourlyPatterns(from: notes)
                
                await MainActor.run {
                    self.hourlyPatterns = patterns
                    completion(patterns)
                }
            } catch {
                print("Failed to analyze hourly patterns: \(error)")
                completion([])
            }
        }
    }
    
    private func calculateHourlyPatterns(from notes: [Note]) -> [HourlyPattern] {
        var patterns: [Int: (count: Int, totalValence: Float, totalArousal: Float)] = [:]
        
        for note in notes {
            guard let createdAt = note.createdAt else { continue }
            
            let hour = Calendar.current.component(.hour, from: createdAt)
            let emotionScore = note.getEmotionScore()
            
            if patterns[hour] == nil {
                patterns[hour] = (0, 0.0, 0.0)
            }
            
            patterns[hour]?.count += 1
            patterns[hour]?.totalValence += emotionScore?.valence ?? 0.0
            patterns[hour]?.totalArousal += emotionScore?.arousal ?? 0.0
        }
        
        return (0..<24).map { hour in
            let data = patterns[hour] ?? (0, 0.0, 0.0)
            let count = data.count
            let avgValence = count > 0 ? data.totalValence / Float(count) : 0.0
            let avgArousal = count > 0 ? data.totalArousal / Float(count) : 0.0
            
            return HourlyPattern(
                hour: hour,
                noteCount: count,
                averageValence: avgValence,
                averageArousal: avgArousal
            )
        }
    }
    
    // MARK: - 週間パターン分析
    
    func analyzeWeeklyPatterns(completion: @escaping ([WeeklyPattern]) -> Void) {
        Task {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "contentText != nil")
            
            do {
                let notes = try context.fetch(request)
                let patterns = calculateWeeklyPatterns(from: notes)
                
                await MainActor.run {
                    self.weeklyPatterns = patterns
                    completion(patterns)
                }
            } catch {
                print("Failed to analyze weekly patterns: \(error)")
                completion([])
            }
        }
    }
    
    private func calculateWeeklyPatterns(from notes: [Note]) -> [WeeklyPattern] {
        var patterns: [Int: (count: Int, totalValence: Float, totalArousal: Float)] = [:]
        
        for note in notes {
            guard let createdAt = note.createdAt else { continue }
            
            let weekday = Calendar.current.component(.weekday, from: createdAt)
            let emotionScore = note.getEmotionScore()
            
            if patterns[weekday] == nil {
                patterns[weekday] = (0, 0.0, 0.0)
            }
            
            patterns[weekday]?.count += 1
            patterns[weekday]?.totalValence += emotionScore?.valence ?? 0.0
            patterns[weekday]?.totalArousal += emotionScore?.arousal ?? 0.0
        }
        
        return (1...7).map { weekday in
            let data = patterns[weekday] ?? (0, 0.0, 0.0)
            let count = data.count
            let avgValence = count > 0 ? data.totalValence / Float(count) : 0.0
            let avgArousal = count > 0 ? data.totalArousal / Float(count) : 0.0
            
            return WeeklyPattern(
                weekday: weekday,
                noteCount: count,
                averageValence: avgValence,
                averageArousal: avgArousal
            )
        }
    }
    
    // MARK: - 感情トレンド分析
    
    func analyzeEmotionTrends(days: Int = 30, completion: @escaping ([EmotionTrend]) -> Void) {
        Task {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "contentText != nil AND createdAt >= %@", 
                                          Calendar.current.date(byAdding: .day, value: -days, to: Date())! as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: true)]
            
            do {
                let notes = try context.fetch(request)
                let trends = calculateEmotionTrends(from: notes, days: days)
                
                await MainActor.run {
                    self.emotionTrends = trends
                    completion(trends)
                }
            } catch {
                print("Failed to analyze emotion trends: \(error)")
                completion([])
            }
        }
    }
    
    private func calculateEmotionTrends(from notes: [Note], days: Int) -> [EmotionTrend] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date())!
        
        var trends: [Date] = []
        var currentDate = startDate
        
        while currentDate <= Date() {
            trends.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return trends.map { date in
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let dayNotes = notes.filter { note in
                guard let createdAt = note.createdAt else { return false }
                return createdAt >= dayStart && createdAt < dayEnd
            }
            
            let emotionScores = dayNotes.compactMap { $0.getEmotionScore() }
            
            let avgValence = emotionScores.isEmpty ? 0.0 : 
                emotionScores.map { $0.valence }.reduce(0, +) / Float(emotionScores.count)
            let avgArousal = emotionScores.isEmpty ? 0.0 : 
                emotionScores.map { $0.arousal }.reduce(0, +) / Float(emotionScores.count)
            
            return EmotionTrend(
                date: date,
                noteCount: dayNotes.count,
                averageValence: avgValence,
                averageArousal: avgArousal,
                dominantEmotion: calculateDominantEmotion(from: dayNotes)
            )
        }
    }
    
    private func calculateDominantEmotion(from notes: [Note]) -> EmotionCategory? {
        var emotionCounts: [EmotionCategory: Int] = [:]
        
        for note in notes {
            let emotionScore = note.getEmotionScore()
            
            // 感情スコアから主要感情を判定
            if let valence = emotionScore?.valence, let arousal = emotionScore?.arousal {
                var category: EmotionCategory?
                
                if valence > 0.3 {
                    if arousal > 0.5 {
                        category = .joy
                    } else {
                        category = .joy
                    }
                } else if valence < -0.3 {
                    if arousal > 0.5 {
                        category = .anger
                    } else {
                        category = .sadness
                    }
                } else if arousal > 0.5 {
                    category = .surprise
                } else if arousal < 0.3 {
                    category = .disgust
                }
                
                if let category = category {
                    emotionCounts[category, default: 0] += 1
                }
            }
        }
        
        return emotionCounts.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - 統計情報
    
    func getPatternSummary() -> PatternSummary {
        let recentNotes = try? context.fetch(Note.fetchRequest())
        let notes = recentNotes ?? []
        
        let totalNotes = notes.count
        let averageValence = notes.compactMap { $0.getEmotionScore()?.valence }
            .reduce(0.0, +) / Float(max(1, notes.count))
        let averageArousal = notes.compactMap { $0.getEmotionScore()?.arousal }
            .reduce(0.0, +) / Float(max(1, notes.count))
        
        // 最もアクティブな時間帯
        let hourlyNotes = Dictionary(grouping: notes) { note in
            Calendar.current.component(.hour, from: note.createdAt ?? Date())
        }
        let mostActiveHour = hourlyNotes.max(by: { $0.value.count < $1.value.count })?.key ?? 0
        
        // 最もアクティブな曜日
        let weeklyNotes = Dictionary(grouping: notes) { note in
            Calendar.current.component(.weekday, from: note.createdAt ?? Date())
        }
        let mostActiveDay = weeklyNotes.max(by: { $0.value.count < $1.value.count })?.key ?? 1
        
        return PatternSummary(
            totalNotes: totalNotes,
            averageValence: averageValence,
            averageArousal: averageArousal,
            mostActiveHour: mostActiveHour,
            mostActiveDay: mostActiveDay
        )
    }
}

// MARK: - Data Models

struct HourlyPattern: Identifiable {
    let id = UUID()
    let hour: Int
    let noteCount: Int
    let averageValence: Float
    let averageArousal: Float
    
    var timeLabel: String {
        String(format: "%02d:00", hour)
    }
}

struct WeeklyPattern: Identifiable {
    let id = UUID()
    let weekday: Int
    let noteCount: Int
    let averageValence: Float
    let averageArousal: Float
    
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let date = Calendar.current.date(from: DateComponents(weekday: weekday)) ?? Date()
        return formatter.string(from: date)
    }
    
    var dayName: String {
        let weekdays = ["", "日", "月", "火", "水", "木", "金", "土"]
        return weekday >= 0 && weekday < weekdays.count ? weekdays[weekday] : ""
    }
}

struct EmotionTrend: Identifiable {
    let id = UUID()
    let date: Date
    let noteCount: Int
    let averageValence: Float
    let averageArousal: Float
    let dominantEmotion: EmotionCategory?
    
    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct PatternSummary {
    let totalNotes: Int
    let averageValence: Float
    let averageArousal: Float
    let mostActiveHour: Int
    let mostActiveDay: Int
    
    var mostActiveHourLabel: String {
        String(format: "%02d:00", mostActiveHour)
    }
    
    var mostActiveDayLabel: String {
        let weekdays = ["", "日", "月", "火", "水", "木", "金", "土"]
        return weekdays[mostActiveDay]
    }
}


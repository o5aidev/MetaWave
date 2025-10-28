//
//  MetaWaveWidget.swift
//  MetaWaveWidget
//
//  v2.4: ウィジェット実装
//

import WidgetKit
import SwiftUI
import CoreData

struct MetaWaveWidget: Widget {
    let kind: String = "MetaWaveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetaWaveTimelineProvider()) { entry in
            MetaWaveWidgetView(entry: entry)
        }
        .configurationDisplayName("MetaWave")
        .description("現在の感情状況と統計を表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct MetaWaveTimelineProvider: TimelineProvider {
    typealias Entry = MetaWaveWidgetEntry
    
    func placeholder(in context: Context) -> MetaWaveWidgetEntry {
        MetaWaveWidgetEntry(date: Date(), emotionData: EmotionWidgetData(
            currentValence: 0.5,
            currentArousal: 0.6,
            todayNotes: 5,
            weekNotes: 32,
            averageValence: 0.4,
            emotionLabel: "安定"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (MetaWaveWidgetEntry) -> ()) {
        let entry = createEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [MetaWaveWidgetEntry] = []
        let currentDate = Date()
        
        // 現在のエントリ
        let entry = createEntry()
        entries.append(entry)
        
        // 1時間後
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        entries.append(MetaWaveWidgetEntry(date: nextUpdate, emotionData: entry.emotionData))
        
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func createEntry() -> MetaWaveWidgetEntry {
        // Core Dataからデータを取得
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt >= %@", 
                                      Calendar.current.startOfDay(for: Date()) as NSDate)
        
        let notes = try? context.fetch(request)
        let todayCount = notes?.count ?? 0
        
        // 感情データの計算
        let emotionScores = notes?.compactMap { $0.getEmotionScore() } ?? []
        let avgValence = emotionScores.isEmpty ? 0.0 : 
            emotionScores.map { $0.valence }.reduce(0, +) / Float(emotionScores.count)
        let avgArousal = emotionScores.isEmpty ? 0.0 : 
            emotionScores.map { $0.arousal }.reduce(0, +) / Float(emotionScores.count)
        
        let currentValence = emotionScores.last?.valence ?? avgValence
        let currentArousal = emotionScores.last?.arousal ?? avgArousal
        
        // 週間のノート数
        let weekRequest: NSFetchRequest<Note> = Note.fetchRequest()
        weekRequest.predicate = NSPredicate(format: "createdAt >= %@",
                                           Calendar.current.date(byAdding: .day, value: -7, to: Date())! as NSDate)
        let weekNotes = try? context.fetch(weekRequest)
        let weekCount = weekNotes?.count ?? 0
        
        let emotionLabel = getEmotionLabel(valence: currentValence, arousal: currentArousal)
        
        let emotionData = EmotionWidgetData(
            currentValence: currentValence,
            currentArousal: currentArousal,
            todayNotes: todayCount,
            weekNotes: weekCount,
            averageValence: avgValence,
            emotionLabel: emotionLabel
        )
        
        return MetaWaveWidgetEntry(date: Date(), emotionData: emotionData)
    }
    
    private func getEmotionLabel(valence: Float, arousal: Float) -> String {
        if valence > 0.3 && arousal > 0.6 {
            return "興奮"
        } else if valence > 0.3 && arousal < 0.4 {
            return "穏やか"
        } else if valence < -0.3 && arousal > 0.6 {
            return "イライラ"
        } else if valence < -0.3 && arousal < 0.4 {
            return "落ち込み"
        } else {
            return "安定"
        }
    }
}

// MARK: - Widget Entry

struct MetaWaveWidgetEntry: TimelineEntry {
    let date: Date
    let emotionData: EmotionWidgetData
}

struct EmotionWidgetData {
    let currentValence: Float
    let currentArousal: Float
    let todayNotes: Int
    let weekNotes: Int
    let averageValence: Float
    let emotionLabel: String
}

// MARK: - Widget View

struct MetaWaveWidgetView: View {
    var entry: MetaWaveWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(emotionData: entry.emotionData)
        case .systemMedium:
            MediumWidgetView(emotionData: entry.emotionData)
        default:
            SmallWidgetView(emotionData: entry.emotionData)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let emotionData: EmotionWidgetData
    
    var body: some View {
        VStack(spacing: 8) {
            // 感情ラベル
            Text(emotionData.emotionLabel)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(emotionColor)
            
            // 感情スコア
            HStack(spacing: 4) {
                Circle()
                    .fill(valenceColor)
                    .frame(width: 16, height: 16)
                Text(String(format: "%.2f", emotionData.currentValence))
                    .font(.caption)
                
                Circle()
                    .fill(.orange)
                    .frame(width: 16, height: 16)
                Text(String(format: "%.2f", emotionData.currentArousal))
                    .font(.caption)
            }
            
            Divider()
            
            // 今日のノート数
            HStack {
                Image(systemName: "note.text")
                    .font(.caption)
                Text("今日: \(emotionData.todayNotes)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var emotionColor: Color {
        if emotionData.currentValence > 0.3 {
            return .green
        } else if emotionData.currentValence < -0.3 {
            return .red
        } else {
            return .blue
        }
    }
    
    private var valenceColor: Color {
        if emotionData.currentValence > 0.3 {
            return .green
        } else if emotionData.currentValence < -0.3 {
            return .red
        } else {
            return .orange
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let emotionData: EmotionWidgetData
    
    var body: some View {
        HStack(spacing: 16) {
            // 左側: 感情情報
            VStack(alignment: .leading, spacing: 8) {
                Text(emotionData.emotionLabel)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(emotionColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(valenceColor)
                            .frame(width: 12, height: 12)
                        Text("感情: \(String(format: "%.2f", emotionData.currentValence))")
                            .font(.caption)
                    }
                    
                    HStack {
                        Circle()
                            .fill(.orange)
                            .frame(width: 12, height: 12)
                        Text("覚醒: \(String(format: "%.2f", emotionData.currentArousal))")
                            .font(.caption)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // 右側: 統計情報
            VStack(alignment: .trailing, spacing: 8) {
                StatRow(icon: "note.text", value: "\(emotionData.todayNotes)", label: "今日")
                StatRow(icon: "calendar", value: "\(emotionData.weekNotes)", label: "今週")
                StatRow(icon: "chart.line.uptrend.xyaxis", value: String(format: "%.2f", emotionData.averageValence), label: "平均感情")
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var emotionColor: Color {
        if emotionData.currentValence > 0.3 {
            return .green
        } else if emotionData.currentValence < -0.3 {
            return .red
        } else {
            return .blue
        }
    }
    
    private var valenceColor: Color {
        if emotionData.currentValence > 0.3 {
            return .green
        } else if emotionData.currentValence < -0.3 {
            return .red
        } else {
            return .orange
        }
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct MetaWaveWidget_Previews: PreviewProvider {
    static var previews: some View {
        MetaWaveWidgetView(entry: MetaWaveWidgetEntry(
            date: Date(),
            emotionData: EmotionWidgetData(
                currentValence: 0.5,
                currentArousal: 0.6,
                todayNotes: 5,
                weekNotes: 32,
                averageValence: 0.4,
                emotionLabel: "安定"
            )
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}


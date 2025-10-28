//
//  PatternAnalysisView.swift
//  MetaWave
//
//  v2.3: パターン分析ビュー
//

import SwiftUI
import CoreData

struct PatternAnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var patternService: PatternAnalysisService
    @State private var hourlyPatterns: [HourlyPattern] = []
    @State private var weeklyPatterns: [WeeklyPattern] = []
    @State private var emotionTrends: [EmotionTrend] = []
    @State private var patternSummary: PatternSummary?
    @State private var isLoading = false
    @State private var selectedTimeframe: Timeframe = .hourly
    
    enum Timeframe: String, CaseIterable {
        case hourly = "時間帯別"
        case weekly = "週間"
        case trend = "推移"
    }
    
    init(context: NSManagedObjectContext) {
        self._patternService = StateObject(wrappedValue: PatternAnalysisService(context: context))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヘッダー
                headerView
                
                // 統計サマリー
                if let summary = patternSummary {
                    summaryCard(summary)
                }
                
                // 時間フレーム選択
                timeframeSelector
                
                // パターン表示
                patternContent
            }
            .padding()
        }
        .navigationTitle("パターン分析")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("感情パターン分析")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("時間帯・曜日・推移での感情パターンを可視化")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private func summaryCard(_ summary: PatternSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("統計サマリー")
                .font(.headline)
            
            HStack(spacing: 16) {
                SummaryStat(
                    icon: "note.text",
                    title: "総ノート数",
                    value: "\(summary.totalNotes)",
                    color: .blue
                )
                
                SummaryStat(
                    icon: "face.smiling",
                    title: "平均感情",
                    value: String(format: "%.2f", summary.averageValence),
                    color: summary.averageValence >= 0 ? .green : .red
                )
                
                SummaryStat(
                    icon: "clock.fill",
                    title: "最活性時間",
                    value: summary.mostActiveHourLabel,
                    color: .orange
                )
            }
            
            Text("最も活動的な曜日: \(summary.mostActiveDayLabel)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var timeframeSelector: some View {
        Picker("時間フレーム", selection: $selectedTimeframe) {
            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                Text(timeframe.rawValue).tag(timeframe)
            }
        }
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    private var patternContent: some View {
        if isLoading {
            ProgressView("分析中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch selectedTimeframe {
            case .hourly:
                hourlyPatternView
            case .weekly:
                weeklyPatternView
            case .trend:
                trendView
            }
        }
    }
    
    private var hourlyPatternView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("24時間パターン")
                .font(.headline)
            
            if hourlyPatterns.isEmpty {
                Text("データが不足しています")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(hourlyPatterns) { pattern in
                            HourlyPatternCard(pattern: pattern)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var weeklyPatternView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("週間パターン")
                .font(.headline)
            
            if weeklyPatterns.isEmpty {
                Text("データが不足しています")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(weeklyPatterns) { pattern in
                    WeeklyPatternRow(pattern: pattern)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var trendView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("感情推移（30日間）")
                .font(.headline)
            
            if emotionTrends.isEmpty {
                Text("データが不足しています")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(emotionTrends) { trend in
                            TrendBar(trend: trend)
                        }
                    }
                }
                .frame(height: 150)
                
                // レジェンド
                HStack(spacing: 20) {
                    LegendItem(color: .green, label: "ポジティブ")
                    LegendItem(color: .red, label: "ネガティブ")
                    LegendItem(color: .orange, label: "中性")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    @MainActor
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        // 統計サマリー
        patternSummary = patternService.getPatternSummary()
        
        // 時間帯別パターン
        patternService.analyzeHourlyPatterns { patterns in
            self.hourlyPatterns = patterns
        }
        
        // 週間パターン
        patternService.analyzeWeeklyPatterns { patterns in
            self.weeklyPatterns = patterns
        }
        
        // 感情推移
        patternService.analyzeEmotionTrends(days: 30) { trends in
            self.emotionTrends = trends
        }
    }
}

// MARK: - Supporting Views

struct SummaryStat: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HourlyPatternCard: View {
    let pattern: HourlyPattern
    
    var body: some View {
        VStack(spacing: 8) {
            Text(pattern.timeLabel)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(pattern.noteCount)")
                .font(.title3)
                .fontWeight(.bold)
            
            if pattern.noteCount > 0 {
                Circle()
                    .fill(colorForValence(pattern.averageValence))
                    .frame(width: 40, height: 40)
                
                Text(valenceLabel(pattern.averageValence))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 80)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func colorForValence(_ valence: Float) -> Color {
        if valence > 0.2 {
            return .green
        } else if valence < -0.2 {
            return .red
        } else {
            return .orange
        }
    }
    
    private func valenceLabel(_ valence: Float) -> String {
        if valence > 0.2 {
            return "ポジ"
        } else if valence < -0.2 {
            return "ネガ"
        } else {
            return "中性"
        }
    }
}

struct WeeklyPatternRow: View {
    let pattern: WeeklyPattern
    
    var body: some View {
        HStack {
            Text(pattern.dayLabel)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 40)
            
            Text("\(pattern.noteCount)件")
                .font(.subheadline)
                .frame(width: 60, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(colorForValence(pattern.averageValence))
                        .frame(
                            width: geometry.size.width * CGFloat(max(pattern.averageValence, 0) + 1) / 2,
                            height: 8
                        )
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func colorForValence(_ valence: Float) -> Color {
        if valence > 0.2 {
            return .green
        } else if valence < -0.2 {
            return .red
        } else {
            return .orange
        }
    }
}

struct TrendBar: View {
    let trend: EmotionTrend
    
    var body: some View {
        VStack {
            Spacer()
            
            if trend.noteCount > 0 {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colorForValence(trend.averageValence))
                    .frame(width: 12, height: CGFloat(max(trend.averageValence, 0) * 50 + 20))
                    .overlay(
                        Text("\(trend.noteCount)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-90))
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 12, height: 4)
            }
        }
        .frame(width: 16)
    }
    
    private func colorForValence(_ valence: Float) -> Color {
        if valence > 0.2 {
            return .green
        } else if valence < -0.2 {
            return .red
        } else {
            return .orange
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Preview

struct PatternAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PatternAnalysisView(context: PersistenceController.preview.container.viewContext)
        }
    }
}


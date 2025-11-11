//
//  AnalysisVisualization.swift
//  MetaWave
//
//  v2.4: 分析結果の可視化強化
//

import SwiftUI
import CoreData
import Charts

struct AnalysisVisualizationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var emotionData: [EmotionDataPoint] = []
    @State private var patternData: [PatternDataPoint] = []
    @State private var predictionData: [PredictionDataPoint] = []
    @State private var isLoading = false
    @State private var selectedTab: AnalysisTab = .emotion
    
    enum AnalysisTab: String, CaseIterable {
        case emotion = "感情分析"
        case pattern = "パターン"
        case prediction = "予測"
        
        var systemImage: String {
            switch self {
            case .emotion: return "heart.fill"
            case .pattern: return "chart.line.uptrend.xyaxis"
            case .prediction: return "crystal.ball"
            }
        }
    }
    
    init(context: NSManagedObjectContext) {
        // 初期化処理
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // タブ選択
                tabSelector
                
                // コンテンツ
                TabView(selection: $selectedTab) {
                    emotionAnalysisView
                        .tag(AnalysisTab.emotion)
                    
                    patternAnalysisView
                        .tag(AnalysisTab.pattern)
                    
                    predictionAnalysisView
                        .tag(AnalysisTab.prediction)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("分析結果")
            .onAppear {
                loadAnalysisData()
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AnalysisTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Emotion Analysis View
    
    private var emotionAnalysisView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 感情分布円グラフ
                emotionDistributionChart
                
                // 感情推移グラフ
                emotionTrendChart
                
                // 感情統計カード
                emotionStatisticsCards
            }
            .padding()
        }
    }
    
    private var emotionDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("感情分布")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 17.0, *) {
                Chart(emotionData) { data in
                    SectorMark(
                        angle: .value("Count", data.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Emotion", data.emotion))
                }
                .frame(height: 200)
                .padding()
            } else {
                // iOS 16未満の代替表示
                emotionDistributionLegacy
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var emotionDistributionLegacy: some View {
        VStack(spacing: 12) {
            ForEach(emotionData, id: \.emotion) { data in
                HStack {
                    Circle()
                        .fill(data.color)
                        .frame(width: 16, height: 16)
                    
                    Text(data.emotion)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(data.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal)
            }
        }
        .frame(height: 200)
        .padding()
    }
    
    private var emotionTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("感情推移")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart(emotionData) { data in
                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("Valence", data.valence)
                    )
                    .foregroundStyle(.blue)
                    
                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("Arousal", data.arousal)
                    )
                    .foregroundStyle(.red)
                }
                .frame(height: 200)
                .padding()
            } else {
                // iOS 16未満の代替表示
                emotionTrendLegacy
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var emotionTrendLegacy: some View {
        VStack(spacing: 8) {
            Text("感情推移グラフ")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 簡易的なバー表示
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(emotionData.prefix(7), id: \.date) { data in
                    VStack {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 20, height: CGFloat(data.valence * 50 + 50))
                        
                        Text(data.date, style: .date)
                            .font(.caption2)
                    }
                }
            }
            .frame(height: 150)
        }
        .padding()
    }
    
    private var emotionStatisticsCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatisticCard(
                title: "平均感情",
                value: String(format: "%.2f", averageValence),
                color: .blue
            )
            
            StatisticCard(
                title: "平均覚醒度",
                value: String(format: "%.2f", averageArousal),
                color: .red
            )
            
            StatisticCard(
                title: "記録数",
                value: "\(emotionData.count)",
                color: .green
            )
            
            StatisticCard(
                title: "分析期間",
                value: analysisPeriod,
                color: .orange
            )
        }
    }
    
    // MARK: - Pattern Analysis View
    
    private var patternAnalysisView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // パターンクラスタリング表示
                patternClusteringView
                
                // 時間帯別パターン
                hourlyPatternView
                
                // パターン統計
                patternStatisticsView
            }
            .padding()
        }
    }
    
    private var patternClusteringView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("パターンクラスタリング")
                .font(.headline)
                .padding(.horizontal)
            
            if patternData.isEmpty {
                Text("パターンデータがありません")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
            } else {
                // クラスタリング結果の可視化
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(patternData, id: \.id) { pattern in
                        PatternCard(pattern: pattern)
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var hourlyPatternView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("時間帯別パターン")
                .font(.headline)
                .padding(.horizontal)
            
            // 時間帯別の活動パターン
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<24, id: \.self) { hour in
                    VStack {
                        Rectangle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 12, height: CGFloat.random(in: 20...100))
                        
                        Text("\(hour)")
                            .font(.caption2)
                    }
                }
            }
            .frame(height: 120)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var patternStatisticsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatisticCard(
                title: "発見パターン",
                value: "\(patternData.count)",
                color: .purple
            )
            
            StatisticCard(
                title: "最大クラスタ",
                value: "\(maxClusterSize)",
                color: .indigo
            )
        }
    }
    
    // MARK: - Prediction Analysis View
    
    private var predictionAnalysisView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 予測精度表示
                predictionAccuracyView
                
                // 予測結果の信頼度
                predictionConfidenceView
                
                // 予測統計
                predictionStatisticsView
            }
            .padding()
        }
    }
    
    private var predictionAccuracyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("予測精度")
                .font(.headline)
                .padding(.horizontal)
            
            // 予測精度の円グラフ
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: predictionAccuracy / 100)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(predictionAccuracy))%")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("精度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 150)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var predictionConfidenceView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("予測信頼度")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(predictionData, id: \.id) { prediction in
                HStack {
                    Text(prediction.type)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    ProgressView(value: prediction.confidence, total: 1.0)
                        .frame(width: 100)
                    
                    Text("\(Int(prediction.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var predictionStatisticsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatisticCard(
                title: "予測数",
                value: "\(predictionData.count)",
                color: .cyan
            )
            
            StatisticCard(
                title: "平均信頼度",
                value: String(format: "%.1f%%", averageConfidence * 100),
                color: .mint
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAnalysisData() {
        isLoading = true
        
        Task {
            // 感情データの読み込み
            await loadEmotionData()
            
            // パターンデータの読み込み
            await loadPatternData()
            
            // 予測データの読み込み
            await loadPredictionData()
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadEmotionData() async {
        // 実際のデータ読み込み処理
        // ここではサンプルデータを生成
        let sampleData = generateSampleEmotionData()
        await MainActor.run {
            self.emotionData = sampleData
        }
    }
    
    private func loadPatternData() async {
        // 実際のデータ読み込み処理
        let sampleData = generateSamplePatternData()
        await MainActor.run {
            self.patternData = sampleData
        }
    }
    
    private func loadPredictionData() async {
        // 実際のデータ読み込み処理
        let sampleData = generateSamplePredictionData()
        await MainActor.run {
            self.predictionData = sampleData
        }
    }
    
    // MARK: - Computed Properties
    
    private var averageValence: Double {
        guard !emotionData.isEmpty else { return 0 }
        return emotionData.map { $0.valence }.reduce(0, +) / Double(emotionData.count)
    }
    
    private var averageArousal: Double {
        guard !emotionData.isEmpty else { return 0 }
        return emotionData.map { $0.arousal }.reduce(0, +) / Double(emotionData.count)
    }
    
    private var analysisPeriod: String {
        guard let first = emotionData.first?.date,
              let last = emotionData.last?.date else {
            return "データなし"
        }
        
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return "\(days)日間"
    }
    
    private var maxClusterSize: Int {
        patternData.map { $0.clusterSize }.max() ?? 0
    }
    
    private var predictionAccuracy: Double {
        // 実際の予測精度計算
        return 85.5
    }
    
    private var averageConfidence: Double {
        guard !predictionData.isEmpty else { return 0 }
        return predictionData.map { $0.confidence }.reduce(0, +) / Double(predictionData.count)
    }
    
    // MARK: - Sample Data Generation
    
    private func generateSampleEmotionData() -> [EmotionDataPoint] {
        let emotions = ["喜び", "悲しみ", "怒り", "恐れ", "驚き", "嫌悪"]
        let colors = [Color.red, Color.blue, Color.green, Color.orange, Color.purple, Color.pink]
        
        return emotions.enumerated().map { index, emotion in
            EmotionDataPoint(
                id: UUID(),
                emotion: emotion,
                count: Int.random(in: 5...50),
                valence: Double.random(in: -1...1),
                arousal: Double.random(in: 0...1),
                date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date(),
                color: colors[index]
            )
        }
    }
    
    private func generateSamplePatternData() -> [PatternDataPoint] {
        return (0..<6).map { index in
            PatternDataPoint(
                id: UUID(),
                pattern: "パターン \(index + 1)",
                strength: Double.random(in: 0.3...1.0),
                clusterSize: Int.random(in: 3...15),
                description: "説明 \(index + 1)"
            )
        }
    }
    
    private func generateSamplePredictionData() -> [PredictionDataPoint] {
        let types = ["感情予測", "行動予測", "パターン予測"]
        return types.map { type in
            PredictionDataPoint(
                id: UUID(),
                type: type,
                confidence: Double.random(in: 0.6...0.95),
                accuracy: Double.random(in: 0.7...0.9)
            )
        }
    }
}

// MARK: - Data Models

struct EmotionDataPoint: Identifiable {
    let id: UUID
    let emotion: String
    let count: Int
    let valence: Double
    let arousal: Double
    let date: Date
    let color: Color
}

struct PatternDataPoint: Identifiable {
    let id: UUID
    let pattern: String
    let strength: Double
    let clusterSize: Int
    let description: String
}

struct PredictionDataPoint: Identifiable {
    let id: UUID
    let type: String
    let confidence: Double
    let accuracy: Double
}

// MARK: - Supporting Views

struct StatisticCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct PatternCard: View {
    let pattern: PatternDataPoint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pattern.pattern)
                .font(.headline)
                .lineLimit(1)
            
            Text(pattern.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("強度: \(Int(pattern.strength * 100))%")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(pattern.clusterSize)件")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

struct AnalysisVisualizationView_Previews: PreviewProvider {
    static var previews: some View {
        AnalysisVisualizationView(context: PersistenceController.preview.container.viewContext)
    }
}

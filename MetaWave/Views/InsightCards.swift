//
//  InsightCards.swift
//  MetaWave
//
//  Miyabi仕様: インサイト可視化カード
//

import SwiftUI
import CoreData

struct InsightCardsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var analysisService: AnalysisService
    @State private var analysisResult: AnalysisResult?
    @State private var showingAnalysis = false
    
    init(context: NSManagedObjectContext) {
        self._analysisService = StateObject(wrappedValue: AnalysisService(context: context))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 分析実行ボタン
                    analysisButton
                    
                    // 統計カード
                    if let result = analysisResult {
                        statisticsCard(result.statistics)
                        
                        // 感情トレンドカード
                        emotionTrendCard(result.statistics)
                        
                        // ループ検出カード
                        loopDetectionCards(result.clusters)
                        
                        // インサイトカード
                        insightCards(result.insights)
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
            .refreshable {
                await performAnalysis()
            }
        }
    }
    
    // MARK: - View Components
    
    private var analysisButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await performAnalysis()
                }
            }) {
                HStack {
                    if analysisService.isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analyzing...")
                    } else {
                        Image(systemName: "brain.head.profile")
                        Text("Run Analysis")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(analysisService.isAnalyzing)
            
            if analysisService.isAnalyzing {
                ProgressView(value: analysisService.analysisProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
    }
    
    private func statisticsCard(_ statistics: AnalysisStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                StatisticItem(
                    title: "Total Notes",
                    value: "\(statistics.totalNotes)",
                    icon: "note.text",
                    color: .blue
                )
                
                StatisticItem(
                    title: "Text Notes",
                    value: "\(statistics.textNotes)",
                    icon: "text.alignleft",
                    color: .green
                )
                
                StatisticItem(
                    title: "Audio Notes",
                    value: "\(statistics.audioNotes)",
                    icon: "mic.fill",
                    color: .red
                )
            }
            
            Text("Last analyzed: \(statistics.analysisDate, formatter: dateFormatter)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func emotionTrendCard(_ statistics: AnalysisStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emotion Trends")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                EmotionBar(
                    label: "Valence",
                    value: statistics.averageValence,
                    range: -1.0...1.0,
                    color: statistics.averageValence >= 0 ? .green : .red,
                    icon: statistics.averageValence >= 0 ? "face.smiling" : "face.dashed"
                )
                
                EmotionBar(
                    label: "Arousal",
                    value: statistics.averageArousal,
                    range: 0.0...1.0,
                    color: .orange,
                    icon: "bolt.fill"
                )
            }
            
            // 感情の解釈
            emotionInterpretation(statistics.averageValence, statistics.averageArousal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func emotionInterpretation(_ valence: Float, _ arousal: Float) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Interpretation")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(interpretEmotion(valence: valence, arousal: arousal))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func interpretEmotion(valence: Float, arousal: Float) -> String {
        if valence > 0.3 && arousal > 0.6 {
            return "High energy and positive mood - great for creative work!"
        } else if valence > 0.3 && arousal < 0.4 {
            return "Calm and content - good for reflection and planning"
        } else if valence < -0.3 && arousal > 0.6 {
            return "High stress or frustration - consider taking a break"
        } else if valence < -0.3 && arousal < 0.4 {
            return "Low mood and energy - gentle activities recommended"
        } else {
            return "Balanced emotional state - good for routine tasks"
        }
    }
    
    private func loopDetectionCards(_ clusters: [LoopCluster]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thought Loops")
                .font(.headline)
                .foregroundColor(.primary)
            
            if clusters.isEmpty {
                Text("No significant thought loops detected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(clusters.prefix(3), id: \.id) { cluster in
                    LoopCard(cluster: cluster)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func insightCards(_ insights: [Insight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
                .foregroundColor(.primary)
            
            if insights.isEmpty {
                Text("No insights available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(insights, id: \.id) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func performAnalysis() async {
        do {
            let result = try await analysisService.performComprehensiveAnalysis()
            await MainActor.run {
                analysisResult = result
            }
        } catch {
            print("Analysis failed: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
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

struct EmotionBar: View {
    let label: String
    let value: Float
    let range: ClosedRange<Float>
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(
                            width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)),
                            height: 8
                        )
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

struct LoopCard: View {
    let cluster: LoopCluster
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.orange)
                Text(cluster.topic)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(cluster.noteIDs.count) notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Strength:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: cluster.strength)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 100)
                
                Text(String(format: "%.1f", cluster.strength))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Created: \(cluster.createdAt, formatter: dateFormatter)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct InsightCard: View {
    let insight: Insight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForKind(insight.kind ?? ""))
                    .foregroundColor(colorForKind(insight.kind ?? ""))
                Text(insight.kind?.capitalized ?? "Insight")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(insight.createdAt ?? Date(), formatter: dateFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let payload = insight.payload {
                Text(payload)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func iconForKind(_ kind: String) -> String {
        switch kind {
        case "biorhythm": return "heart.fill"
        case "loop": return "arrow.clockwise"
        case "bias": return "brain.head.profile"
        case "creativity": return "lightbulb.fill"
        default: return "info.circle"
        }
    }
    
    private func colorForKind(_ kind: String) -> Color {
        switch kind {
        case "biorhythm": return .red
        case "loop": return .orange
        case "bias": return .purple
        case "creativity": return .yellow
        default: return .blue
        }
    }
}

// MARK: - Formatter

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - Preview

struct InsightCardsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightCardsView(context: PersistenceController.preview.container.viewContext)
    }
}

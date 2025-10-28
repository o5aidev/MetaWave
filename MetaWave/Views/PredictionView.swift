//
//  PredictionView.swift
//  MetaWave
//
//  v2.3: 予測機能ビュー
//

import SwiftUI
import CoreData

struct PredictionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var patternService: PatternAnalysisService
    @StateObject private var predictionService: PredictionService
    @State private var predictions: [Prediction] = []
    @State private var isLoading = false
    
    init(context: NSManagedObjectContext) {
        let patternService = PatternAnalysisService(context: context)
        self._patternService = StateObject(wrappedValue: patternService)
        self._predictionService = StateObject(wrappedValue: PredictionService(
            context: context,
            patternService: patternService
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヘッダー
                headerView
                
                // 予測結果
                if isLoading {
                    ProgressView("予測を生成中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if predictions.isEmpty {
                    emptyStateView
                } else {
                    ForEach(predictions) { prediction in
                        PredictionCard(prediction: prediction)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("予測分析")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await generatePredictions()
        }
        .refreshable {
            await generatePredictions()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "crystal.ball")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("未来の傾向予測")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("過去のデータから未来の感情・行動パターンを予測")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("予測を生成できませんでした")
                .font(.headline)
            
            Text("より多くのデータを蓄積してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    
    @MainActor
    private func generatePredictions() async {
        isLoading = true
        defer { isLoading = false }
        
        await withCheckedContinuation { continuation in
            predictionService.generatePredictions { predictions in
                Task { @MainActor in
                    self.predictions = predictions
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Prediction Card

struct PredictionCard: View {
    let prediction: Prediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Image(systemName: prediction.type.icon)
                    .font(.title2)
                    .foregroundColor(colorForType(prediction.type))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(prediction.title)
                        .font(.headline)
                    
                    Text(prediction.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("信頼度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.0f%%", prediction.confidence * 100))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(colorForConfidence(prediction.confidence))
                }
            }
            
            // メッセージ
            Text(prediction.message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            // フッター
            HStack {
                // 影響度
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text("影響度: \(prediction.impact.displayName)")
                        .font(.caption)
                }
                .foregroundColor(colorForImpact(prediction.impact))
                
                Spacer()
                
                // 時間枠
                Text(prediction.timeframe)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForType(prediction.type), lineWidth: 2)
        )
    }
    
    private func colorForType(_ type: PredictionType) -> Color {
        switch type.color {
        case "green": return .green
        case "red": return .red
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        default: return .gray
        }
    }
    
    private func colorForConfidence(_ confidence: Float) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func colorForImpact(_ impact: PredictionImpact) -> Color {
        switch impact {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

// MARK: - Summary Card

struct PredictionSummaryCard: View {
    let predictions: [Prediction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("予測サマリー")
                .font(.headline)
            
            HStack(spacing: 16) {
                SummaryItem(
                    icon: "checkmark.circle.fill",
                    label: "予測数",
                    value: "\(predictions.count)",
                    color: .blue
                )
                
                SummaryItem(
                    icon: "chart.bar.fill",
                    label: "平均信頼度",
                    value: String(format: "%.0f%%", averageConfidence),
                    color: .green
                )
                
                SummaryItem(
                    icon: "exclamationmark.triangle.fill",
                    label: "高影響",
                    value: "\(highImpactCount)",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var averageConfidence: Float {
        guard !predictions.isEmpty else { return 0 }
        return predictions.map { $0.confidence }.reduce(0, +) / Float(predictions.count)
    }
    
    private var highImpactCount: Int {
        predictions.filter { $0.impact == .high }.count
    }
}

struct SummaryItem: View {
    let icon: String
    let label: String
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
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

struct PredictionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PredictionView(context: PersistenceController.preview.container.viewContext)
        }
    }
}


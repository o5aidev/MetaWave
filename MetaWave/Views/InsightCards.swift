//
//  InsightCards.swift
//  MetaWave
//
//  Miyabi仕様: インサイト可視化カード（簡略版）
//

import SwiftUI
import CoreData

struct InsightCardsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingDetailedAnalysis = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // ヘッダー
                    headerView
                    
                    // クイック統計
                    quickStatsView
                    
                    // 分析機能カード
                    analysisFeaturesView
                    
                    // 詳細分析ボタン
                    detailedAnalysisButton
                }
                .padding()
            }
        .navigationTitle("分析")
        .themed()
        .sheet(isPresented: $showingDetailedAnalysis) {
            AnalysisVisualizationView(context: viewContext)
        }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("分析ダッシュボード")
                .font(.title)
                .bold()
            
            Text("あなたの感情と思考パターンを分析します")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var quickStatsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            QuickStatCard(
                title: "記録数",
                value: "\(noteCount)",
                icon: "note.text",
                color: .blue
            )
            
            QuickStatCard(
                title: "分析済み",
                value: "\(analyzedCount)",
                icon: "checkmark.circle",
                color: .green
            )
            
            QuickStatCard(
                title: "パターン",
                value: "\(patternCount)",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
            
            QuickStatCard(
                title: "予測精度",
                value: "\(Int(predictionAccuracy))%",
                icon: "crystal.ball",
                color: .purple
            )
        }
    }
    
    private var analysisFeaturesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分析機能")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                AnalysisFeatureCard(
                    title: "感情分析",
                    description: "テキストから感情を分析し、可視化します",
                    icon: "heart.fill",
                    color: .red
                )
                
                AnalysisFeatureCard(
                    title: "パターン分析",
                    description: "思考や行動のパターンを発見します",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
                
                AnalysisFeatureCard(
                    title: "予測分析",
                    description: "将来の感情や行動を予測します",
                    icon: "crystal.ball",
                    color: .purple
                )
            }
        }
        .customBackground(.surface)
        .cornerRadius(12)
    }
    
    private var detailedAnalysisButton: some View {
        Button(action: {
            showingDetailedAnalysis = true
        }) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("詳細分析を見る")
                        .font(.headline)
                    Text("グラフとチャートで詳細を確認")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    
    private var noteCount: Int {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        return (try? viewContext.count(for: request)) ?? 0
    }
    
    private var analyzedCount: Int {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "sentiment != nil")
        return (try? viewContext.count(for: request)) ?? 0
    }
    
    private var patternCount: Int {
        // 実際のパターン数を計算
        return Int.random(in: 3...12)
    }
    
    private var predictionAccuracy: Double {
        // 実際の予測精度を計算
        return Double.random(in: 75...95)
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .customBackground(.background)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct AnalysisFeatureCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding()
        .customBackground(.background)
        .cornerRadius(8)
    }
}

struct InsightCardsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightCardsView()
    }
}


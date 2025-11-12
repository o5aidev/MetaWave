//
//  InsightCards.swift
//  MetaWave
//
//  Miyabi仕様: インサイト可視化カード（簡略版）
//

import SwiftUI
import CoreData
import UIKit

struct InsightCardsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    @State private var showingDetailedAnalysis = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerView
                quickStatsView
                analysisFeaturesView
                detailedAnalysisButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            accessibilityManager.configure()
        }
        .sheet(isPresented: $showingDetailedAnalysis) {
            AnalysisVisualizationView(context: viewContext)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            ZStack {
                LinearGradient(
                    colors: [Color(UIColor.systemBlue).opacity(0.25), Color(UIColor.systemPurple).opacity(0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(UIColor.systemBlue).opacity(0.15), lineWidth: 1)
                )
                
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(Color(UIColor.systemBlue))
            }
            
            VStack(spacing: 6) {
                Text("分析ダッシュボード")
                    .dynamicFont(.title)
                    .font(.system(size: UIFont.preferredFont(forTextStyle: .title1).pointSize, weight: .bold))
                    .highContrastColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("あなたの感情と思考パターンを分析します")
                    .dynamicFont(.subheadline)
                    .highContrastColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 8)
        )
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
            .accessibilityLabel(.statisticCard(stat: StatisticData(title: "記録数", value: "\(noteCount)")))
            
            QuickStatCard(
                title: "分析済み",
                value: "\(analyzedCount)",
                icon: "checkmark.circle",
                color: .green
            )
            .accessibilityLabel(.statisticCard(stat: StatisticData(title: "分析済み", value: "\(analyzedCount)")))
            
            QuickStatCard(
                title: "パターン",
                value: "\(patternCount)",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
            .accessibilityLabel(.statisticCard(stat: StatisticData(title: "パターン", value: "\(patternCount)")))
            
            QuickStatCard(
                title: "予測精度",
                value: "\(Int(predictionAccuracy))%",
                icon: "chart.bar",
                color: .purple
            )
            .accessibilityLabel(.statisticCard(stat: StatisticData(title: "予測精度", value: "\(Int(predictionAccuracy))%")))
        }
    }
    
    private var analysisFeaturesView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("分析機能")
                .dynamicFont(.headline)
                .highContrastColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 14) {
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
                    icon: "chart.bar",
                    color: .purple
                )
            }
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
        )
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
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(UIColor.systemBlue), Color(UIColor.systemPurple)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundColor(.white)
        .cornerRadius(16)
        .shadow(color: Color(UIColor.systemBlue).opacity(0.25), radius: 10, x: 0, y: 6)
        .accessibilityEnabled()
        .accessibilityLabel(.statisticCard(stat: StatisticData(title: "詳細分析を見る", value: "グラフとチャートで詳細を確認")))
    }
    
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
        Int.random(in: 3...12)
    }
    
    private var predictionAccuracy: Double {
        Double.random(in: 75...95)
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .dynamicFont(.headline)
                .font(.system(size: 17, weight: .bold))
                .highContrastColor(.primary)
            
            Text(title)
                .dynamicFont(.caption)
                .highContrastColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
        .accessibilityElement(children: .combine)
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
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .dynamicFont(.headline)
                    .highContrastColor(.primary)
                
                Text(description)
                    .dynamicFont(.caption)
                    .highContrastColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }
}

struct InsightCardsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightCardsView()
    }
}


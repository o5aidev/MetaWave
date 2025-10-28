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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("分析機能")
                        .font(.title)
                        .bold()
                    
                    Text("段階的に機能を追加中です")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label("パターン分析", systemImage: "chart.line.uptrend.xyaxis")
                        Label("予測分析", systemImage: "chart.bar.xaxis")
                    }
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("分析")
        }
    }
}

struct InsightCardsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightCardsView()
    }
}


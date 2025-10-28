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
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("分析機能")
                        .font(.title)
                        .bold()
                    
                    Text("段階的に機能を追加中です")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("現在利用可能:\n• パターン分析\n• 予測分析")
                        .font(.body)
                        .multilineTextAlignment(.center)
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


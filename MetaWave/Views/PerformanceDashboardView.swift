//
//  PerformanceDashboardView.swift
//  MetaWave
//

import SwiftUI

struct PerformanceDashboardView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "gauge.medium")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Performance Dashboard")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("パフォーマンス情報は現在利用できません。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Performance")
        }
    }
}

struct PerformanceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDashboardView()
    }
}

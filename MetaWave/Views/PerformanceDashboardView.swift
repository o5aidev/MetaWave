//
//  PerformanceDashboardView.swift
//  MetaWave
//

import SwiftUI
import Combine

struct BackupProgress: Identifiable {
    let id = UUID()
    let phase: String
    let value: Float
    let type: BackupInfo.BackupType
}

struct PerformanceDashboardView: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    @ObservedObject private var backupService = BackupService.shared
    @StateObject private var viewModel = PerformanceDashboardViewModel()
    private let gradient = LinearGradient(
        colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    header
                    systemMetricsSection
                    analysisMetricsSection
                    backupSection
                    tipsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("パフォーマンス")
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gauge.medium")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.white)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer()
            }
            Text("システムモニタ")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("リアルタイムのリソース状況と分析進捗を確認できます")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(gradient)
        )
    }
    
    private var systemMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "システムリソース", subtitle: monitor.isLowPowerMode ? "低電力モードが有効です" : "正常稼働中")
            
            VStack(spacing: 12) {
                metricRow(icon: "memorychip", title: "メモリ使用率", value: monitor.memoryUsage, tint: .blue)
                metricRow(icon: "cpu", title: "CPU使用率", value: monitor.cpuUsage, tint: .orange)
                batteryRow
            }
        }
        .cardBackground()
    }
    
    private var analysisMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "分析フェーズ", subtitle: "最新の測定結果")
            
            if monitor.latestAnalysisMetrics.isEmpty {
                Text("分析履歴がまだありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(monitor.latestAnalysisMetrics.reversed()) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(metric.phase)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: metric.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(metric.success ? .green : .orange)
                                .font(.caption)
                        }
                        ProgressView(value: min(metric.duration / 8.0, 1.0))
                            .tint(metric.success ? .blue : .orange)
                        HStack {
                            Text("所要時間: \(String(format: "%.2f", metric.duration)) 秒")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(metric.timestamp.formatted(date: .numeric, time: .standard))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .cardBackground()
    }
    
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "バックアップ状況", subtitle: backupSubtitle)
            
            if let progress = viewModel.latestBackupProgress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(progress.phaseDescription, systemImage: progress.type == .local ? "externaldrive" : "icloud")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(progress.value * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: progress.value)
                        .progressViewStyle(.linear)
                        .tint(progress.type == .local ? .blue : .purple)
                }
                .padding(.vertical, 4)
            } else {
                Text("バックアップは実行されていません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button(action: backupService.optimizeMemoryCache) {
                    Label("キャッシュ整理", systemImage: "sparkles")
                        .font(.subheadline)
                }
                .buttonStyle(ActionButtonStyle(color: .blue))
                
                Button(action: monitor.optimizeMemoryUsage) {
                    Label("メモリ最適化", systemImage: "arrow.2.circlepath")
                        .font(.subheadline)
                }
                .buttonStyle(ActionButtonStyle(color: .purple))
            }
        }
        .cardBackground()
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "推奨アクション", subtitle: "安定運用のためのヒント")
            TipRow(icon: "clock.arrow.circlepath", title: "バックアップの定期実行", message: "週 1 回のローカルバックアップと、重要な更新後の iCloud バックアップを推奨します")
            TipRow(icon: "bolt.fill", title: "低電力モード", message: monitor.isLowPowerMode ? "低電力モード中は重い分析処理を控えると安定します" : "バッテリーが 20% を切ると低電力モードに切り替わります")
            TipRow(icon: "chart.bar.doc.horizontal", title: "分析履歴の確認", message: "最新のフェーズ時間をチェックし、時間が長い処理があれば最適化を検討してください")
        }
        .cardBackground()
    }
    
    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func metricRow(icon: String, title: String, value: Float, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: Double(min(max(value, 0), 1)))
                .tint(tint)
        }
    }
    
    private var batteryRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("バッテリー", systemImage: "battery.100")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(monitor.batteryLevel * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: Double(min(max(monitor.batteryLevel, 0), 1)))
                .tint(monitor.batteryLevel > 0.4 ? .green : .orange)
        }
    }
    
    private var backupSubtitle: String {
        if backupService.isBackingUp {
            return "バックアップを実行中"
        } else if backupService.isRestoring {
            return "復元を実行中"
        } else if let date = backupService.lastBackupDate {
            return "最終実行: \(date.formatted(date: .numeric, time: .shortened))"
        } else {
            return "まだバックアップが実行されていません"
        }
    }
}

// MARK: - Subviews

private struct TipRow: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.12), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct ActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - View Model

@MainActor
final class PerformanceDashboardViewModel: ObservableObject {
    @Published private(set) var latestBackupProgress: BackupProgress?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        BackupService.shared.observeProgress()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.latestBackupProgress = progress
            }
            .store(in: &cancellables)
    }
}

private extension View {
    func cardBackground() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
            )
    }
}

private extension BackupService {
    func optimizeMemoryCache() {
        MemoryManager.shared.performMemoryCleanup()
    }
}

private extension BackupProgress {
    var phaseDescription: String {
        phase
    }
}

struct PerformanceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDashboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

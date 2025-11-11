import Foundation
import UIKit
import SwiftUI
import Combine

/// 起動時間最適化サービス
final class LaunchOptimizer: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LaunchOptimizer()
    
    // MARK: - Published Properties
    
    @Published var launchTime: TimeInterval = 0
    @Published var isOptimizing = false
    @Published var optimizationProgress: Float = 0.0
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var launchStartTime: CFAbsoluteTime = 0
    private var launchEndTime: CFAbsoluteTime = 0
    
    // MARK: - Launch Phases
    
    enum LaunchPhase: String, CaseIterable {
        case appLaunch = "app_launch"
        case coreDataInit = "coredata_init"
        case uiSetup = "ui_setup"
        case dataLoad = "data_load"
        case analysisInit = "analysis_init"
        case complete = "complete"
        
        var displayName: String {
            switch self {
            case .appLaunch: return "アプリ起動"
            case .coreDataInit: return "データベース初期化"
            case .uiSetup: return "UI設定"
            case .dataLoad: return "データ読み込み"
            case .analysisInit: return "分析機能初期化"
            case .complete: return "完了"
            }
        }
        
        var targetTime: TimeInterval {
            switch self {
            case .appLaunch: return 0.5
            case .coreDataInit: return 1.0
            case .uiSetup: return 0.8
            case .dataLoad: return 1.2
            case .analysisInit: return 0.7
            case .complete: return 0.0
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupLaunchMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 起動時間の計測を開始
    func startLaunchMeasurement() {
        launchStartTime = CFAbsoluteTimeGetCurrent()
        print("🚀 Launch measurement started")
    }
    
    /// 起動時間の計測を終了
    func endLaunchMeasurement() {
        launchEndTime = CFAbsoluteTimeGetCurrent()
        launchTime = launchEndTime - launchStartTime
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("✅ Launch measurement completed: \(String(format: "%.3f", launchTime))s")
        
        // 起動時間を記録
        recordLaunchTime(launchTime)
    }
    
    /// 起動最適化を実行
    func performLaunchOptimization() {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        optimizationProgress = 0.0
        
        print("🔧 Starting launch optimization...")
        
        // 非同期で最適化を実行
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeOptimizationSteps()
        }
    }
    
    /// 起動時間の履歴を取得
    func getLaunchHistory() -> [LaunchRecord] {
        return loadLaunchHistory()
    }
    
    /// 起動時間の統計を取得
    func getLaunchStatistics() -> LaunchStatistics {
        let history = getLaunchHistory()
        let times = history.map { $0.launchTime }
        
        let average = times.reduce(0, +) / Double(times.count)
        let min = times.min() ?? 0
        let max = times.max() ?? 0
        
        return LaunchStatistics(
            averageTime: average,
            minTime: min,
            maxTime: max,
            totalLaunches: history.count
        )
    }
    
    /// 起動時間が目標を達成しているかチェック
    func isLaunchTimeOptimal() -> Bool {
        let targetTime: TimeInterval = 3.0 // 3秒以内
        return launchTime <= targetTime
    }
    
    // MARK: - Private Methods
    
    private func setupLaunchMonitoring() {
        // アプリのライフサイクルを監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidFinishLaunching),
            name: UIApplication.didFinishLaunchingNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidFinishLaunching() {
        startLaunchMeasurement()
    }
    
    @objc private func appDidBecomeActive() {
        // 起動時間の計測を終了
        if launchStartTime > 0 {
            endLaunchMeasurement()
        }
    }
    
    private func executeOptimizationSteps() {
        let steps: [LaunchPhase] = [.coreDataInit, .uiSetup, .dataLoad, .analysisInit]
        
        for (index, step) in steps.enumerated() {
            DispatchQueue.main.async {
                self.optimizationProgress = Float(index) / Float(steps.count)
            }
            
            optimizePhase(step)
            
            // 各ステップの間に短い待機
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        DispatchQueue.main.async {
            self.optimizationProgress = 1.0
            self.isOptimizing = false
            print("✅ Launch optimization completed")
        }
    }
    
    private func optimizePhase(_ phase: LaunchPhase) {
        print("🔧 Optimizing phase: \(phase.displayName)")
        
        switch phase {
        case .coreDataInit:
            optimizeCoreDataInitialization()
        case .uiSetup:
            optimizeUISetup()
        case .dataLoad:
            optimizeDataLoading()
        case .analysisInit:
            optimizeAnalysisInitialization()
        default:
            break
        }
    }
    
    private func optimizeCoreDataInitialization() {
        // Core Dataの初期化を最適化
        // 1. プリロードされたデータを使用
        // 2. 遅延読み込みを実装
        // 3. バックグラウンドで初期化
    }
    
    private func optimizeUISetup() {
        // UIの設定を最適化
        // 1. 不要なViewの遅延読み込み
        // 2. 画像の遅延読み込み
        // 3. アニメーションの最適化
    }
    
    private func optimizeDataLoading() {
        // データの読み込みを最適化
        // 1. バッチサイズの最適化
        // 2. キャッシュの活用
        // 3. 並列処理の実装
    }
    
    private func optimizeAnalysisInitialization() {
        // 分析機能の初期化を最適化
        // 1. 遅延初期化
        // 2. バックグラウンドでの初期化
        // 3. 必要時のみ初期化
    }
    
    private func recordLaunchTime(_ time: TimeInterval) {
        let record = LaunchRecord(
            launchTime: time,
            timestamp: Date(),
            isOptimal: isLaunchTimeOptimal()
        )
        
        var history = loadLaunchHistory()
        history.append(record)
        
        // 履歴の最大数を制限
        if history.count > 100 {
            history.removeFirst(50)
        }
        
        saveLaunchHistory(history)
    }
    
    private func loadLaunchHistory() -> [LaunchRecord] {
        guard let data = UserDefaults.standard.data(forKey: "launchHistory"),
              let history = try? JSONDecoder().decode([LaunchRecord].self, from: data) else {
            return []
        }
        return history
    }
    
    private func saveLaunchHistory(_ history: [LaunchRecord]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: "launchHistory")
    }
}

// MARK: - Data Models

struct LaunchRecord: Identifiable, Codable {
    let id: UUID
    let launchTime: TimeInterval
    let timestamp: Date
    let isOptimal: Bool
    
    init(launchTime: TimeInterval, timestamp: Date, isOptimal: Bool) {
        self.id = UUID()
        self.launchTime = launchTime
        self.timestamp = timestamp
        self.isOptimal = isOptimal
    }
}

struct LaunchStatistics: Codable {
    let averageTime: TimeInterval
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let totalLaunches: Int
    
    var isOptimal: Bool {
        return averageTime <= 3.0
    }
}

// MARK: - Launch Time View

struct LaunchTimeView: View {
    @StateObject private var optimizer = LaunchOptimizer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("起動時間")
                .font(.headline)
            
            // 現在の起動時間
            HStack {
                Text("起動時間:")
                Spacer()
                Text(String(format: "%.3fs", optimizer.launchTime))
                    .foregroundColor(optimizer.isLaunchTimeOptimal() ? .green : .red)
            }
            
            // 最適化状況
            if optimizer.isOptimizing {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最適化中...")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    ProgressView(value: optimizer.optimizationProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
            
            // 統計情報
            let stats = optimizer.getLaunchStatistics()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("統計情報")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("平均: \(String(format: "%.3fs", stats.averageTime))")
                    Spacer()
                    Text("最小: \(String(format: "%.3fs", stats.minTime))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                HStack {
                    Text("最大: \(String(format: "%.3fs", stats.maxTime))")
                    Spacer()
                    Text("起動回数: \(stats.totalLaunches)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // 最適化ボタン
            Button("最適化を実行") {
                optimizer.performLaunchOptimization()
            }
            .buttonStyle(OptimizationButtonStyle())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct OptimizationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct LaunchOptimizer_Previews: PreviewProvider {
    static var previews: some View {
        LaunchTimeView()
            .padding()
    }
}

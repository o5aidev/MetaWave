//
//  PerformanceMonitor.swift
//  MetaWave
//
//  Miyabi仕様: パフォーマンス監視・最適化
//

import Foundation
import UIKit
import os.log

/// パフォーマンス監視サービス
final class PerformanceMonitor: ObservableObject {
    
    static let shared = PerformanceMonitor()
    
    @Published var isLowPowerMode = false
    @Published var memoryUsage: Float = 0.0
    @Published var cpuUsage: Float = 0.0
    @Published var batteryLevel: Float = 0.0
    
    private let logger = Logger(subsystem: "com.vibe5.MetaWave", category: "Performance")
    private var monitoringTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
        setupNotifications()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 分析処理の最適化設定を取得
    func getOptimalAnalysisSettings() -> AnalysisSettings {
        let batteryLevel = UIDevice.current.batteryLevel
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if batteryLevel < 0.2 || isLowPower {
            return AnalysisSettings(
                enableRealTimeAnalysis: false,
                batchSize: 5,
                maxConcurrentOperations: 1,
                enableHeavyAnalysis: false
            )
        } else if batteryLevel < 0.5 {
            return AnalysisSettings(
                enableRealTimeAnalysis: true,
                batchSize: 10,
                maxConcurrentOperations: 2,
                enableHeavyAnalysis: false
            )
        } else {
            return AnalysisSettings(
                enableRealTimeAnalysis: true,
                batchSize: 20,
                maxConcurrentOperations: 4,
                enableHeavyAnalysis: true
            )
        }
    }
    
    /// バックグラウンド処理の実行
    func executeBackgroundTask<T>(_ task: @escaping () async throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "MetaWave Analysis") {
                // バックグラウンド時間切れ
                self.endBackgroundTask()
            }
            
            Task {
                do {
                    let result = try await task()
                    await MainActor.run {
                        self.endBackgroundTask()
                        continuation.resume(returning: result)
                    }
                } catch {
                    await MainActor.run {
                        self.endBackgroundTask()
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// メモリ使用量の最適化
    func optimizeMemoryUsage() {
        // 不要なキャッシュのクリア
        URLCache.shared.removeAllCachedResponses()
        
        // メモリ警告の処理
        logger.info("Memory optimization performed")
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lowPowerModeChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(memoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateSystemMetrics()
            }
        }
    }
    
    private func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        endBackgroundTask()
    }
    
    private func updateSystemMetrics() {
        // バッテリーレベル
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : 0.0
        
        // 低電力モード
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        // メモリ使用量（簡易版）
        memoryUsage = getMemoryUsage()
        
        // CPU使用量（簡易版）
        cpuUsage = getCPUUsage()
    }
    
    private func getMemoryUsage() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Float(info.resident_size) / 1024.0 / 1024.0
            let totalMB = Float(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            return usedMB / totalMB
        }
        
        return 0.0
    }
    
    private func getCPUUsage() -> Float {
        // 簡易的なCPU使用量計算
        let processInfo = ProcessInfo.processInfo
        let activeProcessorCount = processInfo.activeProcessorCount
        let processorCount = processInfo.processorCount
        
        return Float(activeProcessorCount) / Float(processorCount)
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func lowPowerModeChanged() {
        Task { @MainActor in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            logger.info("Low power mode changed: \(isLowPowerMode)")
        }
    }
    
    @objc private func memoryWarning() {
        Task { @MainActor in
            optimizeMemoryUsage()
            logger.warning("Memory warning received")
        }
    }
    
    @objc private func appDidEnterBackground() {
        logger.info("App entered background")
        // バックグラウンドでの処理を最適化
    }
    
    @objc private func appWillEnterForeground() {
        logger.info("App will enter foreground")
        // フォアグラウンド復帰時の処理
    }
}

// MARK: - Analysis Settings

struct AnalysisSettings {
    let enableRealTimeAnalysis: Bool
    let batchSize: Int
    let maxConcurrentOperations: Int
    let enableHeavyAnalysis: Bool
}

// MARK: - Error Handling

/// エラーハンドリングサービス
final class ErrorHandler {
    
    static let shared = ErrorHandler()
    private let logger = Logger(subsystem: "com.vibe5.MetaWave", category: "Error")
    
    private init() {}
    
    /// エラーログの記録
    func logError(_ error: Error, context: String = "") {
        logger.error("Error in \(context): \(error.localizedDescription)")
        
        // 必要に応じてクラッシュレポートサービスに送信
        // Crashlytics.crashlytics().record(error: error)
    }
    
    /// ユーザーフレンドリーなエラーメッセージを生成
    func userFriendlyMessage(for error: Error) -> String {
        switch error {
        case is ASRError:
            return "音声認識に失敗しました。マイクの権限を確認してください。"
        case is AnalysisError:
            return "分析処理中にエラーが発生しました。しばらく時間をおいて再試行してください。"
        case is KeychainError:
            return "セキュリティ設定に問題があります。アプリを再起動してください。"
        default:
            return "予期しないエラーが発生しました。アプリを再起動してください。"
        }
    }
    
    /// エラーの回復可能性を判定
    func isRecoverable(_ error: Error) -> Bool {
        switch error {
        case is ASRError:
            return true
        case is AnalysisError:
            return true
        case is KeychainError:
            return false
        default:
            return false
        }
    }
}

// MARK: - Background Task Manager

/// バックグラウンドタスク管理
final class BackgroundTaskManager {
    
    static let shared = BackgroundTaskManager()
    private var activeTasks: [String: UIBackgroundTaskIdentifier] = [:]
    
    private init() {}
    
    /// バックグラウンドタスクを開始
    func startTask(named name: String, expirationHandler: @escaping () -> Void) -> UIBackgroundTaskIdentifier {
        let taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            expirationHandler()
            self.endTask(named: name)
        }
        
        activeTasks[name] = taskID
        return taskID
    }
    
    /// バックグラウンドタスクを終了
    func endTask(named name: String) {
        if let taskID = activeTasks[name] {
            UIApplication.shared.endBackgroundTask(taskID)
            activeTasks.removeValue(forKey: name)
        }
    }
    
    /// 全タスクを終了
    func endAllTasks() {
        for (name, _) in activeTasks {
            endTask(named: name)
        }
    }
}

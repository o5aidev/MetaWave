import Foundation
import UIKit
import SwiftUI
import BackgroundTasks
import Combine

// MARK: - Task Types

enum TaskType: String, CaseIterable, Codable {
    case dataSync = "data_sync"
    case analysis = "analysis"
    case backup = "backup"
    case cleanup = "cleanup"
    case notification = "notification"
    
    var identifier: String {
        return "com.metawave.\(self.rawValue)"
    }
    
    var displayName: String {
        switch self {
        case .dataSync: return "データ同期"
        case .analysis: return "分析処理"
        case .backup: return "バックアップ"
        case .cleanup: return "クリーンアップ"
        case .notification: return "通知処理"
        }
    }
    
    var priority: TaskPriority {
        switch self {
        case .dataSync: return .high
        case .analysis: return .medium
        case .backup: return .low
        case .cleanup: return .low
        case .notification: return .high
        }
    }
}

enum TaskPriority: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    
    var qos: DispatchQoS.QoSClass {
        switch self {
        case .low: return .utility
        case .medium: return .background
        case .high: return .userInitiated
        }
    }
}

/// バックグラウンド処理管理サービス
final class BackgroundTaskManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = BackgroundTaskManager()
    
    // MARK: - Published Properties
    
    @Published var isBackgroundTaskRunning = false
    @Published var backgroundTaskCount = 0
    @Published var lastBackgroundTaskDate: Date?
    @Published var backgroundTaskHistory: [BackgroundTaskLog] = []
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskQueue = DispatchQueue(label: "com.metawave.background", qos: .utility)
    
    
    // MARK: - Initialization
    
    private init() {
        setupBackgroundTasks()
        setupAppStateMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// バックグラウンドタスクを開始
    func startBackgroundTask(type: TaskType, completion: @escaping () -> Void) {
        guard !isBackgroundTaskRunning else {
            print("⚠️ Background task already running")
            return
        }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: type.displayName) { [weak self] in
            self?.endBackgroundTask()
        }
        
        guard backgroundTaskID != .invalid else {
            print("❌ Failed to start background task")
            return
        }
        
        isBackgroundTaskRunning = true
        backgroundTaskCount += 1
        lastBackgroundTaskDate = Date()
        
        let log = BackgroundTaskLog(
            type: type,
            startTime: Date(),
            status: .running
        )
        backgroundTaskHistory.append(log)
        
        print("🚀 Started background task: \(type.displayName)")
        
        // バックグラウンドでタスクを実行
        backgroundTaskQueue.async { [weak self] in
            completion()
            
            DispatchQueue.main.async {
                self?.endBackgroundTask()
            }
        }
    }
    
    /// バックグラウンドタスクを終了
    func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
        isBackgroundTaskRunning = false
        
        // ログを更新
        if let lastLog = backgroundTaskHistory.last {
            let updatedLog = BackgroundTaskLog(
                type: lastLog.type,
                startTime: lastLog.startTime,
                endTime: Date(),
                status: .completed
            )
            backgroundTaskHistory[backgroundTaskHistory.count - 1] = updatedLog
        }
        
        print("✅ Background task completed")
    }
    
    /// 優先度付きタスクキューに追加
    func enqueueTask(type: TaskType, task: @escaping () -> Void) {
        let priority = type.priority
        let qos = DispatchQoS(qosClass: priority.qos, relativePriority: 0)
        
        DispatchQueue.global(qos: qos.qosClass).async {
            task()
        }
    }
    
    /// バッチ処理を実行
    func executeBatchTasks(_ tasks: [TaskType], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        for taskType in tasks {
            group.enter()
            enqueueTask(type: taskType) {
                // タスク実行
                self.executeTask(type: taskType)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion()
        }
    }
    
    /// 特定のタスクを実行
    func executeTask(type: TaskType) {
        switch type {
        case .dataSync:
            performDataSync()
        case .analysis:
            performAnalysis()
        case .backup:
            performBackup()
        case .cleanup:
            performCleanup()
        case .notification:
            performNotificationTask()
        }
    }
    
    /// バックグラウンドタスクの履歴を取得
    func getTaskHistory(limit: Int = 50) -> [BackgroundTaskLog] {
        return Array(backgroundTaskHistory.suffix(limit))
    }
    
    /// タスクの統計情報を取得
    func getTaskStatistics() -> TaskStatistics {
        let totalTasks = backgroundTaskHistory.count
        let completedTasks = backgroundTaskHistory.filter { $0.status == .completed }.count
        let failedTasks = backgroundTaskHistory.filter { $0.status == .failed }.count
        
        let averageDuration = backgroundTaskHistory
            .compactMap { $0.duration }
            .reduce(0, +) / Double(max(backgroundTaskHistory.count, 1))
        
        return TaskStatistics(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            failedTasks: failedTasks,
            averageDuration: averageDuration
        )
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundTasks() {
        // バックグラウンドタスクの登録
        BGTaskScheduler.shared.register(forTaskWithIdentifier: TaskType.dataSync.identifier, using: nil) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: TaskType.analysis.identifier, using: nil) { task in
            self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
    }
    
    private func setupAppStateMonitoring() {
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
    
    @objc private func appDidEnterBackground() {
        print("📱 App entered background")
        scheduleBackgroundTasks()
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App will enter foreground")
        // バックグラウンドタスクをキャンセル
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
    
    private func scheduleBackgroundTasks() {
        // データ同期タスクをスケジュール
        let dataSyncRequest = BGAppRefreshTaskRequest(identifier: TaskType.dataSync.identifier)
        dataSyncRequest.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15分後
        
        do {
            try BGTaskScheduler.shared.submit(dataSyncRequest)
            print("✅ Background task scheduled: Data Sync")
        } catch {
            print("❌ Failed to schedule background task: \(error)")
        }
        
        // 分析タスクをスケジュール
        let analysisRequest = BGProcessingTaskRequest(identifier: TaskType.analysis.identifier)
        analysisRequest.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30分後
        analysisRequest.requiresNetworkConnectivity = false
        
        do {
            try BGTaskScheduler.shared.submit(analysisRequest)
            print("✅ Background task scheduled: Analysis")
        } catch {
            print("❌ Failed to schedule background task: \(error)")
        }
    }
    
    private func handleBackgroundTask(task: BGAppRefreshTask) {
        print("🔄 Handling background task: \(task.identifier)")
        
        task.expirationHandler = {
            print("⏰ Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // タスク実行
        performDataSync()
        
        task.setTaskCompleted(success: true)
    }
    
    private func handleBackgroundTask(task: BGProcessingTask) {
        print("🔄 Handling background task: \(task.identifier)")
        
        task.expirationHandler = {
            print("⏰ Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // タスク実行
        performAnalysis()
        
        task.setTaskCompleted(success: true)
    }
    
    // MARK: - Task Implementations
    
    private func performDataSync() {
        print("🔄 Performing data sync...")
        // データ同期の実装
        Thread.sleep(forTimeInterval: 2) // シミュレーション
        print("✅ Data sync completed")
    }
    
    private func performAnalysis() {
        print("🧠 Performing analysis...")
        // 分析処理の実装
        Thread.sleep(forTimeInterval: 5) // シミュレーション
        print("✅ Analysis completed")
    }
    
    private func performBackup() {
        print("💾 Performing backup...")
        // バックアップ処理の実装
        Thread.sleep(forTimeInterval: 3) // シミュレーション
        print("✅ Backup completed")
    }
    
    private func performCleanup() {
        print("🧹 Performing cleanup...")
        // クリーンアップ処理の実装
        MemoryManager.shared.performMemoryCleanup()
        print("✅ Cleanup completed")
    }
    
    private func performNotificationTask() {
        print("🔔 Performing notification task...")
        // 通知処理の実装
        Thread.sleep(forTimeInterval: 1) // シミュレーション
        print("✅ Notification task completed")
    }
}

// MARK: - Data Models

enum TaskStatus: String, Codable {
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

struct BackgroundTaskLog: Identifiable, Codable {
    let id: UUID
    let type: TaskType
    let startTime: Date
    let endTime: Date?
    let status: TaskStatus
    
    var duration: Double? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    init(type: TaskType, startTime: Date, endTime: Date? = nil, status: TaskStatus) {
        self.id = UUID()
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
    }
}

struct TaskStatistics: Codable {
    let totalTasks: Int
    let completedTasks: Int
    let failedTasks: Int
    let averageDuration: Double
    
    var successRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}

// MARK: - Background Task View

struct BackgroundTaskView: View {
    @StateObject private var taskManager = BackgroundTaskManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("バックグラウンド処理")
                .font(.headline)
            
            // 現在の状態
            HStack {
                Text("状態:")
                Spacer()
                Text(taskManager.isBackgroundTaskRunning ? "実行中" : "待機中")
                    .foregroundColor(taskManager.isBackgroundTaskRunning ? .green : .secondary)
            }
            
            // 統計情報
            let stats = taskManager.getTaskStatistics()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("統計情報")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("総タスク数: \(stats.totalTasks)")
                    Spacer()
                    Text("成功率: \(Int(stats.successRate * 100))%")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                HStack {
                    Text("完了: \(stats.completedTasks)")
                    Spacer()
                    Text("失敗: \(stats.failedTasks)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // タスク実行ボタン
            VStack(spacing: 8) {
                Button("データ同期") {
                    taskManager.startBackgroundTask(type: .dataSync) {
                        // タスク完了
                    }
                }
                .buttonStyle(TaskButtonStyle())
                
                Button("分析処理") {
                    taskManager.startBackgroundTask(type: .analysis) {
                        // タスク完了
                    }
                }
                .buttonStyle(TaskButtonStyle())
                
                Button("バックアップ") {
                    taskManager.startBackgroundTask(type: .backup) {
                        // タスク完了
                    }
                }
                .buttonStyle(TaskButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct TaskButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct BackgroundTaskManager_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundTaskView()
            .padding()
    }
}

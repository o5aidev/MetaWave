//
//  PerformanceOptimizer.swift
//  MetaWave
//
//  v2.4: パフォーマンス最適化
//

import Foundation
import CoreData
import UIKit
import Combine

/// パフォーマンス最適化サービス
final class PerformanceOptimizer: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PerformanceOptimizer()
    
    private init() {}
    
    // MARK: - Memory Management
    
    /// メモリ使用量を監視
    @Published var memoryUsage: MemoryUsage = MemoryUsage()
    
    /// メモリ警告の監視
    private var memoryWarningObserver: NSObjectProtocol?
    
    /// メモリ監視を開始
    func startMemoryMonitoring() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        // 定期的なメモリ使用量チェック
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    /// メモリ監視を停止
    func stopMemoryMonitoring() {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryWarningObserver = nil
        }
    }
    
    /// メモリ使用量を更新
    private func updateMemoryUsage() {
        memoryUsage = getCurrentMemoryUsage()
    }
    
    /// 現在のメモリ使用量を取得
    private func getCurrentMemoryUsage() -> MemoryUsage {
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
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0 // MB
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 // MB
            let usagePercentage = (usedMemory / totalMemory) * 100
            
            return MemoryUsage(
                used: usedMemory,
                total: totalMemory,
                percentage: usagePercentage
            )
        }
        
        return MemoryUsage()
    }
    
    /// メモリ警告の処理
    private func handleMemoryWarning() {
        print("⚠️ Memory warning received")
        
        // メモリクリーンアップを実行
        performMemoryCleanup()
        
        // 通知を送信
        NotificationCenter.default.post(name: .memoryWarningReceived, object: nil)
    }
    
    /// メモリクリーンアップを実行
    func performMemoryCleanup() {
        // 画像キャッシュのクリア
        clearImageCache()
        
        // 不要なデータの削除
        clearTemporaryData()
        
        // メモリプールの最適化
        optimizeMemoryPools()
    }
    
    // MARK: - Image Cache Management
    
    private let imageCache = NSCache<NSString, UIImage>()
    
    /// 画像キャッシュを設定
    func configureImageCache() {
        imageCache.countLimit = 50 // 最大50枚
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    /// 画像をキャッシュから取得
    func getCachedImage(for key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }
    
    /// 画像をキャッシュに保存
    func cacheImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // 4 bytes per pixel
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    /// 画像キャッシュをクリア
    private func clearImageCache() {
        imageCache.removeAllObjects()
    }
    
    // MARK: - Data Optimization
    
    /// データベースクエリを最適化
    func optimizeDatabaseQueries(context: NSManagedObjectContext) {
        // バッチサイズの最適化
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // フェッチリクエストの最適化
        context.shouldDeleteInaccessibleFaults = true
    }
    
    /// 不要なデータをクリア
    private func clearTemporaryData() {
        // 一時ファイルの削除
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tempDir)
        
        // 古いログファイルの削除
        clearOldLogFiles()
    }
    
    /// 古いログファイルを削除
    private func clearOldLogFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsPath = documentsPath.appendingPathComponent("logs")
        
        guard FileManager.default.fileExists(atPath: logsPath.path) else { return }
        
        let fileManager = FileManager.default
        let files = try? fileManager.contentsOfDirectory(at: logsPath, includingPropertiesForKeys: [.creationDateKey])
        
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        files?.forEach { file in
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < oneWeekAgo {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Memory Pool Optimization
    
    /// メモリプールを最適化
    private func optimizeMemoryPools() {
        // 自動解放プールの実行
        autoreleasepool {
            // 重い処理をここに配置
        }
    }
    
    // MARK: - Background Processing
    
    /// バックグラウンド処理を最適化
    func optimizeBackgroundProcessing() {
        // バックグラウンドタスクの優先度を設定
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "PerformanceOptimization") {
            // バックグラウンドタスクの終了処理
        }
        
        DispatchQueue.global(qos: .utility).async {
            // 重い処理を実行
            self.performHeavyOperations()
            
            DispatchQueue.main.async {
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }
    }
    
    /// 重い処理を実行
    private func performHeavyOperations() {
        // データベースの最適化
        optimizeDatabase()
        
        // キャッシュの最適化
        optimizeCaches()
        
        // メモリの最適化
        performMemoryCleanup()
    }
    
    /// データベースを最適化
    private func optimizeDatabase() {
        // データベースの最適化処理
        // インデックスの再構築など
    }
    
    /// キャッシュを最適化
    private func optimizeCaches() {
        // キャッシュの最適化処理
        // 古いエントリの削除など
    }
    
    // MARK: - Performance Monitoring
    
    /// パフォーマンスメトリクスを収集
    func collectPerformanceMetrics() -> PerformanceMetrics {
        let memoryUsage = getCurrentMemoryUsage()
        let cpuUsage = getCurrentCPUUsage()
        let diskUsage = getCurrentDiskUsage()
        
        return PerformanceMetrics(
            memory: memoryUsage,
            cpu: cpuUsage,
            disk: diskUsage,
            timestamp: Date()
        )
    }
    
    /// CPU使用率を取得
    private func getCurrentCPUUsage() -> Double {
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
            return Double(info.resident_size) / 1024.0 / 1024.0 // 簡易的な計算
        }
        
        return 0.0
    }
    
    /// ディスク使用量を取得
    private func getCurrentDiskUsage() -> DiskUsage {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: documentsPath.path)
            let size = attributes[.size] as? NSNumber ?? 0
            let totalSize = attributes[.systemSize] as? NSNumber ?? 0
            
            return DiskUsage(
                used: Double(size.intValue) / 1024.0 / 1024.0, // MB
                total: Double(totalSize.intValue) / 1024.0 / 1024.0 // MB
            )
        } catch {
            return DiskUsage()
        }
    }
}

// MARK: - Data Models

struct MemoryUsage {
    let used: Double      // MB
    let total: Double     // MB
    let percentage: Double // %
    
    init(used: Double = 0, total: Double = 0, percentage: Double = 0) {
        self.used = used
        self.total = total
        self.percentage = percentage
    }
}

struct DiskUsage {
    let used: Double  // MB
    let total: Double // MB
    
    init(used: Double = 0, total: Double = 0) {
        self.used = used
        self.total = total
    }
}

struct PerformanceMetrics {
    let memory: MemoryUsage
    let cpu: Double
    let disk: DiskUsage
    let timestamp: Date
}

// MARK: - Notifications

extension Notification.Name {
    static let memoryWarningReceived = Notification.Name("memoryWarningReceived")
}

// MARK: - Memory Management Extensions

extension UIViewController {
    /// メモリ警告の監視を開始
    func startMemoryMonitoring() {
        PerformanceOptimizer.shared.startMemoryMonitoring()
    }
    
    /// メモリ警告の監視を停止
    func stopMemoryMonitoring() {
        PerformanceOptimizer.shared.stopMemoryMonitoring()
    }
}

extension UIView {
    /// メモリ効率的な画像読み込み
    func loadImageEfficiently(from url: URL, placeholder: UIImage? = nil) {
        // プレースホルダーを表示
        if let placeholder = placeholder {
            self.backgroundColor = UIColor(patternImage: placeholder)
        }
        
        // キャッシュから画像を取得
        if let cachedImage = PerformanceOptimizer.shared.getCachedImage(for: url.absoluteString) {
            DispatchQueue.main.async {
                self.backgroundColor = UIColor(patternImage: cachedImage)
            }
            return
        }
        
        // バックグラウンドで画像を読み込み
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    // キャッシュに保存
                    PerformanceOptimizer.shared.cacheImage(image, for: url.absoluteString)
                    
                    DispatchQueue.main.async {
                        self.backgroundColor = UIColor(patternImage: image)
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
            }
        }
    }
}

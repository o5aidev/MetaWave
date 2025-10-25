import SwiftUI
import CoreData

// MARK: - 同期状態ビュー
struct SyncStatusView: View {
    @ObservedObject var cloudSyncService: CloudSyncService
    @State private var syncStatus: SyncStatus = .idle
    @State private var lastSyncDate: Date?
    @State private var syncStatistics: SyncStatistics?
    @State private var showSyncDetails = false
    @State private var isManualSync = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 同期状態ヘッダー
            HStack {
                Image(systemName: syncStatusIcon)
                    .foregroundColor(syncStatusColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("同期状態")
                        .font(.headline)
                    
                    Text(syncStatusText)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if case .syncing = syncStatus {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // 同期統計
            if let statistics = syncStatistics {
                SyncStatisticsView(statistics: statistics)
            }
            
            // 最後の同期時刻
            if let lastSync = lastSyncDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    
                    Text("最後の同期: \(lastSync, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            // アクションボタン
            HStack(spacing: 12) {
                Button("手動同期") {
                    Task {
                        await performManualSync()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isManualSync || case .syncing = syncStatus)
                
                Button("詳細") {
                    showSyncDetails = true
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            setupSyncStatusObserver()
        }
        .sheet(isPresented: $showSyncDetails) {
            SyncDetailsSheet(cloudSyncService: cloudSyncService)
        }
    }
    
    // MARK: - 同期状態アイコン
    private var syncStatusIcon: String {
        switch syncStatus {
        case .idle:
            return "icloud"
        case .syncing:
            return "icloud.and.arrow.up"
        case .completed:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        case .conflict:
            return "exclamationmark.triangle"
        }
    }
    
    // MARK: - 同期状態色
    private var syncStatusColor: Color {
        switch syncStatus {
        case .idle:
            return .blue
        case .syncing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        case .conflict:
            return .yellow
        }
    }
    
    // MARK: - 同期状態テキスト
    private var syncStatusText: String {
        switch syncStatus {
        case .idle:
            return "同期待機中"
        case .syncing:
            return "同期中..."
        case .completed:
            return "同期完了"
        case .error(let error):
            return "同期エラー: \(error.localizedDescription)"
        case .conflict(let conflict):
            return "競合が発生しました: \(conflict.entityName)"
        }
    }
    
    // MARK: - 同期状態オブザーバーの設定
    private func setupSyncStatusObserver() {
        cloudSyncService.addSyncStatusObserver { status in
            DispatchQueue.main.async {
                self.syncStatus = status
                
                if case .completed = status {
                    self.lastSyncDate = Date()
                }
            }
        }
        
        // 初期状態の取得
        syncStatus = cloudSyncService.getSyncStatus()
        syncStatistics = cloudSyncService.getSyncStatistics()
    }
    
    // MARK: - 手動同期の実行
    private func performManualSync() async {
        isManualSync = true
        
        do {
            try await cloudSyncService.forceSync()
        } catch {
            // エラーは同期状態オブザーバーで処理される
        }
        
        isManualSync = false
    }
}

// MARK: - 同期統計ビュー
struct SyncStatisticsView: View {
    let statistics: SyncStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("同期統計")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatisticItem(
                    title: "同期済み",
                    value: "\(statistics.totalSyncedItems)",
                    color: .green
                )
                
                StatisticItem(
                    title: "保留中",
                    value: "\(statistics.pendingSyncItems)",
                    color: .orange
                )
                
                StatisticItem(
                    title: "エラー",
                    value: "\(statistics.syncErrors)",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - 統計アイテム
struct StatisticItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 同期詳細シート
struct SyncDetailsSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var cloudSyncService: CloudSyncService
    
    @State private var syncLog: [SyncLogEntry] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(syncLog, id: \.id) { entry in
                            SyncLogRowView(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("同期詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSyncLog()
            }
        }
    }
    
    // MARK: - 同期ログの読み込み
    private func loadSyncLog() {
        // 実際の実装では、同期ログをデータベースから取得
        // ここではダミーデータを生成
        syncLog = generateDummySyncLog()
        isLoading = false
    }
    
    // MARK: - ダミー同期ログの生成
    private func generateDummySyncLog() -> [SyncLogEntry] {
        return [
            SyncLogEntry(
                id: UUID(),
                timestamp: Date().addingTimeInterval(-300),
                type: .sync,
                message: "ノート 5件を同期しました",
                status: .success
            ),
            SyncLogEntry(
                id: UUID(),
                timestamp: Date().addingTimeInterval(-600),
                type: .conflict,
                message: "ノート 'メモ' で競合が発生しました",
                status: .warning
            ),
            SyncLogEntry(
                id: UUID(),
                timestamp: Date().addingTimeInterval(-900),
                type: .error,
                message: "ネットワークエラーが発生しました",
                status: .error
            )
        ]
    }
}

// MARK: - 同期ログエントリ
struct SyncLogEntry {
    let id: UUID
    let timestamp: Date
    let type: SyncLogType
    let message: String
    let status: SyncLogStatus
}

// MARK: - 同期ログタイプ
enum SyncLogType {
    case sync
    case conflict
    case error
    case info
}

// MARK: - 同期ログステータス
enum SyncLogStatus {
    case success
    case warning
    case error
    case info
}

// MARK: - 同期ログ行ビュー
struct SyncLogRowView: View {
    let entry: SyncLogEntry
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.message)
                    .font(.body)
                
                Text(entry.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - ステータスアイコン
    private var statusIcon: String {
        switch entry.status {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    // MARK: - ステータス色
    private var statusColor: Color {
        switch entry.status {
        case .success:
            return .green
        case .warning:
            return .yellow
        case .error:
            return .red
        case .info:
            return .blue
        }
    }
}

// MARK: - プレビュー
#Preview {
    SyncStatusView(cloudSyncService: CloudSyncService(persistentContainer: PersistenceController.preview.container, vault: Vault.shared))
}

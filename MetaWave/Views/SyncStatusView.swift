import SwiftUI
import CloudKit

// MARK: - 同期ステータスビュー
struct SyncStatusView: View {
    @StateObject private var cloudSyncService = CloudSyncService.shared
    @StateObject private var sharingService = SharingService.shared
    @State private var showingShareSheet = false
    @State private var selectedItem: Item?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // ヘッダー
                headerView
                
                // 同期ステータス
                syncStatusView
                
                // 共有管理
                sharingManagementView
                
                // アクション
                actionButtonsView
                
                Spacer()
            }
            .padding()
            .navigationTitle("同期・共有")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    try? await sharingService.loadActiveShares()
                }
            }
        }
    }
    
    // MARK: - ヘッダービュー
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("クラウド同期・共有")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("データを安全に同期・共有できます")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 同期ステータスビュー
    private var syncStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("同期ステータス")
                    .font(.headline)
                
                Spacer()
                
                if cloudSyncService.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            if let lastSync = cloudSyncService.lastSyncDate {
                Text("最終同期: \(lastSync, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let error = cloudSyncService.syncError {
                Text("エラー: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 共有管理ビュー
    private var sharingManagementView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("共有管理")
                .font(.headline)
            
            if sharingService.activeShares.isEmpty {
                Text("アクティブな共有はありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(sharingService.activeShares, id: \.id) { share in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("共有ID: \(share.id.prefix(8))...")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            if let expiresAt = share.expiresAt {
                                Text("有効期限: \(expiresAt, formatter: dateFormatter)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("取り消し") {
                            Task {
                                try? await sharingService.revokeShare(share)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - アクションボタンビュー
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            // 同期ボタン
            Button(action: {
                Task {
                    try? await cloudSyncService.startSync()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("今すぐ同期")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(cloudSyncService.isSyncing)
            
            // 共有ボタン
            Button(action: {
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("ノートを共有")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - 日付フォーマッター
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - プレビュー
#Preview {
    SyncStatusView()
}
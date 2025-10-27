import SwiftUI
import CloudKit

// MARK: - 共有ビュー
struct SharingView: View {
    @StateObject private var sharingService = SharingService.shared
    @State private var shareLink: ShareLink?
    @State private var isCreatingShare = false
    @State private var shareError: String?
    @State private var showingShareSheet = false
    
    let item: Item
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // ヘッダー
                headerView
                
                // ノート情報
                noteInfoView
                
                // 共有リンク
                if let shareLink = shareLink {
                    shareLinkView(shareLink)
                }
                
                // アクション
                actionButtonsView
                
                Spacer()
            }
            .padding()
            .navigationTitle("ノート共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        // ビューを閉じる
                    }
                }
            }
        }
    }
    
    // MARK: - ヘッダービュー
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("ノートを共有")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("暗号化された安全な共有リンクを作成します")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - ノート情報ビュー
    private var noteInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("共有するノート")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title ?? "Untitled")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                if let timestamp = item.timestamp {
                    Text("作成日: \(timestamp, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 共有リンクビュー
    private func shareLinkView(_ shareLink: ShareLink) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("共有リンク")
                        .font(.headline)
                    
            VStack(alignment: .leading, spacing: 8) {
                Text(shareLink.url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.blue)
                        .padding()
                    .background(Color(.systemGray6))
                        .cornerRadius(8)
                
                HStack {
                    Text("有効期限: 30日間")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("コピー") {
                        UIPasteboard.general.string = shareLink.url.absoluteString
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - アクションボタンビュー
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if shareLink == nil {
                // 共有作成ボタン
                Button(action: {
                    Task {
                        await createShare()
                    }
                }) {
                    HStack {
                        if isCreatingShare {
                            ProgressView()
                                .scaleEffect(0.8)
                } else {
                            Image(systemName: "link")
                        }
                        Text(isCreatingShare ? "作成中..." : "共有リンクを作成")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isCreatingShare)
            } else {
                // 共有ボタン
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("共有する")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // 取り消しボタン
                Button(action: {
                    Task {
                        if let shareLink = shareLink {
                            try? await sharingService.revokeShare(shareLink)
                            self.shareLink = nil
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("共有を取り消し")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            if let error = shareError {
                Text("エラー: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 共有作成
    private func createShare() async {
        isCreatingShare = true
        shareError = nil
        
        do {
            let link = try await sharingService.shareNote(item)
            shareLink = link
        } catch {
            shareError = error.localizedDescription
        }
        
        isCreatingShare = false
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
    SharingView(item: Item())
}
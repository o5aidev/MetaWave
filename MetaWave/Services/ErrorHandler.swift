import Foundation
import SwiftUI
import Combine

/// エラーハンドリング管理サービス
final class ErrorHandler: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ErrorHandler()
    
    // MARK: - Published Properties
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    @Published var errorHistory: [ErrorLog] = []
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupErrorLogging()
    }
    
    // MARK: - Public Methods
    
    /// エラーを処理して表示
    func handleError(_ error: Error, context: ErrorContext? = nil) {
        let appError = AppError.from(error, context: context)
        
        DispatchQueue.main.async {
            self.currentError = appError
            self.isShowingError = true
            self.logError(appError)
        }
    }
    
    /// エラーをログに記録
    func logError(_ error: AppError) {
        let errorLog = ErrorLog(
            error: error,
            timestamp: Date(),
            context: error.context
        )
        
        errorHistory.append(errorLog)
        
        // ログの最大数を制限（メモリ管理）
        if errorHistory.count > 100 {
            errorHistory.removeFirst(50)
        }
        
        // デバッグ用のコンソール出力
        print("🚨 Error: \(error.title) - \(error.description)")
        if let context = error.context {
            print("📍 Context: \(context)")
        }
    }
    
    /// エラーをクリア
    func clearError() {
        currentError = nil
        isShowingError = false
    }
    
    /// エラーヒストリーをクリア
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    /// 特定のエラータイプの発生回数を取得
    func getErrorCount(for type: AppErrorType) -> Int {
        return errorHistory.filter { $0.error.type == type }.count
    }
    
    /// 最近のエラーを取得
    func getRecentErrors(limit: Int = 10) -> [ErrorLog] {
        return Array(errorHistory.suffix(limit))
    }
    
    // MARK: - Private Methods
    
    private func setupErrorLogging() {
        // エラーログの永続化（UserDefaults）
        loadErrorHistory()
        
        // アプリ終了時のログ保存
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.saveErrorHistory()
        }
    }
    
    private func loadErrorHistory() {
        if let data = UserDefaults.standard.data(forKey: "errorHistory"),
           let history = try? JSONDecoder().decode([ErrorLog].self, from: data) {
            errorHistory = history
        }
    }
    
    private func saveErrorHistory() {
        if let data = try? JSONEncoder().encode(errorHistory) {
            UserDefaults.standard.set(data, forKey: "errorHistory")
        }
    }
}

// MARK: - Error Types

enum AppErrorType: String, CaseIterable, Codable {
    case network = "network"
    case database = "database"
    case audio = "audio"
    case analysis = "analysis"
    case backup = "backup"
    case permission = "permission"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .network: return "ネットワーク"
        case .database: return "データベース"
        case .audio: return "音声"
        case .analysis: return "分析"
        case .backup: return "バックアップ"
        case .permission: return "権限"
        case .unknown: return "不明"
        }
    }
    
    var icon: String {
        switch self {
        case .network: return "wifi.slash"
        case .database: return "externaldrive.badge.exclamationmark"
        case .audio: return "mic.slash"
        case .analysis: return "chart.bar.xaxis"
        case .backup: return "icloud.slash"
        case .permission: return "lock.slash"
        case .unknown: return "exclamationmark.triangle"
        }
    }
}

struct AppError: Identifiable, Codable {
    let id: UUID
    let type: AppErrorType
    let title: String
    let description: String
    let context: ErrorContext?
    let timestamp: Date
    let isRecoverable: Bool
    let recoveryAction: String?
    
    init(type: AppErrorType, title: String, description: String, context: ErrorContext? = nil, isRecoverable: Bool = true, recoveryAction: String? = nil) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.context = context
        self.timestamp = Date()
        self.isRecoverable = isRecoverable
        self.recoveryAction = recoveryAction
    }
    
    static func from(_ error: Error, context: ErrorContext? = nil) -> AppError {
        // AppErrorの場合はそのまま返す（実際には型チェックは不要）
        
        // システムエラーからAppErrorに変換
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                return AppError(
                    type: .network,
                    title: "ネットワークエラー",
                    description: "インターネット接続を確認してください。",
                    context: context,
                    recoveryAction: "接続を確認"
                )
            case NSCocoaErrorDomain:
                return AppError(
                    type: .database,
                    title: "データエラー",
                    description: "データの保存に失敗しました。",
                    context: context,
                    recoveryAction: "再試行"
                )
            default:
                return AppError(
                    type: .unknown,
                    title: "エラーが発生しました",
                    description: error.localizedDescription,
                    context: context
                )
            }
        }
        
        return AppError(
            type: .unknown,
            title: "エラーが発生しました",
            description: error.localizedDescription,
            context: context
        )
    }
}

struct ErrorContext: Codable {
    let screen: String
    let action: String
    let additionalInfo: String?
    
    init(screen: String, action: String, additionalInfo: String? = nil) {
        self.screen = screen
        self.action = action
        self.additionalInfo = additionalInfo
    }
}

struct ErrorLog: Identifiable, Codable {
    let id: UUID
    let error: AppError
    let timestamp: Date
    let context: ErrorContext?
    
    init(error: AppError, timestamp: Date, context: ErrorContext?) {
        self.id = UUID()
        self.error = error
        self.timestamp = timestamp
        self.context = context
    }
}

// MARK: - Error Alert View

struct ErrorAlertView: View {
    @ObservedObject var errorHandler: ErrorHandler
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    init(errorHandler: ErrorHandler = ErrorHandler.shared, onRetry: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.errorHandler = errorHandler
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        if let error = errorHandler.currentError {
            VStack(spacing: 20) {
                // エラーアイコン
                Image(systemName: error.type.icon)
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                // エラー情報
                VStack(spacing: 12) {
                    Text(error.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(error.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if let context = error.context {
                        Text("場所: \(context.screen)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // アクションボタン
                HStack(spacing: 12) {
                    if error.isRecoverable, let onRetry = onRetry {
                        Button(error.recoveryAction ?? "再試行") {
                            onRetry()
                            errorHandler.clearError()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    
                    Button("閉じる") {
                        onDismiss?()
                        errorHandler.clearError()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Error Handling Modifier

struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorHandler = ErrorHandler.shared
    let onRetry: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if errorHandler.isShowingError {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        errorHandler.clearError()
                    }
                
                ErrorAlertView(
                    errorHandler: errorHandler,
                    onRetry: onRetry
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: errorHandler.isShowingError)
    }
}

extension View {
    /// エラーハンドリングを適用
    func errorHandling(onRetry: (() -> Void)? = nil) -> some View {
        self.modifier(ErrorHandlingModifier(onRetry: onRetry))
    }
}

// MARK: - Error Recovery Actions

extension ErrorHandler {
    /// ネットワークエラーの回復処理
    func retryNetworkOperation() {
        // ネットワーク接続を確認
        // 必要に応じて再試行
        clearError()
    }
    
    /// データベースエラーの回復処理
    func retryDatabaseOperation() {
        // データベース接続を再確立
        // 必要に応じてデータを復元
        clearError()
    }
    
    /// 音声エラーの回復処理
    func retryAudioOperation() {
        // 音声セッションを再初期化
        // マイクの許可を確認
        clearError()
    }
}

// MARK: - Preview

struct ErrorHandler_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Button("エラーを発生させる") {
                ErrorHandler.shared.handleError(
                    NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "テストエラーです"]),
                    context: ErrorContext(screen: "テスト画面", action: "テストアクション")
                )
            }
        }
        .errorHandling {
            print("再試行が実行されました")
        }
    }
}

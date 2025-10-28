import SwiftUI
import Speech
import AVFoundation

// MARK: - 音声入力ビュー v2.1
struct VoiceInputView_v2_1: View {
    
    // MARK: - プロパティ
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechService: SpeechRecognitionService
    @State private var isRecording = false
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var showTimeLimitAlert = false
    
    // 録音時間制限
    private let maxRecordingDuration: TimeInterval = 60.0
    private let warningDuration: TimeInterval = 50.0
    
    // コールバック
    let onSave: (String) -> Void
    
    // MARK: - 初期化
    init(vault: Vaulting, onSave: @escaping (String) -> Void) {
        self._speechService = StateObject(wrappedValue: SpeechRecognitionService(vault: vault))
        self.onSave = onSave
    }
    
    // MARK: - 部分結果の監視
    private func setupPartialResultObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpeechRecognitionPartialResult"),
            object: nil,
            queue: .main
        ) { notification in
            if let text = notification.userInfo?["text"] as? String {
                recognizedText = text
            }
        }
    }
    
    // MARK: - ビュー
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                
                // ヘッダー
                headerView
                
                // 音声認識結果表示
                recognitionResultView
                
                // 録音ボタン
                recordingButtonView
                
                // 録音時間表示
                recordingDurationView
                
                // 操作ボタン
                actionButtonsView
                
                Spacer()
            }
            .padding()
            .navigationTitle("音声入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupPartialResultObserver()
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "不明なエラーが発生しました")
            }
            .alert("録音時間制限", isPresented: $showTimeLimitAlert) {
                Button("OK") { }
            } message: {
                Text("最大録音時間（60秒）に達しました。録音を停止しました。")
            }
        }
    }
    
    // MARK: - ヘッダービュー
    private var headerView: some View {
        VStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.system(size: 50))
                .foregroundColor(isRecording ? .red : .blue)
                .scaleEffect(isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)
            
            Text(isRecording ? "録音中..." : "音声を録音してください")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 音声認識結果ビュー
    private var recognitionResultView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("認識結果")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView {
                Text(recognizedText.isEmpty ? "音声認識結果がここに表示されます..." : recognizedText)
                    .font(.body)
                    .foregroundColor(recognizedText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            .frame(height: 150)
        }
    }
    
    // MARK: - 録音ボタンビュー（最適化版）
    private var recordingButtonView: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 100, height: 100)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1.0)
        .accessibilityLabel(isRecording ? "録音停止" : "録音開始")
        .accessibilityHint(isRecording ? "録音を停止します" : "音声録音を開始します")
    }
    
    // MARK: - 録音時間ビュー（最適化版）
    private var recordingDurationView: some View {
        VStack(spacing: 4) {
            Text(formatDuration(recordingDuration))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(isRecording ? (recordingDuration >= warningDuration ? .orange : .red) : .secondary)
                .opacity(isRecording ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: isRecording)
                .accessibilityLabel("録音時間: \(formatDuration(recordingDuration))")
                .accessibilityHint(isRecording ? "録音中です" : "録音停止中です")
            
            if isRecording && recordingDuration >= warningDuration {
                Text("もうすぐ制限時間です")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .opacity(isRecording ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: isRecording)
            }
        }
    }
    
    // MARK: - 操作ボタンビュー
    private var actionButtonsView: some View {
        HStack(spacing: 20) {
            // クリアボタン
            Button("クリア") {
                clearText()
            }
            .disabled(isRecording) // 録音中のみ無効化
            .foregroundColor(recognizedText.isEmpty ? .gray : .secondary)
            .opacity(recognizedText.isEmpty ? 0.5 : 1.0)
            
            // 保存ボタン
            Button("保存") {
                saveText()
            }
            .disabled(recognizedText.isEmpty || isRecording) // 空または録音中は無効化
            .foregroundColor(recognizedText.isEmpty ? .gray : .blue)
            .fontWeight(.semibold)
            .opacity(recognizedText.isEmpty ? 0.5 : 1.0)
        }
        .font(.headline)
    }
    
    // MARK: - 録音の開始/停止
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // MARK: - 録音の開始
    private func startRecording() {
        isRecording = true
        isProcessing = false  // 録音中は処理中ではない
        recordingDuration = 0
        recognizedText = ""
        errorMessage = nil
        
        // 録音時間のタイマー開始
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
            
            // 制限時間チェック
            if recordingDuration >= maxRecordingDuration {
                stopRecording()
                showTimeLimitAlert = true
            }
        }
        
        Task {
            do {
                let result = try await speechService.startRecognition()
                
                await MainActor.run {
                    recognizedText = result.text
                    isRecording = false
                    isProcessing = false
                    recordingTimer?.invalidate()
                    recordingTimer = nil
                    print("✅ 音声認識完了、UI更新: \(result.text)")
                }
            } catch {
                await MainActor.run {
                    isRecording = false
                    isProcessing = false
                    recordingTimer?.invalidate()
                    recordingTimer = nil
                    errorMessage = error.localizedDescription
                    showError = true
                    print("❌ 音声認識エラー: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 録音の停止
    private func stopRecording() {
        speechService.stopRecognition()
        isRecording = false
        isProcessing = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - テキストのクリア
    private func clearText() {
        recognizedText = ""
        recordingDuration = 0
    }
    
    // MARK: - テキストの保存
    private func saveText() {
        guard !recognizedText.isEmpty else { return }
        
        onSave(recognizedText)
        dismiss()
    }
    
    // MARK: - 時間のフォーマット
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
}

// MARK: - プレビュー
#Preview {
    VoiceInputView_v2_1(vault: Vault()) { text in
        print("保存されたテキスト: \(text)")
    }
}

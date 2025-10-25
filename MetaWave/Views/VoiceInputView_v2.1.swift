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
    
    // コールバック
    let onSave: (String) -> Void
    
    // MARK: - 初期化
    init(vault: Vaulting, onSave: @escaping (String) -> Void) {
        self._speechService = StateObject(wrappedValue: SpeechRecognitionService(vault: vault))
        self.onSave = onSave
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
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "不明なエラーが発生しました")
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
    
    // MARK: - 録音ボタンビュー
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
    }
    
    // MARK: - 録音時間ビュー
    private var recordingDurationView: some View {
        Text(formatDuration(recordingDuration))
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(isRecording ? .red : .secondary)
            .opacity(isRecording ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.3), value: isRecording)
    }
    
    // MARK: - 操作ボタンビュー
    private var actionButtonsView: some View {
        HStack(spacing: 20) {
            // クリアボタン
            Button("クリア") {
                clearText()
            }
            .disabled(recognizedText.isEmpty || isRecording)
            .foregroundColor(.secondary)
            
            // 保存ボタン
            Button("保存") {
                saveText()
            }
            .disabled(recognizedText.isEmpty || isRecording)
            .foregroundColor(.blue)
            .fontWeight(.semibold)
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
        isProcessing = true
        recordingDuration = 0
        recognizedText = ""
        errorMessage = nil
        
        // 録音時間のタイマー開始
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
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
                }
            } catch {
                await MainActor.run {
                    isRecording = false
                    isProcessing = false
                    recordingTimer?.invalidate()
                    recordingTimer = nil
                    errorMessage = error.localizedDescription
                    showError = true
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

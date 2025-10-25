//
//  VoiceInputView.swift
//  MetaWave
//
//  Created by Miyabi Workflow on 2025-10-25.
//

import SwiftUI
import AVFoundation
import Speech

struct VoiceInputView: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var audioRecorder: AVAudioRecorder?
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 60))
                        .foregroundColor(isRecording ? .red : .blue)
                        .scaleEffect(isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)
                    
                    Text(isRecording ? "録音中..." : "音声入力")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(isRecording ? "話してください" : "マイクボタンをタップして録音開始")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 録音ボタン
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.blue)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!isRecording && transcribedText.isEmpty)
                
                // 文字起こし結果
                if !transcribedText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("文字起こし結果")
                            .font(.headline)
                        
                        ScrollView {
                            Text(transcribedText)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                Spacer()
                
                // アクションボタン
                HStack(spacing: 16) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button("保存") {
                        onComplete(transcribedText)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(transcribedText.isEmpty)
                }
                .padding(.bottom, 20)
            }
            .padding()
            .navigationTitle("音声入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            requestPermissions()
        }
        .alert("権限が必要です", isPresented: $showingPermissionAlert) {
            Button("設定") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text(permissionMessage)
        }
    }
    
    // MARK: - Actions
    
    private func requestPermissions() {
        // マイク権限
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    permissionMessage = "マイクへのアクセス権限が必要です。設定から権限を有効にしてください。"
                    showingPermissionAlert = true
                }
            }
        }
        
        // 音声認識権限
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    break
                case .denied, .restricted, .notDetermined:
                    permissionMessage = "音声認識へのアクセス権限が必要です。設定から権限を有効にしてください。"
                    showingPermissionAlert = true
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // 音声認識を開始
        startSpeechRecognition()
        isRecording = true
    }
    
    private func stopRecording() {
        // 音声認識を停止
        stopSpeechRecognition()
        isRecording = false
    }
    
    private func startSpeechRecognition() {
        // 既存のタスクをキャンセル
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // オーディオセッションを設定
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }
        
        // 認識リクエストを作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 音声認識を開始
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                
                if error != nil {
                    self.stopSpeechRecognition()
                }
            }
        }
        
        // オーディオエンジンを設定
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine start failed: \(error)")
        }
    }
    
    private func stopSpeechRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

#Preview {
    VoiceInputView { text in
        print("Transcribed: \(text)")
    }
}

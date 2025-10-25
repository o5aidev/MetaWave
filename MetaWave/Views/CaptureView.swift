//
//  CaptureView.swift
//  MetaWave
//
//  Miyabi仕様: ハイブリッド入力画面
//

import SwiftUI
import CoreData
import AVFoundation

struct CaptureView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var audioRecorder = AudioRecorderService()
    @State private var asrService = AppleASRService()
    
    @State private var inputText = ""
    @State private var selectedModality: Note.Modality = .text
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var isTranscribing = false
    @State private var transcriptionResult = ""
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // モダリティ選択
                modalitySelector
                
                // 入力エリア
                inputArea
                
                // タグ入力
                tagInput
                
                // アクションボタン
                actionButtons
                
                Spacer()
            }
            .padding()
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(permissionMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var modalitySelector: some View {
        Picker("Input Type", selection: $selectedModality) {
            ForEach(Note.Modality.allCases, id: \.self) { modality in
                Text(modality.rawValue.capitalized).tag(modality)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    private var inputArea: some View {
        Group {
            switch selectedModality {
            case .text:
                textInputArea
            case .audio:
                audioInputArea
            case .image:
                imageInputArea
            }
        }
        .frame(minHeight: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Input")
                .font(.headline)
                .foregroundColor(.secondary)
            
            TextEditor(text: $inputText)
                .frame(minHeight: 150)
                .background(Color.clear)
        }
        .padding()
    }
    
    private var audioInputArea: some View {
        VStack(spacing: 16) {
            if audioRecorder.isRecording {
                recordingView
            } else if isTranscribing {
                transcribingView
            } else if !transcriptionResult.isEmpty {
                transcriptionResultView
            } else {
                recordingPromptView
            }
        }
        .padding()
    }
    
    private var recordingView: some View {
        VStack(spacing: 16) {
            // 録音中のアニメーション
            Circle()
                .fill(Color.red)
                .frame(width: 80, height: 80)
                .scaleEffect(audioRecorder.isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: audioRecorder.isRecording)
            
            Text("Recording...")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(formatTime(audioRecorder.recordingTime))
                .font(.title2)
                .monospacedDigit()
            
            Button("Stop Recording") {
                stopRecording()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var transcribingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Transcribing...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private var transcriptionResultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription Result")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(transcriptionResult)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
            
            Button("Re-record") {
                transcriptionResult = ""
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var recordingPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Tap to Start Recording")
                .font(.headline)
            
            Button("Start Recording") {
                startRecording()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var imageInputArea: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Image Input")
                .font(.headline)
            
            Text("Coming in v2.1")
                .foregroundColor(.secondary)
        }
    }
    
    private var tagInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
            
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addTag()
                    }
                
                Button("Add") {
                    addTag()
                }
                .disabled(newTag.isEmpty)
            }
            
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            TagView(tag: tag) {
                                removeTag(tag)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Clear All") {
                clearAll()
            }
            .buttonStyle(.bordered)
            .disabled(!hasContent)
            
            Spacer()
            
            Button("Save Note") {
                saveNote()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasContent: Bool {
        !inputText.isEmpty || !transcriptionResult.isEmpty || !tags.isEmpty
    }
    
    private var canSave: Bool {
        switch selectedModality {
        case .text:
            return !inputText.isEmpty
        case .audio:
            return !transcriptionResult.isEmpty
        case .image:
            return false // 未実装
        }
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        Task {
            do {
                _ = try await audioRecorder.startRecording()
            } catch {
                await MainActor.run {
                    permissionMessage = "Microphone access is required for recording."
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func stopRecording() {
        guard let audioURL = audioRecorder.stopRecording() else { return }
        
        isTranscribing = true
        
        Task {
            do {
                let result = try await asrService.transcribe(url: audioURL)
                await MainActor.run {
                    transcriptionResult = result
                    isTranscribing = false
                }
            } catch {
                await MainActor.run {
                    transcriptionResult = "Transcription failed: \(error.localizedDescription)"
                    isTranscribing = false
                }
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    private func clearAll() {
        inputText = ""
        transcriptionResult = ""
        tags = []
        newTag = ""
    }
    
    private func saveNote() {
        let content: String
        switch selectedModality {
        case .text:
            content = inputText
        case .audio:
            content = transcriptionResult
        case .image:
            return // 未実装
        }
        
        let note = Note.create(
            modality: selectedModality,
            contentText: content,
            tags: tags,
            in: viewContext
        )
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save error: \(error.localizedDescription)")
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Tag View

struct TagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

// MARK: - Preview

struct CaptureView_Previews: PreviewProvider {
    static var previews: some View {
        CaptureView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

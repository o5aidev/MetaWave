//
//  ContentView.swift
//  MetaWave
//
//  Created by 渡部一生 on 2025/10/21.
//

import SwiftUI
import CoreData
import Speech
import AVFoundation
import Foundation

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var selectedTab = 1
    @State private var analysisSelection: AnalysisSection = .overview
    
    init() {
        // フェッチバッチサイズは別途設定
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Notes Tab
            NotesView(onVoiceNoteAdd: addVoiceNote)
            .tabItem {
                Image(systemName: "note.text")
                Text("Notes")
            }
            .tag(0)
            
            // Analysis Tab
            NavigationView {
                VStack(spacing: 16) {
                    Picker("分析ビュー", selection: $analysisSelection) {
                        Text("概要").tag(AnalysisSection.overview)
                        Text("パターン").tag(AnalysisSection.patterns)
                        Text("予測").tag(AnalysisSection.predictions)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    Group {
                        switch analysisSelection {
                        case .overview:
                            InsightCardsView()
                        case .patterns:
                            PatternAnalysisView(context: viewContext)
                        case .predictions:
                            PredictionView(context: viewContext)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, 16)
                .navigationTitle("分析")
            }
            .tabItem {
                Image(systemName: "brain.head.profile")
                Text("分析")
            }
            .tag(1)
            
            // Settings Tab
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(2)
        }
        .fullScreenCover(isPresented: $onboardingManager.shouldShowOnboarding) {
            OnboardingView()
        }
        .errorHandling {
            // エラー時の再試行処理
            print("エラーが発生しました。再試行します。")
        }
    }

    // MARK: - Actions
    
    /// 音声入力でノートを追加
    private func addVoiceNote(text: String) {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            newItem.title = "音声ノート"
            newItem.note = text
            
            do {
                try viewContext.save()
                
                // 音声感情分析の実行（非同期）
                Task {
                    await analyzeVoiceEmotion(for: newItem)
                }
            } catch {
                print("[CoreData] Voice note save error:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - 音声感情分析
    private func analyzeVoiceEmotion(for item: Item) async {
        // テキスト内容を取得
        guard let note = item.note, !note.isEmpty else {
            print("⚠️ ノートが空です")
            return
        }
        
        print("音声感情分析を実行: \(note)")
        
        // 簡易的な感情分析を実行
        let valence = calculateSimpleValence(text: note)
        let arousal = calculateSimpleArousal(text: note)
        
        print("✅ 感情分析完了: valence=\(valence), arousal=\(arousal)")
        
        // 感情の解釈
        let emotionLabel = interpretEmotion(valence: valence, arousal: arousal)
        print("📊 感情状態: \(emotionLabel)")
    }
    
    // MARK: - 簡易感情分析
    private func calculateSimpleValence(text: String) -> Float {
        let positiveWords = ["楽しい", "嬉しい", "幸せ", "良い", "好き", "最高", "素晴らしい", "良い", "great", "good", "happy", "love"]
        let negativeWords = ["悲しい", "辛い", "苦しい", "嫌い", "悪い", "最悪", "ダメ", "bad", "sad", "hate", "angry"]
        
        let lowerText = text.lowercased()
        var positiveCount = 0
        var negativeCount = 0
        
        for word in positiveWords {
            if lowerText.contains(word) {
                positiveCount += 1
            }
        }
        
        for word in negativeWords {
            if lowerText.contains(word) {
                negativeCount += 1
            }
        }
        
        let total = positiveCount + negativeCount
        if total == 0 {
            return 0.0
        }
        
        return Float(positiveCount - negativeCount) / Float(total)
    }
    
    private func calculateSimpleArousal(text: String) -> Float {
        let highArousalWords = ["興奮", "ワクワク", "ドキドキ", "驚いた", "驚き", "excited", "thrilled", "wow", "amazing"]
        let lowArousalWords = ["疲れた", "眠い", "穏やか", "静か", "tired", "sleepy", "calm"]
        
        let lowerText = text.lowercased()
        var highCount = 0
        var lowCount = 0
        
        for word in highArousalWords {
            if lowerText.contains(word) {
                highCount += 1
            }
        }
        
        for word in lowArousalWords {
            if lowerText.contains(word) {
                lowCount += 1
            }
        }
        
        let total = highCount + lowCount
        if total == 0 {
            return 0.5 // デフォルトは中間
        }
        
        return Float(highCount) / Float(total)
    }
    
    private func interpretEmotion(valence: Float, arousal: Float) -> String {
        if valence > 0.3 && arousal > 0.6 {
            return "興奮（高ポジティブ）"
        } else if valence > 0.3 && arousal < 0.4 {
            return "穏やか（ポジティブ）"
        } else if valence < -0.3 && arousal > 0.6 {
            return "イライラ（高ネガティブ）"
        } else if valence < -0.3 && arousal < 0.4 {
            return "落ち込み（ネガティブ）"
        } else if arousal > 0.6 {
            return "高覚醒（中性）"
        } else {
            return "安定（中性）"
        }
    }
}

private enum AnalysisSection: Hashable {
    case overview
    case patterns
    case predictions
}

// MARK: - Simple Voice Input View

struct SimpleVoiceInputView: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("音声入力")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("テキストを入力してください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // テキスト入力
                VStack(alignment: .leading, spacing: 12) {
                    Text("ノート内容")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 200)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
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
                        onComplete(inputText)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(inputText.isEmpty)
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
    }
}

// MARK: - Insights View

struct InsightsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default
    )
    private var items: FetchedResults<Item>
    
    @State private var emotionAnalysis: [String: Double] = [:]
    @State private var loopDetection: [String] = []
    @State private var biasSignals: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("メタ認知分析")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("思考パターンの分析結果")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // 分析ボタン
                Button(action: performAnalysis) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "brain")
                        }
                        Text(isLoading ? "分析中..." : "分析を実行")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading || items.isEmpty)
                .padding(.horizontal)
                
                // 分析結果
                if !emotionAnalysis.isEmpty || !loopDetection.isEmpty || !biasSignals.isEmpty {
                    VStack(spacing: 16) {
                        // 感情分析結果
                        if !emotionAnalysis.isEmpty {
                            AnalysisCard(
                                title: "感情分析",
                                icon: "heart.fill",
                                color: .red
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(emotionAnalysis.keys.sorted()), id: \.self) { emotion in
                                        HStack {
                                            Text(emotion)
                                                .font(.subheadline)
                                            Spacer()
                                            Text(String(format: "%.1f%%", emotionAnalysis[emotion]! * 100))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        ProgressView(value: emotionAnalysis[emotion]!)
                                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                                    }
                                }
                            }
                        }
                        
                        // ループ検出結果
                        if !loopDetection.isEmpty {
                            AnalysisCard(
                                title: "思考ループ検出",
                                icon: "arrow.clockwise",
                                color: .orange
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(loopDetection, id: \.self) { loop in
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                            Text(loop)
                                                .font(.subheadline)
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                        
                        // バイアス検出結果
                        if !biasSignals.isEmpty {
                            AnalysisCard(
                                title: "認知バイアス検出",
                                icon: "eye.trianglebadge.exclamationmark",
                                color: .purple
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(biasSignals, id: \.self) { bias in
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.purple)
                                            Text(bias)
                                                .font(.subheadline)
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                } else if !isLoading && !items.isEmpty {
                    // 分析結果がない場合
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("分析結果がありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("「分析を実行」ボタンをタップして分析を開始してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else if items.isEmpty {
                    // ノートがない場合
                    VStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("ノートがありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Notesタブでノートを作成してから分析を実行してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Insights")
    }
    
    // MARK: - Actions
    
    private func performAnalysis() {
        isLoading = true
        
        // 非同期で分析を実行
        DispatchQueue.global(qos: .userInitiated).async {
            let analysis = analyzeNotes()
            
            DispatchQueue.main.async {
                self.emotionAnalysis = analysis.emotions
                self.loopDetection = analysis.loops
                self.biasSignals = analysis.biases
                self.isLoading = false
            }
        }
    }
    
    private func analyzeNotes() -> (emotions: [String: Double], loops: [String], biases: [String]) {
        var emotions: [String: Double] = [:]
        var loops: [String] = []
        var biases: [String] = []
        
        // 簡単な感情分析（サンプル）
        let allText = items.compactMap { $0.note }.joined(separator: " ")
        
        // 感情分析（キーワードベース）
        let positiveWords = ["楽しい", "嬉しい", "幸せ", "良い", "素晴らしい", "最高"]
        let negativeWords = ["悲しい", "辛い", "苦しい", "悪い", "最悪", "嫌い"]
        let neutralWords = ["普通", "まあまあ", "特に", "なんでもない"]
        
        let positiveCount = positiveWords.reduce(0) { count, word in
            count + allText.components(separatedBy: word).count - 1
        }
        let negativeCount = negativeWords.reduce(0) { count, word in
            count + allText.components(separatedBy: word).count - 1
        }
        let neutralCount = neutralWords.reduce(0) { count, word in
            count + allText.components(separatedBy: word).count - 1
        }
        
        let total = positiveCount + negativeCount + neutralCount
        if total > 0 {
            emotions["ポジティブ"] = Double(positiveCount) / Double(total)
            emotions["ネガティブ"] = Double(negativeCount) / Double(total)
            emotions["ニュートラル"] = Double(neutralCount) / Double(total)
        }
        
        // ループ検出（重複テキスト）
        let uniqueTexts = Set(items.compactMap { $0.note })
        if uniqueTexts.count < items.count {
            loops.append("同じ内容のノートが複数回記録されています")
        }
        
        // バイアス検出（サンプル）
        if allText.contains("絶対") || allText.contains("必ず") {
            biases.append("全か無か思考の兆候")
        }
        if allText.contains("みんな") || allText.contains("誰でも") {
            biases.append("一般化の過誤の兆候")
        }
        
        return (emotions: emotions, loops: loops, biases: biases)
    }
}

// MARK: - Analysis Card

struct AnalysisCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default
    )
    private var items: FetchedResults<Item>
    
    @State private var showingDeleteAlert = false
    @State private var showingExportAlert = false
    @State private var showingPruningView = false
    // @StateObject private var cloudSyncService = CloudSyncService(persistentContainer: PersistenceController.shared.container, vault: Vault.shared)
    
    var body: some View {
        List {
            // アプリ情報セクション
            Section {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .frame(width: 50, height: 50)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MetaWave v2.2")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("メタ認知パートナー")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("思考と行動を記録・分析")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // 同期セクション
            Section("同期") {
                // SyncStatusView(cloudSyncService: cloudSyncService)
                HStack {
                    Image(systemName: "icloud")
                        .foregroundColor(.blue)
                    Text("クラウド同期")
                    Spacer()
                    Text("準備中")
                        .foregroundColor(.secondary)
                }
            }
            
            // データ管理セクション
            Section("データ管理") {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text("ノート数")
                    Spacer()
                    Text("\(items.count)件")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.green)
                    Text("データをエクスポート")
                }
                .onTapGesture {
                    showingExportAlert = true
                }
                
                HStack {
                    Image(systemName: "scissors")
                        .foregroundColor(.orange)
                    Text("剪定アシスタント")
                }
                .onTapGesture {
                    showingPruningView = true
                }
                
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("すべてのデータを削除")
                }
                .onTapGesture {
                    showingDeleteAlert = true
                }
            }
            
            // セキュリティセクション
            Section("セキュリティ") {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("E2E暗号化")
                    Spacer()
                    Text("有効")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.blue)
                    Text("暗号化キー")
                    Spacer()
                    Text("デバイス内保存")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "icloud.slash")
                        .foregroundColor(.orange)
                    Text("クラウド同期")
                    Spacer()
                    Text("無効")
                        .foregroundColor(.secondary)
                }
            }
            
            // 分析設定セクション
            Section("分析設定") {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                    Text("感情分析")
                    Spacer()
                    Text("有効")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.orange)
                    Text("ループ検出")
                    Spacer()
                    Text("有効")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .foregroundColor(.red)
                    Text("バイアス検出")
                    Spacer()
                    Text("有効")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
            }
            
            // アプリ情報セクション
            Section("アプリ情報") {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("バージョン")
                    Spacer()
                    Text("2.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text("リリース日")
                    Spacer()
                    Text("2025-10-25")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.green)
                    Text("開発者")
                    Spacer()
                    Text("Miyabi Workflow")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("データを削除", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("すべてのノートとデータが削除されます。この操作は取り消せません。")
        }
        .alert("データをエクスポート", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: {
            Text("エクスポート機能は準備中です。")
        }
        .sheet(isPresented: $showingPruningView) {
            PruningView()
        }
    }
    
    // MARK: - Actions
    
    private func deleteAllData() {
        withAnimation {
            items.forEach { item in
                viewContext.delete(item)
            }
            
            do {
                try viewContext.save()
            } catch {
                print("[CoreData] Delete all error:", error.localizedDescription)
            }
        }
    }
}

// MARK: - Pruning View

struct PruningView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default
    )
    private var items: FetchedResults<Item>
    
    @State private var pruningCandidates: [PruningCandidate] = []
    @State private var isLoading = false
    @State private var showingDeleteAlert = false
    @State private var selectedCandidate: PruningCandidate?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "scissors")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("剪定アシスタント")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("不要なノートを整理しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 分析ボタン
                Button(action: analyzePruningCandidates) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(isLoading ? "分析中..." : "剪定候補を分析")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading || items.isEmpty)
                .padding(.horizontal)
                
                // 剪定候補リスト
                if !pruningCandidates.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(pruningCandidates, id: \.id) { candidate in
                                PruningCandidateCard(candidate: candidate) {
                                    selectedCandidate = candidate
                                    showingDeleteAlert = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else if !isLoading && !items.isEmpty {
                    // 剪定候補がない場合
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("剪定候補はありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("すべてのノートが有用です")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else if items.isEmpty {
                    // ノートがない場合
                    VStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("ノートがありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Notesタブでノートを作成してから剪定を実行してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                }
                
                Spacer()
            }
            .navigationTitle("剪定アシスタント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .alert("ノートを削除", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                if let candidate = selectedCandidate {
                    deletePruningCandidate(candidate)
                }
            }
        } message: {
            if let candidate = selectedCandidate {
                Text("「\(candidate.title)」を削除しますか？この操作は取り消せません。")
            }
        }
    }
    
    // MARK: - Actions
    
    private func analyzePruningCandidates() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let candidates = findPruningCandidates()
            
            DispatchQueue.main.async {
                self.pruningCandidates = candidates
                self.isLoading = false
            }
        }
    }
    
    private func findPruningCandidates() -> [PruningCandidate] {
        var candidates: [PruningCandidate] = []
        
        // 古いノート（30日以上前）
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let oldItems = items.filter { item in
            guard let timestamp = item.timestamp else { return false }
            return timestamp < thirtyDaysAgo
        }
        
        for item in oldItems {
            candidates.append(PruningCandidate(
                id: item.objectID,
                title: item.title ?? "Untitled",
                note: item.note ?? "",
                timestamp: item.timestamp ?? Date(),
                reason: "30日以上前の古いノート",
                priority: .medium
            ))
        }
        
        // 短いノート（10文字以下）
        let shortItems = items.filter { item in
            guard let note = item.note else { return false }
            return note.count <= 10
        }
        
        for item in shortItems {
            candidates.append(PruningCandidate(
                id: item.objectID,
                title: item.title ?? "Untitled",
                note: item.note ?? "",
                timestamp: item.timestamp ?? Date(),
                reason: "短いノート（10文字以下）",
                priority: .low
            ))
        }
        
        // 重複ノート
        let noteTexts = items.compactMap { $0.note }
        let uniqueTexts = Set(noteTexts)
        
        if noteTexts.count != uniqueTexts.count {
            // 重複を検出
            var textCounts: [String: Int] = [:]
            for text in noteTexts {
                textCounts[text, default: 0] += 1
            }
            
            for (text, count) in textCounts {
                if count > 1 {
                    let duplicateItems = items.filter { $0.note == text }
                    for item in duplicateItems.dropFirst() { // 最初の1つ以外
                        candidates.append(PruningCandidate(
                            id: item.objectID,
                            title: item.title ?? "Untitled",
                            note: item.note ?? "",
                            timestamp: item.timestamp ?? Date(),
                            reason: "重複ノート",
                            priority: .high
                        ))
                    }
                }
            }
        }
        
        // 優先度順にソート
        return candidates.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    private func deletePruningCandidate(_ candidate: PruningCandidate) {
        withAnimation {
            if let item = items.first(where: { $0.objectID == candidate.id }) {
                viewContext.delete(item)
                
                do {
                    try viewContext.save()
                    // 候補リストからも削除
                    pruningCandidates.removeAll { $0.id == candidate.id }
                } catch {
                    print("[CoreData] Delete pruning candidate error:", error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Pruning Candidate

struct PruningCandidate {
    let id: NSManagedObjectID
    let title: String
    let note: String
    let timestamp: Date
    let reason: String
    let priority: Priority
    
    enum Priority: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
        
        var text: String {
            switch self {
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            }
        }
    }
}

// MARK: - Pruning Candidate Card

struct PruningCandidateCard: View {
    let candidate: PruningCandidate
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(candidate.timestamp, formatter: itemFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(candidate.priority.text)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(candidate.priority.color)
                        .cornerRadius(8)
                    
                    Text(candidate.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !candidate.note.isEmpty {
                Text(candidate.note)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            HStack {
                Spacer()
                Button("削除") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Formatter

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
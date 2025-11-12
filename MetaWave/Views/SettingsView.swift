//
//  SettingsView.swift
//  MetaWave
//
//  Miyabi仕様: 設定画面
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var vault = Vault.shared
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingKeyDetails = false
    @State private var showingDeleteConfirmation = false
    @State private var showingExportAlert = false
    @State private var exportMessage = ""
    @State private var dailyReminderTime = Date()
    @State private var showingNotificationSettings = false
    @State private var showingExportView = false
    
    var body: some View {
        NavigationView {
            List {
                // 通知設定セクション
                notificationSection
                
                // セキュリティセクション
                securitySection
                
                // データ管理セクション
                dataManagementSection
                
                // テーマ設定セクション
                themeSection
                
                // 分析設定セクション
                analysisSection
                
                // アプリ情報セクション
                appInfoSection
            }
            .navigationTitle("Settings")
            .alert("Key Details", isPresented: $showingKeyDetails) {
                Button("OK") { }
            } message: {
                Text(keyDetailsMessage)
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all your notes and data. This action cannot be undone.")
            }
            .alert("Export Status", isPresented: $showingExportAlert) {
                Button("OK") { }
            } message: {
                Text(exportMessage)
            }
            .sheet(isPresented: $showingExportView) {
                DataExportView(context: viewContext)
            }
        }
    }
    
    // MARK: - View Sections
    
    private var notificationSection: some View {
        Section("通知") {
            // 通知の有効/無効
            Toggle(isOn: Binding(
                get: { notificationService.isPermissionGranted },
                set: { enabled in
                    if enabled {
                        Task {
                            _ = await notificationService.requestNotificationPermission()
                        }
                    }
                }
            )) {
                HStack {
                    Image(systemName: "bell")
                        .foregroundColor(.blue)
                    Text("通知を有効にする")
                }
            }
            
            // 毎日のリマインダー
            if notificationService.isPermissionGranted {
                DatePicker("毎日のリマインダー", selection: $dailyReminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: dailyReminderTime) { newValue in
                        Task {
                            await notificationService.scheduleDailyReminder(time: newValue)
                        }
                    }
                    .font(.subheadline)
                
                // 予定済みリマインダー
                if !notificationService.scheduledReminders.isEmpty {
                    ForEach(notificationService.scheduledReminders) { reminder in
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.orange)
                            Text(reminder.title)
                            Spacer()
                            Text(reminder.time, style: .time)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
    
    private var securitySection: some View {
        Section("Security") {
            // 暗号化状態
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                VStack(alignment: .leading) {
                    Text("Encryption")
                        .font(.headline)
                    Text("All data is encrypted with AES-256")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .padding(.vertical, 4)
            
            // 鍵情報
            Button(action: { showingKeyDetails = true }) {
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.blue)
                    Text("View Key Information")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // 鍵再生成
            Button(action: regenerateKey) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.orange)
                    Text("Regenerate Encryption Key")
                    Spacer()
                }
            }
        }
    }
    
    private var dataManagementSection: some View {
        Section("Data Management") {
            // データ統計
            NavigationLink(destination: DataStatisticsView()) {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.blue)
                    Text("Data Statistics")
                    Spacer()
                }
            }
            
            // データエクスポート
            NavigationLink(destination: DataExportView(context: viewContext)) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.green)
                    Text("Export Data")
                    Spacer()
                }
            }
            
            // フィードバックセンター
            NavigationLink(destination: FeedbackCenterView()) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundColor(.mint)
                    Text("Feedback Center")
                    Spacer()
                }
            }
            
            // バックアップ・復元
            NavigationLink(destination: BackupSettingsView()) {
                HStack {
                    Image(systemName: "externaldrive")
                        .foregroundColor(.purple)
                    Text("Backup & Restore")
                    Spacer()
                }
            }
            
            // 剪定機能
            NavigationLink(destination: PruningView(context: viewContext)) {
                HStack {
                    Image(systemName: "scissors")
                        .foregroundColor(.orange)
                    Text("Pruning Assistant")
                    Spacer()
                }
            }
            
            // データ削除
            Button(action: { showingDeleteConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Delete All Data")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Theme Section
    
    private var themeSection: some View {
        Section("テーマ設定") {
            NavigationLink(destination: ThemePreview()) {
                HStack {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.purple)
                    Text("テーマ設定")
                    Spacer()
                }
            }
            
            HStack {
                Image(systemName: "moon")
                    .foregroundColor(.blue)
                Text("ダークモード")
                Spacer()
                Toggle("", isOn: .constant(false))
            }
        }
    }
    
    private var analysisSection: some View {
        Section("Analysis Settings") {
            // 感情分析設定
            NavigationLink(destination: AnalysisSettingsView()) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("Analysis Preferences")
                    Spacer()
                }
            }
            
            // プライバシー設定
            NavigationLink(destination: PrivacySettingsView()) {
                HStack {
                    Image(systemName: "eye.slash")
                        .foregroundColor(.gray)
                    Text("Privacy Settings")
                    Spacer()
                }
            }
        }
    }
    
    private var appInfoSection: some View {
        Section("App Information") {
            HStack {
                Text("Version")
                Spacer()
                Text("2.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("1")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Bundle ID")
                Spacer()
                Text("com.vibe5.MetaWave")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            Button(action: openAppStore) {
                HStack {
                    Image(systemName: "star")
                        .foregroundColor(.yellow)
                    Text("Rate MetaWave")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var keyDetailsMessage: String {
        do {
            let key = try vault.loadOrCreateSymmetricKey()
            let keyData = key.withUnsafeBytes { Data($0) }
            let keyHash = keyData.sha256().prefix(8).map { String(format: "%02x", $0) }.joined()
            return "Encryption Key Hash: \(keyHash)\n\nThis key is stored securely in the iOS Keychain and is used to encrypt all your data."
        } catch {
            return "Unable to retrieve key information: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Actions
    
    private func regenerateKey() {
        // 鍵再生成の実装
        // 注意: これにより既存データが読み取れなくなる
        print("Key regeneration requested")
    }
    
    private func exportData() {
        showingExportView = true
        /* 旧実装をDataExportViewに移行
        Task {
            do {
                let exportData = try await generateExportData()
                let jsonString = String(data: exportData, encoding: .utf8) ?? "Export failed"
                
                await MainActor.run {
                    exportMessage = "Data exported successfully. \(jsonString.count) characters of data ready for export."
                    showingExportAlert = true
                }
            } catch {
                await MainActor.run {
                    exportMessage = "Export failed: \(error.localizedDescription)"
                    showingExportAlert = true
                }
            }
        }
        */
    }
    
    private func exportDataOld() {
        Task {
            do {
                let exportData = try await generateExportData()
                let jsonString = String(data: exportData, encoding: .utf8) ?? "Export failed"
                
                await MainActor.run {
                    exportMessage = "Data exported successfully. \(jsonString.count) characters of data ready for export."
                    showingExportAlert = true
                }
            } catch {
                await MainActor.run {
                    exportMessage = "Export failed: \(error.localizedDescription)"
                    showingExportAlert = true
                }
            }
        }
    }
    
    private func deleteAllData() {
        // 全データ削除の実装
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Note")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
        } catch {
            print("Failed to delete data: \(error)")
        }
    }
    
    private func generateExportData() async throws -> Data {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let notes = try viewContext.fetch(request)
        
        let exportNotes = notes.map { note in
            ExportNote(
                id: note.id?.uuidString ?? "",
                createdAt: note.createdAt ?? Date(),
                modality: note.modality ?? "text",
                contentText: note.contentText,
                tags: note.getTags(),
                sentiment: note.sentiment,
                arousal: note.arousal
            )
        }
        
        let exportData = ExportData(
            notes: exportNotes,
            exportDate: Date(),
            version: "2.0.0"
        )
        
        return try JSONEncoder().encode(exportData)
    }
    
    private func openAppStore() {
        // App Store評価ページを開く
        if let url = URL(string: "https://apps.apple.com/app/metawave/id123456789") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct DataStatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)],
        animation: .default
    )
    private var notes: FetchedResults<Note>
    
    var body: some View {
        List {
            Section("Overview") {
                StatisticRow(title: "Total Notes", value: "\(notes.count)")
                StatisticRow(title: "Text Notes", value: "\(notes.filter { $0.modality == "text" }.count)")
                StatisticRow(title: "Audio Notes", value: "\(notes.filter { $0.modality == "audio" }.count)")
            }
            
            Section("Time Range") {
                if let firstNote = notes.last {
                    StatisticRow(title: "First Note", value: firstNote.createdAt?.formatted() ?? "Unknown")
                }
                if let lastNote = notes.first {
                    StatisticRow(title: "Last Note", value: lastNote.createdAt?.formatted() ?? "Unknown")
                }
            }
            
            Section("Storage") {
                StatisticRow(title: "Database Size", value: "~\(estimatedDatabaseSize) KB")
                StatisticRow(title: "Average Note Length", value: "\(averageNoteLength) characters")
            }
        }
        .navigationTitle("Data Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var estimatedDatabaseSize: Int {
        // 簡易的なデータベースサイズ推定
        let totalCharacters = notes.reduce(0) { count, note in
            count + (note.contentText?.count ?? 0)
        }
        return totalCharacters / 10 // 大まかな推定
    }
    
    private var averageNoteLength: Int {
        let textNotes = notes.filter { $0.contentText != nil }
        guard !textNotes.isEmpty else { return 0 }
        
        let totalLength = textNotes.reduce(0) { count, note in
            count + (note.contentText?.count ?? 0)
        }
        
        return totalLength / textNotes.count
    }
}

struct StatisticRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct AnalysisSettingsView: View {
    @AppStorage("enableEmotionAnalysis") private var enableEmotionAnalysis = true
    @AppStorage("enableLoopDetection") private var enableLoopDetection = true
    @AppStorage("enableBiasDetection") private var enableBiasDetection = true
    @AppStorage("analysisFrequency") private var analysisFrequency = "daily"
    
    var body: some View {
        List {
            Section("Analysis Features") {
                Toggle("Emotion Analysis", isOn: $enableEmotionAnalysis)
                Toggle("Loop Detection", isOn: $enableLoopDetection)
                Toggle("Bias Detection", isOn: $enableBiasDetection)
            }
            
            Section("Analysis Frequency") {
                Picker("Frequency", selection: $analysisFrequency) {
                    Text("Real-time").tag("realtime")
                    Text("Daily").tag("daily")
                    Text("Weekly").tag("weekly")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationTitle("Analysis Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    @AppStorage("shareAnalytics") private var shareAnalytics = false
    @AppStorage("allowCrashReports") private var allowCrashReports = true
    
    var body: some View {
        List {
            Section("Data Sharing") {
                Toggle("Share Analytics", isOn: $shareAnalytics)
                Toggle("Allow Crash Reports", isOn: $allowCrashReports)
            }
            
            Section("Privacy Notice") {
                Text("MetaWave processes all data locally on your device. No personal data is sent to external servers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Privacy Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Export Data Models

struct ExportData: Codable {
    let notes: [ExportNote]
    let exportDate: Date
    let version: String
}

struct ExportNote: Codable {
    let id: String
    let createdAt: Date
    let modality: String
    let contentText: String?
    let tags: [String]
    let sentiment: Float?
    let arousal: Float?
}

// MARK: - Extensions

extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

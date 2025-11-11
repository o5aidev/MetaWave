//
//  BackupSettingsView.swift
//  MetaWave
//
//  v2.4: バックアップ設定ビュー
//

import SwiftUI
import CoreData

struct BackupSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var backupService = BackupService.shared
    @State private var showingBackupOptions = false
    @State private var showingRestoreOptions = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedBackup: BackupInfo?
    
    var body: some View {
        NavigationView {
            List {
                // バックアップ状況セクション
                backupStatusSection
                
                // バックアップ操作セクション
                backupActionsSection
                
                // 利用可能なバックアップセクション
                availableBackupsSection
                
                // 設定セクション
                settingsSection
            }
            .navigationTitle("バックアップ・復元")
            .onAppear {
                Task {
                    try? await backupService.loadAvailableBackups()
                }
            }
            .sheet(isPresented: $showingBackupOptions) {
                BackupOptionsView(backupService: backupService)
            }
            .sheet(isPresented: $showingRestoreOptions) {
                RestoreOptionsView(backupService: backupService)
            }
            .alert("バックアップを削除", isPresented: $showingDeleteConfirmation) {
                Button("削除", role: .destructive) {
                    if let backup = selectedBackup {
                        Task {
                            try? await backupService.deleteBackup(backup)
                        }
                    }
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("このバックアップを削除しますか？この操作は取り消せません。")
            }
        }
    }
    
    // MARK: - Backup Status Section
    
    private var backupStatusSection: some View {
        Section("バックアップ状況") {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("最終バックアップ")
                    if let lastBackup = backupService.lastBackupDate {
                        Text(lastBackup.formatted(.dateTime.year().month().day().hour().minute()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("バックアップなし")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if backupService.isBackingUp {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if backupService.isBackingUp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("バックアップ中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: backupService.backupProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
            
            if backupService.isRestoring {
                VStack(alignment: .leading, spacing: 8) {
                    Text("復元中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: backupService.restoreProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
        }
    }
    
    // MARK: - Backup Actions Section
    
    private var backupActionsSection: some View {
        Section("バックアップ操作") {
            Button(action: {
                showingBackupOptions = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("バックアップを作成")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .disabled(backupService.isBackingUp || backupService.isRestoring)
            
            Button(action: {
                showingRestoreOptions = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.green)
                    Text("バックアップから復元")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .disabled(backupService.isBackingUp || backupService.isRestoring)
        }
    }
    
    // MARK: - Available Backups Section
    
    private var availableBackupsSection: some View {
        Section("利用可能なバックアップ") {
            if backupService.availableBackups.isEmpty {
                Text("バックアップがありません")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(backupService.availableBackups) { backup in
                    BackupRowView(
                        backup: backup,
                        onRestore: {
                            Task {
                                try? await backupService.restoreFromBackup(backup)
                            }
                        },
                        onDelete: {
                            selectedBackup = backup
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        Section("設定") {
            HStack {
                Image(systemName: "icloud")
                    .foregroundColor(.blue)
                Text("iCloudバックアップ")
                Spacer()
                Toggle("", isOn: .constant(true))
            }
            
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                Text("自動バックアップ")
                Spacer()
                Toggle("", isOn: .constant(false))
            }
            
            HStack {
                Image(systemName: "wifi")
                    .foregroundColor(.green)
                Text("Wi-Fiのみでバックアップ")
                Spacer()
                Toggle("", isOn: .constant(true))
            }
        }
    }
}

// MARK: - Backup Row View

struct BackupRowView: View {
    let backup: BackupInfo
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: backup.type == .local ? "externaldrive" : "icloud")
                    .foregroundColor(backup.type == .local ? .blue : .cyan)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.name)
                        .font(.headline)
                    
                    Text(backup.date.formatted(.dateTime.year().month().day().hour().minute()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatFileSize(backup.size))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Button("復元") {
                    onRestore()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("削除") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Backup Options View

struct BackupOptionsView: View {
    @ObservedObject var backupService: BackupService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("バックアップオプション")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("データのバックアップ方法を選択してください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    BackupOptionCard(
                        title: "ローカルバックアップ",
                        description: "デバイスにバックアップを保存します",
                        icon: "externaldrive",
                        color: .blue
                    ) {
                        Task {
                            do {
                                _ = try await backupService.createLocalBackup()
                                dismiss()
                            } catch {
                                print("ローカルバックアップの作成に失敗しました: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    BackupOptionCard(
                        title: "iCloudバックアップ",
                        description: "iCloudにバックアップを保存します",
                        icon: "icloud",
                        color: .cyan
                    ) {
                        Task {
                            do {
                                _ = try await backupService.createCloudBackup()
                                dismiss()
                            } catch {
                                print("iCloudバックアップの作成に失敗しました: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("バックアップ作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Restore Options View

struct RestoreOptionsView: View {
    @ObservedObject var backupService: BackupService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("復元オプション")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("復元するバックアップを選択してください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if backupService.availableBackups.isEmpty {
                    Text("利用可能なバックアップがありません")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    List(backupService.availableBackups) { backup in
                        Button(action: {
                            Task {
                                try? await backupService.restoreFromBackup(backup)
                                dismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: backup.type == .local ? "externaldrive" : "icloud")
                                    .foregroundColor(backup.type == .local ? .blue : .cyan)
                                
                                VStack(alignment: .leading) {
                                    Text(backup.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(backup.date.formatted(.dateTime.year().month().day().hour().minute()))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("復元")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Backup Option Card

struct BackupOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct BackupSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        BackupSettingsView()
    }
}

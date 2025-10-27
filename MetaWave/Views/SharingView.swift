import SwiftUI
import CoreData

// MARK: - 共有ビュー
struct SharingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var sharingService: SharingService
    @StateObject private var cloudSyncService: CloudSyncService
    
    @State private var sharedNotes: [SharedNote] = []
    @State private var showShareSheet = false
    @State private var selectedNote: NSManagedObject?
    @State private var showShareInfo = false
    @State private var shareInfo: ShareInfo?
    @State private var showJoinShare = false
    @State private var shareKeyInput = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    init(persistentContainer: NSPersistentContainer, vault: Vaulting) {
        let cloudSync = CloudSyncService(persistentContainer: persistentContainer, vault: vault)
        self._cloudSyncService = StateObject(wrappedValue: cloudSync)
        self._sharingService = StateObject(wrappedValue: SharingService(persistentContainer: persistentContainer, vault: vault, cloudSyncService: cloudSync))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // 共有ノートセクション
                        Section("共有中のノート") {
                            if sharedNotes.isEmpty {
                                Text("共有中のノートはありません")
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                ForEach(sharedNotes, id: \.id) { sharedNote in
                                    SharedNoteRowView(sharedNote: sharedNote) {
                                        Task {
                                            await shareNote(sharedNote)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // アクションセクション
                        Section("アクション") {
                            Button("共有ノートに参加") {
                                showJoinShare = true
                            }
                            .foregroundColor(.blue)
                            
                            Button("共有ノートを更新") {
                                Task {
                                    await refreshSharedNotes()
                                }
                            }
                            .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("共有")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("共有") {
                        showShareSheet = true
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareNoteSheet(selectedNote: $selectedNote, sharingService: sharingService)
            }
            .sheet(isPresented: $showShareInfo) {
                if let shareInfo = shareInfo {
                    ShareInfoSheet(shareInfo: shareInfo)
                }
            }
            .sheet(isPresented: $showJoinShare) {
                JoinShareSheet(shareKeyInput: $shareKeyInput, sharingService: sharingService) { sharedNote in
                    // 共有ノートに参加成功
                    sharedNotes.append(sharedNote)
                }
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                Task {
                    await loadSharedNotes()
                }
            }
        }
    }
    
    // MARK: - 共有ノートの読み込み
    private func loadSharedNotes() async {
        isLoading = true
        do {
            sharedNotes = try await sharingService.getSharedNotes()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
        isLoading = false
    }
    
    // MARK: - 共有ノートの更新
    private func refreshSharedNotes() async {
        await loadSharedNotes()
    }
    
    // MARK: - ノートの共有
    private func shareNote(_ sharedNote: SharedNote) async {
        do {
            let shareInfo = try await sharingService.getShareInfo(sharedNote.id)
            self.shareInfo = shareInfo
            showShareInfo = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - 共有ノート行ビュー
struct SharedNoteRowView: View {
    let sharedNote: SharedNote
    let onShare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(sharedNote.title)
                    .font(.headline)
                Spacer()
                Button("共有") {
                    onShare()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Text(sharedNote.content)
                .font(.body)
                .lineLimit(2)
                .foregroundColor(.secondary)
            
            HStack {
                Text("共有者: \(sharedNote.sharedBy)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("共有日: \(sharedNote.sharedAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 権限表示
            HStack {
                if sharedNote.permissions.canRead {
                    Label("読み取り", systemImage: "eye")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                if sharedNote.permissions.canWrite {
                    Label("編集", systemImage: "pencil")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                if sharedNote.permissions.canShare {
                    Label("共有", systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if let expiresAt = sharedNote.permissions.expiresAt {
                    Text("期限: \(expiresAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ノート共有シート
struct ShareNoteSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedNote: NSManagedObject?
    @ObservedObject var sharingService: SharingService
    
    @State private var notes: [NSManagedObject] = []
    @State private var selectedPermissions = SharingPermissions(canRead: true, canWrite: false, canShare: false, expiresAt: nil)
    @State private var showExpirationDate = false
    @State private var expirationDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7日後
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var shareInfo: ShareInfo?
    @State private var showShareInfo = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("共有中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // ノート選択セクション
                        Section("共有するノートを選択") {
                            ForEach(notes, id: \.objectID) { note in
                                NoteSelectionRow(note: note, isSelected: selectedNote?.objectID == note.objectID) {
                                    selectedNote = note
                                }
                            }
                        }
                        
                        // 権限設定セクション
                        Section("共有権限") {
                            Toggle("読み取り", isOn: $selectedPermissions.canRead)
                            Toggle("編集", isOn: $selectedPermissions.canWrite)
                            Toggle("共有", isOn: $selectedPermissions.canShare)
                            
                            Toggle("期限を設定", isOn: $showExpirationDate)
                            
                            if showExpirationDate {
                                DatePicker("期限", selection: $expirationDate, displayedComponents: .date)
                            }
                        }
                    }
                }
            }
            .navigationTitle("ノートを共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("共有") {
                        Task {
                            await shareNote()
                        }
                    }
                    .disabled(selectedNote == nil || isLoading)
                }
            }
            .sheet(isPresented: $showShareInfo) {
                if let shareInfo = shareInfo {
                    ShareInfoSheet(shareInfo: shareInfo)
                }
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadNotes()
            }
        }
    }
    
    // MARK: - ノートの読み込み
    private func loadNotes() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NSManagedObject.value(forKey: "createdAt"), ascending: false)]
        
        do {
            notes = try sharingService.persistentContainer.viewContext.fetch(request)
        } catch {
            alertMessage = "ノートの読み込みに失敗しました: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - ノートの共有
    private func shareNote() async {
        guard let note = selectedNote,
              let noteId = note.value(forKey: "id") as? UUID else {
            alertMessage = "ノートが選択されていません"
            showAlert = true
            return
        }
        
        isLoading = true
        
        // 期限の設定
        let permissions = SharingPermissions(
            canRead: selectedPermissions.canRead,
            canWrite: selectedPermissions.canWrite,
            canShare: selectedPermissions.canShare,
            expiresAt: showExpirationDate ? expirationDate : nil
        )
        
        do {
            let shareInfo = try await sharingService.shareNote(noteId, with: permissions)
            self.shareInfo = shareInfo
            showShareInfo = true
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
        
        isLoading = false
    }
}

// MARK: - ノート選択行
struct NoteSelectionRow: View {
    let note: NSManagedObject
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.value(forKey: "title") as? String ?? "無題")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(note.value(forKey: "contentText") as? String ?? "")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 共有情報シート
struct ShareInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    let shareInfo: ShareInfo
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // QRコード表示
                Image(uiImage: shareInfo.qrCode)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                
                // 共有キー
                VStack(alignment: .leading, spacing: 8) {
                    Text("共有キー")
                        .font(.headline)
                    
                    Text(shareInfo.shareKey)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // 共有URL
                VStack(alignment: .leading, spacing: 8) {
                    Text("共有URL")
                        .font(.headline)
                    
                    Text(shareInfo.shareUrl.absoluteString)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // 期限表示
                if let expiresAt = shareInfo.expiresAt {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("有効期限")
                            .font(.headline)
                        
                        Text(expiresAt, style: .date)
                            .font(.body)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("共有情報")
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

// MARK: - 共有参加シート
struct JoinShareSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var shareKeyInput: String
    @ObservedObject var sharingService: SharingService
    let onJoin: (SharedNote) -> Void
    
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("共有キーを入力してください")
                    .font(.headline)
                
                TextField("共有キー", text: $shareKeyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if isLoading {
                    ProgressView("参加中...")
                } else {
                    Button("参加") {
                        Task {
                            await joinShare()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(shareKeyInput.isEmpty || isLoading)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("共有に参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - 共有への参加
    private func joinShare() async {
        isLoading = true
        
        do {
            let sharedNote = try await sharingService.joinSharedNote(shareKeyInput)
            onJoin(sharedNote)
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
        
        isLoading = false
    }
}

// MARK: - プレビュー
#Preview {
    SharingView(persistentContainer: PersistenceController.preview.container, vault: Vault.shared)
}

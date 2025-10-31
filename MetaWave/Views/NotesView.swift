//
//  NotesView.swift
//  MetaWave
//
//  ContentViewの分割 - Notes専用ビュー
//

import SwiftUI
import CoreData

struct NotesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showVoiceInput = false
    @State private var showVoiceInput_v2_1 = false
    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    @State private var selectedNoteIDs = Set<NSManagedObjectID>()
    @State private var editingItem: Item?
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default
    )
    private var items: FetchedResults<Item>
    
    let onVoiceNoteAdd: (String) -> Void

    // デフォルト引数付きのイニシャライザ（ContentViewから引数なしで呼べるように）
    init(onVoiceNoteAdd: @escaping (String) -> Void = { _ in }) {
        self.onVoiceNoteAdd = onVoiceNoteAdd
    }
    
    // 検索フィルタリング
    private var filteredItems: [Item] {
        if searchText.isEmpty {
            return Array(items)
        }
        return items.filter { item in
            let titleMatch = item.title?.localizedCaseInsensitiveContains(searchText) ?? false
            let noteMatch = item.note?.localizedCaseInsensitiveContains(searchText) ?? false
            return titleMatch || noteMatch
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if items.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if editMode == .active {
                        Button("キャンセル") {
                            exitEditMode()
                        }
                    } else {
                        Button {
                            showVoiceInput_v2_1 = true
                        } label: {
                            Label("Voice", systemImage: "mic.fill")
                        }
                        .accessibilityIdentifier("voiceButton")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if editMode == .active {
                        if !items.isEmpty {
                            Button("全削除", role: .destructive) {
                                deleteAll()
                            }
                        }
                        Button("削除", role: .destructive) {
                            deleteSelectedItems()
                        }
                        .disabled(selectedNoteIDs.isEmpty)
                    } else {
                        Button {
                            addSample()
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                        }
                        .accessibilityIdentifier("addButton")
                        EditButton()
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showVoiceInput) {
                SimpleVoiceInputView { text in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    searchText = ""
                    onVoiceNoteAdd(trimmed)
                }
            }
            .sheet(isPresented: $showVoiceInput_v2_1) {
                VoiceInputView_v2_1(vault: Vault.shared) { text in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    searchText = ""
                    onVoiceNoteAdd(trimmed)
                }
            }
            .sheet(item: $editingItem) { item in
                NoteEditSheet(item: item) { title, note in
                    saveEdits(for: item, title: title, note: note)
                }
            }
        }
        .onChange(of: editMode) { newValue in
            if newValue != .active {
                selectedNoteIDs.removeAll()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("MetaWave")
                .font(.largeTitle).bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                Text("メタ認知パートナー v2.0")
                    .font(.title3).bold()
                Text("思考と行動を記録・分析")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
            
            Button("サンプルを1件追加") {
                addSample()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
    }
    
    private var listView: some View {
        List(selection: $selectedNoteIDs) {
            Section {
                SearchBarRow(text: $searchText)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .disabled(true)
            }
            
            Section {
                if filteredItems.isEmpty {
                    emptySearchResultRow
                        .listRowInsets(EdgeInsets(top: 24, leading: 16, bottom: 24, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredItems, id: \.objectID) { item in
                        rowContent(for: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    if let index = filteredItems.firstIndex(where: { $0.objectID == item.objectID }) {
                                        deleteItems(offsets: IndexSet(integer: index))
                                    }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                                
                                Button {
                                    startEditing(item)
                                } label: {
                                    Label("編集", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .listRowSeparator(.hidden)
                            .tag(item.objectID)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func rowContent(for item: Item) -> some View {
        Group {
            if editMode == .active {
                listItemView(for: item)
            } else {
                NavigationLink {
                    detailView(for: item)
                } label: {
                    listItemView(for: item)
                }
            }
        }
    }
    
    private func listItemView(for item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.yellow)
                
                Text(item.title ?? "Untitled")
                    .font(.headline)
                
                Spacer()
                
                Text(item.timestamp ?? Date(), formatter: itemFormatter)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
    
    private func detailView(for item: Item) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading) {
                    Text(item.title ?? "Untitled")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(item.timestamp ?? Date(), formatter: itemFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let note = item.note, !note.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.headline)
                    
                    Text(note)
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Item Detail")
    }
    
    // MARK: - Actions
    
    private func addSample() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            newItem.title = "Sample Item"
            newItem.note = "This is a sample note for testing"
            
            try? viewContext.save()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            let itemsToDelete = offsets.map { filteredItems[$0] }
            itemsToDelete.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("[CoreData] Delete error:", error.localizedDescription)
            }
        }
    }
    
    private func deleteSelectedItems() {
        guard !selectedNoteIDs.isEmpty else { return }
        withAnimation {
            items.filter { selectedNoteIDs.contains($0.objectID) }
                .forEach(viewContext.delete)
            saveContext()
            selectedNoteIDs.removeAll()
        }
    }
    
    private func deleteAll() {
        guard !items.isEmpty else { return }
        withAnimation {
            items.forEach(viewContext.delete)
            saveContext()
            selectedNoteIDs.removeAll()
            editMode = .inactive
        }
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
            selectedNoteIDs.removeAll()
        }
    }
    
    private func startEditing(_ item: Item) {
        editingItem = item
    }
    
    private func saveEdits(for item: Item, title: String, note: String) {
        item.title = title
        item.note = note
        item.timestamp = Date()
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("[CoreData] Context save error:", error.localizedDescription)
        }
    }
}

// MARK: - Private Helpers

private struct NoteEditSheet: View {
    let item: Item
    let onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var note: String
    
    init(item: Item, onSave: @escaping (String, String) -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.title ?? "")
        _note = State(initialValue: item.note ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("タイトル")) {
                    TextField("タイトル", text: $title)
                }
                
                Section(header: Text("本文")) {
                    TextEditor(text: $note)
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle("ノートを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines),
                               note.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct SearchBarRow: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var hasFocused = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("ノートを検索", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($isFocused)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear {
            // 一度だけフォーカスを付与してキーボードを開く（必要時）
            if text.isEmpty && !hasFocused {
                hasFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }
}

private extension NotesView {
    var emptySearchResultRow: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("一致するノートが見つかりません")
                .font(.headline)
            Text("検索条件を変えて再度お試しください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()


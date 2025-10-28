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
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>
    
    let onVoiceNoteAdd: (String) -> Void
    
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
            .searchable(text: $searchText, prompt: "ノートを検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addSample()
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("addButton")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showVoiceInput_v2_1 = true
                    } label: {
                        Label("Voice", systemImage: "mic.fill")
                    }
                    .accessibilityIdentifier("voiceButton")
                }
            }
            .sheet(isPresented: $showVoiceInput) {
                SimpleVoiceInputView { text in
                    onVoiceNoteAdd(text)
                }
            }
            .sheet(isPresented: $showVoiceInput_v2_1) {
                VoiceInputView_v2_1(vault: Vault.shared) { text in
                    onVoiceNoteAdd(text)
                }
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
        List {
            ForEach(filteredItems) { item in
                NavigationLink {
                    detailView(for: item)
                } label: {
                    listItemView(for: item)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        if let index = filteredItems.firstIndex(where: { $0.objectID == item.objectID }) {
                            deleteItems(offsets: IndexSet(integer: index))
                        }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                    
                    Button {
                        // 編集機能（今後実装）
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteItems)
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
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()


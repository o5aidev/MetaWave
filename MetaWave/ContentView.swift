//
//  ContentView.swift
//  MetaWave
//
//  Created by 渡部一生 on 2025/10/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    var body: some View {
        TabView(selection: $selectedTab) {
            // Notes Tab
            NavigationView {
            Group {
                if items.isEmpty {
                    // Empty state UI
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
                } else {
                    // List display
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                // Detailed view
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
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "bolt.fill")
                                            .foregroundStyle(.yellow)
                                        Text(item.title ?? "Untitled")
                                            .font(.headline)
                                    }
                                    if let note = item.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    Text(item.timestamp ?? Date(), formatter: itemFormatter)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("Notes")
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
            }
            }
            .tabItem {
                Image(systemName: "note.text")
                Text("Notes")
            }
            .tag(0)
            
            // Insights Tab (Placeholder)
            NavigationView {
                VStack(spacing: 20) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Insights")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("分析機能は準備中です")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("感情分析、ループ検出、バイアス検出などの機能が追加予定です。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Insights")
            }
            .tabItem {
                Image(systemName: "brain.head.profile")
                Text("Insights")
            }
            .tag(1)
            
            // Settings Tab (Placeholder)
            NavigationView {
                VStack(spacing: 20) {
                    Image(systemName: "gear")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("設定機能は準備中です")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("セキュリティ設定、データ管理、分析設定などの機能が追加予定です。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Settings")
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(2)
        }
    }

    // MARK: - Actions

    /// サンプルを1件追加（現在時刻のみ）
    private func addSample() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            newItem.title = "Sample Item" // titleフィールドを設定
            newItem.note = "This is a sample note for testing" // noteフィールドも設定

            do {
                try viewContext.save()
            } catch {
                // 失敗してもクラッシュさせずログ
                print("[CoreData] Save error:", error.localizedDescription)
            }
        }
    }

    /// 行の削除（スワイプ削除対応）
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                print("[CoreData] Delete error:", error.localizedDescription)
            }
        }
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
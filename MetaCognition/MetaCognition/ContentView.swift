//
//  ContentView.swift
//  MetaCognition
//
//  Created by 渡部一生 on 2025/10/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    var body: some View {
        NavigationView {
            Group {
                if items.isEmpty {
                    // 空状態
                    VStack(spacing: 16) {
                        Text("MetaCognition")
                            .font(.largeTitle).bold()
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 8) {
                            Text("MetaCognition 起動テスト")
                                .font(.title3).bold()
                            Text("iPhone 14 Pro Max (iOS 26.0.1)")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)

                        Button("サンプルを1件追加") { addSample() }
                            .buttonStyle(.borderedProminent)

                        Spacer()
                    }
                    .padding()
                } else {
                    // リスト表示
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                // 簡易詳細
                                VStack(spacing: 12) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 48))
                                    Text(item.timestamp ?? Date(), formatter: itemFormatter)
                                        .font(.title3)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()
                                .navigationTitle("Detail")
                            } label: {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                        .foregroundStyle(.yellow)
                                    Text(item.timestamp ?? Date(), formatter: itemFormatter)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("MetaCognition")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addSample()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addItemButton")
                }
            }
        }
    }

    // MARK: - Actions

    /// サンプルを1件追加（現在時刻のみ）
    private func addSample() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()

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

/// 日付表示フォーマッタ
private let itemFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .medium
    return f
}()

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        ContentView()
            .environment(\.managedObjectContext, context)
    }
}

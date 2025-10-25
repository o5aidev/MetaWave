//
//  ContentView_Simple.swift
//  MetaWave
//
//  簡素化されたContentView（新機能統合前の基本版）
//

import SwiftUI
import CoreData

struct ContentView_Simple: View {
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
                                // Simple detail
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
            .navigationTitle("MetaWave v2.0")
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

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

// MARK: - Preview

struct ContentView_Simple_Previews: PreviewProvider {
    static var previews: some View {
        ContentView_Simple().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

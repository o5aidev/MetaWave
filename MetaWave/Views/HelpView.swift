//
//  HelpView.swift
//  MetaWave
//
//  v2.4: ユーザビリティ改善 - ヘルプ・チュートリアル
//

import SwiftUI
import Combine

struct HelpView: View {
    @State private var selectedCategory: HelpCategory = .gettingStarted
    @State private var searchText = ""
    
    let helpCategories: [HelpCategory] = [
        .gettingStarted,
        .features,
        .troubleshooting,
        .tips
    ]
    
    var filteredItems: [HelpItem] {
        let items = selectedCategory.items
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索バー
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // カテゴリ選択
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(helpCategories, id: \.self) { category in
                            CategoryButton(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                
                // ヘルプコンテンツ
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredItems) { item in
                            HelpItemCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("ヘルプ")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("検索...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button("クリア") {
                    text = ""
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CategoryButton: View {
    let category: HelpCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.title2)
                
                Text(category.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HelpItemCard: View {
    let item: HelpItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !isExpanded {
                        Text(item.content)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.content)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let steps = item.steps {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("手順:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                        .frame(width: 20, alignment: .leading)
                                    
                                    Text(step)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    if let tips = item.tips {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ヒント:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            ForEach(tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                        .frame(width: 16)
                                    
                                    Text(tip)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Data Models

enum HelpCategory: String, CaseIterable {
    case gettingStarted = "getting_started"
    case features = "features"
    case troubleshooting = "troubleshooting"
    case tips = "tips"
    
    var title: String {
        switch self {
        case .gettingStarted: return "はじめに"
        case .features: return "機能"
        case .troubleshooting: return "トラブル"
        case .tips: return "ヒント"
        }
    }
    
    var icon: String {
        switch self {
        case .gettingStarted: return "play.circle"
        case .features: return "star.circle"
        case .troubleshooting: return "wrench.and.screwdriver"
        case .tips: return "lightbulb.circle"
        }
    }
    
    var items: [HelpItem] {
        switch self {
        case .gettingStarted:
            return [
                HelpItem(
                    title: "アプリの基本操作",
                    content: "MetaWaveの基本的な使い方を説明します。",
                    steps: [
                        "ホーム画面で「記録」タブをタップ",
                        "テキストまたは音声で感情を記録",
                        "「分析」タブで結果を確認",
                        "「設定」でアプリをカスタマイズ"
                    ]
                ),
                HelpItem(
                    title: "初回設定",
                    content: "アプリを初めて使用する際の設定手順です。",
                    steps: [
                        "通知の許可を設定",
                        "音声認識の許可を設定",
                        "プライバシー設定を確認",
                        "バックアップ設定を有効化"
                    ]
                )
            ]
        case .features:
            return [
                HelpItem(
                    title: "感情分析機能",
                    content: "テキストから感情を分析し、可視化します。",
                    tips: [
                        "より正確な分析のため、詳細な記録を心がけましょう",
                        "定期的に記録することで、パターンが見つかりやすくなります"
                    ]
                ),
                HelpItem(
                    title: "パターン分析",
                    content: "あなたの思考パターンを発見し、改善点を提案します。",
                    tips: [
                        "同じような状況での記録を続けると、パターンが明確になります",
                        "週単位での分析結果を確認することをお勧めします"
                    ]
                ),
                HelpItem(
                    title: "予測機能",
                    content: "過去のデータから将来の感情を予測します。",
                    tips: [
                        "予測精度は記録数に比例して向上します",
                        "予測結果は参考程度に留め、最終的な判断は自分で行いましょう"
                    ]
                )
            ]
        case .troubleshooting:
            return [
                HelpItem(
                    title: "音声認識が動作しない",
                    content: "音声認識機能が正常に動作しない場合の対処法です。",
                    steps: [
                        "設定アプリでマイクの許可を確認",
                        "アプリを再起動",
                        "デバイスの音声認識設定を確認",
                        "ネットワーク接続を確認"
                    ]
                ),
                HelpItem(
                    title: "データが保存されない",
                    content: "記録したデータが保存されない場合の対処法です。",
                    steps: [
                        "デバイスのストレージ容量を確認",
                        "アプリを再起動",
                        "iCloudの同期設定を確認",
                        "アプリを最新版に更新"
                    ]
                ),
                HelpItem(
                    title: "分析結果が表示されない",
                    content: "分析結果が正しく表示されない場合の対処法です。",
                    steps: [
                        "十分なデータが記録されているか確認",
                        "アプリを再起動",
                        "分析を再実行",
                        "サポートに問い合わせ"
                    ]
                )
            ]
        case .tips:
            return [
                HelpItem(
                    title: "効果的な記録方法",
                    content: "より良い分析結果を得るための記録のコツです。",
                    tips: [
                        "感情が高まった時にすぐに記録する",
                        "具体的な状況や出来事を詳しく記録する",
                        "定期的に記録する習慣を作る",
                        "正直な気持ちを記録する"
                    ]
                ),
                HelpItem(
                    title: "プライバシー保護",
                    content: "あなたのデータを安全に保護する方法です。",
                    tips: [
                        "定期的にバックアップを作成する",
                        "強力なパスワードを使用する",
                        "不要なデータは定期的に削除する",
                        "共有設定を定期的に確認する"
                    ]
                ),
                HelpItem(
                    title: "アプリの活用方法",
                    content: "MetaWaveを最大限活用するためのアイデアです。",
                    tips: [
                        "朝と夜に記録して一日の変化を追跡する",
                        "週末に振り返りを行い、パターンを確認する",
                        "目標設定と進捗を記録する",
                        "家族や友人と結果を共有する"
                    ]
                )
            ]
        }
    }
}

struct HelpItem: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let steps: [String]?
    let tips: [String]?
    
    init(title: String, content: String, steps: [String]? = nil, tips: [String]? = nil) {
        self.title = title
        self.content = content
        self.steps = steps
        self.tips = tips
    }
}

// MARK: - Preview

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}

//
//  ThemeManager.swift
//  MetaWave
//
//  v2.4: ダークモード対応
//

import Foundation
import SwiftUI
import Combine

/// テーマ管理サービス
final class ThemeManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ThemeManager()
    
    private init() {
        loadTheme()
    }
    
    // MARK: - Published Properties
    
    @Published var currentTheme: AppTheme = .system
    @Published var colorScheme: ColorScheme?
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"
    
    // MARK: - Public Methods
    
    /// テーマを設定
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        userDefaults.set(theme.rawValue, forKey: themeKey)
        updateColorScheme()
    }
    
    /// システムテーマを取得
    func getSystemColorScheme() -> ColorScheme? {
        if #available(iOS 13.0, *) {
            return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        }
        return .light
    }
    
    /// カスタムカラーを取得
    func getCustomColor(_ color: CustomColor) -> Color {
        switch currentTheme {
        case .light:
            return color.light
        case .dark:
            return color.dark
        case .system:
            return color.system
        }
    }
    
    // MARK: - Private Methods
    
    /// テーマを読み込み
    private func loadTheme() {
        let themeValue = userDefaults.string(forKey: themeKey) ?? AppTheme.system.rawValue
        currentTheme = AppTheme(rawValue: themeValue) ?? .system
        updateColorScheme()
    }
    
    /// カラースキームを更新
    private func updateColorScheme() {
        switch currentTheme {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .system:
            colorScheme = getSystemColorScheme()
        }
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "ライト"
        case .dark:
            return "ダーク"
        case .system:
            return "システム"
        }
    }
    
    var systemImage: String {
        switch self {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        case .system:
            return "gear"
        }
    }
}

// MARK: - Custom Colors

enum CustomColor {
    case primary
    case secondary
    case accent
    case background
    case surface
    case text
    case textSecondary
    case border
    case success
    case warning
    case error
    case info
    
    var light: Color {
        switch self {
        case .primary:
            return Color.blue
        case .secondary:
            return Color.gray
        case .accent:
            return Color.purple
        case .background:
            return Color(.systemBackground)
        case .surface:
            return Color(.secondarySystemBackground)
        case .text:
            return Color.primary
        case .textSecondary:
            return Color.secondary
        case .border:
            return Color(.separator)
        case .success:
            return Color.green
        case .warning:
            return Color.orange
        case .error:
            return Color.red
        case .info:
            return Color.blue
        }
    }
    
    var dark: Color {
        switch self {
        case .primary:
            return Color.blue
        case .secondary:
            return Color.gray
        case .accent:
            return Color.purple
        case .background:
            return Color(.systemBackground)
        case .surface:
            return Color(.secondarySystemBackground)
        case .text:
            return Color.primary
        case .textSecondary:
            return Color.secondary
        case .border:
            return Color(.separator)
        case .success:
            return Color.green
        case .warning:
            return Color.orange
        case .error:
            return Color.red
        case .info:
            return Color.blue
        }
    }
    
    var system: Color {
        switch self {
        case .primary:
            return Color.accentColor
        case .secondary:
            return Color(UIColor.secondaryLabel)
        case .accent:
            return Color(UIColor.systemBlue)
        case .background:
            return Color(UIColor.systemBackground)
        case .surface:
            return Color(UIColor.secondarySystemBackground)
        case .text:
            return Color.primary
        case .textSecondary:
            return Color.secondary
        case .border:
            return Color(UIColor.separator)
        case .success:
            return Color(UIColor.systemGreen)
        case .warning:
            return Color(UIColor.systemOrange)
        case .error:
            return Color(UIColor.systemRed)
        case .info:
            return Color(UIColor.systemBlue)
        }
    }
}

// MARK: - Theme Extensions

extension View {
    /// テーマを適用
    func themed() -> some View {
        self
            .preferredColorScheme(ThemeManager.shared.colorScheme)
    }
    
    /// カスタムカラーを適用
    func customColor(_ color: CustomColor) -> some View {
        self.foregroundColor(ThemeManager.shared.getCustomColor(color))
    }
    
    /// カスタム背景色を適用
    func customBackground(_ color: CustomColor) -> some View {
        self.background(ThemeManager.shared.getCustomColor(color))
    }
}

// MARK: - Theme Components

struct ThemedCard: View {
    let content: AnyView
    
    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }
    
    var body: some View {
        content
            .padding()
            .background(ThemeManager.shared.getCustomColor(.surface))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ThemedButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }
    
    init(_ title: String, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundColor)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return ThemeManager.shared.getCustomColor(.accent)
        case .secondary:
            return ThemeManager.shared.getCustomColor(.surface)
        case .destructive:
            return ThemeManager.shared.getCustomColor(.error)
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return ThemeManager.shared.getCustomColor(.text)
        case .destructive:
            return .white
        }
    }
}

struct ThemedTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .customColor(.text)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .customColor(.text)
        }
    }
}

struct ThemedToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .customColor(.text)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: ThemeManager.shared.getCustomColor(.accent)))
        }
    }
}

// MARK: - Theme Preview

struct ThemePreview: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // テーマ選択
                VStack(alignment: .leading, spacing: 12) {
                    Text("テーマ設定")
                        .font(.headline)
                        .customColor(.text)
                    
                    Picker("テーマ", selection: $themeManager.currentTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            HStack {
                                Image(systemName: theme.systemImage)
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // カラーパレット
                VStack(alignment: .leading, spacing: 12) {
                    Text("カラーパレット")
                        .font(.headline)
                        .customColor(.text)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ColorSwatch(color: .primary, name: "Primary")
                        ColorSwatch(color: .secondary, name: "Secondary")
                        ColorSwatch(color: .accent, name: "Accent")
                        ColorSwatch(color: .success, name: "Success")
                        ColorSwatch(color: .warning, name: "Warning")
                        ColorSwatch(color: .error, name: "Error")
                    }
                }
                
                // サンプルコンポーネント
                VStack(alignment: .leading, spacing: 12) {
                    Text("サンプルコンポーネント")
                        .font(.headline)
                        .customColor(.text)
                    
                    ThemedCard {
                        VStack(spacing: 12) {
                            ThemedTextField(title: "タイトル", text: .constant("サンプルテキスト"), placeholder: "プレースホルダー")
                            
                            ThemedToggle(title: "通知を有効にする", isOn: .constant(true))
                            
                            HStack(spacing: 12) {
                                ThemedButton("保存", style: .primary) { }
                                ThemedButton("キャンセル", style: .secondary) { }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("テーマ設定")
            .themed()
        }
    }
}

struct ColorSwatch: View {
    let color: CustomColor
    let name: String
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(ThemeManager.shared.getCustomColor(color))
                .frame(height: 40)
            
            Text(name)
                .font(.caption)
                .customColor(.textSecondary)
        }
    }
}

// MARK: - Preview

struct ThemePreview_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview()
    }
}

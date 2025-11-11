//
//  AccessibilityManager.swift
//  MetaWave
//

import SwiftUI
import UIKit
import Combine

struct StatisticData {
    let title: String
    let value: String
}

struct EmotionChartData {
    let emotion: String
    let percentage: Double
}

struct PatternCardData {
    let title: String
    let strength: Double
}

struct PredictionData {
    let type: String
    let confidence: Double
}

struct BackupItemData {
    let name: String
    let date: Date
}

enum AccessibilityElement {
    case emotionChart(data: EmotionChartData)
    case patternCard(pattern: PatternCardData)
    case predictionResult(prediction: PredictionData)
    case backupItem(backup: BackupItemData)
    case statisticCard(stat: StatisticData)
}

enum FontStyle {
    case title
    case headline
    case subheadline
    case body
    case caption
    case footnote
    
    var textStyle: UIFont.TextStyle {
        switch self {
        case .title: return .title1
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .caption: return .caption1
        case .footnote: return .footnote
        }
    }
    
    var weight: Font.Weight {
        switch self {
        case .title: return .bold
        case .headline: return .semibold
        case .subheadline: return .medium
        case .body: return .regular
        case .caption: return .regular
        case .footnote: return .regular
        }
    }
    
    var design: Font.Design {
        .default
    }
}

final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isVoiceOverEnabled = false
    @Published var isReduceMotionEnabled = false
    @Published var preferredContentSizeCategory: UIContentSizeCategory = .medium
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func configure() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .sink { [weak self] notification in
                if let category = notification.userInfo?[UIContentSizeCategory.newValueUserInfoKey] as? UIContentSizeCategory {
                    self?.preferredContentSizeCategory = category
                } else {
                    self?.preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
                }
            }
            .store(in: &cancellables)
    }
    
    func generateAccessibilityLabel(for element: AccessibilityElement) -> String {
        switch element {
        case .emotionChart(let data):
            return "感情分析グラフ。\(data.emotion)が\(Int(data.percentage))パーセント。"
        case .patternCard(let pattern):
            return "パターンカード。\(pattern.title)。強度は\(Int(pattern.strength * 100))パーセント。"
        case .predictionResult(let prediction):
            return "予測結果。\(prediction.type)。信頼度は\(Int(prediction.confidence * 100))パーセント。"
        case .backupItem(let backup):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月d日"
            return "バックアップ項目。\(backup.name)。作成日\(formatter.string(from: backup.date))。"
        case .statisticCard(let stat):
            return "\(stat.title)。値は\(stat.value)。"
        }
    }
    
    func generateAccessibilityHint(for element: AccessibilityElement) -> String? {
        switch element {
        case .emotionChart:
            return "ダブルタップで詳細を表示します。"
        case .patternCard:
            return "ダブルタップでパターンの詳細を確認します。"
        case .predictionResult:
            return "ダブルタップで詳細な予測情報を確認します。"
        case .backupItem:
            return "ダブルタップでバックアップを復元します。"
        case .statisticCard:
            return nil
        }
    }
    
    func getDynamicFontSize(for style: FontStyle) -> Font {
        let baseFont = UIFont.preferredFont(forTextStyle: style.textStyle)
        return Font.system(size: baseFont.pointSize, weight: style.weight, design: style.design)
    }
    
    func getHighContrastColor(for color: Color) -> Color {
        isVoiceOverEnabled ? color.opacity(0.9) : color
    }
}

extension View {
    func accessibilityEnabled() -> some View {
        accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }
    
    func dynamicFont(_ style: FontStyle) -> some View {
        font(AccessibilityManager.shared.getDynamicFontSize(for: style))
    }
    
    func highContrastColor(_ color: Color) -> some View {
        foregroundColor(AccessibilityManager.shared.getHighContrastColor(for: color))
    }
    
    func reduceMotion() -> some View {
        animation(AccessibilityManager.shared.isReduceMotionEnabled ? .none : .default, value: UUID())
    }
    
    func accessibilityLabel(_ element: AccessibilityElement) -> some View {
        accessibilityLabel(AccessibilityManager.shared.generateAccessibilityLabel(for: element))
    }
    
    func accessibilityHint(_ element: AccessibilityElement) -> some View {
        if let hint = AccessibilityManager.shared.generateAccessibilityHint(for: element) {
            return accessibilityHint(hint)
        } else {
            return accessibilityHint("")
        }
    }
}

struct AccessibleButton: View {
    enum Style {
        case primary
        case secondary
        case destructive
    }
    
    let title: String
    let style: Style
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .dynamicFont(.headline)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundColor)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .accessibilityEnabled()
        .accessibilityLabel(.statisticCard(stat: StatisticData(title: title, value: "")))
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return .blue
        case .secondary: return .gray.opacity(0.2)
        case .destructive: return .red
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary: return .primary
        }
    }
}

struct AccessibleCard<Content: View>: View {
    let title: String
    let accessibilityData: AccessibilityElement
    let content: Content
    
    init(title: String, accessibilityData: AccessibilityElement, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessibilityData = accessibilityData
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .dynamicFont(.headline)
                .highContrastColor(.primary)
            
            content
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityData)
        .accessibilityHint(accessibilityData)
    }
}

struct AccessibleTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .dynamicFont(.headline)
                .highContrastColor(.primary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .dynamicFont(.body)
                .accessibilityLabel(.statisticCard(stat: StatisticData(title: title, value: text)))
        }
    }
}

struct AccessibleToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .dynamicFont(.body)
                .highContrastColor(.primary)
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
        .accessibilityLabel(.statisticCard(stat: StatisticData(title: title, value: isOn ? "オン" : "オフ")))
    }
}


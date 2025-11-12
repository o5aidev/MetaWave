import Foundation

enum FeedbackAnalysisType: String, Codable, CaseIterable, Identifiable {
    case emotion
    case bias
    case cognitiveDistortion
    case topic
    case temporal
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .emotion: return "感情分析"
        case .bias: return "バイアス検出"
        case .cognitiveDistortion: return "認知の歪み"
        case .topic: return "トピック分析"
        case .temporal: return "時系列分析"
        case .other: return "その他"
        }
    }
}

enum FeedbackVote: String, Codable, CaseIterable, Identifiable {
    case accurate
    case partiallyAccurate
    case inaccurate
    case unsure
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .accurate: return "hand.thumbsup.fill"
        case .partiallyAccurate: return "hand.thumbsup"
        case .inaccurate: return "hand.thumbsdown.fill"
        case .unsure: return "questionmark.circle"
        }
    }
    
    var displayName: String {
        switch self {
        case .accurate: return "的確"
        case .partiallyAccurate: return "一部的確"
        case .inaccurate: return "不正確"
        case .unsure: return "不明"
        }
    }
}

struct FeedbackEntry: Identifiable, Codable {
    let id: UUID
    let type: FeedbackAnalysisType
    let vote: FeedbackVote
    let originalResult: String
    let correctedResult: String?
    let noteID: UUID?
    let timestamp: Date
    let comment: String?
} 
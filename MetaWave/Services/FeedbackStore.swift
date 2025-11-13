import Foundation
import Combine

actor FeedbackStore {
    static let shared = FeedbackStore()
    
    private var entries: [FeedbackEntry] = [] {
        didSet { subject.send(entries) }
    }
    private let storageURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let subject = CurrentValueSubject<[FeedbackEntry], Never>([])
    
    nonisolated var entriesPublisher: AnyPublisher<[FeedbackEntry], Never> {
        subject.eraseToAnyPublisher()
    }
    
    init(fileManager: FileManager = .default, storageURL: URL? = nil) {
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let directory = baseURL.appendingPathComponent("MetaWave", isDirectory: true)
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            self.storageURL = directory.appendingPathComponent("feedback.json")
        }
        Task { await load() }
    }
    
    func record(entry: FeedbackEntry) async {
        entries.append(entry)
        await persist()
    }
    
    func record(
        type: FeedbackAnalysisType,
        vote: FeedbackVote,
        originalResult: String,
        correctedResult: String? = nil,
        noteID: UUID? = nil,
        comment: String? = nil
    ) async {
        let entry = FeedbackEntry(
            id: UUID(),
            type: type,
            vote: vote,
            originalResult: originalResult,
            correctedResult: correctedResult,
            noteID: noteID,
            timestamp: Date(),
            comment: comment
        )
        entries.append(entry)
        await persist()
    }
    
    func deleteAll() async {
        entries.removeAll()
        await persist()
    }
    
    func entries(for type: FeedbackAnalysisType?) -> [FeedbackEntry] {
        guard let type else { return entries }
        return entries.filter { $0.type == type }
    }
    
    private func load() async {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let loaded = try decoder.decode([FeedbackEntry].self, from: data)
            entries = loaded.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("[FeedbackStore] Failed to load feedback: \(error)")
            entries = []
        }
    }
    
    private func persist() async {
        do {
            let data = try encoder.encode(entries)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("[FeedbackStore] Failed to persist feedback: \(error)")
        }
    }
} 

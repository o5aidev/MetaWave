import SwiftUI
import Combine

struct FeedbackCenterView: View {
    @StateObject private var viewModel = FeedbackCenterViewModel()
    @State private var selectedType: FeedbackAnalysisType? = nil
    @State private var selectedVote: FeedbackVote? = nil
    @State private var searchText: String = ""
    
    var body: some View {
        List {
            if viewModel.filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.and.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("フィードバックはまだありません")
                        .font(.headline)
                    Text("分析結果に不一致があれば、各カードのフィードバックボタンから報告できます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.filteredEntries) { entry in
                    FeedbackEntryRow(entry: entry)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("フィードバック")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Picker("分析種類", selection: Binding(get: { selectedType }, set: { newValue in
                        selectedType = newValue
                        Task { await viewModel.applyFilters(type: selectedType, vote: selectedVote, searchText: searchText) }
                    })) {
                        Text("すべて").tag(FeedbackAnalysisType?.none)
                        ForEach(FeedbackAnalysisType.allCases) { type in
                            Text(type.displayName).tag(FeedbackAnalysisType?.some(type))
                        }
                    }
                    
                    Picker("評価", selection: Binding(get: { selectedVote }, set: { newValue in
                        selectedVote = newValue
                        Task { await viewModel.applyFilters(type: selectedType, vote: selectedVote, searchText: searchText) }
                    })) {
                        Text("すべて").tag(FeedbackVote?.none)
                        ForEach(FeedbackVote.allCases) { vote in
                            Text(vote.displayName).tag(FeedbackVote?.some(vote))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                
                Button {
                    Task { await viewModel.clearAll() }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.entries.isEmpty)
                .tint(.red)
            }
        }
        .searchable(text: $searchText)
        .onChange(of: searchText) { newValue in
            Task { await viewModel.applyFilters(type: selectedType, vote: selectedVote, searchText: newValue) }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.reload()
        }
    }
}

private struct FeedbackEntryRow: View {
    let entry: FeedbackEntry
    
    private var primaryColor: Color {
        switch entry.vote {
        case .accurate: return .green
        case .partiallyAccurate: return .blue
        case .inaccurate: return .orange
        case .unsure: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: entry.vote.iconName)
                    .font(.title2)
                    .foregroundColor(primaryColor)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.type.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(entry.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(entry.originalResult)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    if let corrected = entry.correctedResult, !corrected.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("訂正内容")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(corrected)
                                .font(.subheadline)
                        }
                    }
                    if let comment = entry.comment, !comment.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("コメント")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(comment)
                                .font(.subheadline)
                        }
                    }
                }
            }
            if let noteID = entry.noteID {
                Text("関連ノート: \(noteID.uuidString.prefix(8))…")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

@MainActor
final class FeedbackCenterViewModel: ObservableObject {
    @Published private(set) var entries: [FeedbackEntry] = []
    @Published private(set) var filteredEntries: [FeedbackEntry] = []
    private var cancellables = Set<AnyCancellable>()
    
    func load() async {
        guard cancellables.isEmpty else { return }
        FeedbackStore.shared.entriesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.entries = entries.sorted { $0.timestamp > $1.timestamp }
                self?.filteredEntries = self?.entries ?? []
            }
            .store(in: &cancellables)
    }
    
    func reload() async {
        await applyFilters(type: nil, vote: nil, searchText: "")
    }
    
    func applyFilters(type: FeedbackAnalysisType?, vote: FeedbackVote?, searchText: String) async {
        let lowered = searchText.lowercased()
        filteredEntries = entries.filter { entry in
            let matchesType = type == nil || entry.type == type
            let matchesVote = vote == nil || entry.vote == vote
            let matchesSearch: Bool
            if lowered.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = entry.originalResult.lowercased().contains(lowered) ||
                (entry.correctedResult?.lowercased().contains(lowered) ?? false) ||
                (entry.comment?.lowercased().contains(lowered) ?? false)
            }
            return matchesType && matchesVote && matchesSearch
        }
    }
    
    func clearAll() async {
        await FeedbackStore.shared.deleteAll()
    }
}

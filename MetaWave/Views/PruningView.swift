//
//  PruningView.swift
//  MetaWave
//
//  Miyabi仕様: 剪定画面
//

import SwiftUI
import CoreData

struct PruningView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var pruningService: PruningService
    @State private var selectedCandidates: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    
    init(context: NSManagedObjectContext) {
        self._pruningService = StateObject(wrappedValue: PruningService(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if pruningService.isAnalyzing {
                    analysisView
                } else if pruningService.pruningCandidates.isEmpty {
                    emptyStateView
                } else {
                    candidatesListView
                }
            }
            .navigationTitle("Pruning")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !pruningService.pruningCandidates.isEmpty {
                        Button("Analyze") {
                            Task {
                                await pruningService.analyzePruningCandidates()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if !selectedCandidates.isEmpty {
                        Button("Delete Selected") {
                            showingDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .alert("Delete Selected Notes", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSelectedCandidates()
                }
            } message: {
                Text("This will permanently delete \(selectedCandidates.count) notes. This action cannot be undone.")
            }
            .onAppear {
                Task {
                    await pruningService.analyzePruningCandidates()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var analysisView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyzing Notes for Pruning")
                .font(.headline)
            
            Text("Looking for notes that may no longer be valuable...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("No Pruning Needed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("All your notes appear to be valuable and worth keeping.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Re-analyze") {
                Task {
                    await pruningService.analyzePruningCandidates()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var candidatesListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ヘッダー情報
            headerView
            
            // 候補リスト
            List {
                ForEach(pruningService.pruningCandidates) { candidate in
                    PruningCandidateRow(
                        candidate: candidate,
                        isSelected: selectedCandidates.contains(candidate.noteID)
                    ) {
                        toggleSelection(for: candidate.noteID)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pruning Candidates")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(pruningService.pruningCandidates.count) notes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("These notes may no longer be valuable and could be removed to declutter your collection.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !selectedCandidates.isEmpty {
                HStack {
                    Text("\(selectedCandidates.count) selected")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Select All") {
                        selectAllCandidates()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Actions
    
    private func toggleSelection(for noteID: UUID) {
        if selectedCandidates.contains(noteID) {
            selectedCandidates.remove(noteID)
        } else {
            selectedCandidates.insert(noteID)
        }
    }
    
    private func selectAllCandidates() {
        selectedCandidates = Set(pruningService.pruningCandidates.map { $0.noteID })
    }
    
    private func deleteSelectedCandidates() {
        Task {
            let candidatesToDelete = pruningService.pruningCandidates.filter { candidate in
                selectedCandidates.contains(candidate.noteID)
            }
            
            do {
                try await pruningService.executePruning(candidatesToDelete)
                selectedCandidates.removeAll()
            } catch {
                print("Failed to delete candidates: \(error)")
            }
        }
    }
}

// MARK: - Pruning Candidate Row

struct PruningCandidateRow: View {
    let candidate: PruningCandidate
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 選択チェックボックス
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // タイトル
                Text(candidate.title)
                    .font(.headline)
                    .lineLimit(2)
                
                // 内容プレビュー
                Text(candidate.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                // メタデータ
                HStack {
                    Text(candidate.createdAt, formatter: dateFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 剪定スコア
                    HStack(spacing: 4) {
                        Image(systemName: "scissors")
                            .font(.caption)
                        Text(String(format: "%.1f", candidate.pruningScore))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                }
                
                // 理由
                if !candidate.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(candidate.reasons, id: \.self) { reason in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(reason)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Formatter

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
}()

// MARK: - Preview

struct PruningView_Previews: PreviewProvider {
    static var previews: some View {
        PruningView(context: PersistenceController.preview.container.viewContext)
    }
}

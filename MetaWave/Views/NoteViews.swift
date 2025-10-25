//
//  NoteViews.swift
//  MetaWave
//
//  Miyabi仕様: Note表示用View
//

import SwiftUI
import CoreData

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // モダリティアイコン
                modalityIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    // 内容プレビュー
                    Text(contentPreview)
                        .font(.body)
                        .lineLimit(2)
                    
                    // タグ
                    if !note.getTags().isEmpty {
                        tagRow
                    }
                }
                
                Spacer()
                
                // 作成日時
                Text(note.createdAt ?? Date(), formatter: dateFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 感情スコア（あれば表示）
            if let emotionScore = note.getEmotionScore() {
                emotionIndicator(emotionScore)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var modalityIcon: some View {
        Group {
            switch Note.Modality(rawValue: note.modality ?? "text") {
            case .text:
                Image(systemName: "text.alignleft")
                    .foregroundColor(.blue)
            case .audio:
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            case .image:
                Image(systemName: "photo.fill")
                    .foregroundColor(.green)
            case .none:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
        }
        .font(.title3)
    }
    
    private var contentPreview: String {
        if let content = note.contentText, !content.isEmpty {
            return content
        } else {
            return "No content"
        }
    }
    
    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(note.getTags(), id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 1)
        }
    }
    
    private func emotionIndicator(_ score: EmotionScore) -> some View {
        HStack(spacing: 8) {
            // Valence (ポジティブ/ネガティブ)
            HStack(spacing: 4) {
                Image(systemName: score.valence >= 0 ? "face.smiling" : "face.dashed")
                    .foregroundColor(score.valence >= 0 ? .green : .red)
                Text(String(format: "%.1f", score.valence))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Arousal (覚醒度)
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(score.arousal > 0.5 ? .orange : .gray)
                Text(String(format: "%.1f", score.arousal))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct NoteDetailView: View {
    let note: Note
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var editedTags: [String] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // ヘッダー
                headerSection
                
                // 内容
                contentSection
                
                // メタデータ
                metadataSection
                
                // 感情分析
                if let emotionScore = note.getEmotionScore() {
                    emotionSection(emotionScore)
                }
                
                // バイアス信号
                if !note.getBiasSignals().isEmpty {
                    biasSection
                }
            }
            .padding()
        }
        .navigationTitle("Note Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                modalityIcon
                Text(Note.Modality(rawValue: note.modality ?? "text")?.rawValue.capitalized ?? "Unknown")
                    .font(.headline)
                Spacer()
                Text(note.createdAt ?? Date(), formatter: dateFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !note.getTags().isEmpty {
                tagRow
            }
        }
    }
    
    private var modalityIcon: some View {
        Group {
            switch Note.Modality(rawValue: note.modality ?? "text") {
            case .text:
                Image(systemName: "text.alignleft")
                    .foregroundColor(.blue)
            case .audio:
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            case .image:
                Image(systemName: "photo.fill")
                    .foregroundColor(.green)
            case .none:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
        }
        .font(.title2)
    }
    
    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(isEditing ? editedTags : note.getTags(), id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 1)
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content")
                .font(.headline)
            
            if isEditing {
                TextEditor(text: $editedContent)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                Text(note.contentText ?? "No content")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metadata")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                metadataRow("Created", value: note.createdAt ?? Date(), formatter: dateFormatter)
                metadataRow("Updated", value: note.updatedAt ?? Date(), formatter: dateFormatter)
                metadataRow("ID", value: note.id?.uuidString ?? "Unknown")
                if let topicHash = note.topicHash {
                    metadataRow("Topic Hash", value: topicHash)
                }
                if let loopGroupID = note.loopGroupID {
                    metadataRow("Loop Group", value: loopGroupID)
                }
            }
        }
    }
    
    private func metadataRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
    
    private func metadataRow(_ label: String, value: Date, formatter: DateFormatter) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value, formatter: formatter)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
    
    private func emotionSection(_ score: EmotionScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Emotion Analysis")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Valence
                emotionBar(
                    label: "Valence",
                    value: score.valence,
                    range: -1.0...1.0,
                    color: score.valence >= 0 ? .green : .red,
                    icon: score.valence >= 0 ? "face.smiling" : "face.dashed"
                )
                
                // Arousal
                emotionBar(
                    label: "Arousal",
                    value: score.arousal,
                    range: 0.0...1.0,
                    color: .orange,
                    icon: "bolt.fill"
                )
            }
        }
    }
    
    private func emotionBar(
        label: String,
        value: Float,
        range: ClosedRange<Float>,
        color: Color,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(
                            width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)),
                            height: 8
                        )
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var biasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bias Signals")
                .font(.headline)
            
            let biasSignals = note.getBiasSignals()
            ForEach(Array(biasSignals.keys), id: \.self) { bias in
                HStack {
                    Text(bias.rawValue.capitalized)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.2f", biasSignals[bias] ?? 0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        editedContent = note.contentText ?? ""
        editedTags = note.getTags()
        isEditing = true
    }
    
    private func saveChanges() {
        note.contentText = editedContent
        note.setTags(editedTags)
        note.updatedAt = Date()
        
        do {
            try viewContext.save()
            isEditing = false
        } catch {
            print("Save error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Formatter

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - Preview

struct NoteRowView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let note = Note.create(
            modality: .text,
            contentText: "This is a sample note for preview.",
            tags: ["work", "important"],
            in: context
        )
        
        return NoteRowView(note: note)
            .environment(\.managedObjectContext, context)
    }
}

struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let note = Note.create(
            modality: .text,
            contentText: "This is a detailed sample note for preview. It contains more content to demonstrate the layout.",
            tags: ["work", "important", "meeting"],
            in: context
        )
        
        return NavigationView {
            NoteDetailView(note: note)
        }
        .environment(\.managedObjectContext, context)
    }
}

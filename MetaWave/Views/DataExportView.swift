//
//  DataExportView.swift
//  MetaWave
//
//  v2.4: データエクスポートビュー
//

import SwiftUI
import CoreData

struct DataExportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var exportService: DataExportService
    @State private var selectedFormat: ExportFormat = .json
    @State private var showShareSheet = false
    @State private var exportData: Data?
    @Environment(\.dismiss) private var dismiss
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case encryptedJSON = "暗号化JSON"
        
        var fileExtension: String {
            switch self {
            case .json, .encryptedJSON: return "json"
            case .csv: return "csv"
            }
        }
        
        var mimeType: String {
            switch self {
            case .json, .encryptedJSON: return "application/json"
            case .csv: return "text/csv"
            }
        }
    }
    
    init(context: NSManagedObjectContext) {
        self._exportService = StateObject(wrappedValue: DataExportService(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // ヘッダー
                headerView
                
                // フォーマット選択
                formatSelector
                
                // エクスポートボタン
                exportButton
                
                // 進捗表示
                if exportService.isExporting {
                    progressView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("データエクスポート")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = exportData {
                    ShareSheet(activityItems: [data])
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("データをエクスポート")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("ノート、感情データ、分析結果を外部ファイルとして保存")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private var formatSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("フォーマット")
                .font(.headline)
            
            ForEach(ExportFormat.allCases, id: \.self) { format in
                FormatOption(
                    format: format,
                    isSelected: selectedFormat == format,
                    action: { selectedFormat = format }
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var exportButton: some View {
        Button(action: {
            Task {
                await performExport()
            }
        }) {
            HStack {
                if exportService.isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("エクスポート中...")
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text("エクスポート")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(exportService.isExporting ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(exportService.isExporting)
    }
    
    private var progressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: exportService.exportProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("\(Int(exportService.exportProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    @MainActor
    private func performExport() async {
        do {
            let data: Data
            
            switch selectedFormat {
            case .json:
                data = try await exportService.exportToJSON()
            case .csv:
                data = try await exportService.exportToCSV()
            case .encryptedJSON:
                data = try await exportService.exportEncryptedJSON()
            }
            
            exportData = data
            showShareSheet = true
        } catch {
            print("Export failed: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct FormatOption: View {
    let format: DataExportView.ExportFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconForFormat(format))
                    .foregroundColor(colorForFormat(format))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(format.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(descriptionForFormat(format))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color(.systemGray5) : Color.clear)
            .cornerRadius(8)
        }
    }
    
    private func iconForFormat(_ format: DataExportView.ExportFormat) -> String {
        switch format {
        case .json: return "doc.text"
        case .csv: return "tablecells"
        case .encryptedJSON: return "lock.doc"
        }
    }
    
    private func colorForFormat(_ format: DataExportView.ExportFormat) -> Color {
        switch format {
        case .json: return .blue
        case .csv: return .green
        case .encryptedJSON: return .orange
        }
    }
    
    private func descriptionForFormat(_ format: DataExportView.ExportFormat) -> String {
        switch format {
        case .json: return "読みやすい形式"
        case .csv: return "Excelなどで開ける"
        case .encryptedJSON: return "セキュアな形式"
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct DataExportView_Previews: PreviewProvider {
    static var previews: some View {
        DataExportView(context: PersistenceController.preview.container.viewContext)
    }
}


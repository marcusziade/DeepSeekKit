import SwiftUI
import DeepSeekKit
import UniformTypeIdentifiers

// Custom file type for conversations
extension UTType {
    static let deepseekConversation = UTType(exportedAs: "com.deepseek.conversation")
}

// Export formats
enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case markdown = "Markdown"
    case text = "Plain Text"
    case csv = "CSV"
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .markdown: return "md"
        case .text: return "txt"
        case .csv: return "csv"
        }
    }
}

// Export manager
class ConversationExporter {
    
    // MARK: - Export Methods
    
    static func exportConversation(_ conversation: Conversation, 
                                 format: ExportFormat) -> Data? {
        switch format {
        case .json:
            return exportAsJSON(conversation)
        case .markdown:
            return exportAsMarkdown(conversation)
        case .text:
            return exportAsText(conversation)
        case .csv:
            return exportAsCSV(conversation)
        }
    }
    
    // JSON Export
    private static func exportAsJSON(_ conversation: Conversation) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            return try encoder.encode(conversation)
        } catch {
            print("JSON export failed: \(error)")
            return nil
        }
    }
    
    // Markdown Export
    private static func exportAsMarkdown(_ conversation: Conversation) -> Data? {
        var markdown = "# \(conversation.title)\n\n"
        markdown += "*Created: \(formatDate(conversation.createdAt))*\n\n"
        
        if !conversation.tags.isEmpty {
            markdown += "**Tags:** \(conversation.tags.joined(separator: ", "))\n\n"
        }
        
        markdown += "## Conversation\n\n"
        
        for message in conversation.messages {
            let role = message.role.rawValue.capitalized
            let timestamp = formatDate(message.timestamp)
            
            markdown += "### \(role) - \(timestamp)\n\n"
            markdown += "\(message.content)\n\n"
            markdown += "---\n\n"
        }
        
        return markdown.data(using: .utf8)
    }
    
    // Plain Text Export
    private static func exportAsText(_ conversation: Conversation) -> Data? {
        var text = "\(conversation.title)\n"
        text += String(repeating: "=", count: conversation.title.count) + "\n\n"
        text += "Created: \(formatDate(conversation.createdAt))\n\n"
        
        for message in conversation.messages {
            let role = message.role.rawValue.uppercased()
            text += "[\(role)]: \(message.content)\n\n"
        }
        
        return text.data(using: .utf8)
    }
    
    // CSV Export
    private static func exportAsCSV(_ conversation: Conversation) -> Data? {
        var csv = "Timestamp,Role,Content\n"
        
        for message in conversation.messages {
            let timestamp = ISO8601DateFormatter().string(from: message.timestamp)
            let role = message.role.rawValue
            let content = message.content
                .replacingOccurrences(of: "\"", with: "\"\"")
                .replacingOccurrences(of: "\n", with: " ")
            
            csv += "\"\(timestamp)\",\"\(role)\",\"\(content)\"\n"
        }
        
        return csv.data(using: .utf8)
    }
    
    // Helper
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Export View

struct ExportConversationView: View {
    let conversation: Conversation
    @State private var selectedFormat: ExportFormat = .markdown
    @State private var isExporting = false
    @State private var exportError: Error?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Preview
                GroupBox("Preview") {
                    ScrollView {
                        Text(previewText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                }
                .padding(.horizontal)
                
                // Format selector
                Picker("Export Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Export info
                VStack(alignment: .leading, spacing: 8) {
                    Label("Messages: \(conversation.messages.count)", 
                          systemImage: "message")
                    Label("File extension: .\(selectedFormat.fileExtension)", 
                          systemImage: "doc")
                    Label("Created: \(conversation.createdAt, style: .date)", 
                          systemImage: "calendar")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Spacer()
                
                // Export button
                Button(action: exportConversation) {
                    Label("Export Conversation", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Export Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: ConversationDocument(
                    conversation: conversation,
                    format: selectedFormat
                ),
                contentType: contentType,
                defaultFilename: defaultFilename
            ) { result in
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    exportError = error
                }
            }
            .alert("Export Error", 
                   isPresented: .constant(exportError != nil),
                   presenting: exportError) { _ in
                Button("OK") { exportError = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
        }
    }
    
    private var previewText: String {
        guard let data = ConversationExporter.exportConversation(
            conversation,
            format: selectedFormat
        ) else { return "Preview unavailable" }
        
        let text = String(data: data, encoding: .utf8) ?? "Preview unavailable"
        return String(text.prefix(1000))
    }
    
    private var contentType: UTType {
        switch selectedFormat {
        case .json: return .json
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .text: return .plainText
        case .csv: return .commaSeparatedText
        }
    }
    
    private var defaultFilename: String {
        let sanitizedTitle = conversation.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        return "\(sanitizedTitle).\(selectedFormat.fileExtension)"
    }
    
    private func exportConversation() {
        isExporting = true
    }
}

// MARK: - Document Type

struct ConversationDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }
    
    let conversation: Conversation
    let format: ExportFormat
    
    init(conversation: Conversation, format: ExportFormat) {
        self.conversation = conversation
        self.format = format
    }
    
    init(configuration: ReadConfiguration) throws {
        // For import functionality
        fatalError("Import not implemented")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = ConversationExporter.exportConversation(
            conversation, 
            format: format
        ) else {
            throw ExportError.exportFailed
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
}

enum ExportError: LocalizedError {
    case exportFailed
    
    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Failed to export conversation"
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Usage in a view
struct ConversationActionsView: View {
    let conversation: Conversation
    @State private var showingExport = false
    @State private var showingShare = false
    
    var body: some View {
        Menu {
            Button(action: { showingExport = true }) {
                Label("Export...", systemImage: "square.and.arrow.up")
            }
            
            Button(action: shareAsText) {
                Label("Share as Text", systemImage: "square.and.arrow.up")
            }
            
            Button(action: copyToClipboard) {
                Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .sheet(isPresented: $showingExport) {
            ExportConversationView(conversation: conversation)
        }
        .sheet(isPresented: $showingShare) {
            if let data = ConversationExporter.exportConversation(conversation, format: .text),
               let text = String(data: data, encoding: .utf8) {
                ShareSheet(items: [text])
            }
        }
    }
    
    private func shareAsText() {
        showingShare = true
    }
    
    private func copyToClipboard() {
        if let data = ConversationExporter.exportConversation(conversation, format: .text),
           let text = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = text
        }
    }
}
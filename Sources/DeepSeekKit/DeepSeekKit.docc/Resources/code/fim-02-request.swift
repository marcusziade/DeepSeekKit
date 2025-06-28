import SwiftUI
import DeepSeekKit

// Create a basic FIM completion request
struct FIMRequestView: View {
    @StateObject private var completionService = FIMCompletionService()
    @State private var prefix = "func calculateAverage(numbers: [Double]) -> Double {\n    "
    @State private var suffix = "\n}"
    @State private var showingAdvancedOptions = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Request builder
                RequestBuilderView(
                    prefix: $prefix,
                    suffix: $suffix,
                    showingAdvanced: $showingAdvancedOptions
                )
                
                // Advanced options
                if showingAdvancedOptions {
                    AdvancedOptionsView(service: completionService)
                }
                
                // Request preview
                RequestPreviewView(
                    prefix: prefix,
                    suffix: suffix,
                    service: completionService
                )
                
                // Send request button
                RequestControlsView(
                    service: completionService,
                    prefix: prefix,
                    suffix: suffix
                )
                
                // Response display
                if let completion = completionService.currentCompletion {
                    CompletionResultView(completion: completion)
                }
                
                // Request history
                if !completionService.requestHistory.isEmpty {
                    RequestHistoryView(history: completionService.requestHistory)
                }
                
                // Code examples
                CodeExamplesView(
                    onSelect: { example in
                        prefix = example.prefix
                        suffix = example.suffix
                    }
                )
            }
            .padding()
        }
        .navigationTitle("FIM Requests")
    }
}

// MARK: - FIM Completion Service

class FIMCompletionService: ObservableObject {
    @Published var currentCompletion: FIMCompletion?
    @Published var requestHistory: [FIMRequest] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // Configuration
    @Published var temperature: Double = 0.0
    @Published var maxTokens: Int = 150
    @Published var topP: Double = 0.95
    @Published var stopSequences: [String] = []
    
    private let client: DeepSeekClient
    
    init() {
        self.client = DeepSeekClient(apiKey: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "")
    }
    
    func requestCompletion(prefix: String, suffix: String) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        let request = FIMRequest(
            prefix: prefix,
            suffix: suffix,
            temperature: temperature,
            maxTokens: maxTokens,
            timestamp: Date()
        )
        
        do {
            // Format the FIM request
            let fimPrompt = formatFIMPrompt(prefix: prefix, suffix: suffix)
            
            let messages = [
                Message(role: .user, content: fimPrompt)
            ]
            
            let params = ChatCompletionParameters(
                model: "deepseek-coder",
                messages: messages,
                temperature: temperature,
                maxTokens: maxTokens,
                topP: topP,
                stop: stopSequences.isEmpty ? nil : stopSequences
            )
            
            let response = try await client.chatCompletion(params: params)
            
            if let content = response.choices.first?.message.content {
                let completion = FIMCompletion(
                    id: UUID().uuidString,
                    request: request,
                    completion: extractCompletion(from: content),
                    fullResponse: content,
                    tokensUsed: response.usage?.totalTokens ?? 0,
                    latency: Date().timeIntervalSince(request.timestamp)
                )
                
                await MainActor.run {
                    self.currentCompletion = completion
                    self.requestHistory.append(request)
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    private func formatFIMPrompt(prefix: String, suffix: String) -> String {
        // DeepSeek FIM format
        return "<｜fim▁begin｜>\(prefix)<｜fim▁hole｜>\(suffix)<｜fim▁end｜>"
    }
    
    private func extractCompletion(from response: String) -> String {
        // Extract the actual completion from the response
        // Remove any FIM tokens if present
        let cleaned = response
            .replacingOccurrences(of: "<｜fim▁begin｜>", with: "")
            .replacingOccurrences(of: "<｜fim▁hole｜>", with: "")
            .replacingOccurrences(of: "<｜fim▁end｜>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
}

// MARK: - Data Models

struct FIMRequest: Identifiable {
    let id = UUID()
    let prefix: String
    let suffix: String
    let temperature: Double
    let maxTokens: Int
    let timestamp: Date
}

struct FIMCompletion: Identifiable {
    let id: String
    let request: FIMRequest
    let completion: String
    let fullResponse: String
    let tokensUsed: Int
    let latency: TimeInterval
}

struct CodeExample {
    let name: String
    let prefix: String
    let suffix: String
    let description: String
}

// MARK: - Supporting Views

struct RequestBuilderView: View {
    @Binding var prefix: String
    @Binding var suffix: String
    @Binding var showingAdvanced: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Request Builder", systemImage: "hammer")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAdvanced.toggle() }) {
                    Label(showingAdvanced ? "Hide Advanced" : "Show Advanced", 
                          systemImage: showingAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            
            // Prefix input
            VStack(alignment: .leading, spacing: 8) {
                Label("Prefix (before cursor)", systemImage: "arrow.left")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                TextEditor(text: $prefix)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .padding(8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }
            
            // Visual separator
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Label("Cursor Position", systemImage: "cursorarrow")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Suffix input
            VStack(alignment: .leading, spacing: 8) {
                Label("Suffix (after cursor)", systemImage: "arrow.right")
                    .font(.subheadline)
                    .foregroundColor(.purple)
                
                TextEditor(text: $suffix)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .padding(8)
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
}

struct AdvancedOptionsView: View {
    @ObservedObject var service: FIMCompletionService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Options")
                .font(.headline)
            
            // Temperature
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Temperature", systemImage: "thermometer")
                    Spacer()
                    Text(String(format: "%.2f", service.temperature))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $service.temperature, in: 0...1)
                
                Text("Controls randomness. 0 = deterministic, 1 = creative")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Max tokens
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Max Tokens", systemImage: "textformat.123")
                    Spacer()
                    Text("\(service.maxTokens)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(service.maxTokens) },
                    set: { service.maxTokens = Int($0) }
                ), in: 10...500, step: 10)
                
                Text("Maximum length of completion")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Top-p
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Top-p", systemImage: "chart.bar")
                    Spacer()
                    Text(String(format: "%.2f", service.topP))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $service.topP, in: 0.1...1)
                
                Text("Nucleus sampling threshold")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Stop sequences
            VStack(alignment: .leading, spacing: 8) {
                Label("Stop Sequences", systemImage: "stop.circle")
                    .font(.subheadline)
                
                ForEach(service.stopSequences, id: \.self) { sequence in
                    HStack {
                        Text(sequence)
                            .font(.system(.caption, design: .monospaced))
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Button(action: {
                            service.stopSequences.removeAll { $0 == sequence }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                Button("Add Stop Sequence") {
                    service.stopSequences.append("\\n\\n")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct RequestPreviewView: View {
    let prefix: String
    let suffix: String
    @ObservedObject var service: FIMCompletionService
    
    var formattedRequest: String {
        return "<｜fim▁begin｜>\(prefix)<｜fim▁hole｜>\(suffix)<｜fim▁end｜>"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Request Preview", systemImage: "eye")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(formattedRequest)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 80)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            HStack {
                Label("Format: DeepSeek FIM", systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("~\(estimateTokens(formattedRequest)) tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func estimateTokens(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token
        return text.count / 4
    }
}

struct RequestControlsView: View {
    @ObservedObject var service: FIMCompletionService
    let prefix: String
    let suffix: String
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: sendRequest) {
                if service.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Label("Send Completion Request", systemImage: "paperplane.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(prefix.isEmpty || service.isLoading)
            
            if let error = service.error {
                ErrorView(error: error)
            }
        }
    }
    
    private func sendRequest() {
        Task {
            await service.requestCompletion(prefix: prefix, suffix: suffix)
        }
    }
}

struct CompletionResultView: View {
    let completion: FIMCompletion
    @State private var showingFullResponse = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Completion Result", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completion.tokensUsed) tokens")
                        .font(.caption)
                    Text("\(Int(completion.latency * 1000))ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Show completed code
            VStack(alignment: .leading, spacing: 8) {
                Text("Complete Code:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ScrollView {
                    Text(buildCompleteCode())
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Just the completion
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Generated Completion:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("Copy") {
                        copyToClipboard(completion.completion)
                    }
                    .font(.caption)
                }
                
                Text(completion.completion)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Button("Show Full Response") {
                showingFullResponse.toggle()
            }
            .font(.caption)
            
            if showingFullResponse {
                ScrollView {
                    Text(completion.fullResponse)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private func buildCompleteCode() -> String {
        return completion.request.prefix + completion.completion + completion.request.suffix
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

struct RequestHistoryView: View {
    let history: [FIMRequest]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Request History", systemImage: "clock")
                .font(.headline)
            
            ForEach(history.reversed()) { request in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(truncate(request.prefix) + "..." + truncate(request.suffix))
                            .font(.caption)
                            .lineLimit(1)
                        
                        HStack {
                            Text("Temp: \(String(format: "%.1f", request.temperature))")
                            Text("•")
                            Text("\(request.maxTokens) tokens")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(request.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private func truncate(_ text: String, length: Int = 20) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > length {
            return String(cleaned.prefix(length))
        }
        return cleaned
    }
}

struct CodeExamplesView: View {
    let onSelect: (CodeExample) -> Void
    
    let examples = [
        CodeExample(
            name: "Array Average",
            prefix: "func calculateAverage(numbers: [Double]) -> Double {\n    ",
            suffix: "\n}",
            description: "Calculate average of array"
        ),
        CodeExample(
            name: "Filter & Map",
            prefix: "let evenSquares = numbers\n    .filter { ",
            suffix: " }\n    .map { $0 * $0 }",
            description: "Filter even numbers and square them"
        ),
        CodeExample(
            name: "SwiftUI Button",
            prefix: "Button(action: {\n    ",
            suffix: "\n}) {\n    Text(\"Submit\")\n}",
            description: "Button action handler"
        ),
        CodeExample(
            name: "Error Handling",
            prefix: "do {\n    let data = try ",
            suffix: "\n} catch {\n    print(\"Error: \\(error)\")\n}",
            description: "Try-catch block completion"
        ),
        CodeExample(
            name: "Class Method",
            prefix: "class UserManager {\n    private var users: [User] = []\n    \n    func addUser(_ user: User) {\n        ",
            suffix: "\n    }\n}",
            description: "Implement addUser method"
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Example Templates", systemImage: "doc.on.doc")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(examples, id: \.name) { example in
                        ExampleCard(example: example, onSelect: onSelect)
                    }
                }
            }
        }
    }
}

struct ExampleCard: View {
    let example: CodeExample
    let onSelect: (CodeExample) -> Void
    
    var body: some View {
        Button(action: { onSelect(example) }) {
            VStack(alignment: .leading, spacing: 8) {
                Label(example.name, systemImage: "doc.text")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(example.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Text("Tap to use")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .frame(width: 150, height: 100)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - App

struct FIMRequestApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                FIMRequestView()
            }
        }
    }
}
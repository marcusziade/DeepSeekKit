import SwiftUI
import DeepSeekKit

// Handle FIM completion responses
struct FIMResponseView: View {
    @StateObject private var responseHandler = FIMResponseHandler()
    @State private var testMode = false
    @State private var selectedResponseType: ResponseType = .single
    
    enum ResponseType: String, CaseIterable {
        case single = "Single Completion"
        case streaming = "Streaming"
        case multiple = "Multiple Suggestions"
        case contextual = "Contextual"
        
        var description: String {
            switch self {
            case .single: return "Standard single completion response"
            case .streaming: return "Real-time streaming completions"
            case .multiple: return "Multiple completion alternatives"
            case .contextual: return "Context-aware adaptive completions"
            }
        }
        
        var icon: String {
            switch self {
            case .single: return "1.circle"
            case .streaming: return "dot.radiowaves.left.and.right"
            case .multiple: return "square.stack"
            case .contextual: return "brain"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Response type selector
                ResponseTypeSelector(
                    selectedType: $selectedResponseType,
                    onChange: { responseHandler.responseType = $0 }
                )
                
                // Test mode toggle
                TestModeToggle(enabled: $testMode)
                
                // Active response display
                if let activeResponse = responseHandler.activeResponse {
                    ActiveResponseView(
                        response: activeResponse,
                        handler: responseHandler
                    )
                }
                
                // Response handling demonstration
                ResponseHandlingDemo(
                    handler: responseHandler,
                    testMode: testMode,
                    responseType: selectedResponseType
                )
                
                // Response processing pipeline
                ProcessingPipelineView(handler: responseHandler)
                
                // Error handling
                if !responseHandler.errors.isEmpty {
                    ErrorHandlingView(errors: responseHandler.errors)
                }
                
                // Response metrics
                if let metrics = responseHandler.currentMetrics {
                    ResponseMetricsView(metrics: metrics)
                }
                
                // Best practices
                ResponseBestPracticesView()
            }
            .padding()
        }
        .navigationTitle("FIM Responses")
    }
}

// MARK: - FIM Response Handler

class FIMResponseHandler: ObservableObject {
    @Published var activeResponse: FIMResponse?
    @Published var responseHistory: [FIMResponse] = []
    @Published var errors: [ResponseError] = []
    @Published var currentMetrics: ResponseMetrics?
    @Published var isProcessing = false
    @Published var responseType: FIMResponseView.ResponseType = .single
    
    // Streaming support
    @Published var streamingBuffer = ""
    @Published var streamingCompletions: [String] = []
    private var streamingTimer: Timer?
    
    // Multiple suggestions
    @Published var suggestions: [CompletionSuggestion] = []
    @Published var selectedSuggestionIndex = 0
    
    struct FIMResponse {
        let id: String
        let type: FIMResponseView.ResponseType
        let content: String
        let metadata: ResponseMetadata
        let timestamp: Date
    }
    
    struct ResponseMetadata {
        let model: String
        let tokensGenerated: Int
        let stopReason: StopReason
        let confidence: Double
    }
    
    enum StopReason: String {
        case maxTokens = "Max Tokens"
        case stopSequence = "Stop Sequence"
        case endOfText = "End of Text"
        case userStop = "User Stopped"
    }
    
    struct CompletionSuggestion {
        let id: String
        let content: String
        let score: Double
        let explanation: String
    }
    
    struct ResponseError: Identifiable {
        let id = UUID()
        let type: ErrorType
        let message: String
        let timestamp: Date
        let recoverable: Bool
    }
    
    enum ErrorType {
        case network
        case parsing
        case timeout
        case rateLimit
        case invalid
    }
    
    struct ResponseMetrics {
        let latency: TimeInterval
        let throughput: Double // tokens/second
        let qualityScore: Double
        let contextRelevance: Double
    }
    
    func simulateResponse(type: FIMResponseView.ResponseType) {
        isProcessing = true
        errors.removeAll()
        
        switch type {
        case .single:
            simulateSingleResponse()
        case .streaming:
            simulateStreamingResponse()
        case .multiple:
            simulateMultipleResponses()
        case .contextual:
            simulateContextualResponse()
        }
    }
    
    private func simulateSingleResponse() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            let response = FIMResponse(
                id: UUID().uuidString,
                type: .single,
                content: "return numbers.reduce(0, +) / Double(numbers.count)",
                metadata: ResponseMetadata(
                    model: "deepseek-coder",
                    tokensGenerated: 12,
                    stopReason: .endOfText,
                    confidence: 0.95
                ),
                timestamp: Date()
            )
            
            self.processResponse(response)
        }
    }
    
    private func simulateStreamingResponse() {
        streamingBuffer = ""
        streamingCompletions.removeAll()
        
        let tokens = ["return", " numbers", ".reduce", "(0,", " +)", " /", " Double", "(numbers", ".count", ")"]
        var currentIndex = 0
        
        streamingTimer?.invalidate()
        streamingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self = self, currentIndex < tokens.count else {
                timer.invalidate()
                self?.finalizeStreamingResponse()
                return
            }
            
            self.streamingBuffer += tokens[currentIndex]
            self.streamingCompletions.append(self.streamingBuffer)
            currentIndex += 1
            
            // Update UI
            self.objectWillChange.send()
        }
    }
    
    private func finalizeStreamingResponse() {
        let response = FIMResponse(
            id: UUID().uuidString,
            type: .streaming,
            content: streamingBuffer,
            metadata: ResponseMetadata(
                model: "deepseek-coder",
                tokensGenerated: streamingBuffer.split(separator: " ").count,
                stopReason: .endOfText,
                confidence: 0.92
            ),
            timestamp: Date()
        )
        
        processResponse(response)
    }
    
    private func simulateMultipleResponses() {
        suggestions = [
            CompletionSuggestion(
                id: "1",
                content: "return numbers.isEmpty ? 0 : numbers.reduce(0, +) / Double(numbers.count)",
                score: 0.95,
                explanation: "Safe handling of empty arrays"
            ),
            CompletionSuggestion(
                id: "2",
                content: "let sum = numbers.reduce(0, +)\nreturn sum / Double(numbers.count)",
                score: 0.88,
                explanation: "More readable with intermediate variable"
            ),
            CompletionSuggestion(
                id: "3",
                content: "return numbers.reduce(0, +) / Double(numbers.count)",
                score: 0.85,
                explanation: "Concise functional approach"
            )
        ]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self = self else { return }
            
            let response = FIMResponse(
                id: UUID().uuidString,
                type: .multiple,
                content: self.suggestions.first?.content ?? "",
                metadata: ResponseMetadata(
                    model: "deepseek-coder",
                    tokensGenerated: 15,
                    stopReason: .endOfText,
                    confidence: 0.95
                ),
                timestamp: Date()
            )
            
            self.processResponse(response)
        }
    }
    
    private func simulateContextualResponse() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            
            let response = FIMResponse(
                id: UUID().uuidString,
                type: .contextual,
                content: """
                guard !numbers.isEmpty else {
                    return 0
                }
                
                let sum = numbers.reduce(0, +)
                return sum / Double(numbers.count)
                """,
                metadata: ResponseMetadata(
                    model: "deepseek-coder",
                    tokensGenerated: 28,
                    stopReason: .endOfText,
                    confidence: 0.97
                ),
                timestamp: Date()
            )
            
            self.processResponse(response)
        }
    }
    
    private func processResponse(_ response: FIMResponse) {
        // Validate response
        guard validateResponse(response) else {
            handleInvalidResponse(response)
            return
        }
        
        // Post-process
        let processed = postProcessResponse(response)
        
        // Calculate metrics
        let metrics = calculateMetrics(for: processed)
        
        // Update state
        activeResponse = processed
        responseHistory.append(processed)
        currentMetrics = metrics
        isProcessing = false
    }
    
    private func validateResponse(_ response: FIMResponse) -> Bool {
        // Check for common issues
        if response.content.isEmpty {
            errors.append(ResponseError(
                type: .invalid,
                message: "Empty response content",
                timestamp: Date(),
                recoverable: true
            ))
            return false
        }
        
        if response.content.count > 1000 {
            errors.append(ResponseError(
                type: .invalid,
                message: "Response exceeds maximum length",
                timestamp: Date(),
                recoverable: true
            ))
            return false
        }
        
        return true
    }
    
    private func postProcessResponse(_ response: FIMResponse) -> FIMResponse {
        var processedContent = response.content
        
        // Remove any residual tokens
        processedContent = processedContent
            .replacingOccurrences(of: "<｜fim▁begin｜>", with: "")
            .replacingOccurrences(of: "<｜fim▁hole｜>", with: "")
            .replacingOccurrences(of: "<｜fim▁end｜>", with: "")
        
        // Trim whitespace
        processedContent = processedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fix common formatting issues
        processedContent = fixIndentation(processedContent)
        
        return FIMResponse(
            id: response.id,
            type: response.type,
            content: processedContent,
            metadata: response.metadata,
            timestamp: response.timestamp
        )
    }
    
    private func fixIndentation(_ code: String) -> String {
        // Simple indentation fix (in real implementation, would be more sophisticated)
        let lines = code.components(separatedBy: .newlines)
        let fixedLines = lines.map { line in
            if line.hasPrefix("    ") {
                return line
            } else if !line.isEmpty && !line.hasPrefix(" ") {
                return "    " + line
            }
            return line
        }
        return fixedLines.joined(separator: "\n")
    }
    
    private func calculateMetrics(for response: FIMResponse) -> ResponseMetrics {
        let latency = Date().timeIntervalSince(response.timestamp)
        let throughput = Double(response.metadata.tokensGenerated) / max(latency, 0.1)
        let qualityScore = response.metadata.confidence
        let contextRelevance = calculateContextRelevance(response.content)
        
        return ResponseMetrics(
            latency: latency,
            throughput: throughput,
            qualityScore: qualityScore,
            contextRelevance: contextRelevance
        )
    }
    
    private func calculateContextRelevance(_ content: String) -> Double {
        // Simplified relevance calculation
        var score = 0.5
        
        if content.contains("numbers") { score += 0.2 }
        if content.contains("reduce") || content.contains("sum") { score += 0.15 }
        if content.contains("count") || content.contains("length") { score += 0.15 }
        
        return min(score, 1.0)
    }
    
    private func handleInvalidResponse(_ response: FIMResponse) {
        errors.append(ResponseError(
            type: .parsing,
            message: "Failed to process response",
            timestamp: Date(),
            recoverable: false
        ))
        isProcessing = false
    }
    
    func selectSuggestion(at index: Int) {
        guard index < suggestions.count else { return }
        selectedSuggestionIndex = index
        
        if let selected = suggestions[safe: index] {
            activeResponse = FIMResponse(
                id: UUID().uuidString,
                type: .multiple,
                content: selected.content,
                metadata: ResponseMetadata(
                    model: "deepseek-coder",
                    tokensGenerated: selected.content.split(separator: " ").count,
                    stopReason: .endOfText,
                    confidence: selected.score
                ),
                timestamp: Date()
            )
        }
    }
    
    func clearErrors() {
        errors.removeAll()
    }
}

// Helper extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Supporting Views

struct ResponseTypeSelector: View {
    @Binding var selectedType: FIMResponseView.ResponseType
    let onChange: (FIMResponseView.ResponseType) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Response Types")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                ForEach(FIMResponseView.ResponseType.allCases, id: \.self) { type in
                    ResponseTypeCard(
                        type: type,
                        isSelected: selectedType == type,
                        action: {
                            selectedType = type
                            onChange(type)
                        }
                    )
                }
            }
        }
    }
}

struct ResponseTypeCard: View {
    let type: FIMResponseView.ResponseType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(type.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TestModeToggle: View {
    @Binding var enabled: Bool
    
    var body: some View {
        HStack {
            Label("Test Mode", systemImage: "testtube.2")
                .font(.subheadline)
            
            Spacer()
            
            Toggle("", isOn: $enabled)
                .labelsHidden()
            
            Text(enabled ? "Simulated Responses" : "Live API")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(enabled ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ActiveResponseView: View {
    let response: FIMResponseHandler.FIMResponse
    @ObservedObject var handler: FIMResponseHandler
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Active Response", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text(response.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
            }
            
            // Response content
            ScrollView {
                Text(response.content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
            
            // Metadata
            HStack(spacing: 16) {
                MetadataItem(
                    label: "Model",
                    value: response.metadata.model
                )
                
                MetadataItem(
                    label: "Tokens",
                    value: "\(response.metadata.tokensGenerated)"
                )
                
                MetadataItem(
                    label: "Stop Reason",
                    value: response.metadata.stopReason.rawValue
                )
                
                MetadataItem(
                    label: "Confidence",
                    value: String(format: "%.0f%%", response.metadata.confidence * 100)
                )
            }
            .font(.caption)
            
            // Multiple suggestions view
            if response.type == .multiple && !handler.suggestions.isEmpty {
                MultipleSuggestionsView(
                    suggestions: handler.suggestions,
                    selectedIndex: handler.selectedSuggestionIndex,
                    onSelect: { index in
                        handler.selectSuggestion(at: index)
                    }
                )
            }
        }
    }
}

struct MetadataItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct MultipleSuggestionsView: View {
    let suggestions: [FIMResponseHandler.CompletionSuggestion]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alternative Suggestions")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                SuggestionCard(
                    suggestion: suggestion,
                    isSelected: index == selectedIndex,
                    onTap: { onSelect(index) }
                )
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: FIMResponseHandler.CompletionSuggestion
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Score: \(Int(suggestion.score * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Text(suggestion.content)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(3)
                
                Text(suggestion.explanation)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ResponseHandlingDemo: View {
    @ObservedObject var handler: FIMResponseHandler
    let testMode: Bool
    let responseType: FIMResponseView.ResponseType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Response Handling Demo", systemImage: "play.circle")
                .font(.headline)
            
            Button(action: startDemo) {
                if handler.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Label("Simulate \(responseType.rawValue)", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!testMode || handler.isProcessing)
            
            if !testMode {
                Text("Enable test mode to simulate responses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Streaming visualization
            if responseType == .streaming && !handler.streamingCompletions.isEmpty {
                StreamingVisualization(completions: handler.streamingCompletions)
            }
        }
    }
    
    private func startDemo() {
        handler.simulateResponse(type: responseType)
    }
}

struct StreamingVisualization: View {
    let completions: [String]
    @State private var visibleIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streaming Progress")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if visibleIndex < completions.count {
                Text(completions[visibleIndex])
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .animation(.easeInOut, value: visibleIndex)
            }
            
            ProgressView(value: Double(visibleIndex + 1), total: Double(completions.count))
                .progressViewStyle(LinearProgressViewStyle())
        }
        .onAppear {
            animateStreaming()
        }
    }
    
    private func animateStreaming() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            if visibleIndex < completions.count - 1 {
                visibleIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

struct ProcessingPipelineView: View {
    @ObservedObject var handler: FIMResponseHandler
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Processing Pipeline", systemImage: "arrow.right.square")
                .font(.headline)
            
            VStack(spacing: 0) {
                PipelineStep(
                    title: "Receive Response",
                    description: "Raw API response",
                    status: handler.activeResponse != nil ? .completed : .pending
                )
                
                PipelineConnector()
                
                PipelineStep(
                    title: "Validate",
                    description: "Check format and content",
                    status: handler.activeResponse != nil && handler.errors.isEmpty ? .completed : handler.errors.isEmpty ? .pending : .error
                )
                
                PipelineConnector()
                
                PipelineStep(
                    title: "Post-Process",
                    description: "Clean and format",
                    status: handler.activeResponse != nil ? .completed : .pending
                )
                
                PipelineConnector()
                
                PipelineStep(
                    title: "Calculate Metrics",
                    description: "Performance analysis",
                    status: handler.currentMetrics != nil ? .completed : .pending
                )
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

struct PipelineStep: View {
    let title: String
    let description: String
    let status: StepStatus
    
    enum StepStatus {
        case pending
        case processing
        case completed
        case error
        
        var color: Color {
            switch self {
            case .pending: return .gray
            case .processing: return .orange
            case .completed: return .green
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "circle"
            case .processing: return "circle.dotted"
            case .completed: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct PipelineConnector: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 2, height: 20)
                .padding(.leading, 11)
            
            Spacer()
        }
    }
}

struct ErrorHandlingView: View {
    let errors: [FIMResponseHandler.ResponseError]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Errors (\(errors.count))", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button("Clear") {
                    // Clear errors action
                }
                .font(.caption)
            }
            
            ForEach(errors) { error in
                ErrorCard(error: error)
            }
        }
    }
}

struct ErrorCard: View {
    let error: FIMResponseHandler.ResponseError
    
    var body: some View {
        HStack {
            Image(systemName: iconForErrorType(error.type))
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(error.message)
                    .font(.subheadline)
                
                HStack {
                    Text(error.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if error.recoverable {
                        Label("Recoverable", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func iconForErrorType(_ type: FIMResponseHandler.ErrorType) -> String {
        switch type {
        case .network: return "wifi.exclamationmark"
        case .parsing: return "doc.badge.ellipsis"
        case .timeout: return "clock.badge.exclamationmark"
        case .rateLimit: return "speedometer"
        case .invalid: return "xmark.octagon"
        }
    }
}

struct ResponseMetricsView: View {
    let metrics: FIMResponseHandler.ResponseMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Response Metrics", systemImage: "chart.bar")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                MetricCard(
                    title: "Latency",
                    value: String(format: "%.0fms", metrics.latency * 1000),
                    icon: "clock",
                    color: metrics.latency < 0.5 ? .green : metrics.latency < 1 ? .orange : .red
                )
                
                MetricCard(
                    title: "Throughput",
                    value: String(format: "%.1f tok/s", metrics.throughput),
                    icon: "speedometer",
                    color: .blue
                )
                
                MetricCard(
                    title: "Quality",
                    value: String(format: "%.0f%%", metrics.qualityScore * 100),
                    icon: "star.fill",
                    color: metrics.qualityScore > 0.8 ? .green : .orange
                )
                
                MetricCard(
                    title: "Relevance",
                    value: String(format: "%.0f%%", metrics.contextRelevance * 100),
                    icon: "link",
                    color: .purple
                )
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ResponseBestPracticesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Response Best Practices", systemImage: "checkmark.seal")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                BestPracticeItem(
                    icon: "checkmark.shield",
                    title: "Always Validate",
                    description: "Check response format and content before use"
                )
                
                BestPracticeItem(
                    icon: "scissors",
                    title: "Post-Process",
                    description: "Clean tokens, fix formatting, normalize output"
                )
                
                BestPracticeItem(
                    icon: "exclamationmark.triangle",
                    title: "Handle Errors",
                    description: "Implement fallbacks for failed completions"
                )
                
                BestPracticeItem(
                    icon: "timer",
                    title: "Set Timeouts",
                    description: "Prevent hanging on slow responses"
                )
                
                BestPracticeItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track Metrics",
                    description: "Monitor quality and performance over time"
                )
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

struct BestPracticeItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - App

struct FIMResponseApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                FIMResponseView()
            }
        }
    }
}
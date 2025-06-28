import SwiftUI
import DeepSeekKit

// Implementing retry logic for failed streams
struct StreamRetryView: View {
    @StateObject private var retryManager = StreamRetryManager()
    @State private var userPrompt = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Stream Retry Logic")
                .font(.largeTitle)
                .bold()
            
            // Retry status display
            RetryStatusView(manager: retryManager)
            
            // Messages with retry indicators
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(retryManager.messages) { message in
                        RetryableMessageView(message: message)
                    }
                }
                .padding()
            }
            
            // Retry controls
            if retryManager.canRetry {
                RetryControlsView(manager: retryManager)
            }
            
            // Input
            HStack {
                TextField("Enter your message", text: $userPrompt)
                    .textFieldStyle(.roundedBorder)
                
                Button("Send") {
                    Task {
                        await retryManager.sendWithRetry(userPrompt)
                        userPrompt = ""
                    }
                }
                .disabled(userPrompt.isEmpty || retryManager.isProcessing)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Stream retry manager with sophisticated retry logic
@MainActor
class StreamRetryManager: ObservableObject {
    @Published var messages: [RetryableMessage] = []
    @Published var isProcessing = false
    @Published var currentRetryAttempt = 0
    @Published var canRetry = false
    @Published var retryState: RetryState = .idle
    
    private let client = DeepSeekClient()
    private let maxRetries = 3
    private var lastFailedMessage: RetryableMessage?
    private var retryTask: Task<Void, Never>?
    
    enum RetryState {
        case idle
        case retrying(attempt: Int, nextRetryIn: TimeInterval)
        case succeeded
        case failed(reason: String)
    }
    
    struct RetryableMessage: Identifiable {
        let id = UUID()
        let role: String
        var content: String
        var status: MessageStatus
        let originalPrompt: String
        var retryInfo: RetryInfo?
        
        enum MessageStatus {
            case pending
            case streaming
            case complete
            case failed(error: StreamError)
            case partialSuccess(lastPosition: Int)
        }
        
        struct RetryInfo {
            var attempts: Int
            var lastAttemptTime: Date
            var partialContent: String?
            var resumePosition: Int
            var errors: [StreamError]
        }
        
        struct StreamError {
            let type: ErrorType
            let message: String
            let timestamp: Date
            let recoverable: Bool
            
            enum ErrorType {
                case network
                case timeout
                case rateLimit
                case server
                case unknown
            }
        }
    }
    
    func sendWithRetry(_ prompt: String) async {
        resetRetryState()
        
        // Add user message
        let userMessage = RetryableMessage(
            role: "user",
            content: prompt,
            status: .complete,
            originalPrompt: prompt
        )
        messages.append(userMessage)
        
        // Create assistant message
        let assistantMessage = RetryableMessage(
            role: "assistant",
            content: "",
            status: .pending,
            originalPrompt: prompt
        )
        messages.append(assistantMessage)
        
        // Attempt to stream
        await attemptStream(messageId: assistantMessage.id, prompt: prompt)
    }
    
    private func attemptStream(messageId: UUID, prompt: String, isRetry: Bool = false) async {
        isProcessing = true
        
        if isRetry {
            currentRetryAttempt += 1
            retryState = .retrying(attempt: currentRetryAttempt, nextRetryIn: 0)
        }
        
        // Update message status
        updateMessageStatus(messageId: messageId, status: .streaming)
        
        do {
            var accumulatedContent = ""
            var chunkCount = 0
            let startTime = Date()
            
            for try await chunk in client.streamMessage(prompt) {
                chunkCount += 1
                
                // Simulate potential failures for demonstration
                if shouldSimulateFailure(chunkCount: chunkCount, prompt: prompt) {
                    throw createSimulatedError(chunkCount: chunkCount)
                }
                
                // Process chunk
                if let content = chunk.choices.first?.delta.content {
                    accumulatedContent += content
                    updateMessageContent(messageId: messageId, content: accumulatedContent)
                }
                
                // Check for completion
                if chunk.choices.first?.finishReason != nil {
                    markMessageComplete(messageId: messageId)
                    retryState = .succeeded
                    canRetry = false
                    lastFailedMessage = nil
                    currentRetryAttempt = 0
                }
            }
        } catch {
            await handleStreamFailure(
                messageId: messageId,
                error: error,
                prompt: prompt
            )
        }
        
        isProcessing = false
    }
    
    private func handleStreamFailure(messageId: UUID, error: Error, prompt: String) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        // Categorize error
        let streamError = categorizeError(error)
        
        // Get current content length for resume position
        let currentContent = messages[index].content
        let resumePosition = currentContent.count
        
        // Update retry info
        var retryInfo = messages[index].retryInfo ?? RetryableMessage.RetryInfo(
            attempts: 0,
            lastAttemptTime: Date(),
            partialContent: nil,
            resumePosition: 0,
            errors: []
        )
        
        retryInfo.attempts += 1
        retryInfo.lastAttemptTime = Date()
        retryInfo.partialContent = currentContent.isEmpty ? nil : currentContent
        retryInfo.resumePosition = resumePosition
        retryInfo.errors.append(streamError)
        
        messages[index].retryInfo = retryInfo
        
        // Update status based on content
        if currentContent.isEmpty {
            messages[index].status = .failed(error: streamError)
        } else {
            messages[index].status = .partialSuccess(lastPosition: resumePosition)
        }
        
        // Determine if retry is possible
        lastFailedMessage = messages[index]
        canRetry = streamError.recoverable && retryInfo.attempts < maxRetries
        
        if canRetry {
            let backoffDelay = calculateBackoffDelay(attempt: retryInfo.attempts)
            retryState = .retrying(
                attempt: retryInfo.attempts,
                nextRetryIn: backoffDelay
            )
        } else {
            retryState = .failed(reason: streamError.message)
        }
    }
    
    func retryLastFailed() {
        guard let failed = lastFailedMessage,
              let retryInfo = failed.retryInfo,
              retryInfo.attempts < maxRetries else { return }
        
        retryTask = Task {
            // Apply exponential backoff
            let delay = calculateBackoffDelay(attempt: retryInfo.attempts)
            
            // Show countdown
            for i in stride(from: Int(delay), through: 1, by: -1) {
                retryState = .retrying(
                    attempt: retryInfo.attempts,
                    nextRetryIn: TimeInterval(i)
                )
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            // Prepare retry prompt
            let retryPrompt: String
            if let partial = retryInfo.partialContent, !partial.isEmpty {
                // Resume from where we left off
                retryPrompt = "Continue from: '\(partial.suffix(50))'"
            } else {
                // Retry from beginning
                retryPrompt = failed.originalPrompt
            }
            
            await attemptStream(
                messageId: failed.id,
                prompt: retryPrompt,
                isRetry: true
            )
        }
    }
    
    func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
        canRetry = false
        retryState = .idle
    }
    
    private func categorizeError(_ error: Error) -> RetryableMessage.StreamError {
        if let deepSeekError = error as? DeepSeekError {
            switch deepSeekError {
            case .rateLimitExceeded:
                return RetryableMessage.StreamError(
                    type: .rateLimit,
                    message: "Rate limit exceeded. Please wait before retrying.",
                    timestamp: Date(),
                    recoverable: true
                )
            case .networkError:
                return RetryableMessage.StreamError(
                    type: .network,
                    message: "Network error occurred",
                    timestamp: Date(),
                    recoverable: true
                )
            case .authenticationError:
                return RetryableMessage.StreamError(
                    type: .unknown,
                    message: "Authentication failed",
                    timestamp: Date(),
                    recoverable: false
                )
            case .apiError(let code, _):
                return RetryableMessage.StreamError(
                    type: code >= 500 ? .server : .unknown,
                    message: "API error (code: \(code))",
                    timestamp: Date(),
                    recoverable: code >= 500
                )
            default:
                break
            }
        }
        
        return RetryableMessage.StreamError(
            type: .unknown,
            message: error.localizedDescription,
            timestamp: Date(),
            recoverable: false
        )
    }
    
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff with jitter
        let baseDelay = pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...1)
        return min(baseDelay + jitter, 30.0) // Max 30 seconds
    }
    
    private func updateMessageStatus(messageId: UUID, status: RetryableMessage.MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = status
        }
    }
    
    private func updateMessageContent(messageId: UUID, content: String) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].content = content
        }
    }
    
    private func markMessageComplete(messageId: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = .complete
        }
    }
    
    private func resetRetryState() {
        currentRetryAttempt = 0
        canRetry = false
        retryState = .idle
        lastFailedMessage = nil
    }
    
    // Simulation helpers for demonstration
    private func shouldSimulateFailure(chunkCount: Int, prompt: String) -> Bool {
        // Simulate failures for testing
        if prompt.contains("fail") {
            if prompt.contains("partial") && chunkCount > 5 {
                return true
            }
            if prompt.contains("immediate") && chunkCount == 1 {
                return true
            }
        }
        return false
    }
    
    private func createSimulatedError(chunkCount: Int) -> Error {
        if chunkCount == 1 {
            return DeepSeekError.networkError(URLError(.notConnectedToInternet))
        } else {
            return DeepSeekError.rateLimitExceeded
        }
    }
}

// UI Components
struct RetryStatusView: View {
    @ObservedObject var manager: StreamRetryManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                statusIcon
                VStack(alignment: .leading) {
                    Text(statusTitle)
                        .font(.headline)
                    if let subtitle = statusSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if case .retrying(_, let countdown) = manager.retryState, countdown > 0 {
                    Text("\(Int(countdown))s")
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundColor(.orange)
                }
            }
            
            if manager.currentRetryAttempt > 0 {
                ProgressView(value: Double(manager.currentRetryAttempt), 
                           total: Double(3)) {
                    Text("Retry attempt \(manager.currentRetryAttempt) of 3")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(10)
    }
    
    var statusIcon: some View {
        Group {
            switch manager.retryState {
            case .idle:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            case .retrying:
                ProgressView()
                    .scaleEffect(0.8)
            case .succeeded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.title2)
    }
    
    var statusTitle: String {
        switch manager.retryState {
        case .idle:
            return "Ready"
        case .retrying(let attempt, _):
            return "Retrying (Attempt \(attempt))"
        case .succeeded:
            return "Stream Completed"
        case .failed:
            return "Stream Failed"
        }
    }
    
    var statusSubtitle: String? {
        switch manager.retryState {
        case .retrying(_, let countdown) where countdown > 0:
            return "Next retry in \(Int(countdown)) seconds"
        case .failed(let reason):
            return reason
        default:
            return nil
        }
    }
    
    var statusColor: Color {
        switch manager.retryState {
        case .idle, .succeeded:
            return .green
        case .retrying:
            return .orange
        case .failed:
            return .red
        }
    }
}

struct RetryControlsView: View {
    @ObservedObject var manager: StreamRetryManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Stream failed but can be retried")
                    .font(.subheadline)
                Text("Partial content has been preserved")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Retry Now") {
                manager.retryLastFailed()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") {
                manager.cancelRetry()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct RetryableMessageView: View {
    let message: StreamRetryManager.RetryableMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(message.role.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                MessageStatusBadge(status: message.status)
            }
            
            // Content
            if !message.content.isEmpty {
                Text(message.content)
                    .padding()
                    .background(backgroundForStatus)
                    .cornerRadius(10)
            } else if case .streaming = message.status {
                StreamingPlaceholder()
            }
            
            // Retry info
            if let retryInfo = message.retryInfo {
                RetryInfoView(info: retryInfo)
            }
        }
    }
    
    var backgroundForStatus: Color {
        switch message.status {
        case .complete:
            return Color.gray.opacity(0.1)
        case .failed:
            return Color.red.opacity(0.05)
        case .partialSuccess:
            return Color.orange.opacity(0.05)
        default:
            return Color.gray.opacity(0.1)
        }
    }
}

struct MessageStatusBadge: View {
    let status: StreamRetryManager.RetryableMessage.MessageStatus
    
    var body: some View {
        Group {
            switch status {
            case .pending:
                Label("Pending", systemImage: "clock")
                    .foregroundColor(.gray)
            case .streaming:
                Label("Streaming", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundColor(.blue)
            case .complete:
                Label("Complete", systemImage: "checkmark")
                    .foregroundColor(.green)
            case .failed(let error):
                Label(error.type == .rateLimit ? "Rate Limited" : "Failed", 
                      systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            case .partialSuccess:
                Label("Partial", systemImage: "exclamationmark.circle")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption2)
    }
}

struct RetryInfoView: View {
    let info: StreamRetryManager.RetryableMessage.RetryInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if info.attempts > 0 {
                Label("\(info.attempts) retry attempts", systemImage: "arrow.clockwise")
            }
            
            if let partial = info.partialContent {
                Label("Saved \(partial.count) characters", systemImage: "square.and.arrow.down")
            }
            
            if !info.errors.isEmpty {
                Text("Errors: \(info.errors.map { $0.type.description }.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal)
    }
}

struct StreamingPlaceholder: View {
    @State private var dots = 0
    
    var body: some View {
        HStack {
            Text("Streaming" + String(repeating: ".", count: dots))
                .foregroundColor(.blue)
                .animation(.easeInOut, value: dots)
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dots = (dots + 1) % 4
            }
        }
    }
}

// Extensions
extension StreamRetryManager.RetryableMessage.StreamError.ErrorType {
    var description: String {
        switch self {
        case .network: return "Network"
        case .timeout: return "Timeout"
        case .rateLimit: return "Rate Limit"
        case .server: return "Server"
        case .unknown: return "Unknown"
        }
    }
}
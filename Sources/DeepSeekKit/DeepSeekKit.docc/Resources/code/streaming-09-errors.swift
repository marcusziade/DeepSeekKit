import SwiftUI
import DeepSeekKit

// Wrapping streaming in proper error handling
struct StreamingErrorHandlingView: View {
    @StateObject private var errorHandler = StreamingErrorHandler()
    @State private var userPrompt = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Streaming Error Handling")
                .font(.largeTitle)
                .bold()
            
            // Error display
            if let currentError = errorHandler.currentError {
                ErrorBanner(error: currentError, onDismiss: {
                    errorHandler.dismissError()
                })
            }
            
            // Stream content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !errorHandler.streamContent.isEmpty {
                        MessageContentView(
                            content: errorHandler.streamContent,
                            isComplete: !errorHandler.isStreaming,
                            hasError: errorHandler.hasError
                        )
                    }
                    
                    if errorHandler.isStreaming {
                        StreamingProgressView()
                    }
                }
                .padding()
            }
            
            // Error recovery options
            if errorHandler.hasRecoverableError {
                ErrorRecoveryView(handler: errorHandler)
            }
            
            // Input controls
            HStack {
                TextField("Enter your prompt", text: $userPrompt)
                    .textFieldStyle(.roundedBorder)
                
                Button("Send") {
                    Task {
                        await errorHandler.streamWithErrorHandling(prompt: userPrompt)
                    }
                }
                .disabled(userPrompt.isEmpty || errorHandler.isStreaming)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Comprehensive streaming error handler
@MainActor
class StreamingErrorHandler: ObservableObject {
    @Published var streamContent = ""
    @Published var isStreaming = false
    @Published var currentError: StreamError?
    @Published var hasError = false
    @Published var hasRecoverableError = false
    
    private let client = DeepSeekClient()
    private var lastPrompt: String?
    private var retryCount = 0
    private var streamTask: Task<Void, Never>?
    
    struct StreamError: Identifiable {
        let id = UUID()
        let type: ErrorType
        let message: String
        let timestamp = Date()
        let isRecoverable: Bool
        
        enum ErrorType {
            case network
            case authentication
            case rateLimit
            case timeout
            case serverError
            case unknown
        }
    }
    
    func streamWithErrorHandling(prompt: String) async {
        // Store prompt for retry
        lastPrompt = prompt
        resetState()
        isStreaming = true
        
        do {
            try await performStream(prompt: prompt)
        } catch {
            await handleStreamError(error)
        }
        
        isStreaming = false
    }
    
    private func performStream(prompt: String) async throws {
        var chunkCount = 0
        let timeoutTask = createTimeoutTask()
        
        defer {
            timeoutTask.cancel()
        }
        
        for try await chunk in client.streamMessage(prompt) {
            // Cancel timeout since we're receiving data
            if chunkCount == 0 {
                timeoutTask.cancel()
            }
            
            chunkCount += 1
            
            // Process chunk
            if let content = chunk.choices.first?.delta.content {
                streamContent += content
            }
            
            // Simulate potential mid-stream errors for demonstration
            if chunkCount == 10 && prompt.contains("error test") {
                throw DeepSeekError.networkError(URLError(.networkConnectionLost))
            }
        }
        
        // Success - clear any previous errors
        currentError = nil
        hasError = false
        retryCount = 0
    }
    
    private func createTimeoutTask() -> Task<Void, Never> {
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            if isStreaming && streamContent.isEmpty {
                await handleStreamError(DeepSeekError.networkError(URLError(.timedOut)))
            }
        }
    }
    
    private func handleStreamError(_ error: Error) async {
        hasError = true
        
        // Categorize error
        let streamError: StreamError
        
        switch error {
        case DeepSeekError.authenticationError:
            streamError = StreamError(
                type: .authentication,
                message: "Invalid API key. Please check your credentials.",
                isRecoverable: false
            )
            
        case DeepSeekError.rateLimitExceeded:
            streamError = StreamError(
                type: .rateLimit,
                message: "Rate limit exceeded. Please wait before retrying.",
                isRecoverable: true
            )
            
        case DeepSeekError.networkError(let networkError):
            let message = getNetworkErrorMessage(networkError)
            streamError = StreamError(
                type: .network,
                message: message,
                isRecoverable: true
            )
            
        case DeepSeekError.apiError(let code, let apiMessage):
            streamError = StreamError(
                type: code >= 500 ? .serverError : .unknown,
                message: apiMessage ?? "API error occurred (code: \(code))",
                isRecoverable: code >= 500
            )
            
        default:
            streamError = StreamError(
                type: .unknown,
                message: error.localizedDescription,
                isRecoverable: false
            )
        }
        
        currentError = streamError
        hasRecoverableError = streamError.isRecoverable
        
        // Add error indication to content if partial
        if !streamContent.isEmpty {
            streamContent += "\n\n[Stream interrupted due to error]"
        }
    }
    
    private func getNetworkErrorMessage(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection. Please check your network."
            case .timedOut:
                return "Request timed out. The server may be slow or unresponsive."
            case .networkConnectionLost:
                return "Network connection lost during streaming."
            case .cannotFindHost:
                return "Cannot connect to DeepSeek servers."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }
        return "Network error occurred"
    }
    
    func retry() {
        guard let prompt = lastPrompt, retryCount < 3 else { return }
        
        retryCount += 1
        Task {
            // Add exponential backoff
            let delay = UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000
            try? await Task.sleep(nanoseconds: delay)
            
            await streamWithErrorHandling(prompt: prompt)
        }
    }
    
    func dismissError() {
        currentError = nil
        hasRecoverableError = false
    }
    
    func cancelStream() {
        streamTask?.cancel()
        isStreaming = false
        streamContent += "\n[Cancelled by user]"
    }
    
    private func resetState() {
        streamContent = ""
        hasError = false
        currentError = nil
        hasRecoverableError = false
    }
}

// Error banner component
struct ErrorBanner: View {
    let error: StreamingErrorHandler.StreamError
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: errorIcon)
                .foregroundColor(errorColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(errorTitle)
                    .font(.headline)
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(errorColor.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(errorColor, lineWidth: 1)
        )
        .cornerRadius(10)
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    var errorIcon: String {
        switch error.type {
        case .network: return "wifi.exclamationmark"
        case .authentication: return "lock.fill"
        case .rateLimit: return "hourglass"
        case .timeout: return "clock.badge.exclamationmark"
        case .serverError: return "server.rack"
        case .unknown: return "exclamationmark.triangle"
        }
    }
    
    var errorTitle: String {
        switch error.type {
        case .network: return "Network Error"
        case .authentication: return "Authentication Failed"
        case .rateLimit: return "Rate Limited"
        case .timeout: return "Timeout"
        case .serverError: return "Server Error"
        case .unknown: return "Error"
        }
    }
    
    var errorColor: Color {
        switch error.type {
        case .authentication: return .red
        case .rateLimit: return .orange
        default: return .red
        }
    }
}

// Error recovery view
struct ErrorRecoveryView: View {
    @ObservedObject var handler: StreamingErrorHandler
    
    var body: some View {
        HStack {
            Text("Stream failed. Would you like to retry?")
                .font(.subheadline)
            
            Spacer()
            
            Button("Retry") {
                handler.retry()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") {
                handler.dismissError()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// Message content view
struct MessageContentView: View {
    let content: String
    let isComplete: Bool
    let hasError: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content)
                .textSelection(.enabled)
            
            if hasError {
                Label("Stream encountered an error", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if !isComplete {
                Label("Streaming...", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hasError ? Color.red.opacity(0.05) : Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// Streaming progress view
struct StreamingProgressView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}
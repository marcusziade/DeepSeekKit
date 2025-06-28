import SwiftUI
import DeepSeekKit

// Creating an error handler with recovery actions
struct ErrorHandlerView: View {
    @StateObject private var errorHandler = UniversalErrorHandler()
    @State private var testScenario = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Universal Error Handler")
                    .font(.largeTitle)
                    .bold()
                
                // Error handler status
                ErrorHandlerStatusView(handler: errorHandler)
                
                // Active errors
                if !errorHandler.activeErrors.isEmpty {
                    ActiveErrorsView(handler: errorHandler)
                }
                
                // Test controls
                ErrorTestControls(handler: errorHandler)
                
                // Recovery actions
                if let currentError = errorHandler.currentError {
                    RecoveryActionsView(
                        error: currentError,
                        handler: errorHandler
                    )
                }
                
                // Error log
                ErrorLogView(errors: errorHandler.errorHistory)
            }
            .padding()
        }
        .alert("Error Resolved", isPresented: $errorHandler.showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text(errorHandler.successMessage)
        }
    }
}

// Universal error handler with recovery actions
@MainActor
class UniversalErrorHandler: ObservableObject {
    @Published var currentError: HandledError?
    @Published var activeErrors: [HandledError] = []
    @Published var errorHistory: [ErrorLogEntry] = []
    @Published var isRecovering = false
    @Published var showSuccessAlert = false
    @Published var successMessage = ""
    
    private let client = DeepSeekClient()
    private var recoveryTasks: [UUID: Task<Void, Never>] = [:]
    
    struct HandledError: Identifiable {
        let id = UUID()
        let error: DeepSeekError
        let context: ErrorContext
        let timestamp = Date()
        var status: ErrorStatus = .active
        let recoveryActions: [RecoveryAction]
        
        enum ErrorStatus {
            case active
            case recovering
            case resolved
            case failed
        }
    }
    
    struct ErrorContext {
        let operation: String
        let requestDetails: [String: String]
        let userMessage: String?
    }
    
    struct RecoveryAction: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let icon: String
        let action: () async -> Bool
    }
    
    struct ErrorLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let error: String
        let resolution: String?
        let duration: TimeInterval?
    }
    
    func handleError(_ error: Error, context: ErrorContext) {
        guard let deepSeekError = error as? DeepSeekError else { return }
        
        let handledError = HandledError(
            error: deepSeekError,
            context: context,
            recoveryActions: getRecoveryActions(for: deepSeekError, context: context)
        )
        
        currentError = handledError
        activeErrors.append(handledError)
        
        // Log the error
        logError(handledError)
    }
    
    private func getRecoveryActions(for error: DeepSeekError, context: ErrorContext) -> [RecoveryAction] {
        var actions: [RecoveryAction] = []
        
        switch error {
        case .authenticationError:
            actions.append(RecoveryAction(
                name: "Update API Key",
                description: "Enter a new API key",
                icon: "key.fill",
                action: { await self.updateAPIKey() }
            ))
            
        case .rateLimitExceeded:
            actions.append(RecoveryAction(
                name: "Wait and Retry",
                description: "Wait for rate limit reset",
                icon: "clock.arrow.circlepath",
                action: { await self.waitAndRetry(context: context) }
            ))
            actions.append(RecoveryAction(
                name: "Use Cached Response",
                description: "Return cached data if available",
                icon: "archivebox",
                action: { await self.useCachedResponse(context: context) }
            ))
            
        case .networkError:
            actions.append(RecoveryAction(
                name: "Retry Request",
                description: "Try the request again",
                icon: "arrow.clockwise",
                action: { await self.retryRequest(context: context) }
            ))
            actions.append(RecoveryAction(
                name: "Check Connection",
                description: "Verify network settings",
                icon: "wifi",
                action: { await self.checkConnection() }
            ))
            
        case .apiError(let code, _):
            if code >= 500 {
                actions.append(RecoveryAction(
                    name: "Retry with Backoff",
                    description: "Retry with exponential backoff",
                    icon: "timer",
                    action: { await self.retryWithBackoff(context: context) }
                ))
            } else {
                actions.append(RecoveryAction(
                    name: "Fix Request",
                    description: "Review and fix request parameters",
                    icon: "wrench",
                    action: { await self.fixRequest(context: context) }
                ))
            }
            
        default:
            actions.append(RecoveryAction(
                name: "Report Issue",
                description: "Send error report",
                icon: "exclamationmark.bubble",
                action: { await self.reportIssue(error: error, context: context) }
            ))
        }
        
        // Always add dismiss action
        actions.append(RecoveryAction(
            name: "Dismiss",
            description: "Ignore this error",
            icon: "xmark.circle",
            action: { self.dismissError(); return true }
        ))
        
        return actions
    }
    
    func executeRecoveryAction(_ action: RecoveryAction, for error: HandledError) {
        guard let index = activeErrors.firstIndex(where: { $0.id == error.id }) else { return }
        
        activeErrors[index].status = .recovering
        isRecovering = true
        
        let task = Task {
            let success = await action.action()
            
            await MainActor.run {
                if success {
                    self.activeErrors[index].status = .resolved
                    self.showSuccess(message: "\(action.name) completed successfully")
                    self.removeError(error)
                } else {
                    self.activeErrors[index].status = .failed
                }
                self.isRecovering = false
            }
        }
        
        recoveryTasks[error.id] = task
    }
    
    // Recovery action implementations
    private func updateAPIKey() async -> Bool {
        // In real app, show API key input
        await Task.sleep(nanoseconds: 2_000_000_000)
        return true
    }
    
    private func waitAndRetry(context: ErrorContext) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            return await retryRequest(context: context)
        } catch {
            return false
        }
    }
    
    private func useCachedResponse(context: ErrorContext) async -> Bool {
        // Check cache for response
        await Task.sleep(nanoseconds: 500_000_000)
        return Bool.random() // Simulate cache hit/miss
    }
    
    private func retryRequest(context: ErrorContext) async -> Bool {
        do {
            _ = try await client.sendMessage(context.userMessage ?? "Test")
            return true
        } catch {
            return false
        }
    }
    
    private func checkConnection() async -> Bool {
        // Check network connectivity
        await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }
    
    private func retryWithBackoff(context: ErrorContext) async -> Bool {
        for attempt in 1...3 {
            let delay = pow(2.0, Double(attempt - 1)) * 2.0
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            do {
                _ = try await client.sendMessage(context.userMessage ?? "Test")
                return true
            } catch {
                continue
            }
        }
        return false
    }
    
    private func fixRequest(context: ErrorContext) async -> Bool {
        // In real app, show request editor
        await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }
    
    private func reportIssue(error: DeepSeekError, context: ErrorContext) async -> Bool {
        // Send error report
        print("Error reported: \(error)")
        await Task.sleep(nanoseconds: 500_000_000)
        return true
    }
    
    private func dismissError() {
        if let error = currentError {
            removeError(error)
        }
    }
    
    private func removeError(_ error: HandledError) {
        activeErrors.removeAll { $0.id == error.id }
        if currentError?.id == error.id {
            currentError = activeErrors.last
        }
        recoveryTasks[error.id]?.cancel()
        recoveryTasks.removeValue(forKey: error.id)
    }
    
    private func showSuccess(message: String) {
        successMessage = message
        showSuccessAlert = true
    }
    
    private func logError(_ error: HandledError) {
        let entry = ErrorLogEntry(
            timestamp: error.timestamp,
            error: "\(error.error)",
            resolution: nil,
            duration: nil
        )
        errorHistory.insert(entry, at: 0)
    }
    
    // Test methods
    func simulateAuthError() {
        let context = ErrorContext(
            operation: "sendMessage",
            requestDetails: ["endpoint": "/v1/chat/completions"],
            userMessage: "Test message"
        )
        handleError(DeepSeekError.authenticationError, context: context)
    }
    
    func simulateNetworkError() {
        let context = ErrorContext(
            operation: "streamMessage",
            requestDetails: ["model": "deepseek-chat"],
            userMessage: "Stream test"
        )
        handleError(DeepSeekError.networkError(URLError(.notConnectedToInternet)), context: context)
    }
    
    func simulateRateLimit() {
        let context = ErrorContext(
            operation: "batchRequests",
            requestDetails: ["count": "100"],
            userMessage: nil
        )
        handleError(DeepSeekError.rateLimitExceeded, context: context)
    }
}

// UI Components
struct ErrorHandlerStatusView: View {
    @ObservedObject var handler: UniversalErrorHandler
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Error Handler Status")
                    .font(.headline)
                Text("\(handler.activeErrors.count) active errors")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if handler.isRecovering {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Recovering...")
                        .font(.caption)
                }
            } else if handler.activeErrors.isEmpty {
                Label("All Clear", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ActiveErrorsView: View {
    @ObservedObject var handler: UniversalErrorHandler
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Errors")
                .font(.headline)
            
            ForEach(handler.activeErrors) { error in
                ActiveErrorCard(error: error, handler: handler)
            }
        }
    }
}

struct ActiveErrorCard: View {
    let error: UniversalErrorHandler.HandledError
    @ObservedObject var handler: UniversalErrorHandler
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                statusIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(error.context.operation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // Expanded content
            if isExpanded {
                Divider()
                
                // Error details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(error.context.requestDetails), id: \.key) { key, value in
                        HStack {
                            Text("\(key):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(value)
                                .font(.caption)
                                .fontFamily(.monospaced)
                        }
                    }
                }
                
                // Recovery actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recovery Actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(error.recoveryActions) { action in
                        RecoveryActionButton(
                            action: action,
                            isDisabled: error.status == .recovering
                        ) {
                            handler.executeRecoveryAction(action, for: error)
                        }
                    }
                }
            }
        }
        .padding()
        .background(backgroundForStatus)
        .cornerRadius(12)
    }
    
    var statusIcon: some View {
        Group {
            switch error.status {
            case .active:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            case .recovering:
                ProgressView()
                    .scaleEffect(0.8)
            case .resolved:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
    }
    
    var errorTitle: String {
        switch error.error {
        case .authenticationError:
            return "Authentication Error"
        case .rateLimitExceeded:
            return "Rate Limit Exceeded"
        case .networkError:
            return "Network Error"
        case .apiError(let code, _):
            return "API Error (\(code))"
        default:
            return "Unknown Error"
        }
    }
    
    var backgroundForStatus: Color {
        switch error.status {
        case .active:
            return Color.red.opacity(0.05)
        case .recovering:
            return Color.blue.opacity(0.05)
        case .resolved:
            return Color.green.opacity(0.05)
        case .failed:
            return Color.orange.opacity(0.05)
        }
    }
}

struct RecoveryActionButton: View {
    let action: UniversalErrorHandler.RecoveryAction
    let isDisabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: action.icon)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(action.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .disabled(isDisabled)
    }
}

struct ErrorTestControls: View {
    @ObservedObject var handler: UniversalErrorHandler
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Error Scenarios")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button("Auth Error") {
                    handler.simulateAuthError()
                }
                .buttonStyle(.bordered)
                
                Button("Network Error") {
                    handler.simulateNetworkError()
                }
                .buttonStyle(.bordered)
                
                Button("Rate Limit") {
                    handler.simulateRateLimit()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RecoveryActionsView: View {
    let error: UniversalErrorHandler.HandledError
    @ObservedObject var handler: UniversalErrorHandler
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Recovery Actions")
                .font(.headline)
            
            ForEach(error.recoveryActions) { action in
                RecoveryActionCard(action: action) {
                    handler.executeRecoveryAction(action, for: error)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RecoveryActionCard: View {
    let action: UniversalErrorHandler.RecoveryAction
    let onExecute: () -> Void
    
    var body: some View {
        Button(action: onExecute) {
            HStack(spacing: 16) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(action.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ErrorLogView: View {
    let errors: [UniversalErrorHandler.ErrorLogEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Log")
                .font(.headline)
            
            if errors.isEmpty {
                Text("No errors logged")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(errors.prefix(5)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(entry.error)
                                .font(.caption)
                                .lineLimit(1)
                            
                            if let resolution = entry.resolution {
                                Text(resolution)
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Spacer()
                        
                        if let duration = entry.duration {
                            Text("\(String(format: "%.1f", duration))s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}
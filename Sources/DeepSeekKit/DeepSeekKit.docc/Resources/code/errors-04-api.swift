import SwiftUI
import DeepSeekKit

// Handling API-specific errors with error codes
struct APIErrorHandlingView: View {
    @StateObject private var apiErrorHandler = APIErrorHandler()
    @State private var selectedScenario: ErrorScenario = .serverError
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("API Error Handling")
                    .font(.largeTitle)
                    .bold()
                
                // Error scenario selector
                ErrorScenarioSelector(selectedScenario: $selectedScenario)
                
                // Current error display
                if let currentError = apiErrorHandler.currentError {
                    CurrentErrorView(error: currentError)
                }
                
                // Error simulation
                ErrorSimulationView(
                    handler: apiErrorHandler,
                    scenario: selectedScenario
                )
                
                // Error code reference
                ErrorCodeReferenceView()
                
                // Recovery strategies
                RecoveryStrategiesView(handler: apiErrorHandler)
            }
            .padding()
        }
    }
}

// Error scenarios
enum ErrorScenario: String, CaseIterable {
    case serverError = "Server Error (5xx)"
    case badRequest = "Bad Request (400)"
    case forbidden = "Forbidden (403)"
    case notFound = "Not Found (404)"
    case conflict = "Conflict (409)"
    case tooManyRequests = "Too Many Requests (429)"
    case serviceUnavailable = "Service Unavailable (503)"
    
    var statusCode: Int {
        switch self {
        case .serverError: return 500
        case .badRequest: return 400
        case .forbidden: return 403
        case .notFound: return 404
        case .conflict: return 409
        case .tooManyRequests: return 429
        case .serviceUnavailable: return 503
        }
    }
    
    var errorMessage: String {
        switch self {
        case .serverError:
            return "Internal server error. Please try again later."
        case .badRequest:
            return "Invalid request format or parameters."
        case .forbidden:
            return "Access forbidden. Check your permissions."
        case .notFound:
            return "The requested resource was not found."
        case .conflict:
            return "Request conflicts with current server state."
        case .tooManyRequests:
            return "Rate limit exceeded. Please slow down."
        case .serviceUnavailable:
            return "Service temporarily unavailable."
        }
    }
}

// API error handler
@MainActor
class APIErrorHandler: ObservableObject {
    @Published var currentError: APIError?
    @Published var errorHistory: [APIError] = []
    @Published var isRetrying = false
    @Published var retryAttempts = 0
    @Published var successfulRecoveries = 0
    
    private let client = DeepSeekClient()
    
    struct APIError: Identifiable {
        let id = UUID()
        let statusCode: Int
        let message: String
        let details: ErrorDetails?
        let timestamp = Date()
        let isRecoverable: Bool
        let suggestedAction: String
        
        struct ErrorDetails {
            let errorCode: String?
            let requestId: String?
            let documentation: String?
            let context: [String: Any]?
        }
    }
    
    func simulateError(scenario: ErrorScenario) async {
        // Create simulated error
        let error = createAPIError(for: scenario)
        currentError = error
        errorHistory.insert(error, at: 0)
        
        // Attempt recovery if applicable
        if error.isRecoverable {
            await attemptRecovery(for: error)
        }
    }
    
    private func createAPIError(for scenario: ErrorScenario) -> APIError {
        let details = APIError.ErrorDetails(
            errorCode: "ERR_\(scenario.statusCode)",
            requestId: UUID().uuidString,
            documentation: "https://platform.deepseek.com/docs/errors#\(scenario.statusCode)",
            context: [
                "endpoint": "/v1/chat/completions",
                "model": "deepseek-chat",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
        
        return APIError(
            statusCode: scenario.statusCode,
            message: scenario.errorMessage,
            details: details,
            isRecoverable: isErrorRecoverable(statusCode: scenario.statusCode),
            suggestedAction: getSuggestedAction(for: scenario)
        )
    }
    
    private func isErrorRecoverable(statusCode: Int) -> Bool {
        switch statusCode {
        case 500...599: // Server errors
            return true
        case 429: // Rate limit
            return true
        case 408: // Timeout
            return true
        case 502, 503, 504: // Gateway errors
            return true
        default:
            return false
        }
    }
    
    private func getSuggestedAction(for scenario: ErrorScenario) -> String {
        switch scenario {
        case .serverError:
            return "Retry with exponential backoff"
        case .badRequest:
            return "Review and fix request parameters"
        case .forbidden:
            return "Check API key permissions"
        case .notFound:
            return "Verify endpoint and resource ID"
        case .conflict:
            return "Resolve state conflict and retry"
        case .tooManyRequests:
            return "Wait for rate limit reset"
        case .serviceUnavailable:
            return "Wait and retry in a few minutes"
        }
    }
    
    func attemptRecovery(for error: APIError) async {
        isRetrying = true
        retryAttempts = 0
        
        for attempt in 1...3 {
            retryAttempts = attempt
            
            // Exponential backoff
            let delay = pow(2.0, Double(attempt - 1)) * 2.0
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Simulate recovery attempt
            if Bool.random() && attempt > 1 { // Higher chance of success with more attempts
                successfulRecoveries += 1
                currentError = nil
                break
            }
        }
        
        isRetrying = false
    }
    
    func handleRealAPIError(_ error: Error) -> APIError? {
        if case DeepSeekError.apiError(let code, let message) = error {
            return APIError(
                statusCode: code,
                message: message ?? "Unknown API error",
                details: nil,
                isRecoverable: isErrorRecoverable(statusCode: code),
                suggestedAction: getActionForStatusCode(code)
            )
        }
        return nil
    }
    
    private func getActionForStatusCode(_ code: Int) -> String {
        switch code {
        case 400:
            return "Check your request parameters"
        case 401:
            return "Verify your API key"
        case 403:
            return "Check your account permissions"
        case 404:
            return "Verify the endpoint URL"
        case 429:
            return "Implement rate limiting"
        case 500...599:
            return "Retry with backoff"
        default:
            return "Check the API documentation"
        }
    }
}

// UI Components
struct ErrorScenarioSelector: View {
    @Binding var selectedScenario: ErrorScenario
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Error Scenario")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ErrorScenario.allCases, id: \.self) { scenario in
                    ErrorScenarioCard(
                        scenario: scenario,
                        isSelected: selectedScenario == scenario,
                        action: { selectedScenario = scenario }
                    )
                }
            }
        }
    }
}

struct ErrorScenarioCard: View {
    let scenario: ErrorScenario
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("\(scenario.statusCode)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(scenario.rawValue)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? errorColor : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
    }
    
    var errorColor: Color {
        switch scenario.statusCode {
        case 400...499:
            return .orange
        case 500...599:
            return .red
        default:
            return .gray
        }
    }
}

struct CurrentErrorView: View {
    let error: APIErrorHandler.APIError
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.title)
                    .foregroundColor(errorColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("HTTP \(error.statusCode)")
                        .font(.headline)
                    Text(error.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if error.isRecoverable {
                    Label("Recoverable", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Text(error.message)
                .font(.subheadline)
            
            // Error details
            if let details = error.details {
                ErrorDetailsBox(details: details)
            }
            
            // Suggested action
            Label(error.suggestedAction, systemImage: "lightbulb")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
    }
    
    var errorColor: Color {
        switch error.statusCode {
        case 400...499:
            return .orange
        case 500...599:
            return .red
        default:
            return .gray
        }
    }
}

struct ErrorDetailsBox: View {
    let details: APIErrorHandler.APIError.ErrorDetails
    
    var body: some View {
        GroupBox("Error Details") {
            VStack(alignment: .leading, spacing: 8) {
                if let errorCode = details.errorCode {
                    DetailRow(label: "Error Code", value: errorCode)
                }
                
                if let requestId = details.requestId {
                    DetailRow(label: "Request ID", value: requestId)
                        .textSelection(.enabled)
                }
                
                if let documentation = details.documentation {
                    HStack {
                        Text("Documentation:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Link("View Docs", destination: URL(string: documentation)!)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontFamily(.monospaced)
        }
    }
}

struct ErrorSimulationView: View {
    @ObservedObject var handler: APIErrorHandler
    let scenario: ErrorScenario
    
    var body: some View {
        VStack(spacing: 12) {
            Button("Simulate \(scenario.rawValue)") {
                Task {
                    await handler.simulateError(scenario: scenario)
                }
            }
            .buttonStyle(.borderedProminent)
            
            if handler.isRetrying {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Retrying... Attempt \(handler.retryAttempts) of 3")
                        .font(.caption)
                }
            }
            
            // Statistics
            HStack(spacing: 20) {
                StatisticView(
                    value: "\(handler.errorHistory.count)",
                    label: "Total Errors"
                )
                
                StatisticView(
                    value: "\(handler.successfulRecoveries)",
                    label: "Recovered"
                )
                
                let recoveryRate = handler.errorHistory.isEmpty ? 0 :
                    Double(handler.successfulRecoveries) / Double(handler.errorHistory.count) * 100
                
                StatisticView(
                    value: String(format: "%.0f%%", recoveryRate),
                    label: "Recovery Rate"
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct StatisticView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorCodeReferenceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common API Error Codes")
                .font(.headline)
            
            VStack(spacing: 8) {
                ErrorCodeRow(code: 400, name: "Bad Request", description: "Invalid request syntax or parameters")
                ErrorCodeRow(code: 401, name: "Unauthorized", description: "Missing or invalid authentication")
                ErrorCodeRow(code: 403, name: "Forbidden", description: "Valid request but refused by server")
                ErrorCodeRow(code: 404, name: "Not Found", description: "Resource doesn't exist")
                ErrorCodeRow(code: 429, name: "Too Many Requests", description: "Rate limit exceeded")
                ErrorCodeRow(code: 500, name: "Internal Server Error", description: "Server encountered an error")
                ErrorCodeRow(code: 502, name: "Bad Gateway", description: "Invalid response from upstream")
                ErrorCodeRow(code: 503, name: "Service Unavailable", description: "Server temporarily unavailable")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ErrorCodeRow: View {
    let code: Int
    let name: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text("\(code)")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .frame(width: 40, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct RecoveryStrategiesView: View {
    @ObservedObject var handler: APIErrorHandler
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recovery Strategies", systemImage: "heart.text.square")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                RecoveryStrategy(
                    title: "Exponential Backoff",
                    description: "Increase delay between retries: 2s, 4s, 8s...",
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                RecoveryStrategy(
                    title: "Circuit Breaker",
                    description: "Stop requests after repeated failures",
                    icon: "powerplug.fill"
                )
                
                RecoveryStrategy(
                    title: "Fallback Response",
                    description: "Use cached or default responses",
                    icon: "arrow.uturn.backward"
                )
                
                RecoveryStrategy(
                    title: "Request Queuing",
                    description: "Queue and retry failed requests",
                    icon: "tray.full"
                )
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RecoveryStrategy: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.green)
                .frame(width: 24)
            
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
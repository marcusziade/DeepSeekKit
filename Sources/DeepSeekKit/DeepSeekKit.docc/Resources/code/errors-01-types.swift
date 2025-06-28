import SwiftUI
import DeepSeekKit

// Exploring the DeepSeekError enum cases
struct ErrorTypesView: View {
    @StateObject private var errorDemo = ErrorDemonstrator()
    @State private var selectedErrorType: ErrorType = .none
    
    var body: some View {
        VStack(spacing: 20) {
            Text("DeepSeekError Types")
                .font(.largeTitle)
                .bold()
            
            // Error type selector
            Picker("Error Type", selection: $selectedErrorType) {
                ForEach(ErrorType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Error demonstration
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ErrorTypeExplanation(errorType: selectedErrorType)
                    
                    if selectedErrorType != .none {
                        Button("Trigger \(selectedErrorType.rawValue) Error") {
                            Task {
                                await errorDemo.triggerError(type: selectedErrorType)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    // Error display
                    if let error = errorDemo.lastError {
                        ErrorDetailsView(error: error)
                    }
                    
                    // Response display
                    if let response = errorDemo.lastResponse {
                        ResponseView(response: response)
                    }
                }
                .padding()
            }
        }
    }
}

// Error types enumeration
enum ErrorType: String, CaseIterable {
    case none = "None"
    case authentication = "Authentication"
    case rateLimit = "Rate Limit"
    case network = "Network"
    case apiError = "API Error"
    case invalidRequest = "Invalid Request"
    case timeout = "Timeout"
}

// Error demonstrator
@MainActor
class ErrorDemonstrator: ObservableObject {
    @Published var lastError: DeepSeekError?
    @Published var lastResponse: String?
    @Published var isLoading = false
    
    private let client = DeepSeekClient()
    
    func triggerError(type: ErrorType) async {
        isLoading = true
        lastError = nil
        lastResponse = nil
        
        do {
            switch type {
            case .none:
                break
                
            case .authentication:
                // Trigger authentication error
                try await triggerAuthenticationError()
                
            case .rateLimit:
                // Simulate rate limit
                try await triggerRateLimitError()
                
            case .network:
                // Simulate network error
                try await triggerNetworkError()
                
            case .apiError:
                // Trigger API error
                try await triggerAPIError()
                
            case .invalidRequest:
                // Trigger invalid request
                try await triggerInvalidRequestError()
                
            case .timeout:
                // Trigger timeout
                try await triggerTimeoutError()
            }
        } catch let error as DeepSeekError {
            lastError = error
        } catch {
            lastResponse = "Unexpected error: \(error)"
        }
        
        isLoading = false
    }
    
    private func triggerAuthenticationError() async throws {
        // Create client with invalid API key
        let invalidClient = DeepSeekClient(apiKey: "invalid_key_12345")
        
        _ = try await invalidClient.sendMessage("Test message")
    }
    
    private func triggerRateLimitError() async throws {
        // In real scenario, this would happen after too many requests
        // For demo, we'll simulate it
        throw DeepSeekError.rateLimitExceeded
    }
    
    private func triggerNetworkError() async throws {
        // Simulate network error
        throw DeepSeekError.networkError(URLError(.notConnectedToInternet))
    }
    
    private func triggerAPIError() async throws {
        // Simulate API error
        throw DeepSeekError.apiError(
            statusCode: 500,
            message: "Internal server error occurred while processing your request"
        )
    }
    
    private func triggerInvalidRequestError() async throws {
        // Send invalid request
        let request = ChatCompletionRequest(
            model: .deepseekChat,
            messages: [], // Empty messages array is invalid
            temperature: 3.0 // Invalid temperature (should be 0-2)
        )
        
        _ = try await client.sendChatCompletion(request)
    }
    
    private func triggerTimeoutError() async throws {
        // Simulate timeout
        throw DeepSeekError.networkError(URLError(.timedOut))
    }
}

// UI Components
struct ErrorTypeExplanation: View {
    let errorType: ErrorType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForErrorType)
                    .font(.title2)
                    .foregroundColor(colorForErrorType)
                
                Text(errorType.rawValue)
                    .font(.title2)
                    .bold()
            }
            
            Text(descriptionForErrorType)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Code example
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to handle:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(codeExampleForErrorType)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
    }
    
    var iconForErrorType: String {
        switch errorType {
        case .none: return "checkmark.circle"
        case .authentication: return "lock.fill"
        case .rateLimit: return "hourglass"
        case .network: return "wifi.exclamationmark"
        case .apiError: return "server.rack"
        case .invalidRequest: return "exclamationmark.square"
        case .timeout: return "clock.badge.exclamationmark"
        }
    }
    
    var colorForErrorType: Color {
        switch errorType {
        case .none: return .green
        case .authentication: return .red
        case .rateLimit: return .orange
        case .network: return .blue
        case .apiError: return .purple
        case .invalidRequest: return .yellow
        case .timeout: return .gray
        }
    }
    
    var descriptionForErrorType: String {
        switch errorType {
        case .none:
            return "No error - everything is working correctly."
        case .authentication:
            return "Occurs when the API key is invalid, missing, or has been revoked. This requires user action to provide a valid key."
        case .rateLimit:
            return "Happens when you exceed the API's rate limits. Wait before retrying or implement exponential backoff."
        case .network:
            return "Network-related errors like no internet connection, DNS failures, or connection timeouts."
        case .apiError:
            return "Server-side errors with status codes and messages. May be temporary (5xx) or client errors (4xx)."
        case .invalidRequest:
            return "The request parameters are invalid - wrong model, invalid temperature, empty messages, etc."
        case .timeout:
            return "Request took too long to complete. Can happen with slow network or long responses."
        }
    }
    
    var codeExampleForErrorType: String {
        switch errorType {
        case .none:
            return "// Success case\nlet response = try await client.sendMessage(\"Hello\")"
        case .authentication:
            return """
            catch DeepSeekError.authenticationError {
                // Prompt user for valid API key
                showAPIKeyAlert()
            }
            """
        case .rateLimit:
            return """
            catch DeepSeekError.rateLimitExceeded {
                // Wait and retry with backoff
                await Task.sleep(nanoseconds: 60_000_000_000)
                return try await retry()
            }
            """
        case .network:
            return """
            catch DeepSeekError.networkError(let error) {
                if (error as? URLError)?.code == .notConnectedToInternet {
                    showOfflineMessage()
                }
            }
            """
        case .apiError:
            return """
            catch DeepSeekError.apiError(let code, let message) {
                if code >= 500 {
                    // Server error - retry
                    return try await retry()
                } else {
                    // Client error - fix request
                    print("Error \\(code): \\(message ?? "")")
                }
            }
            """
        case .invalidRequest:
            return """
            catch DeepSeekError.invalidRequest(let message) {
                // Fix the request parameters
                print("Invalid request: \\(message)")
            }
            """
        case .timeout:
            return """
            catch DeepSeekError.networkError(let error) {
                if (error as? URLError)?.code == .timedOut {
                    // Retry with longer timeout
                    return try await retryWithTimeout(120)
                }
            }
            """
        }
    }
}

struct ErrorDetailsView: View {
    let error: DeepSeekError
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Error Details", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.red)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    // Error type
                    HStack {
                        Text("Type:")
                            .fontWeight(.semibold)
                        Text(errorTypeName)
                    }
                    
                    // Error description
                    HStack(alignment: .top) {
                        Text("Description:")
                            .fontWeight(.semibold)
                        Text(error.localizedDescription)
                    }
                    
                    // Additional info
                    if let additionalInfo = errorAdditionalInfo {
                        HStack(alignment: .top) {
                            Text("Details:")
                                .fontWeight(.semibold)
                            Text(additionalInfo)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    // Recovery suggestion
                    HStack(alignment: .top) {
                        Text("Recovery:")
                            .fontWeight(.semibold)
                        Text(recoverySuggestion)
                            .foregroundColor(.blue)
                    }
                }
                .font(.caption)
            }
        }
    }
    
    var errorTypeName: String {
        switch error {
        case .authenticationError:
            return "Authentication Error"
        case .rateLimitExceeded:
            return "Rate Limit Exceeded"
        case .networkError:
            return "Network Error"
        case .apiError:
            return "API Error"
        case .invalidRequest:
            return "Invalid Request"
        case .invalidResponse:
            return "Invalid Response"
        case .streamError:
            return "Stream Error"
        }
    }
    
    var errorAdditionalInfo: String? {
        switch error {
        case .networkError(let underlyingError):
            return "Underlying: \(underlyingError)"
        case .apiError(let code, let message):
            return "Status: \(code)\nMessage: \(message ?? "No message")"
        case .invalidRequest(let details):
            return details
        case .invalidResponse(let details):
            return details
        case .streamError(let details):
            return details
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String {
        switch error {
        case .authenticationError:
            return "Check your API key in settings"
        case .rateLimitExceeded:
            return "Wait a minute before retrying"
        case .networkError:
            return "Check your internet connection"
        case .apiError(let code, _):
            return code >= 500 ? "Retry in a few seconds" : "Check your request parameters"
        case .invalidRequest:
            return "Review and fix request parameters"
        case .invalidResponse:
            return "Contact support if this persists"
        case .streamError:
            return "Try non-streaming request instead"
        }
    }
}

struct ResponseView: View {
    let response: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Response", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            Text(response)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
        }
    }
}
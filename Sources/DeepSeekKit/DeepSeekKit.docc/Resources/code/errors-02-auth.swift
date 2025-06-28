import SwiftUI
import DeepSeekKit

// Handling authentication errors
struct AuthenticationErrorView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var testMessage = "Hello, can you help me with Swift?"
    @State private var showAPIKeyInput = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Authentication Error Handling")
                .font(.largeTitle)
                .bold()
            
            // API Key Status
            APIKeyStatusView(manager: authManager)
            
            // Test authentication
            VStack(alignment: .leading, spacing: 16) {
                Text("Test Authentication")
                    .font(.headline)
                
                TextField("Test message", text: $testMessage)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Button("Test Current Key") {
                        Task {
                            await authManager.testCurrentKey(with: testMessage)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test Invalid Key") {
                        Task {
                            await authManager.testInvalidKey(with: testMessage)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test Missing Key") {
                        Task {
                            await authManager.testMissingKey(with: testMessage)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Error display
            if let error = authManager.lastError {
                AuthErrorDetailView(error: error, onResolve: {
                    showAPIKeyInput = true
                })
            }
            
            // Success display
            if let response = authManager.lastSuccessResponse {
                SuccessResponseView(response: response)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showAPIKeyInput) {
            APIKeyInputSheet(manager: authManager)
        }
        .onAppear {
            authManager.checkAPIKeyStatus()
        }
    }
}

// Authentication manager
@MainActor
class AuthenticationManager: ObservableObject {
    @Published var apiKeyStatus: APIKeyStatus = .checking
    @Published var lastError: AuthError?
    @Published var lastSuccessResponse: String?
    @Published var isLoading = false
    
    private var currentAPIKey: String?
    
    enum APIKeyStatus {
        case checking
        case valid(maskedKey: String)
        case invalid
        case missing
    }
    
    struct AuthError: Identifiable {
        let id = UUID()
        let type: ErrorType
        let message: String
        let timestamp = Date()
        let suggestion: String
        
        enum ErrorType {
            case invalidKey
            case missingKey
            case expiredKey
            case revokedKey
            case networkError
        }
    }
    
    func checkAPIKeyStatus() {
        // Check if API key exists
        if let apiKey = getStoredAPIKey() {
            currentAPIKey = apiKey
            let masked = maskAPIKey(apiKey)
            apiKeyStatus = .valid(maskedKey: masked)
        } else {
            apiKeyStatus = .missing
        }
    }
    
    func testCurrentKey(with message: String) async {
        guard let apiKey = currentAPIKey else {
            lastError = AuthError(
                type: .missingKey,
                message: "No API key configured",
                suggestion: "Please add your DeepSeek API key"
            )
            return
        }
        
        await performAuthTest(apiKey: apiKey, message: message)
    }
    
    func testInvalidKey(with message: String) async {
        let invalidKey = "sk-invalid-key-12345"
        await performAuthTest(apiKey: invalidKey, message: message, expectFailure: true)
    }
    
    func testMissingKey(with message: String) async {
        await performAuthTest(apiKey: "", message: message, expectFailure: true)
    }
    
    private func performAuthTest(apiKey: String, message: String, expectFailure: Bool = false) async {
        isLoading = true
        lastError = nil
        lastSuccessResponse = nil
        
        do {
            let client = DeepSeekClient(apiKey: apiKey)
            let response = try await client.sendMessage(message)
            
            if expectFailure {
                lastError = AuthError(
                    type: .networkError,
                    message: "Expected authentication to fail but it succeeded",
                    suggestion: "This might indicate a test configuration issue"
                )
            } else {
                lastSuccessResponse = response.choices.first?.message.content ?? "Empty response"
                apiKeyStatus = .valid(maskedKey: maskAPIKey(apiKey))
            }
        } catch DeepSeekError.authenticationError {
            handleAuthenticationError(apiKey: apiKey)
        } catch {
            lastError = AuthError(
                type: .networkError,
                message: "Unexpected error: \(error.localizedDescription)",
                suggestion: "Check your network connection and try again"
            )
        }
        
        isLoading = false
    }
    
    private func handleAuthenticationError(apiKey: String) {
        if apiKey.isEmpty {
            lastError = AuthError(
                type: .missingKey,
                message: "API key is required but not provided",
                suggestion: "Add your DeepSeek API key to continue"
            )
            apiKeyStatus = .missing
        } else if apiKey.starts(with: "sk-invalid") || apiKey.count < 20 {
            lastError = AuthError(
                type: .invalidKey,
                message: "The provided API key is invalid",
                suggestion: "Check your API key for typos or get a new one from DeepSeek"
            )
            apiKeyStatus = .invalid
        } else if apiKey.contains("expired") {
            lastError = AuthError(
                type: .expiredKey,
                message: "Your API key has expired",
                suggestion: "Generate a new API key from your DeepSeek dashboard"
            )
            apiKeyStatus = .invalid
        } else {
            lastError = AuthError(
                type: .revokedKey,
                message: "Your API key may have been revoked or is incorrect",
                suggestion: "Verify your API key in the DeepSeek dashboard"
            )
            apiKeyStatus = .invalid
        }
    }
    
    func updateAPIKey(_ newKey: String) {
        currentAPIKey = newKey
        storeAPIKey(newKey)
        checkAPIKeyStatus()
        
        // Clear any previous errors
        lastError = nil
        lastSuccessResponse = nil
    }
    
    private func getStoredAPIKey() -> String? {
        // In production, use Keychain
        return ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]
    }
    
    private func storeAPIKey(_ key: String) {
        // In production, store in Keychain
        print("API key would be stored securely")
    }
    
    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return "***" }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}

// UI Components
struct APIKeyStatusView: View {
    @ObservedObject var manager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("API Key Status", systemImage: "key.fill")
                .font(.headline)
            
            HStack {
                statusIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.subheadline)
                    if case .valid(let maskedKey) = manager.apiKeyStatus {
                        Text(maskedKey)
                            .font(.caption)
                            .fontFamily(.monospaced)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                if manager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(statusBackground)
            .cornerRadius(10)
        }
    }
    
    var statusIcon: some View {
        Group {
            switch manager.apiKeyStatus {
            case .checking:
                ProgressView()
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .invalid:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .missing:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.title2)
    }
    
    var statusText: String {
        switch manager.apiKeyStatus {
        case .checking:
            return "Checking API key..."
        case .valid:
            return "API key is valid"
        case .invalid:
            return "API key is invalid"
        case .missing:
            return "No API key configured"
        }
    }
    
    var statusBackground: Color {
        switch manager.apiKeyStatus {
        case .checking:
            return Color.gray.opacity(0.1)
        case .valid:
            return Color.green.opacity(0.1)
        case .invalid:
            return Color.red.opacity(0.1)
        case .missing:
            return Color.orange.opacity(0.1)
        }
    }
}

struct AuthErrorDetailView: View {
    let error: AuthenticationManager.AuthError
    let onResolve: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: errorIcon)
                    .font(.title)
                    .foregroundColor(errorColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Authentication Failed")
                        .font(.headline)
                    Text(error.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(error.message)
                .font(.subheadline)
            
            // Error details
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Error Type", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(errorTypeDescription)
                        .font(.caption)
                    
                    Divider()
                    
                    Label("Suggestion", systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(error.suggestion)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Action buttons
            HStack {
                Button("Add API Key") {
                    onResolve()
                }
                .buttonStyle(.borderedProminent)
                
                Link("Get API Key", destination: URL(string: "https://platform.deepseek.com/api_keys")!)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
    }
    
    var errorIcon: String {
        switch error.type {
        case .invalidKey: return "key.slash"
        case .missingKey: return "key"
        case .expiredKey: return "clock.badge.exclamationmark"
        case .revokedKey: return "xmark.shield"
        case .networkError: return "wifi.exclamationmark"
        }
    }
    
    var errorColor: Color {
        switch error.type {
        case .invalidKey, .revokedKey: return .red
        case .missingKey: return .orange
        case .expiredKey: return .yellow
        case .networkError: return .blue
        }
    }
    
    var errorTypeDescription: String {
        switch error.type {
        case .invalidKey:
            return "The API key format is incorrect or the key doesn't exist"
        case .missingKey:
            return "No API key was provided in the request"
        case .expiredKey:
            return "The API key has passed its expiration date"
        case .revokedKey:
            return "The API key has been manually revoked or disabled"
        case .networkError:
            return "A network error occurred while validating the key"
        }
    }
}

struct SuccessResponseView: View {
    let response: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Authentication Successful", systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            Text(response)
                .lineLimit(3)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
        }
    }
}

struct APIKeyInputSheet: View {
    @ObservedObject var manager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var isValidating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Add Your DeepSeek API Key")
                    .font(.title2)
                    .bold()
                
                Text("Your API key is required to authenticate with DeepSeek's services")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                
                // Validation hints
                VStack(alignment: .leading, spacing: 8) {
                    ValidationHint(
                        isValid: apiKey.starts(with: "sk-"),
                        text: "Starts with 'sk-'"
                    )
                    ValidationHint(
                        isValid: apiKey.count >= 20,
                        text: "At least 20 characters"
                    )
                    ValidationHint(
                        isValid: !apiKey.contains(" "),
                        text: "No spaces"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Button("Validate and Save") {
                    Task {
                        await validateAndSave()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || isValidating)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func validateAndSave() async {
        isValidating = true
        
        // Test the API key
        await manager.updateAPIKey(apiKey)
        await manager.testCurrentKey(with: "Test")
        
        isValidating = false
        
        // Dismiss if successful
        if case .valid = manager.apiKeyStatus {
            dismiss()
        }
    }
}

struct ValidationHint: View {
    let isValid: Bool
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .green : .gray)
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .primary : .secondary)
        }
    }
}
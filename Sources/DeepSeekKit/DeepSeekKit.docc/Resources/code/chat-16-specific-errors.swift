struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var currentError: DeepSeekError?
    
    var body: some View {
        VStack {
            // Error-specific UI
            if let error = currentError {
                ErrorBanner(error: error) {
                    currentError = nil
                } onRetry: {
                    Task { await retryLastMessage() }
                }
            }
            
            // Messages display
            ScrollView {
                ForEach(messages.indices, id: \.self) { index in
                    MessageRow(message: messages[index])
                }
            }
            
            // Input area
            HStack {
                TextField("Ask me anything...", text: $userInput)
                    .textFieldStyle(.roundedBorder)
                
                Button("Send") {
                    Task { await sendMessage() }
                }
                .disabled(userInput.isEmpty || isLoading)
            }
            .padding()
        }
    }
    
    func sendMessage() async {
        messages.append(.user(userInput))
        userInput = ""
        await performRequest()
    }
    
    func retryLastMessage() async {
        currentError = nil
        await performRequest()
    }
    
    func performRequest() async {
        isLoading = true
        
        do {
            let request = ChatCompletionRequest(
                model: .chat,
                messages: messages
            )
            
            let chatResponse = try await viewModel.client.chat.createCompletion(request)
            
            if let content = chatResponse.choices.first?.message.content {
                messages.append(.assistant(content))
            }
        } catch let error as DeepSeekError {
            currentError = error
            
            // Log specific error details for debugging
            switch error {
            case .invalidAPIKey:
                print("API Key validation failed")
            case .rateLimitExceeded(let retryAfter):
                print("Rate limit hit. Retry after: \(retryAfter ?? "unknown") seconds")
            case .modelNotAvailable(let model):
                print("Model not available: \(model)")
            case .contentFiltered(let reason):
                print("Content filtered: \(reason)")
            case .serverError(let statusCode, let message):
                print("Server error \(statusCode): \(message ?? "No message")")
            case .networkError(let underlying):
                print("Network error: \(underlying)")
            case .decodingError(let underlying):
                print("Decoding error: \(underlying)")
            case .invalidRequest(let reason):
                print("Invalid request: \(reason)")
            }
        } catch {
            // Handle non-DeepSeek errors
            currentError = .networkError(error)
        }
        
        isLoading = false
    }
}

struct ErrorBanner: View {
    let error: DeepSeekError
    let onDismiss: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: errorIcon)
                    .foregroundStyle(errorColor)
                Text(errorMessage)
                    .font(.callout)
                Spacer()
            }
            
            HStack {
                if shouldShowRetry {
                    Button("Retry", action: onRetry)
                        .buttonStyle(.borderedProminent)
                }
                
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(errorColor.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    var errorIcon: String {
        switch error {
        case .invalidAPIKey:
            return "key.fill"
        case .rateLimitExceeded:
            return "clock.fill"
        case .networkError:
            return "wifi.slash"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var errorColor: Color {
        switch error {
        case .rateLimitExceeded:
            return .orange
        case .invalidAPIKey:
            return .red
        default:
            return .red
        }
    }
    
    var errorMessage: String {
        switch error {
        case .invalidAPIKey:
            return "Invalid API key. Please check your configuration."
        case .rateLimitExceeded(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limit exceeded. Please wait \(seconds) seconds."
            }
            return "Rate limit exceeded. Please wait a moment."
        case .modelNotAvailable(let model):
            return "Model '\(model)' is not available."
        case .contentFiltered(let reason):
            return "Content filtered: \(reason)"
        case .serverError(_, let message):
            return message ?? "Server error occurred."
        case .networkError:
            return "Network connection failed. Please check your internet."
        case .decodingError:
            return "Failed to process server response."
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        }
    }
    
    var shouldShowRetry: Bool {
        switch error {
        case .invalidAPIKey, .modelNotAvailable, .contentFiltered:
            return false
        default:
            return true
        }
    }
}
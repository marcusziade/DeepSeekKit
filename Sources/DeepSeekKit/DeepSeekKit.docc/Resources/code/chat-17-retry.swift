struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var currentError: DeepSeekError?
    @State private var retryCount = 0
    @State private var maxRetries = 3
    
    var body: some View {
        VStack {
            // Error banner with retry info
            if let error = currentError {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage(for: error))
                            .font(.callout)
                        Spacer()
                    }
                    
                    if retryCount > 0 {
                        Text("Retry attempt \(retryCount) of \(maxRetries)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        if canRetry(error) {
                            Button("Retry") {
                                Task { await retryWithBackoff() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                        }
                        
                        Button("Cancel") {
                            currentError = nil
                            retryCount = 0
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Messages display
            ScrollView {
                ForEach(messages.indices, id: \.self) { index in
                    MessageRow(message: messages[index])
                }
            }
            
            // Loading indicator
            if isLoading {
                ProgressView("Sending...")
                    .padding()
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
        retryCount = 0
        await performRequest()
    }
    
    func retryWithBackoff() async {
        retryCount += 1
        currentError = nil
        
        // Exponential backoff: 1s, 2s, 4s
        let delay = pow(2.0, Double(retryCount - 1))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
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
                currentError = nil
                retryCount = 0
            }
        } catch let error as DeepSeekError {
            currentError = error
            
            // Auto-retry for transient errors
            if canRetry(error) && retryCount < maxRetries {
                await retryWithBackoff()
            }
        } catch {
            currentError = .networkError(error)
        }
        
        isLoading = false
    }
    
    func canRetry(_ error: DeepSeekError) -> Bool {
        switch error {
        case .networkError, .serverError, .rateLimitExceeded:
            return retryCount < maxRetries
        case .invalidAPIKey, .modelNotAvailable, .contentFiltered, .invalidRequest:
            return false
        case .decodingError:
            return retryCount < 1 // Only retry once for decoding errors
        }
    }
    
    func errorMessage(for error: DeepSeekError) -> String {
        switch error {
        case .rateLimitExceeded(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limit exceeded. Retry after \(seconds)s."
            }
            return "Rate limit exceeded. Please wait."
        case .networkError:
            return "Network error. Check your connection."
        case .serverError(let code, _):
            return "Server error (code: \(code)). This is usually temporary."
        default:
            return error.localizedDescription
        }
    }
}
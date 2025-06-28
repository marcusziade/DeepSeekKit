struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        VStack {
            // Error alert
            if showError, let error = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    HStack {
                        Button("Retry") {
                            Task { await retryLastMessage() }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Dismiss") {
                            showError = false
                            errorMessage = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
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
        let messageToSend = userInput
        messages.append(.user(messageToSend))
        userInput = ""
        await performRequest()
    }
    
    func retryLastMessage() async {
        showError = false
        errorMessage = nil
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
        } catch {
            // Handle different error types
            switch error {
            case DeepSeekError.invalidAPIKey:
                errorMessage = "Invalid API key. Please check your configuration."
            case DeepSeekError.rateLimitExceeded:
                errorMessage = "Rate limit exceeded. Please wait a moment and try again."
            case DeepSeekError.networkError(let underlying):
                errorMessage = "Network error: \(underlying.localizedDescription)"
            default:
                errorMessage = "An error occurred: \(error.localizedDescription)"
            }
            showError = true
        }
        
        isLoading = false
    }
}
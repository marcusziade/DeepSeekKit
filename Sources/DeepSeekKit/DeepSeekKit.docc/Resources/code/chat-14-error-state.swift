struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        VStack {
            // Error banner
            if showError, let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        showError = false
                        errorMessage = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
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
        messages.append(.user(userInput))
        userInput = ""
        isLoading = true
        showError = false
        errorMessage = nil
        
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
            // Store error for display
            errorMessage = error.localizedDescription
            showError = true
            
            // Remove the user message if the request failed
            if messages.last?.role == .user {
                messages.removeLast()
            }
        }
        
        isLoading = false
    }
}
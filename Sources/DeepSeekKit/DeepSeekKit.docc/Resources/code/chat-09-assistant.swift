struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = [
        .system("You are a helpful AI assistant."),
        // Example conversation with assistant messages
        .user("What is Swift?"),
        .assistant("Swift is a powerful and intuitive programming language developed by Apple for building apps for iOS, macOS, watchOS, and tvOS."),
        .user("What are its main features?")
    ]
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // Display all messages
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
        // Add user message to conversation
        messages.append(.user(userInput))
        userInput = ""
        isLoading = true
        
        do {
            let request = ChatCompletionRequest(
                model: .chat,
                messages: messages  // Includes previous assistant responses for context
            )
            
            let chatResponse = try await viewModel.client.chat.createCompletion(request)
            
            if let content = chatResponse.choices.first?.message.content {
                // Add new assistant response
                messages.append(.assistant(content))
            }
        } catch {
            messages.append(.assistant("Error: \(error.localizedDescription)"))
        }
        
        isLoading = false
    }
}
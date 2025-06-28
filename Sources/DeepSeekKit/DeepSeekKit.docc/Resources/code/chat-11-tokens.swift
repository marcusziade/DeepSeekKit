struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = []
    @State private var maxTokens: Int? = 150
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // Token limit control
            VStack(alignment: .leading) {
                HStack {
                    Text("Max Tokens:")
                        .font(.caption)
                    TextField("150", value: $maxTokens, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                Text("Limits response length (nil for no limit)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
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
        
        do {
            let request = ChatCompletionRequest(
                model: .chat,
                messages: messages,
                maxTokens: maxTokens  // Limit response length
            )
            
            let chatResponse = try await viewModel.client.chat.createCompletion(request)
            
            if let content = chatResponse.choices.first?.message.content {
                messages.append(.assistant(content))
            }
        } catch {
            messages.append(.assistant("Error: \(error.localizedDescription)"))
        }
        
        isLoading = false
    }
}
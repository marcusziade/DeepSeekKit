struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = []
    @State private var temperature: Double = 0.7
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // Temperature control
            VStack(alignment: .leading) {
                Text("Temperature: \(temperature, specifier: "%.1f")")
                    .font(.caption)
                Slider(value: $temperature, in: 0...1, step: 0.1)
                Text(temperatureDescription)
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
    
    var temperatureDescription: String {
        switch temperature {
        case 0..<0.3:
            return "Very focused and deterministic"
        case 0.3..<0.7:
            return "Balanced creativity and consistency"
        case 0.7...1.0:
            return "Creative and varied responses"
        default:
            return "Standard behavior"
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
                temperature: temperature  // Control response randomness
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
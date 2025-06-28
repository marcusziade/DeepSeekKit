struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = [
        .system("You are a helpful assistant. When asked for structured data, always respond with valid JSON.")
    ]
    @State private var useJSONMode = false
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // JSON mode toggle
            Toggle("JSON Response Mode", isOn: $useJSONMode)
                .padding()
            
            // Messages display
            ScrollView {
                ForEach(messages.indices, id: \.self) { index in
                    MessageRow(message: messages[index])
                }
            }
            
            // Sample prompts for JSON mode
            if useJSONMode {
                VStack(alignment: .leading) {
                    Text("Try these prompts:")
                        .font(.caption)
                    Button("List 3 programming languages") {
                        userInput = "List 3 popular programming languages with their use cases"
                    }
                    .buttonStyle(.bordered)
                    Button("Weather data structure") {
                        userInput = "Create a JSON structure for weather data"
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
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
                responseFormat: useJSONMode ? .jsonObject : nil  // Enable JSON mode
            )
            
            let chatResponse = try await viewModel.client.chat.createCompletion(request)
            
            if let content = chatResponse.choices.first?.message.content {
                messages.append(.assistant(content))
                
                // If JSON mode, try to parse and pretty-print
                if useJSONMode,
                   let data = content.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data),
                   let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    // Replace the last message with pretty-printed version
                    messages[messages.count - 1] = .assistant(prettyString)
                }
            }
        } catch {
            messages.append(.assistant("Error: \(error.localizedDescription)"))
        }
        
        isLoading = false
    }
}
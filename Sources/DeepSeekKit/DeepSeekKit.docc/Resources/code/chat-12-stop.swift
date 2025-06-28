struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = []
    @State private var stopSequences = ["END", "STOP"]
    @State private var newStopSequence = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // Stop sequences control
            VStack(alignment: .leading) {
                Text("Stop Sequences:")
                    .font(.caption)
                HStack {
                    ForEach(stopSequences, id: \.self) { sequence in
                        Text(sequence)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                HStack {
                    TextField("Add stop sequence", text: $newStopSequence)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    Button("Add") {
                        if !newStopSequence.isEmpty {
                            stopSequences.append(newStopSequence)
                            newStopSequence = ""
                        }
                    }
                }
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
                stop: stopSequences.isEmpty ? nil : stopSequences  // AI stops when it generates these
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
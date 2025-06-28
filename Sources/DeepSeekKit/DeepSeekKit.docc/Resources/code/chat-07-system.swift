func sendMessage() async {
    let message = userInput
    userInput = ""
    isLoading = true
    
    do {
        let request = ChatCompletionRequest(
            model: .chat,
            messages: [
                .system("You are a helpful AI assistant. Be concise and friendly."),
                .user(message)
            ]
        )
        
        let chatResponse = try await viewModel.client.chat.createCompletion(request)
        
        if let content = chatResponse.choices.first?.message.content {
            response = content
        }
    } catch {
        response = "Error: \(error.localizedDescription)"
    }
    
    isLoading = false
}
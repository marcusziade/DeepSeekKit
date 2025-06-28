func sendMessage() async {
    let message = userInput
    userInput = "" // Clear input immediately
    
    do {
        let request = ChatCompletionRequest(
            model: .chat,
            messages: [.user(message)]
        )
        
        let chatResponse = try await viewModel.client.chat.createCompletion(request)
        
        if let content = chatResponse.choices.first?.message.content {
            response = content
        }
    } catch {
        response = "Error: \(error.localizedDescription)"
    }
}
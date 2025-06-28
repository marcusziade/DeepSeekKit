import SwiftUI
import DeepSeekKit

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var response = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // Response area
            ScrollView {
                if isLoading {
                    ProgressView("Thinking...")
                        .padding()
                } else {
                    Text(response)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Input area
            HStack {
                TextField("Ask me anything...", text: $userInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
                
                Button("Send") {
                    Task {
                        await sendMessage()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(userInput.isEmpty || isLoading)
            }
            .padding()
        }
    }
    
    func sendMessage() async {
        let message = userInput
        userInput = ""
        isLoading = true
        
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
        
        isLoading = false
    }
}
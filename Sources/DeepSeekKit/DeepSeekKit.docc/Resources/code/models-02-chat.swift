import SwiftUI
import DeepSeekKit

struct ModelExplorer: View {
    @StateObject private var client = DeepSeekClient()
    @State private var message = ""
    @State private var response = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("DeepSeek Chat Model")
                .font(.largeTitle)
                .bold()
            
            Text("Fast, efficient, and great for most use cases")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("Ask something...", text: $message)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    Task {
                        await sendChatMessage()
                    }
                }
                .disabled(message.isEmpty || isLoading)
            }
            
            if isLoading {
                ProgressView()
                    .padding()
            }
            
            if !response.isEmpty {
                Text("Response:")
                    .font(.headline)
                Text(response)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func sendChatMessage() async {
        isLoading = true
        response = ""
        
        do {
            let chatResponse = try await client.chat(
                messages: [.user(message)],
                model: .chat // Using the chat model
            )
            response = chatResponse.choices.first?.message.content ?? ""
        } catch {
            response = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
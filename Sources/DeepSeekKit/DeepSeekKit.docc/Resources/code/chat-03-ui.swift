import SwiftUI
import DeepSeekKit

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var response = ""
    
    var body: some View {
        VStack {
            // Response area
            ScrollView {
                Text(response)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Input area
            HStack {
                TextField("Ask me anything...", text: $userInput)
                    .textFieldStyle(.roundedBorder)
                
                Button("Send") {
                    Task {
                        await sendMessage()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    
    func sendMessage() async {
        // Implementation coming next
    }
}
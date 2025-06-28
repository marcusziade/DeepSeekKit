import SwiftUI
import DeepSeekKit

@MainActor
class ChatViewModel: ObservableObject {
    let client: DeepSeekClient
    
    init() {
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] else {
            fatalError("Please set DEEPSEEK_API_KEY environment variable")
        }
        self.client = DeepSeekClient(apiKey: apiKey)
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var response = ""
    
    var body: some View {
        VStack {
            // Chat interface will go here
        }
    }
}
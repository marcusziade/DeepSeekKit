import SwiftUI
import DeepSeekKit

struct ContentView: View {
    let client: DeepSeekClient
    
    init() {
        // Get API key from environment or Keychain
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] else {
            fatalError("Please set DEEPSEEK_API_KEY environment variable")
        }
        
        self.client = DeepSeekClient(apiKey: apiKey)
    }
    
    var body: some View {
        Text("DeepSeek Client Ready!")
            .padding()
    }
}
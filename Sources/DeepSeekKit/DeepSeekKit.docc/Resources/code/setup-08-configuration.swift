import SwiftUI
import DeepSeekKit

struct ContentView: View {
    let client: DeepSeekClient
    
    init() {
        guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] else {
            fatalError("Please set DEEPSEEK_API_KEY environment variable")
        }
        
        // Create custom configuration
        let configuration = DeepSeekConfiguration(
            apiKey: apiKey,
            baseURL: URL(string: "https://api.deepseek.com/v1")!,
            timeoutInterval: 120.0, // 2 minutes timeout
            headers: [:] // Optional custom headers
        )
        
        self.client = DeepSeekClient(configuration: configuration)
    }
    
    var body: some View {
        Text("Custom Configuration Ready!")
            .padding()
    }
}
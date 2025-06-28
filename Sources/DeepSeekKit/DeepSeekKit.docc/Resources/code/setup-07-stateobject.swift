import SwiftUI
import DeepSeekKit

@MainActor
class DeepSeekViewModel: ObservableObject {
    let client: DeepSeekClient
    
    init() {
        guard let apiKey = KeychainHelper.shared.getAPIKey() else {
            fatalError("API key not found in Keychain")
        }
        self.client = DeepSeekClient(apiKey: apiKey)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = DeepSeekViewModel()
    
    var body: some View {
        VStack {
            Text("DeepSeek Ready!")
            // Your UI here
        }
        .padding()
    }
}
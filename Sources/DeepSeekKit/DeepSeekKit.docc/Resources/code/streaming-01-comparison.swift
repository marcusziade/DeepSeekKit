import SwiftUI
import DeepSeekKit

// Standard (non-streaming) response - user waits for complete response
struct StandardResponseView: View {
    @StateObject private var client = DeepSeekClient()
    @State private var response = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            Text("Standard Response")
                .font(.headline)
            
            if isLoading {
                ProgressView("Waiting for complete response...")
                    .padding()
            } else if !response.isEmpty {
                Text(response)
                    .padding()
            }
            
            Button("Get Response") {
                Task {
                    await getStandardResponse()
                }
            }
        }
    }
    
    func getStandardResponse() async {
        isLoading = true
        response = ""
        
        do {
            // User waits for entire response
            let result = try await client.sendMessage("Explain quantum computing")
            response = result.choices.first?.message.content ?? ""
        } catch {
            response = "Error: \(error)"
        }
        
        isLoading = false
    }
}

// Streaming response - text appears as it's generated
struct StreamingResponseView: View {
    @StateObject private var client = DeepSeekClient()
    @State private var response = ""
    @State private var isStreaming = false
    
    var body: some View {
        VStack {
            Text("Streaming Response")
                .font(.headline)
            
            if !response.isEmpty || isStreaming {
                Text(response)
                    .padding()
                    .animation(.easeInOut, value: response)
            }
            
            Button("Stream Response") {
                Task {
                    await streamResponse()
                }
            }
            .disabled(isStreaming)
        }
    }
    
    func streamResponse() async {
        isStreaming = true
        response = ""
        
        do {
            // Text appears progressively as generated
            for try await chunk in client.streamMessage("Explain quantum computing") {
                if let content = chunk.choices.first?.delta.content {
                    response += content
                }
            }
        } catch {
            response = "Error: \(error)"
        }
        
        isStreaming = false
    }
}
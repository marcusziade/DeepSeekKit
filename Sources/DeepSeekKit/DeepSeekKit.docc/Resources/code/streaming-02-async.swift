import SwiftUI
import DeepSeekKit

// DeepSeekKit uses AsyncSequence for elegant streaming
struct AsyncSequenceStreamingView: View {
    @StateObject private var client = DeepSeekClient()
    @State private var response = ""
    @State private var isStreaming = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AsyncSequence Streaming")
                .font(.largeTitle)
                .bold()
            
            Text("Modern Swift concurrency in action:")
                .font(.headline)
            
            // Show the response as it streams
            ScrollView {
                Text(response)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Button(action: { Task { await demonstrateAsyncSequence() } }) {
                Label(isStreaming ? "Streaming..." : "Start Streaming", 
                      systemImage: isStreaming ? "stop.circle" : "play.circle")
            }
            .disabled(isStreaming)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    func demonstrateAsyncSequence() async {
        isStreaming = true
        response = ""
        
        do {
            // AsyncSequence allows for-await syntax
            let stream = client.streamMessage("Write a haiku about Swift programming")
            
            // Process each chunk as it arrives
            for try await chunk in stream {
                // Each chunk is processed immediately
                if let content = chunk.choices.first?.delta.content {
                    // Update UI with each piece of content
                    response += content
                }
                
                // You can also access other chunk properties
                if let finishReason = chunk.choices.first?.finishReason {
                    response += "\n\n[Finished: \(finishReason)]"
                }
            }
        } catch {
            response = "Streaming error: \(error.localizedDescription)"
        }
        
        isStreaming = false
    }
}

// Demonstrate cancellation support
struct CancellableStreamView: View {
    @StateObject private var client = DeepSeekClient()
    @State private var response = ""
    @State private var streamTask: Task<Void, Never>?
    
    var body: some View {
        VStack {
            Text(response)
                .padding()
            
            HStack {
                Button("Start Streaming") {
                    streamTask = Task {
                        await startStreaming()
                    }
                }
                .disabled(streamTask != nil)
                
                Button("Cancel") {
                    streamTask?.cancel()
                    streamTask = nil
                    response += "\n[Cancelled by user]"
                }
                .disabled(streamTask == nil)
            }
        }
    }
    
    func startStreaming() async {
        response = "Starting stream...\n"
        
        do {
            for try await chunk in client.streamMessage("Count to 20 slowly") {
                // Check for cancellation
                if Task.isCancelled { break }
                
                if let content = chunk.choices.first?.delta.content {
                    response += content
                }
            }
        } catch {
            response += "\nError: \(error)"
        }
        
        streamTask = nil
    }
}
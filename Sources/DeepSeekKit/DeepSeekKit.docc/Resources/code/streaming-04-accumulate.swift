import SwiftUI
import DeepSeekKit

// Accumulating chunks to build complete response
struct AccumulatingStreamView: View {
    @StateObject private var client = DeepSeekClient()
    @State private var accumulatedResponse = ""
    @State private var currentChunk = ""
    @State private var chunkCount = 0
    @State private var isStreaming = false
    @State private var showChunkDetails = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Accumulating Stream Chunks")
                .font(.largeTitle)
                .bold()
            
            Toggle("Show chunk details", isOn: $showChunkDetails)
            
            if showChunkDetails {
                ChunkDetailsView(
                    currentChunk: currentChunk,
                    chunkCount: chunkCount,
                    totalLength: accumulatedResponse.count
                )
            }
            
            // Main accumulated response
            ScrollView {
                Text(accumulatedResponse)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .frame(maxHeight: 300)
            
            HStack {
                Button("Stream Message") {
                    Task { await streamWithAccumulation() }
                }
                .disabled(isStreaming)
                
                Button("Clear") {
                    accumulatedResponse = ""
                    currentChunk = ""
                    chunkCount = 0
                }
                .disabled(isStreaming)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    func streamWithAccumulation() async {
        // Reset state
        isStreaming = true
        accumulatedResponse = ""
        currentChunk = ""
        chunkCount = 0
        
        do {
            // Create a proper accumulator
            var messageAccumulator = MessageAccumulator()
            
            for try await chunk in client.streamMessage("Write a short story about a coding robot") {
                // Process each chunk
                if let delta = chunk.choices.first?.delta {
                    // Update current chunk display
                    currentChunk = delta.content ?? ""
                    chunkCount += 1
                    
                    // Accumulate the content
                    messageAccumulator.add(delta: delta)
                    
                    // Update the displayed accumulated response
                    accumulatedResponse = messageAccumulator.content
                }
                
                // Handle completion
                if let finishReason = chunk.choices.first?.finishReason {
                    accumulatedResponse += "\n\n[Completed: \(finishReason)]"
                    accumulatedResponse += "\nTotal chunks: \(chunkCount)"
                    accumulatedResponse += "\nFinal length: \(messageAccumulator.content.count) characters"
                }
            }
        } catch {
            accumulatedResponse += "\n\nError: \(error)"
        }
        
        isStreaming = false
        currentChunk = ""
    }
}

// Helper to properly accumulate message content
struct MessageAccumulator {
    private(set) var content = ""
    private(set) var role: String?
    
    mutating func add(delta: ChatCompletionStreamChoice.Delta) {
        // Accumulate content
        if let deltaContent = delta.content {
            content += deltaContent
        }
        
        // Track role if provided
        if let deltaRole = delta.role {
            role = deltaRole
        }
    }
    
    func buildMessage() -> ChatMessage {
        ChatMessage(
            role: role ?? "assistant",
            content: content
        )
    }
}

struct ChunkDetailsView: View {
    let currentChunk: String
    let chunkCount: Int
    let totalLength: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chunk Details")
                .font(.headline)
            
            HStack {
                Label("\(chunkCount) chunks received", systemImage: "square.stack.3d.up")
                Spacer()
                Label("\(totalLength) total characters", systemImage: "textformat.size")
            }
            .font(.caption)
            
            if !currentChunk.isEmpty {
                VStack(alignment: .leading) {
                    Text("Current chunk:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(currentChunk)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}
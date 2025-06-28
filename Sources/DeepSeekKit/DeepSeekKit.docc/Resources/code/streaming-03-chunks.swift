import SwiftUI
import DeepSeekKit

// Understanding streaming chunks
struct StreamingChunksView: View {
    @StateObject private var client = DeepSeekClient()
    @State private var chunks: [StreamChunk] = []
    @State private var isStreaming = false
    
    struct StreamChunk: Identifiable {
        let id = UUID()
        let content: String
        let timestamp: Date
        let tokenCount: Int?
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Understanding Streaming Chunks")
                .font(.largeTitle)
                .bold()
            
            Text("Each chunk contains a delta with new content")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Visualize individual chunks
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(chunks) { chunk in
                        ChunkView(chunk: chunk)
                    }
                }
            }
            .frame(maxHeight: 400)
            
            // Show accumulated result
            VStack(alignment: .leading) {
                Text("Accumulated Result:")
                    .font(.headline)
                
                Text(chunks.map { $0.content }.joined())
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Button("Stream with Chunk Analysis") {
                Task { await analyzeChunks() }
            }
            .disabled(isStreaming)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    func analyzeChunks() async {
        isStreaming = true
        chunks = []
        
        do {
            let startTime = Date()
            
            for try await chunk in client.streamMessage("Explain streaming in 3 sentences") {
                // Extract content from delta
                if let delta = chunk.choices.first?.delta,
                   let content = delta.content {
                    
                    // Create chunk record
                    let streamChunk = StreamChunk(
                        content: content,
                        timestamp: Date(),
                        tokenCount: chunk.usage?.totalTokens
                    )
                    
                    chunks.append(streamChunk)
                    
                    // Small delay to make chunks visible
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
                
                // Check if this is the final chunk
                if let finishReason = chunk.choices.first?.finishReason {
                    let duration = Date().timeIntervalSince(startTime)
                    chunks.append(StreamChunk(
                        content: "\n\n[Stream completed: \(finishReason) in \(String(format: "%.2f", duration))s]",
                        timestamp: Date(),
                        tokenCount: chunk.usage?.totalTokens
                    ))
                }
            }
        } catch {
            chunks.append(StreamChunk(
                content: "\nError: \(error)",
                timestamp: Date(),
                tokenCount: nil
            ))
        }
        
        isStreaming = false
    }
}

struct ChunkView: View {
    let chunk: StreamingChunksView.StreamChunk
    
    var body: some View {
        HStack(alignment: .top) {
            // Chunk indicator
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                // Content
                Text(chunk.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                
                // Metadata
                HStack {
                    Text(chunk.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let tokens = chunk.tokenCount {
                        Text("• \(tokens) tokens total")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
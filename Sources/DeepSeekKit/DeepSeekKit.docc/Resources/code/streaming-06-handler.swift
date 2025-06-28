import SwiftUI
import DeepSeekKit

// Implementing a robust streaming message handler
struct StreamingMessageHandler: View {
    @StateObject private var handler = MessageStreamHandler()
    @State private var userInput = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Streaming Message Handler")
                .font(.largeTitle)
                .bold()
            
            // Status display
            StatusView(handler: handler)
            
            // Message display with metadata
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !handler.currentMessage.isEmpty {
                        MessageView(
                            content: handler.currentMessage,
                            metadata: handler.messageMetadata
                        )
                    }
                    
                    if !handler.debugInfo.isEmpty {
                        DebugView(info: handler.debugInfo)
                    }
                }
            }
            .frame(maxHeight: 400)
            
            // Controls
            HStack {
                TextField("Enter your message", text: $userInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(handler.isProcessing)
                
                Button("Send") {
                    Task {
                        await handler.processStreamingMessage(userInput)
                    }
                }
                .disabled(userInput.isEmpty || handler.isProcessing)
                
                if handler.isProcessing {
                    Button("Cancel") {
                        handler.cancelStream()
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Comprehensive message stream handler
@MainActor
class MessageStreamHandler: ObservableObject {
    @Published var currentMessage = ""
    @Published var isProcessing = false
    @Published var messageMetadata = MessageMetadata()
    @Published var debugInfo: [String] = []
    
    private let client = DeepSeekClient()
    private var streamTask: Task<Void, Never>?
    private var startTime: Date?
    
    struct MessageMetadata {
        var chunkCount = 0
        var totalTokens = 0
        var firstChunkTime: TimeInterval?
        var averageChunkInterval: TimeInterval = 0
        var finishReason: String?
    }
    
    func processStreamingMessage(_ prompt: String) async {
        // Reset state
        resetState()
        isProcessing = true
        startTime = Date()
        
        // Create streaming task
        streamTask = Task {
            await handleStream(prompt: prompt)
        }
        
        // Wait for completion
        await streamTask?.value
        isProcessing = false
    }
    
    private func handleStream(prompt: String) async {
        var chunkTimes: [TimeInterval] = []
        let streamStart = Date()
        
        do {
            for try await chunk in client.streamMessage(prompt) {
                // Check for cancellation
                if Task.isCancelled {
                    debugInfo.append("Stream cancelled by user")
                    break
                }
                
                let chunkTime = Date().timeIntervalSince(streamStart)
                
                // Process chunk content
                if let delta = chunk.choices.first?.delta {
                    processChunk(delta: delta, chunkTime: chunkTime)
                    chunkTimes.append(chunkTime)
                }
                
                // Update token count
                if let usage = chunk.usage {
                    messageMetadata.totalTokens = usage.totalTokens
                }
                
                // Check for completion
                if let finishReason = chunk.choices.first?.finishReason {
                    messageMetadata.finishReason = finishReason
                    debugInfo.append("Stream finished: \(finishReason)")
                }
                
                // Calculate metrics
                updateMetrics(chunkTimes: chunkTimes)
            }
        } catch DeepSeekError.rateLimitExceeded {
            debugInfo.append("Rate limit exceeded - implement backoff")
            currentMessage += "\n\n[Rate limit error - please wait]"
        } catch DeepSeekError.networkError(let underlying) {
            debugInfo.append("Network error: \(underlying.localizedDescription)")
            currentMessage += "\n\n[Network error occurred]"
        } catch {
            debugInfo.append("Unexpected error: \(error)")
            currentMessage += "\n\n[Error: \(error.localizedDescription)]"
        }
        
        // Final metrics
        if let start = startTime {
            let totalTime = Date().timeIntervalSince(start)
            debugInfo.append("Total time: \(String(format: "%.2f", totalTime))s")
        }
    }
    
    private func processChunk(delta: ChatCompletionStreamChoice.Delta, chunkTime: TimeInterval) {
        messageMetadata.chunkCount += 1
        
        // Record first chunk time
        if messageMetadata.firstChunkTime == nil {
            messageMetadata.firstChunkTime = chunkTime
            debugInfo.append("First chunk received at: \(String(format: "%.3f", chunkTime))s")
        }
        
        // Append content
        if let content = delta.content {
            currentMessage += content
            
            // Log significant chunks
            if messageMetadata.chunkCount % 10 == 0 {
                debugInfo.append("Chunk \(messageMetadata.chunkCount): \(content.count) chars")
            }
        }
    }
    
    private func updateMetrics(chunkTimes: [TimeInterval]) {
        guard chunkTimes.count > 1 else { return }
        
        // Calculate average interval between chunks
        var intervals: [TimeInterval] = []
        for i in 1..<chunkTimes.count {
            intervals.append(chunkTimes[i] - chunkTimes[i-1])
        }
        
        if !intervals.isEmpty {
            messageMetadata.averageChunkInterval = intervals.reduce(0, +) / Double(intervals.count)
        }
    }
    
    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        debugInfo.append("Stream cancelled")
    }
    
    private func resetState() {
        currentMessage = ""
        messageMetadata = MessageMetadata()
        debugInfo = []
        startTime = nil
    }
}

// Views for displaying handler state
struct StatusView: View {
    @ObservedObject var handler: MessageStreamHandler
    
    var body: some View {
        HStack {
            if handler.isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Processing stream...")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Ready")
            }
            
            Spacer()
            
            if handler.messageMetadata.chunkCount > 0 {
                Text("\(handler.messageMetadata.chunkCount) chunks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

struct MessageView: View {
    let content: String
    let metadata: MessageStreamHandler.MessageMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            HStack(spacing: 20) {
                if let firstChunk = metadata.firstChunkTime {
                    Label("\(String(format: "%.3f", firstChunk))s to first chunk", 
                          systemImage: "timer")
                }
                
                if metadata.averageChunkInterval > 0 {
                    Label("\(String(format: "%.3f", metadata.averageChunkInterval))s avg interval",
                          systemImage: "chart.line.uptrend.xyaxis")
                }
                
                if metadata.totalTokens > 0 {
                    Label("\(metadata.totalTokens) tokens",
                          systemImage: "number.circle")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

struct DebugView: View {
    let info: [String]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: { isExpanded.toggle() }) {
                Label(isExpanded ? "Hide Debug Info" : "Show Debug Info", 
                      systemImage: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(info.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
}
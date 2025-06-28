import SwiftUI
import DeepSeekKit

// Handling the end of streaming and finalizing messages
struct StreamingFinalizationView: View {
    @StateObject private var streamManager = StreamFinalizationManager()
    @State private var prompt = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Stream Finalization")
                .font(.largeTitle)
                .bold()
            
            // Stream status indicator
            StreamStatusView(status: streamManager.streamStatus)
            
            // Message display with finalization state
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(streamManager.messages) { message in
                        FinalizedMessageView(message: message)
                    }
                }
                .padding()
            }
            
            // Statistics
            if let stats = streamManager.currentStreamStats {
                StreamStatsView(stats: stats)
            }
            
            // Controls
            HStack {
                TextField("Enter prompt", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                
                Button("Stream") {
                    Task {
                        await streamManager.streamMessage(prompt)
                    }
                }
                .disabled(prompt.isEmpty || streamManager.isStreaming)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Manager for handling stream finalization
@MainActor
class StreamFinalizationManager: ObservableObject {
    @Published var messages: [FinalizedMessage] = []
    @Published var isStreaming = false
    @Published var streamStatus: StreamStatus = .idle
    @Published var currentStreamStats: StreamStats?
    
    private let client = DeepSeekClient()
    private var currentMessageId: UUID?
    
    enum StreamStatus {
        case idle
        case connecting
        case streaming(progress: Double)
        case finalizing
        case completed(reason: String)
        case failed(error: String)
    }
    
    struct FinalizedMessage: Identifiable {
        let id = UUID()
        var content: String
        var status: MessageStatus
        let role: String
        var metadata: MessageMetadata
        
        enum MessageStatus {
            case streaming
            case finalizing
            case completed
            case failed
        }
        
        struct MessageMetadata {
            var startTime: Date
            var endTime: Date?
            var chunkCount: Int
            var totalTokens: Int?
            var finishReason: String?
            var streamDuration: TimeInterval?
        }
    }
    
    struct StreamStats {
        let totalChunks: Int
        let totalTokens: Int
        let duration: TimeInterval
        let averageChunkDelay: TimeInterval
        let throughput: Double // tokens per second
    }
    
    func streamMessage(_ prompt: String) async {
        // Initialize stream
        streamStatus = .connecting
        isStreaming = true
        currentStreamStats = nil
        
        // Add user message
        let userMessage = FinalizedMessage(
            content: prompt,
            status: .completed,
            role: "user",
            metadata: FinalizedMessage.MessageMetadata(
                startTime: Date(),
                endTime: Date(),
                chunkCount: 1
            )
        )
        messages.append(userMessage)
        
        // Create assistant message
        var assistantMessage = FinalizedMessage(
            content: "",
            status: .streaming,
            role: "assistant",
            metadata: FinalizedMessage.MessageMetadata(
                startTime: Date(),
                chunkCount: 0
            )
        )
        currentMessageId = assistantMessage.id
        messages.append(assistantMessage)
        
        // Stream and finalize
        await performStreamWithFinalization(prompt: prompt, messageId: assistantMessage.id)
    }
    
    private func performStreamWithFinalization(prompt: String, messageId: UUID) async {
        let startTime = Date()
        var chunkCount = 0
        var totalTokens = 0
        var chunkDelays: [TimeInterval] = []
        var lastChunkTime = startTime
        
        do {
            streamStatus = .streaming(progress: 0)
            
            for try await chunk in client.streamMessage(prompt) {
                let currentTime = Date()
                chunkDelays.append(currentTime.timeIntervalSince(lastChunkTime))
                lastChunkTime = currentTime
                
                // Update message content
                if let content = chunk.choices.first?.delta.content,
                   let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index].content += content
                    messages[index].metadata.chunkCount += 1
                    chunkCount += 1
                }
                
                // Update token count
                if let usage = chunk.usage {
                    totalTokens = usage.totalTokens
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index].metadata.totalTokens = totalTokens
                    }
                }
                
                // Update progress (estimated)
                let progress = min(Double(chunkCount) / 50.0, 0.9) // Assume ~50 chunks typical
                streamStatus = .streaming(progress: progress)
                
                // Check for completion
                if let finishReason = chunk.choices.first?.finishReason {
                    // Enter finalization phase
                    await finalizeMessage(
                        messageId: messageId,
                        finishReason: finishReason,
                        startTime: startTime,
                        chunkCount: chunkCount,
                        totalTokens: totalTokens,
                        chunkDelays: chunkDelays
                    )
                }
            }
        } catch {
            // Handle stream error
            await handleStreamError(messageId: messageId, error: error)
        }
        
        isStreaming = false
    }
    
    private func finalizeMessage(
        messageId: UUID,
        finishReason: String,
        startTime: Date,
        chunkCount: Int,
        totalTokens: Int,
        chunkDelays: [TimeInterval]
    ) async {
        streamStatus = .finalizing
        
        // Simulate finalization work (e.g., saving to database, processing)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Update message status
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            messages[index].status = .completed
            messages[index].metadata.endTime = endTime
            messages[index].metadata.finishReason = finishReason
            messages[index].metadata.streamDuration = duration
            messages[index].metadata.totalTokens = totalTokens
            
            // Calculate statistics
            let avgDelay = chunkDelays.isEmpty ? 0 : chunkDelays.reduce(0, +) / Double(chunkDelays.count)
            let throughput = duration > 0 ? Double(totalTokens) / duration : 0
            
            currentStreamStats = StreamStats(
                totalChunks: chunkCount,
                totalTokens: totalTokens,
                duration: duration,
                averageChunkDelay: avgDelay,
                throughput: throughput
            )
            
            streamStatus = .completed(reason: finishReason)
        }
    }
    
    private func handleStreamError(messageId: UUID, error: Error) async {
        streamStatus = .failed(error: error.localizedDescription)
        
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = .failed
            messages[index].metadata.endTime = Date()
            
            // Add error information to content
            if messages[index].content.isEmpty {
                messages[index].content = "Failed to generate response: \(error.localizedDescription)"
            } else {
                messages[index].content += "\n\n[Stream interrupted: \(error.localizedDescription)]"
            }
        }
    }
}

// View for displaying stream status
struct StreamStatusView: View {
    let status: StreamFinalizationManager.StreamStatus
    
    var body: some View {
        HStack {
            statusIcon
            statusText
            Spacer()
            if case .streaming(let progress) = status {
                ProgressView(value: progress)
                    .frame(width: 100)
            }
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor, lineWidth: 1)
        )
    }
    
    var statusIcon: some View {
        Group {
            switch status {
            case .idle:
                Image(systemName: "circle")
            case .connecting:
                ProgressView()
                    .scaleEffect(0.8)
            case .streaming:
                Image(systemName: "dot.radiowaves.left.and.right")
            case .finalizing:
                Image(systemName: "checkmark.circle")
            case .completed:
                Image(systemName: "checkmark.circle.fill")
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
            }
        }
        .foregroundColor(statusColor)
    }
    
    var statusText: some View {
        Group {
            switch status {
            case .idle:
                Text("Ready")
            case .connecting:
                Text("Connecting...")
            case .streaming(let progress):
                Text("Streaming... \(Int(progress * 100))%")
            case .finalizing:
                Text("Finalizing...")
            case .completed(let reason):
                Text("Completed: \(reason)")
            case .failed(let error):
                Text("Failed: \(error)")
                    .lineLimit(1)
            }
        }
        .font(.subheadline)
    }
    
    var statusColor: Color {
        switch status {
        case .idle: return .gray
        case .connecting, .streaming, .finalizing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// View for finalized messages
struct FinalizedMessageView: View {
    let message: StreamFinalizationManager.FinalizedMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(message.role.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                StatusBadge(status: message.status)
            }
            
            // Content
            Text(message.content)
                .textSelection(.enabled)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            // Metadata
            if message.status == .completed || message.status == .failed {
                MetadataView(metadata: message.metadata)
            }
        }
    }
}

struct StatusBadge: View {
    let status: StreamFinalizationManager.FinalizedMessage.MessageStatus
    
    var body: some View {
        Label(statusText, systemImage: statusIcon)
            .font(.caption2)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .cornerRadius(6)
    }
    
    var statusText: String {
        switch status {
        case .streaming: return "Streaming"
        case .finalizing: return "Finalizing"
        case .completed: return "Complete"
        case .failed: return "Failed"
        }
    }
    
    var statusIcon: String {
        switch status {
        case .streaming: return "dot.radiowaves.left.and.right"
        case .finalizing: return "hourglass"
        case .completed: return "checkmark"
        case .failed: return "xmark"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .streaming, .finalizing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct MetadataView: View {
    let metadata: StreamFinalizationManager.FinalizedMessage.MessageMetadata
    
    var body: some View {
        HStack(spacing: 16) {
            if let duration = metadata.streamDuration {
                Label("\(String(format: "%.2f", duration))s", systemImage: "timer")
            }
            
            Label("\(metadata.chunkCount) chunks", systemImage: "square.stack")
            
            if let tokens = metadata.totalTokens {
                Label("\(tokens) tokens", systemImage: "number")
            }
            
            if let reason = metadata.finishReason {
                Label(reason, systemImage: "flag.checkered")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}

struct StreamStatsView: View {
    let stats: StreamFinalizationManager.StreamStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stream Statistics")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatItem(label: "Total Chunks", value: "\(stats.totalChunks)")
                StatItem(label: "Total Tokens", value: "\(stats.totalTokens)")
                StatItem(label: "Duration", value: String(format: "%.2fs", stats.duration))
                StatItem(label: "Avg Chunk Delay", value: String(format: "%.3fs", stats.averageChunkDelay))
                StatItem(label: "Throughput", value: String(format: "%.1f tok/s", stats.throughput))
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
        }
    }
}
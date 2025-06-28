import SwiftUI
import DeepSeekKit

// Counting tokens as they stream
struct TokenCountingStreamView: View {
    @StateObject private var tokenCounter = StreamingTokenCounter()
    @State private var prompt = ""
    @State private var showCostBreakdown = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Real-time Token Counting")
                .font(.largeTitle)
                .bold()
            
            // Live token meter
            TokenMeterView(counter: tokenCounter)
            
            // Messages with token annotations
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(tokenCounter.messages) { message in
                        TokenAnnotatedMessageView(message: message)
                    }
                    
                    if tokenCounter.isStreaming {
                        LiveTokenStreamView(counter: tokenCounter)
                    }
                }
                .padding()
            }
            
            // Cost breakdown
            if showCostBreakdown {
                CostBreakdownView(usage: tokenCounter.currentUsage)
            }
            
            // Input with estimated tokens
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Enter your message", text: $prompt)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Send") {
                        Task {
                            await tokenCounter.streamWithTokenCounting(prompt)
                            prompt = ""
                        }
                    }
                    .disabled(prompt.isEmpty || tokenCounter.isStreaming)
                }
                
                if !prompt.isEmpty {
                    Text("Estimated tokens: ~\(tokenCounter.estimateTokens(for: prompt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Toggle cost breakdown
            Button(action: { showCostBreakdown.toggle() }) {
                Label(showCostBreakdown ? "Hide Costs" : "Show Costs", 
                      systemImage: "dollarsign.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// Streaming token counter with real-time tracking
@MainActor
class StreamingTokenCounter: ObservableObject {
    @Published var messages: [TokenTrackedMessage] = []
    @Published var isStreaming = false
    @Published var currentUsage = TokenUsage()
    @Published var liveTokenCount = 0
    @Published var tokenRate: Double = 0 // tokens per second
    
    private let client = DeepSeekClient()
    private var streamStartTime: Date?
    private var lastTokenUpdate: Date?
    private var tokenHistory: [(timestamp: Date, count: Int)] = []
    
    struct TokenTrackedMessage: Identifiable {
        let id = UUID()
        let role: String
        var content: String
        var tokenInfo: TokenInfo
        let timestamp = Date()
        
        struct TokenInfo {
            var promptTokens: Int = 0
            var completionTokens: Int = 0
            var totalTokens: Int = 0
            var estimatedTokens: Int = 0
            var tokenChunks: [TokenChunk] = []
            
            struct TokenChunk {
                let content: String
                let tokenCount: Int
                let timestamp: Date
            }
        }
    }
    
    struct TokenUsage {
        var totalPromptTokens: Int = 0
        var totalCompletionTokens: Int = 0
        var totalTokens: Int = 0
        var sessionCost: Double = 0
        
        // Pricing per 1M tokens (example rates)
        let promptTokenPrice: Double = 0.5
        let completionTokenPrice: Double = 1.5
        
        var promptCost: Double {
            Double(totalPromptTokens) / 1_000_000 * promptTokenPrice
        }
        
        var completionCost: Double {
            Double(totalCompletionTokens) / 1_000_000 * completionTokenPrice
        }
        
        var totalCost: Double {
            promptCost + completionCost
        }
    }
    
    func streamWithTokenCounting(_ prompt: String) async {
        isStreaming = true
        streamStartTime = Date()
        tokenHistory = []
        liveTokenCount = 0
        
        // Add user message with estimated tokens
        let userMessage = TokenTrackedMessage(
            role: "user",
            content: prompt,
            tokenInfo: TokenTrackedMessage.TokenInfo(
                promptTokens: estimateTokens(for: prompt),
                estimatedTokens: estimateTokens(for: prompt)
            )
        )
        messages.append(userMessage)
        
        // Create assistant message
        var assistantMessage = TokenTrackedMessage(
            role: "assistant",
            content: "",
            tokenInfo: TokenTrackedMessage.TokenInfo()
        )
        let messageId = assistantMessage.id
        messages.append(assistantMessage)
        
        // Stream and count tokens
        await performTokenCountingStream(
            messageId: messageId,
            prompt: prompt
        )
        
        isStreaming = false
    }
    
    private func performTokenCountingStream(messageId: UUID, prompt: String) async {
        var chunkBuffer = ""
        var chunkCount = 0
        
        do {
            for try await chunk in client.streamMessage(prompt) {
                let now = Date()
                
                // Process content
                if let content = chunk.choices.first?.delta.content {
                    chunkBuffer += content
                    chunkCount += 1
                    
                    // Update message
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index].content += content
                        
                        // Estimate tokens for this chunk (rough estimation)
                        let chunkTokens = estimateTokens(for: content)
                        
                        // Record chunk info
                        let tokenChunk = TokenTrackedMessage.TokenInfo.TokenChunk(
                            content: content,
                            tokenCount: chunkTokens,
                            timestamp: now
                        )
                        messages[index].tokenInfo.tokenChunks.append(tokenChunk)
                        
                        // Update estimated tokens
                        messages[index].tokenInfo.estimatedTokens += chunkTokens
                    }
                }
                
                // Process usage data
                if let usage = chunk.usage {
                    updateTokenCounts(usage: usage, timestamp: now)
                    
                    // Update message token info
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index].tokenInfo.promptTokens = usage.promptTokens
                        messages[index].tokenInfo.completionTokens = usage.completionTokens
                        messages[index].tokenInfo.totalTokens = usage.totalTokens
                    }
                }
                
                // Calculate token rate
                updateTokenRate()
            }
        } catch {
            print("Stream error: \(error)")
        }
        
        // Final token reconciliation
        reconcileTokenCounts(messageId: messageId)
    }
    
    private func updateTokenCounts(usage: ChatCompletionUsage, timestamp: Date) {
        // Update live count
        liveTokenCount = usage.totalTokens
        
        // Update usage totals
        currentUsage.totalPromptTokens = usage.promptTokens
        currentUsage.totalCompletionTokens = usage.completionTokens
        currentUsage.totalTokens = usage.totalTokens
        
        // Record history
        tokenHistory.append((timestamp: timestamp, count: usage.totalTokens))
        lastTokenUpdate = timestamp
    }
    
    private func updateTokenRate() {
        guard let startTime = streamStartTime,
              tokenHistory.count > 1 else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        if duration > 0 {
            tokenRate = Double(liveTokenCount) / duration
        }
        
        // Calculate rolling average over last 5 data points
        if tokenHistory.count > 5 {
            let recentHistory = tokenHistory.suffix(5)
            let timeDiff = recentHistory.last!.timestamp.timeIntervalSince(recentHistory.first!.timestamp)
            let tokenDiff = recentHistory.last!.count - recentHistory.first!.count
            
            if timeDiff > 0 {
                tokenRate = Double(tokenDiff) / timeDiff
            }
        }
    }
    
    private func reconcileTokenCounts(messageId: UUID) {
        // Reconcile estimated vs actual tokens
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            let estimated = messages[index].tokenInfo.estimatedTokens
            let actual = messages[index].tokenInfo.completionTokens
            
            if actual > 0 {
                let accuracy = Double(min(estimated, actual)) / Double(max(estimated, actual)) * 100
                print("Token estimation accuracy: \(String(format: "%.1f", accuracy))%")
            }
        }
    }
    
    func estimateTokens(for text: String) -> Int {
        // Rough estimation: ~4 characters per token on average
        // In production, use a proper tokenizer
        let words = text.split(separator: " ").count
        let chars = text.count
        
        // More sophisticated estimation
        let wordBasedEstimate = words * 1.3
        let charBasedEstimate = Double(chars) / 4.0
        
        return Int((wordBasedEstimate + charBasedEstimate) / 2)
    }
}

// UI Components
struct TokenMeterView: View {
    @ObservedObject var counter: StreamingTokenCounter
    
    var body: some View {
        VStack(spacing: 16) {
            // Live token counter
            HStack {
                VStack(alignment: .leading) {
                    Text("Live Tokens")
                        .font(.headline)
                    Text("\(counter.liveTokenCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", counter.tokenRate)) tok/s")
                        .font(.system(.title3, design: .rounded))
                        .foregroundColor(.blue)
                }
            }
            
            // Token breakdown
            HStack(spacing: 20) {
                TokenStatView(
                    label: "Prompt",
                    value: counter.currentUsage.totalPromptTokens,
                    color: .green
                )
                
                TokenStatView(
                    label: "Completion",
                    value: counter.currentUsage.totalCompletionTokens,
                    color: .blue
                )
                
                TokenStatView(
                    label: "Total",
                    value: counter.currentUsage.totalTokens,
                    color: .purple
                )
            }
            
            // Progress bar
            if counter.isStreaming {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TokenStatView: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TokenAnnotatedMessageView: View {
    let message: StreamingTokenCounter.TokenTrackedMessage
    @State private var showChunkDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with token count
            HStack {
                Text(message.role.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                TokenBadge(tokenInfo: message.tokenInfo)
            }
            
            // Content
            Text(message.content)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            // Token details
            HStack {
                if message.tokenInfo.estimatedTokens > 0 {
                    Label("~\(message.tokenInfo.estimatedTokens) estimated", 
                          systemImage: "number.square")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if !message.tokenInfo.tokenChunks.isEmpty {
                    Button(action: { showChunkDetails.toggle() }) {
                        Label("\(message.tokenInfo.tokenChunks.count) chunks", 
                              systemImage: "square.stack")
                            .font(.caption2)
                    }
                }
            }
            
            // Chunk details
            if showChunkDetails && !message.tokenInfo.tokenChunks.isEmpty {
                ChunkDetailsView(chunks: message.tokenInfo.tokenChunks)
            }
        }
    }
}

struct TokenBadge: View {
    let tokenInfo: StreamingTokenCounter.TokenTrackedMessage.TokenInfo
    
    var body: some View {
        HStack(spacing: 8) {
            if tokenInfo.promptTokens > 0 {
                Label("\(tokenInfo.promptTokens)", systemImage: "arrow.right.circle")
                    .foregroundColor(.green)
            }
            
            if tokenInfo.completionTokens > 0 {
                Label("\(tokenInfo.completionTokens)", systemImage: "arrow.left.circle")
                    .foregroundColor(.blue)
            }
            
            if tokenInfo.totalTokens > 0 {
                Label("\(tokenInfo.totalTokens)", systemImage: "sum")
                    .foregroundColor(.purple)
            }
        }
        .font(.caption2)
    }
}

struct LiveTokenStreamView: View {
    @ObservedObject var counter: StreamingTokenCounter
    @State private var animationValue = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(animationValue)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: animationValue
                    )
                
                Text("LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Spacer()
                
                Text("\(counter.liveTokenCount) tokens")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
            }
            
            // Token flow visualization
            TokenFlowVisualization(rate: counter.tokenRate)
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(10)
        .onAppear { animationValue = 1.0 }
    }
}

struct TokenFlowVisualization: View {
    let rate: Double
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                // Moving tokens
                HStack(spacing: 20) {
                    ForEach(0..<10) { _ in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }
                }
                .offset(x: offset)
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        offset = -geometry.size.width
                    }
                }
            }
        }
        .frame(height: 8)
    }
}

struct ChunkDetailsView: View {
    let chunks: [StreamingTokenCounter.TokenTrackedMessage.TokenInfo.TokenChunk]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Token Chunks")
                .font(.caption)
                .fontWeight(.semibold)
            
            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                HStack {
                    Text("#\(index + 1)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                    
                    Text("\"\(String(chunk.content.prefix(20)))...\"")
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(chunk.tokenCount) tokens")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

struct CostBreakdownView: View {
    let usage: StreamingTokenCounter.TokenUsage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Breakdown")
                .font(.headline)
            
            VStack(spacing: 8) {
                CostRow(
                    label: "Prompt Tokens",
                    tokens: usage.totalPromptTokens,
                    rate: usage.promptTokenPrice,
                    cost: usage.promptCost
                )
                
                CostRow(
                    label: "Completion Tokens",
                    tokens: usage.totalCompletionTokens,
                    rate: usage.completionTokenPrice,
                    cost: usage.completionCost
                )
                
                Divider()
                
                HStack {
                    Text("Total Cost")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(String(format: "%.6f", usage.totalCost))")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            Text("Rates shown per 1M tokens")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(10)
    }
}

struct CostRow: View {
    let label: String
    let tokens: Int
    let rate: Double
    let cost: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text("\(tokens) × $\(String(format: "%.2f", rate))/1M")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(String(format: "%.6f", cost))")
                .font(.system(.body, design: .monospaced))
        }
    }
}
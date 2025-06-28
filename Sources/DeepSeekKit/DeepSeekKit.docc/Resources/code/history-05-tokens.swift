import SwiftUI
import DeepSeekKit

class TokenAwareHistoryManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var estimatedTokens: Int = 0
    
    // Model context limits
    private let maxTokens: Int = 32_000 // DeepSeek context window
    private let safetyMargin: Int = 4_000 // Reserve for response
    
    init() {
        addSystemMessage("You are a helpful AI assistant.")
    }
    
    // Rough token estimation (more accurate would use a tokenizer)
    private func estimateTokens(for text: String) -> Int {
        // Rough estimate: ~1 token per 4 characters
        // More accurate: use a proper tokenizer library
        return text.count / 4
    }
    
    private func calculateTotalTokens() -> Int {
        messages.reduce(0) { total, message in
            total + estimateTokens(for: message.content) + 4 // Role tokens
        }
    }
    
    func addMessage(_ message: Message) {
        messages.append(message)
        estimatedTokens = calculateTotalTokens()
        
        // Check if we're approaching limit
        if estimatedTokens > (maxTokens - safetyMargin) {
            trimOldestMessages()
        }
    }
    
    func addSystemMessage(_ content: String) {
        addMessage(Message(role: .system, content: content))
    }
    
    func addUserMessage(_ content: String) {
        addMessage(Message(role: .user, content: content))
    }
    
    func addAssistantMessage(_ content: String) {
        addMessage(Message(role: .assistant, content: content))
    }
    
    private func trimOldestMessages() {
        // Keep system message and trim from oldest
        guard messages.count > 1 else { return }
        
        let systemMessage = messages.first { $0.role == .system }
        var trimmedMessages: [Message] = []
        
        if let system = systemMessage {
            trimmedMessages.append(system)
        }
        
        // Keep most recent messages within token budget
        var tokenCount = trimmedMessages.reduce(0) { 
            $0 + estimateTokens(for: $1.content) + 4 
        }
        
        for message in messages.reversed() {
            let messageTokens = estimateTokens(for: message.content) + 4
            
            if tokenCount + messageTokens < (maxTokens - safetyMargin) {
                trimmedMessages.insert(message, at: 1) // After system message
                tokenCount += messageTokens
            } else {
                break
            }
        }
        
        messages = trimmedMessages
        estimatedTokens = tokenCount
    }
    
    var tokenUsageInfo: String {
        let percentage = Int((Double(estimatedTokens) / Double(maxTokens)) * 100)
        return "\(estimatedTokens) / \(maxTokens) tokens (\(percentage)%)"
    }
}

// UI component to display token usage
struct TokenUsageView: View {
    @ObservedObject var manager: TokenAwareHistoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Token Usage")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: Double(manager.estimatedTokens), 
                        total: Double(32_000))
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(manager.tokenUsageInfo)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}
import SwiftUI
import DeepSeekKit

class SlidingWindowManager: ObservableObject {
    @Published var messages: [Message] = []
    
    // Configuration
    private let windowSize: Int = 20 // Keep last N messages
    private let preserveSystemMessage: Bool = true
    private let preserveFirstUserMessage: Bool = true
    
    init() {
        setupSystemMessage()
    }
    
    private func setupSystemMessage() {
        messages.append(Message(
            role: .system,
            content: "You are a helpful AI assistant with conversation memory."
        ))
    }
    
    func addMessage(_ message: Message) {
        messages.append(message)
        applyWindowStrategy()
    }
    
    private func applyWindowStrategy() {
        guard messages.count > windowSize else { return }
        
        var preservedMessages: [Message] = []
        var slidingMessages: [Message] = []
        
        // Preserve important messages
        for (index, message) in messages.enumerated() {
            if shouldPreserve(message: message, at: index) {
                preservedMessages.append(message)
            } else {
                slidingMessages.append(message)
            }
        }
        
        // Calculate how many sliding messages we can keep
        let preservedCount = preservedMessages.count
        let availableSlots = windowSize - preservedCount
        
        // Take the most recent messages from sliding window
        let recentMessages = Array(slidingMessages.suffix(availableSlots))
        
        // Reconstruct message history
        messages = preservedMessages + recentMessages
        
        // Sort by original order if needed
        sortMessagesByTimestamp()
    }
    
    private func shouldPreserve(message: Message, at index: Int) -> Bool {
        // Always preserve system messages
        if preserveSystemMessage && message.role == .system {
            return true
        }
        
        // Preserve first user message for context
        if preserveFirstUserMessage && 
           message.role == .user && 
           isFirstUserMessage(at: index) {
            return true
        }
        
        return false
    }
    
    private func isFirstUserMessage(at index: Int) -> Bool {
        let userMessages = messages.enumerated()
            .filter { $0.element.role == .user }
        
        return userMessages.first?.offset == index
    }
    
    private func sortMessagesByTimestamp() {
        // If messages have timestamps, sort by them
        // For this example, we maintain insertion order
    }
    
    // Get messages for API request
    func getMessagesForRequest() -> [Message] {
        // Include a summary of dropped messages if needed
        var requestMessages = messages
        
        if hasDroppedMessages {
            // Insert a summary after system message
            let summary = createDroppedMessagesSummary()
            if let systemIndex = requestMessages.firstIndex(where: { $0.role == .system }) {
                requestMessages.insert(summary, at: systemIndex + 1)
            }
        }
        
        return requestMessages
    }
    
    private var hasDroppedMessages: Bool {
        // Track if we've dropped messages
        return messages.count >= windowSize
    }
    
    private func createDroppedMessagesSummary() -> Message {
        Message(
            role: .assistant,
            content: "[Previous conversation context has been summarized to fit within token limits]"
        )
    }
}

// Demonstration view
struct SlidingWindowDemoView: View {
    @StateObject private var manager = SlidingWindowManager()
    @State private var messageCount = 0
    
    var body: some View {
        VStack {
            Text("Sliding Window Demo")
                .font(.title)
            
            Text("Window Size: 20 messages")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(manager.messages.enumerated()), id: \.offset) { index, message in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(message.role.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(message.content.prefix(50)) + "...")
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .frame(height: 300)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            HStack {
                Button("Add User Message") {
                    messageCount += 1
                    manager.addMessage(Message(
                        role: .user,
                        content: "User message #\(messageCount)"
                    ))
                }
                
                Button("Add Assistant Message") {
                    manager.addMessage(Message(
                        role: .assistant,
                        content: "Response to message #\(messageCount)"
                    ))
                }
            }
            .padding()
            
            Text("Current messages: \(manager.messages.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
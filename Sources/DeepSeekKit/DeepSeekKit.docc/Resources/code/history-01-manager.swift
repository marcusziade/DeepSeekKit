import SwiftUI
import DeepSeekKit

// Message history manager for conversation management
class MessageHistoryManager: ObservableObject {
    @Published var messages: [Message] = []
    
    private let maxMessages = 100
    
    init() {
        // Initialize with a system message
        addSystemMessage("You are a helpful AI assistant.")
    }
    
    func addSystemMessage(_ content: String) {
        let message = Message(role: .system, content: content)
        messages.append(message)
    }
    
    func addUserMessage(_ content: String) {
        let message = Message(role: .user, content: content)
        messages.append(message)
        
        // Trim if exceeds max
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
    }
    
    func addAssistantMessage(_ content: String) {
        let message = Message(role: .assistant, content: content)
        messages.append(message)
    }
    
    func clearHistory() {
        messages.removeAll()
        // Re-add system message
        addSystemMessage("You are a helpful AI assistant.")
    }
}
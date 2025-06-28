import SwiftUI
import DeepSeekKit

class MessageHistoryManager: ObservableObject {
    @Published var messages: [Message] = []
    
    private let maxMessages = 100
    
    init() {
        // System message sets the AI's behavior
        addSystemMessage("You are a helpful AI assistant.")
    }
    
    func addSystemMessage(_ content: String) {
        // System: Sets AI behavior, personality, constraints
        let message = Message(role: .system, content: content)
        messages.append(message)
    }
    
    func addUserMessage(_ content: String) {
        // User: Human input to the conversation
        let message = Message(role: .user, content: content)
        messages.append(message)
        
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
    }
    
    func addAssistantMessage(_ content: String) {
        // Assistant: AI's response to user
        let message = Message(role: .assistant, content: content)
        messages.append(message)
    }
    
    func addFunctionMessage(name: String, content: String) {
        // Function: Results from function calls
        let message = Message(
            role: .function,
            content: content,
            name: name
        )
        messages.append(message)
    }
    
    // Example: Setting up a specialized assistant
    func setupSpecializedAssistant(expertise: String) {
        clearHistory()
        addSystemMessage("""
            You are an expert \(expertise) assistant.
            Provide detailed, accurate information about \(expertise).
            If you're unsure about something, say so.
            Use examples when helpful.
            """)
    }
    
    func clearHistory() {
        messages.removeAll()
        addSystemMessage("You are a helpful AI assistant.")
    }
}